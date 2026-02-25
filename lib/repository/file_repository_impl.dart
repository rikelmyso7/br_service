import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';

import '../models/excel_data.dart';
import '../models/invalid_doc_plano.dart';
import '../models/process_event.dart';
import '../models/processing_filters.dart';
import '../models/validation_item.dart';
import '../services/daemon_service.dart';
import 'file_repository.dart';

/// Pool de processos CLI para reutilizar e reduzir overhead de spawn
class _CLIProcessPool {
  static const int maxIdleTime = 30; // segundos
  Process? _idleProcess;
  DateTime? _lastUsed;

  bool get hasIdleProcess =>
      _idleProcess != null &&
      _lastUsed != null &&
      DateTime.now().difference(_lastUsed!) < Duration(seconds: maxIdleTime);

  void markUsed() {
    _lastUsed = DateTime.now();
  }

  void setProcess(Process? proc) {
    _idleProcess = proc;
    _lastUsed = DateTime.now();
  }

  Process? getProcess() {
    if (hasIdleProcess) {
      final proc = _idleProcess;
      _idleProcess = null;
      return proc;
    }
    return null;
  }

  void cleanup() {
    _idleProcess?.kill();
    _idleProcess = null;
  }
}

class FileRepositoryImpl implements FileRepository {
  final log = Logger('FileRepositoryImpl');
  Process? _currentProcess;
  StreamController<ProcessEvent>? _eventController;
  final _CLIProcessPool _processPool = _CLIProcessPool();

  // Armazena dados do último arquivo analisado
  Map<String, dynamic>? _lastCliData;
  String? _lastAnalyzedFile;

  /// Verifica se um arquivo está aberto/sendo usado por outro processo
  Future<bool> _isFileInUse(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      // Tenta abrir o arquivo em modo de escrita exclusiva
      final randomAccessFile = await file.open(mode: FileMode.append);
      await randomAccessFile.close();
      return false; // Arquivo não está em uso
    } catch (e) {
      // Se falhar ao abrir, provavelmente está em uso
      return true;
    }
  }

  /// Verifica se o arquivo pode ser processado (não está aberto)
  Future<void> _checkFileAvailable(String filePath) async {
    final isInUse = await _isFileInUse(filePath);
    if (isInUse) {
      throw Exception(
        'O arquivo está aberto em outro programa. '
        'Feche o arquivo no Excel (ou outro programa) e tente novamente.',
      );
    }
  }

  Future<void> swapAccountNumber(String path, String accountNumber) async {
    await _checkFileAvailable(path);

    final exe = await _getExecutable();
    final args = ['--input', path, '--conta', accountNumber];

    log.info('swapAccountNumber: ${exe.path} ${args.join(' ')}');

    final result = await Process.run(
      exe.path,
      args,
      runInShell: true,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );

    log.fine('swapAccountNumber stdout: ${result.stdout}');
    if (result.stderr.toString().isNotEmpty) {
      log.warning('swapAccountNumber stderr: ${result.stderr}');
    }

    if (result.exitCode != 0) {
      throw Exception(
        'Falha ao trocar número da conta (code=${result.exitCode}): ${result.stderr}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // NOVO: obter TODOS os dados em uma única chamada via CLI --get-all
  // Combina: get-options + get-datas + get-contas
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getAllData(String path) async {
    log.info('📦 get-all via daemon: $path');
    await _checkFileAvailable(path);

    final map = await BRServiceDaemon.instance.send('get-all', path);

    if (map.containsKey('erro')) {
      log.severe('❌ get-all erro: ${map['erro']}');
      throw Exception('Falha ao obter dados: ${map['erro']}');
    }

    log.info('✅ get-all OK — keys: ${map.keys.join(', ')}');

    map['invalidDocPlanos'] = <Map<String, dynamic>>[];
    _lastCliData = Map<String, dynamic>.from(map);
    _lastAnalyzedFile = path;
    return map;
  }

  // ---------------------------------------------------------------------------
  // NOVO: obter datas por documento via CLI --get-datas
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getDatesByDocument(String path) async {
    log.info('🗓️ get-datas via daemon: $path');
    await _checkFileAvailable(path);
    final map = await BRServiceDaemon.instance.send('get-datas', path);
    if (map.containsKey('erro')) throw Exception('get-datas: ${map['erro']}');
    return map;
  }

  // ---------------------------------------------------------------------------
  // NOVO: análise via CLI (sem heurística no Flutter)
  // Retorna o JSON emitido pelo --get-options (documentos, planos_por_documento, datas)
  // ---------------------------------------------------------------------------
  @override
  Future<Map<String, dynamic>> analyzeFile(String path) async {
    log.info('🔎 get-options via daemon: $path');
    await _checkFileAvailable(path);
    final map = await BRServiceDaemon.instance.send('get-options', path);
    if (map.containsKey('erro')) throw Exception('get-options: ${map['erro']}');
    map['invalidDocPlanos'] = <Map<String, dynamic>>[];
    _lastCliData = Map<String, dynamic>.from(map);
    _lastAnalyzedFile = path;
    return map;
  }

  // ---------------------------------------------------------------------------
  // Apenas LEITURA para exibir a planilha (via CLI --get-preview)
  // ---------------------------------------------------------------------------

  /// Resolve o caminho do executável sem usar rootBundle (seguro em Isolates).
  @override
  Future<ExcelData> loadExcelFile(String path, {String? executablePath}) async {
    try {
      await _checkFileAvailable(path);
      log.info('📄 Carregando preview via CLI: $path');
      // executablePath é pré-resolvido no isolate pai (evita rootBundle em isolate)
      final exePath = executablePath ?? (await _getExecutable()).path;
      final result = await Process.run(
        exePath,
        ['--input', path, '--get-preview', '--quiet'],
        runInShell: true,
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );

      if (result.exitCode != 0) {
        final msg = 'CLI --get-preview falhou (code=${result.exitCode}): ${result.stderr}';
        log.severe(msg);
        throw Exception(msg);
      }

      final data = json.decode(result.stdout.toString().trim()) as Map<String, dynamic>;
      if (data.containsKey('erro')) {
        log.severe('Erro retornado pelo CLI --get-preview: ${data['erro']}');
        throw Exception(data['erro']);
      }

      final headers = (data['headers'] as List<dynamic>).cast<String>();
      final rows = (data['rows'] as List<dynamic>)
          .map((r) => (r as List<dynamic>).cast<String>())
          .toList();

      log.info('✅ Preview carregado: ${headers.length} colunas, ${rows.length} linhas');
      return ExcelData(
        fileName: p.basename(path),
        headers: headers,
        rows: rows,
        docPlanos: const [],
      );
    } catch (e, st) {
      log.severe('❌ Erro ao carregar preview do arquivo: $path', e, st);
      throw Exception('Erro ao ler arquivo Excel: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Método para analisar contas ativas/inativas usando CLI --get-contas
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getContasAnalysis(String filePath) async {
    try {
      print('🔍 Executando análise de contas CLI para: $filePath');
      await _checkFileAvailable(filePath);
      
      final exe = await _getExecutable();
      final args = ['--input', filePath, '--get-contas'];

      final result = await Process.run(
        exe.path,
        args,
        runInShell: true,
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );

      print('🔍 CLI getContasAnalysis executado:');
      print('   📤 Exit code: ${result.exitCode}');
      print('   📄 Stdout length: ${result.stdout.toString().length} chars');
      
      if (result.exitCode != 0) {
        print('❌ CLI falhou: ${result.stderr}');
        return {'erro': 'CLI falhou: ${result.stderr}'};
      }

      final output = result.stdout.toString().trim();
      print('   📄 Stdout: $output');

      // Parse do JSON retornado pelo CLI
      try {
        final jsonData = jsonDecode(output);
        print('✅ JSON parseado com sucesso');
        print('   🗝️ Keys: ${jsonData.keys.toList()}');
        
        if (jsonData.containsKey('contas_ativas')) {
          print('   ✅ Contas ativas: ${jsonData['contas_ativas']}');
        }
        if (jsonData.containsKey('contas_inativas')) {
          print('   ❌ Contas inativas: ${jsonData['contas_inativas']}');
        }
        
        return jsonData;
      } catch (e) {
        print('❌ Erro ao fazer parse do JSON: $e');
        return {'erro': 'Erro ao fazer parse do JSON: $e'};
      }
      
    } catch (e) {
      print('❌ Erro ao executar CLI getContasAnalysis: $e');
      return {'erro': 'Erro ao executar CLI: $e'};
    }
  }

  // ---------------------------------------------------------------------------
  // Métodos para acessar dados salvos do CLI
  // ---------------------------------------------------------------------------

  /// Verifica se os dados salvos são do arquivo especificado
  bool hasCliDataFor(String filePath) {
    final hasData = _lastAnalyzedFile == filePath && _lastCliData != null;
    print('🔍 hasCliDataFor($filePath): $hasData');
    print('   📄 _lastAnalyzedFile: $_lastAnalyzedFile');
    print('   📋 _lastCliData != null: ${_lastCliData != null}');
    return hasData;
  }

  /// Converte dados do CLI em DocPlanos
  List<DocPlano> _parseDocPlanos(Map<String, dynamic> cliData) {
    final List<DocPlano> docPlanos = [];
    final planosMap =
        (cliData['planos_por_documento'] as Map<String, dynamic>?) ?? {};

    planosMap.forEach((documento, planos) {
      final planList = (planos as List<dynamic>).cast<String>();
      for (final plano in planList) {
        docPlanos.add(DocPlano(documento, plano));
      }
    });

    return docPlanos;
  }

  // ---------------------------------------------------------------------------
  // Validação completa usando dados do CLI
  // ---------------------------------------------------------------------------
  @override
  Future<List<ValidationItem>> validateFile(String filePath) async {
    log.info('🔍 Validação via daemon (get-all): $filePath');
    try {
      final cliData = await BRServiceDaemon.instance.send('get-all', filePath);
      if (cliData.containsKey('erro')) {
        throw Exception(cliData['erro']);
      }

      final documentos =
          (cliData['documentos'] as List<dynamic>?)?.cast<String>() ?? [];
      final planosMap =
          (cliData['planos_por_documento'] as Map<String, dynamic>?) ?? {};
      final datas = (cliData['datas'] as List<dynamic>?)?.cast<String>() ?? [];
      final docPlanos = _parseDocPlanos(cliData);

      return [
        ValidationItem(
          title: 'Planilha "Layout" presente',
          description: 'Arquivo deve conter a aba Layout',
          isValid: true,
        ),
        ValidationItem(
          title: 'Documentos identificados',
          description: 'Pelo menos um documento detectado pelo CLI',
          isValid: documentos.isNotEmpty,
          errorMessage:
              documentos.isEmpty ? 'Nenhum documento foi identificado' : null,
        ),
        ValidationItem(
          title: 'Planos por documento',
          description: 'Cada documento deve ter pelo menos um plano',
          isValid:
              planosMap.isNotEmpty &&
              planosMap.values.every(
                (planos) => (planos as List<dynamic>).isNotEmpty,
              ),
          errorMessage:
              (planosMap.isEmpty ||
                      !planosMap.values.every(
                        (planos) => (planos as List<dynamic>).isNotEmpty,
                      ))
                  ? 'Alguns documentos não possuem planos associados'
                  : null,
        ),
        ValidationItem(
          title: 'Datas identificadas',
          description: 'Pelo menos uma data válida encontrada',
          isValid: datas.isNotEmpty,
          errorMessage:
              datas.isEmpty ? 'Nenhuma data válida foi identificada' : null,
        ),
        ValidationItem(
          title: 'Pares Documento-Plano',
          description: 'Combinações válidas de Documento e Plano detectadas',
          isValid: docPlanos.isNotEmpty,
          errorMessage:
              docPlanos.isEmpty
                  ? 'Nenhuma combinação Documento-Plano válida encontrada'
                  : null,
        ),
      ];
    } catch (e) {
      log.severe('Erro ao validar arquivo: $e');
      return [
        ValidationItem(
          title: 'Erro na análise CLI',
          description: 'Falha ao analisar arquivo com CLI',
          isValid: false,
          errorMessage: 'Erro na análise: $e',
        ),
      ];
    }
  }

  // ---------------------------------------------------------------------------
  // Método para obter estatísticas detalhadas
  // ---------------------------------------------------------------------------
  @override
  Future<Map<String, dynamic>> getDetailedFileStats(String filePath) async {
    log.info('📊 getDetailedFileStats via daemon (get-all): $filePath');
    try {
      final cliData = await BRServiceDaemon.instance.send('get-all', filePath);
      if (cliData.containsKey('erro')) {
        throw Exception(cliData['erro']);
      }

      // Verifica se há problema com colunas obrigatórias
      final colunasObrigatorias =
          (cliData['colunas_obrigatorias'] as Map<String, dynamic>?) ?? {};
      final todasColunasPresentes =
          colunasObrigatorias['todas_presentes'] as bool? ?? true;

      if (!todasColunasPresentes) {
        final ausentes =
            (colunasObrigatorias['ausentes'] as List<dynamic>?)
                ?.cast<String>() ??
            [];
        log.warning('Arquivo com colunas ausentes: ${ausentes.join(", ")} — continuando com dados disponíveis');
      }

      // Usa contagens reais do CLI (se disponível)
      final blockCounts =
          (cliData['block_counts'] as Map<String, dynamic>?) ?? {};
      final Map<String, int> countsPerDocPlano = {};

      // Converte blockCounts para formato documento-plano
      blockCounts.forEach((blockName, count) {
        if (count is int) {
          countsPerDocPlano[blockName] = count;
        } else if (count is num) {
          countsPerDocPlano[blockName] = count.toInt();
        }
      });

      final documentos =
          (cliData['documentos'] as List<dynamic>?)?.cast<String>() ?? [];
      final datasRaw =
          (cliData['datas'] as List<dynamic>?)?.cast<String>() ?? [];
      final datasPorDocumento =
          (cliData['datas_por_documento'] as Map<String, dynamic>?) ?? {};

      final datas = datasRaw.map(_convertDateFromCli).toList();

      final Map<String, List<String>> datesByDocument = {};
      datasPorDocumento.forEach((documento, datasRawDoc) {
        if (datasRawDoc is List) {
          datesByDocument[documento] =
              (datasRawDoc as List<dynamic>)
                  .cast<String>()
                  .map(_convertDateFromCli)
                  .toList();
        }
      });

      final docPlanos = _parseDocPlanos(cliData);
      log.fine('📋 DocPlanos: ${docPlanos.length}, Docs: ${documentos.length}, Datas: ${datas.length}');

      final processingFilters = ProcessingFilters(
        selectedDocuments: [], // Inicia vazio para o usuário selecionar
        selectedDates: [], // Inicia vazio para o usuário selecionar
        availableDocuments: documentos,
        availableDates: datas,
        availableDocPlanos: docPlanos,
        datesByDocument: datesByDocument,
        recordCountsByDocument: countsPerDocPlano,
      );
      return {
        'docPlanos':
            docPlanos
                .map((dp) => {'documento': dp.documento, 'plano': dp.plano})
                .toList(),
        'countsPerDocPlano': countsPerDocPlano,
        'totalCombinations': countsPerDocPlano.length,
        'nonEmptyCombinations':
            countsPerDocPlano.values.where((count) => count > 0).length,
        'totalRecords': countsPerDocPlano.values.fold(
          0,
          (sum, count) => sum + count,
        ),
        'colunasObrigatorias': colunasObrigatorias,
        if (!todasColunasPresentes)
          'aviso': 'Colunas obrigatórias ausentes: ${((colunasObrigatorias['ausentes'] as List<dynamic>?)?.cast<String>() ?? []).join(", ")}',
        'processingFilters': {
          'selectedDocuments': processingFilters.selectedDocuments,
          'selectedDates': processingFilters.selectedDates,
          'availableDocuments': processingFilters.availableDocuments,
          'availableDates': processingFilters.availableDates,
          'availableDocPlanos':
              processingFilters.availableDocPlanos
                  .map((dp) => {'documento': dp.documento, 'plano': dp.plano})
                  .toList(),
          'datesByDocument': processingFilters.datesByDocument,
          'recordCountsByDocument': processingFilters.recordCountsByDocument,
        },
        'invalidDocPlanos': cliData['invalidDocPlanos'] ?? [],
      };
    } catch (e, st) {
      log.severe('Erro ao obter estatísticas detalhadas: $e\n$st');
      return {
        'docPlanos': [],
        'countsPerDocPlano': <String, int>{},
        'totalCombinations': 0,
        'nonEmptyCombinations': 0,
        'totalRecords': 0,
        'colunasObrigatorias': {
          'todas_presentes': false,
          'presentes': [],
          'ausentes': ['Contrato', 'Valor', 'Data Crédito'],
        },
        'erro': 'Erro ao analisar arquivo: $e',
        'processingFilters': {
          'selectedDocuments': <String>[],
          'selectedDates': <String>[],
          'availableDocuments': <String>[],
          'availableDates': <String>[],
          'availableDocPlanos': <Map<String, dynamic>>[],
          'datesByDocument': <String, List<String>>{},
          'recordCountsByDocument': <String, int>{},
        },
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Processamento (inalterado, segue usando CLI e stream de eventos)
  // ---------------------------------------------------------------------------
  @override
  Stream<ProcessEvent> processFile(
    String input,
    String outDir, {
    ProcessingFilters? filters,
  }) async* {
    StreamController<ProcessEvent>? controller;

    try {
      await _checkFileAvailable(input);
      await _killCurrentProcess();
      controller = StreamController<ProcessEvent>();
      _eventController = controller;

      log.info('🚀 Iniciando processamento do arquivo: $input em $outDir');
      controller.add(LogEvent('Iniciando processamento...'));
      controller.add(ProgressEvent(0, 'Preparando ambiente...'));

      final exe = await _getExecutable();
      log.info('📋 Executável encontrado: ${exe.path}');
      controller.add(LogEvent('Executável carregado: ${exe.path}'));
      controller.add(ProgressEvent(10, 'Iniciando processo CLI...'));

      // Constrói argumentos com filtros opcionais
      final args = ['--input', input, '--output', outDir, '--progress'];

      if (filters != null) {
        if (filters.selectedDocuments.isNotEmpty) {
          args.addAll(['--documentos', filters.documentosForCli]);
        }
        if (filters.selectedDates.isNotEmpty) {
          args.addAll(['--datas', filters.datasForCli]);
        }
      }

      log.info('📋 Argumentos CLI: $args');
      controller.add(LogEvent('Argumentos: ${args.join(' ')}'));

      _currentProcess = await Process.start(
        exe.path,
        args,
        runInShell: false, // Evita buffering adicional do shell
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUNBUFFERED': '1', // CRÍTICO: Desabilita buffering do Python
          'CHCP': '65001', // UTF-8 no Windows
        },
      );

      if (_currentProcess == null) {
        log.severe('Falha ao iniciar o processo CLI');
        throw Exception('Falha ao iniciar o processo CLI');
      }

      controller.add(
        LogEvent('Processo CLI iniciado (PID: ${_currentProcess!.pid})'),
      );
      controller.add(ProgressEvent(20, 'Conectando com CLI...'));

      final stdoutStream = _currentProcess!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .handleError((error) {
            log.severe('❌ Erro no stdout: $error');
            controller?.add(LogEvent('Erro no stdout: $error'));
          });

      final stderrStream = _currentProcess!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .handleError((error) {
            log.severe('❌ Erro no stderr: $error');
            controller?.add(LogEvent('Erro no stderr: $error'));
          });

      final combinedStream = stdoutStream.mergeWith([stderrStream]);

      int logCount = 0;
      int currentProgress = 20; // Inicia em 20% após conexão
      int blocksProcessed = 0;
      DateTime lastProgressUpdate = DateTime.now();
      DateTime startTime = DateTime.now();

      // Timer de heartbeat para atualizar progresso periodicamente
      Timer? heartbeatTimer;
      heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (controller == null || controller.isClosed) {
          heartbeatTimer?.cancel();
          return;
        }
        // Incrementa progresso lentamente baseado no tempo decorrido
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        final timeBasedProgress = (20 + (elapsed * 2)).clamp(20, 85);
        if (timeBasedProgress > currentProgress) {
          currentProgress = timeBasedProgress;
          controller.add(ProgressEvent(currentProgress, 'Processando... (${elapsed}s)'));
        }
      });

      try {
      await for (final line in combinedStream) {
        if (controller.isClosed) break;

        try {
          if (line.trim().isEmpty) continue;

          // Tenta parsear como JSON (eventos do CLI)
          if (line.trimLeft().startsWith('{')) {
            final event = _parseProcessOutput(line);
            controller.add(event);
            if (event is ErrorEvent) break;
          } else {
            controller.add(LogEvent(line));
            logCount++;

            // Detecção inteligente de progresso baseado em marcos
            final lowerLine = line.toLowerCase();
            int progressIncrement = 0;
            String? operation;

            // Marcos específicos do processamento
            if (lowerLine.contains('carregando') || lowerLine.contains('lendo arquivo')) {
              progressIncrement = 10;
              operation = 'Carregando arquivo...';
            } else if (lowerLine.contains('processando bloco') || lowerLine.contains('bloco ')) {
              blocksProcessed++;
              // Incremento menor por bloco (mais granular)
              progressIncrement = 2;
              operation = 'Processando blocos... ($blocksProcessed blocos)';
            } else if (lowerLine.contains('salvando') || lowerLine.contains('gerando saída')) {
              progressIncrement = 5;
              operation = 'Salvando resultados...';
            } else if (lowerLine.contains('validando') || lowerLine.contains('verificando')) {
              progressIncrement = 3;
              operation = 'Validando dados...';
            } else if (lowerLine.contains('concluí') || lowerLine.contains('finalizado')) {
              progressIncrement = 5;
              operation = 'Finalizando...';
            }

            // Atualiza progresso se detectou um marco OU a cada segundo com logs
            final now = DateTime.now();
            final timeSinceLastUpdate = now.difference(lastProgressUpdate).inMilliseconds;

            if (progressIncrement > 0 || (logCount % 5 == 0 && timeSinceLastUpdate > 500)) {
              if (progressIncrement == 0) {
                progressIncrement = 1; // Incremento mínimo para logs regulares
                operation = 'Processando... ($logCount eventos)';
              }

              currentProgress = (currentProgress + progressIncrement).clamp(20, 95);
              controller.add(ProgressEvent(currentProgress, operation ?? 'Processando...'));
              lastProgressUpdate = now;
            }
          }
        } catch (e, stackTrace) {
          log.severe('❌ Erro ao processar linha "$line": $e', e, stackTrace);
          controller.add(LogEvent('Erro ao processar: $line'));
        }
      }
      } finally {
        heartbeatTimer?.cancel();
      }

      final exitCode = await _currentProcess!.exitCode;
      log.info('🏁 Processo terminou com código: $exitCode');

      if (exitCode == 0) {
        controller.add(LogEvent('Processo finalizado com sucesso'));
        controller.add(ProgressEvent(100, 'Processamento concluído!'));
        controller.add(const CompletedEvent());
      } else {
        log.severe('Processo terminou com erro (código: $exitCode)');
        controller.add(
          LogEvent('Processo terminou com erro (código: $exitCode)'),
        );
        controller.add(
          ErrorEvent('Processo falhou', 'Código de saída: $exitCode'),
        );
      }
    } catch (e, stackTrace) {
      log.severe('❌ Erro geral no processamento: $e', e, stackTrace);
      controller?.add(ErrorEvent('Falha no processamento', '$e\n$stackTrace'));
    } finally {
      await _killCurrentProcess();
      controller?.close();
      _eventController = null;
    }

    yield* controller!.stream;
  }

  // ---------------------------------------------------------------------------
  // Utilitários
  // ---------------------------------------------------------------------------

  /// Converte data de DD/MM/YYYY (CLI) para YYYY-MM-DD (ISO)
  String _convertDateFromCli(String cliDate) {
    try {
      final parts = cliDate.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        final converted = '$year-$month-$day';
        return converted;
      }
    } catch (e) {
      print('❌ Erro ao converter data do CLI: $cliDate -> $e');
    }
    print('⚠️ Retornando data original: $cliDate');
    return cliDate; // Retorna original se falhar
  }

  Future<File> getExecutable() => _getExecutable();

  Future<File> _getExecutable() async {
    log.info('Procurando executável...');
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final executableName =
          Platform.isWindows ? 'br_service_cli.exe' : 'br_service_cli';
      final localExe = File(p.join(exeDir.path, executableName));

      if (await localExe.exists()) {
        log.info('✅ Executável local encontrado: ${localExe.path}');
        return localExe;
      }

      // Se o daemon já está rodando, reutiliza o exe que ele abriu
      final daemonExePath = BRServiceDaemon.instance.executablePath;
      if (daemonExePath != null) {
        log.info('✅ Reutilizando exe do daemon: $daemonExePath');
        return File(daemonExePath);
      }

      log.info('📦 Extraindo executável dos assets...');
      final assetPath =
          Platform.isWindows
              ? 'lib/assets/br_service_cli.exe'
              : 'lib/assets/br_service_cli';
      final bytes = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, executableName));

      try {
        await tempFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        log.info('Executável escrito em: ${tempFile.path}');
      } catch (e) {
        // Arquivo em uso por outro processo (ex: daemon já o abriu) — reutiliza
        if (await tempFile.exists()) {
          log.info('Exe em uso por outro processo, reutilizando: ${tempFile.path}');
          return tempFile;
        }
        rethrow;
      }

      if (!Platform.isWindows) {
        log.info('Definindo permissão de execução para: ${tempFile.path}');
        await Process.run('chmod', ['+x', tempFile.path]);
      }

      log.info('✅ Executável extraído: ${tempFile.path}');
      return tempFile;
    } catch (e, stackTrace) {
      log.severe('❌ Erro ao obter executável: $e', e, stackTrace);
      rethrow;
    }
  }

  ProcessEvent _parseProcessOutput(String line) {
    try {
      final jsonMap = jsonDecode(line);
      final eventType = jsonMap['event'] as String?;

      switch (eventType) {
        case 'progress':
          final pct = jsonMap['pct'] as int? ?? 0;
          final operation = jsonMap['operation'] as String? ?? 'Processando...';
          return ProgressEvent(pct, operation);
        case 'error':
          final msg = jsonMap['msg'] as String? ?? 'Erro desconhecido';
          final details = jsonMap['details'] as String?;
          return ErrorEvent(msg, details);
        case 'done':
          return const CompletedEvent();
        default:
          return LogEvent(line);
      }
    } catch (_) {
      return LogEvent(line);
    }
  }

  Future<void> _killCurrentProcess() async {
    if (_currentProcess != null) {
      try {
        log.info(
          '🔄 Finalizando processo atual (PID: ${_currentProcess!.pid})',
        );
        _currentProcess!.kill();
        await _currentProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () => -1,
        );
        log.info('✅ Processo finalizado');
      } catch (e, s) {
        log.severe('⚠️ Erro ao finalizar processo: $e', e, s);
      } finally {
        _currentProcess = null;
      }
    }
    _eventController?.close();
    _eventController = null;
  }

  void dispose() {
    log.info('🧹 Limpando FileRepositoryImpl...');
    _killCurrentProcess();
    _processPool.cleanup();
    _lastCliData = null;
    _lastAnalyzedFile = null;
  }
}
