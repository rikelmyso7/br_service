import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../models/excel_data.dart';
import '../models/process_event.dart';
import '../models/validation_item.dart';
import 'file_repository.dart';

class FileRepositoryImpl implements FileRepository {
  Process? _currentProcess;
  StreamController<ProcessEvent>? _eventController;

  @override
  Future<ExcelData> loadExcelFile(String path) async {
    try {
      final bytes = File(path).readAsBytesSync();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (!decoder.tables.containsKey('Layout')) {
        throw Exception('A planilha "Layout" não foi encontrada no arquivo.');
      }

      final sheet = decoder.tables['Layout']!;

      if (sheet.rows.isEmpty) {
        throw Exception('A planilha "Layout" está vazia.');
      }

      // ---------------- loadExcelFile ----------------
      int headerRowIdx = sheet.rows.indexWhere((r) => r.any(
          (c) => ((c?.toString() ?? '').trim().toLowerCase()) == 'contrato'));
      if (headerRowIdx == -1) {
        throw Exception('Cabeçalho com a coluna "Contrato" não encontrado.');
      }

      // cabeçalhos reais
      final headers = sheet.rows[headerRowIdx]
          .map((c) => (c?.toString() ?? '').trim())
          .where((h) => h.isNotEmpty)
          .toList();

      // dados
      final dataRows = sheet.rows
          .skip(headerRowIdx + 1)
          .where((r) => r.any((c) => c != null))
          .map((r) => r
              .take(headers.length)
              .map((c) => (c?.toString() ?? '').trim())
              .toList())
          .toList();

      // ---------- EXTRAIR Documento + Plano Financeiro ----------
      final docPlanos = <DocPlano>{};
      if (headerRowIdx > 0) {
        final docRow = sheet.rows[headerRowIdx - 1];

        // percorre procurando pares não‑vazios consecutivos
        for (int i = 0; i < docRow.length - 1; i++) {
          final doc = (docRow[i]?.toString() ?? '').trim();
          final plano = (docRow[i + 1]?.toString() ?? '').trim();
          if (doc.isNotEmpty && plano.isNotEmpty) {
            docPlanos.add(DocPlano(doc, plano));
            i++; // avança para não reprocessar o plano
          }
        }
      }

      return ExcelData(
        fileName: p.basename(path),
        headers: headers,
        rows: dataRows,
        docPlanos: docPlanos.toList(),
      );
    } catch (e) {
      throw Exception('Erro ao ler arquivo Excel: $e');
    }
  }

  @override
  Future<List<ValidationItem>> validateFile(ExcelData data) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      ValidationItem(
        title: 'Planilha "Layout" presente',
        description: 'Arquivo deve conter a aba Layout',
        isValid: true,
      ),
      ValidationItem(
        title: 'Dados válidos',
        description: 'Verificar se os dados estão no formato correto',
        isValid: data.rows.isNotEmpty,
        errorMessage: data.rows.isEmpty ? 'Arquivo não possui dados' : null,
      ),
      ValidationItem(
        title: 'Coluna Contrato',
        description: 'Verificar se existe coluna Contrato',
        isValid: data.headers.contains('Contrato'),
        errorMessage: !data.headers.contains('Contrato')
            ? 'Coluna Contrato é obrigatória'
            : null,
      ),
      ValidationItem(
        title: 'Coluna Data Crédito',
        description: 'Verificar se existe coluna Data Crédito',
        isValid: data.headers.contains('Data Crédito'),
        errorMessage: !data.headers.contains('Data Crédito')
            ? 'Coluna Data Crédito é obrigatória'
            : null,
      ),
      ValidationItem(
        title: 'Documento & Plano detectados',
        description: 'Pelo menos um par Documento‑Plano encontrado',
        isValid: data.docPlanos.isNotEmpty,
        errorMessage: !data.docPlanos.isNotEmpty
            ? 'Nenhum Documento/Plano identificado'
            : null,
      ),
    ];
  }

  @override
  Stream<ProcessEvent> processFile(String input, String outDir) async* {
    StreamController<ProcessEvent>? controller;
    
    try {
      await _killCurrentProcess();
      
      // Cria o controller para eventos
      controller = StreamController<ProcessEvent>();
      _eventController = controller;

      print('🚀 Iniciando processamento do arquivo: $input');
      
      // Emite evento inicial
      controller.add(LogEvent('Iniciando processamento...'));
      controller.add(ProgressEvent(0, 'Preparando ambiente...'));

      final exe = await _getExecutable();
      print('📋 Executável encontrado: ${exe.path}');

      controller.add(LogEvent('Executável carregado: ${exe.path}'));
      controller.add(ProgressEvent(10, 'Iniciando processo CLI...'));

      _currentProcess = await Process.start(
        exe.path,
        ['--input', input, '--output-dir', outDir, '--json'],
        runInShell: true,
        environment: {
          'PYTHONIOENCODING': 'utf-8'
        },
      );

      if (_currentProcess == null) {
        throw Exception('Falha ao iniciar o processo CLI');
      }

      print('🟢 CLI iniciado com PID: ${_currentProcess!.pid}');
      controller.add(LogEvent('Processo CLI iniciado (PID: ${_currentProcess!.pid})'));
      controller.add(ProgressEvent(20, 'Conectando com CLI...'));

      // Combina stdout e stderr
      final stdoutStream = _currentProcess!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .handleError((error) {
            print('❌ Erro no stdout: $error');
            controller?.add(LogEvent('Erro no stdout: $error'));
          });

      final stderrStream = _currentProcess!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .handleError((error) {
            print('❌ Erro no stderr: $error');
            controller?.add(LogEvent('Erro no stderr: $error'));
          });

      final combinedStream = stdoutStream.mergeWith([stderrStream]);

      // Escuta o stream combinado
      await for (final line in combinedStream) {
        if (controller.isClosed) break;
        
        try {
          print('📥 Linha recebida: $line');
          
          if (line.trim().isEmpty) continue;
          
          // Tenta parsear como JSON
          if (line.trimLeft().startsWith('{')) {
            final event = _parseProcessOutput(line);
            controller.add(event);
            
            // Se for um evento de erro, para o processamento
            if (event is ErrorEvent) {
              break;
            }
          } else {
            // Linha de log normal
            controller.add(LogEvent(line));
          }
        } catch (e, stackTrace) {
          print('❌ Erro ao processar linha "$line": $e');
          print('📍 StackTrace: $stackTrace');
          controller.add(LogEvent('Erro ao processar: $line'));
        }
      }

      // Aguarda o processo terminar
      final exitCode = await _currentProcess!.exitCode;
      print('🏁 Processo terminou com código: $exitCode');
      
      if (exitCode == 0) {
        controller.add(LogEvent('Processo finalizado com sucesso'));
        controller.add(ProgressEvent(100, 'Processamento concluído!'));
        controller.add(const CompletedEvent());
      } else {
        controller.add(LogEvent('Processo terminou com erro (código: $exitCode)'));
        controller.add(ErrorEvent('Processo falhou', 'Código de saída: $exitCode'));
      }

    } catch (e, stackTrace) {
      print('❌ Erro geral no processamento: $e');
      print('📍 StackTrace: $stackTrace');
      controller?.add(ErrorEvent('Falha no processamento', '$e\n$stackTrace'));
    } finally {
      await _killCurrentProcess();
      controller?.close();
      _eventController = null;
    }

    // Yield todos os eventos do controller
    yield* controller!.stream;
  }

  Future<File> _getExecutable() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final localExe = File(p.join(exeDir.path, 'br_service_cli.exe'));

      if (await localExe.exists()) {
        print('✅ Executável local encontrado: ${localExe.path}');
        return localExe;
      }

      print('📦 Extraindo executável dos assets...');
      final bytes = await rootBundle.load('lib/assets/br_service_cli.exe');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'br_service_cli.exe'));

      await tempFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', tempFile.path]);
      }

      print('✅ Executável extraído: ${tempFile.path}');
      return tempFile;
    } catch (e, stackTrace) {
      print('❌ Erro ao obter executável: $e');
      print('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }

  ProcessEvent _parseProcessOutput(String line) {
    try {
      final json = jsonDecode(line);
      final eventType = json['event'] as String?;
      
      print('🔍 Evento JSON: $eventType');
      
      switch (eventType) {
        case 'progress':
          final pct = json['pct'] as int? ?? 0;
          final operation = json['operation'] as String? ?? 'Processando...';
          return ProgressEvent(pct, operation);
          
        case 'error':
          final msg = json['msg'] as String? ?? 'Erro desconhecido';
          final details = json['details'] as String?;
          return ErrorEvent(msg, details);
          
        case 'done':
          return const CompletedEvent();
          
        default:
          return LogEvent(line);
      }
    } catch (e) {
      print('❌ Erro ao parsear JSON: $e');
      return LogEvent(line);
    }
  }

  Future<void> _killCurrentProcess() async {
    if (_currentProcess != null) {
      try {
        print('🔄 Finalizando processo atual...');
        _currentProcess!.kill();
        await _currentProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Timeout ao aguardar finalização do processo');
            return -1;
          },
        );
        print('✅ Processo finalizado');
      } catch (e) {
        print('⚠️ Erro ao finalizar processo: $e');
      } finally {
        _currentProcess = null;
      }
    }
    
    _eventController?.close();
    _eventController = null;
  }

  void dispose() {
    print('🧹 Limpando FileRepositoryImpl...');
    _killCurrentProcess();
  }
}