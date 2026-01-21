import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../models/excel_data.dart';
import '../models/invalid_doc_plano.dart';
import '../models/process_event.dart';
import '../models/processing_filters.dart';
import '../models/validation_item.dart';
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

    final proc = await Process.start(
      exe.path,
      args,
      runInShell: true,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _currentProcess = proc;

    final exitCode = await proc.exitCode;

    if (exitCode != 0) {
      throw Exception('Falha ao trocar número da conta (code=$exitCode):');
    }
  }

  // ---------------------------------------------------------------------------
  // NOVO: obter TODOS os dados em uma única chamada via CLI --get-all
  // Combina: get-options + get-datas + get-contas
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getAllData(String path) async {
    log.info('📦 Obtendo todos os dados via CLI (--get-all): $path');
    await _checkFileAvailable(path);
    await _killCurrentProcess();

    final exe = await _getExecutable();
    final args = ['--input', path, '--get-all', '--quiet'];

    final proc = await Process.start(
      exe.path,
      args,
      runInShell: true,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _currentProcess = proc;

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final sub1 = proc.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdoutBuffer.write);
    final sub2 = proc.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderrBuffer.write);

    final exitCode = await proc.exitCode;
    await sub1.cancel();
    await sub2.cancel();

    final out = stdoutBuffer.toString();
    final err = stderrBuffer.toString();

    print('📦 CLI get-all executado:');
    print('   📤 Exit code: $exitCode');
    print('   📄 Stdout length: ${out.length} chars');

    if (exitCode != 0) {
      print('❌ get-all falhou (code=$exitCode)');
      throw Exception(
        'Falha ao obter dados (code=$exitCode): $err',
      );
    }

    try {
      String jsonText;
      if (out.startsWith('{')) {
        final firstNewlineIndex = out.indexOf('\n');
        if (firstNewlineIndex > 0) {
          jsonText = out.substring(0, firstNewlineIndex);
        } else {
          jsonText = out;
        }
      } else {
        throw Exception('Output não começa com JSON válido');
      }

      final map = json.decode(jsonText) as Map<String, dynamic>;
      print('✅ JSON get-all parseado com sucesso');
      print('   🗝️ Keys: ${map.keys.toList()}');
      print('   📄 Has datas_por_documento: ${map.containsKey('datas_por_documento')}');
      print('   📄 Has contas_ativas: ${map.containsKey('contas_ativas')}');
      print('   📄 Has contas_inativas: ${map.containsKey('contas_inativas')}');

      // Captura os docPlanos inválidos do output
      final invalidDocPlanos = _extractInvalidDocPlanos(out + err);
      map['invalidDocPlanos'] = invalidDocPlanos
          .map((invalid) => {
                'docPlano': invalid.docPlano,
                'motivo': invalid.motivo,
              })
          .toList();

      // Salva os dados do CLI para uso posterior
      _lastCliData = Map<String, dynamic>.from(map);
      _lastAnalyzedFile = path;
      print('✅ Dados do CLI (--get-all) salvos para: $path');

      return map;
    } catch (e) {
      print('❌ Erro ao parsear JSON de get-all: $e');
      throw Exception('JSON inválido retornado pelo CLI get-all: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // NOVO: obter datas por documento via CLI --get-datas
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getDatesByDocument(String path) async {
    log.info('🗓️ Obtendo datas por documento via CLI (--get-datas): $path');
    await _checkFileAvailable(path);
    await _killCurrentProcess();

    final exe = await _getExecutable();
    final args = ['--input', path, '--get-datas', '--quiet'];

    final proc = await Process.start(
      exe.path,
      args,
      runInShell: true,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _currentProcess = proc;

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final sub1 = proc.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdoutBuffer.write);
    final sub2 = proc.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderrBuffer.write);

    final exitCode = await proc.exitCode;
    await sub1.cancel();
    await sub2.cancel();

    final out = stdoutBuffer.toString();
    final err = stderrBuffer.toString();

    print('🗓️ CLI get-datas executado:');
    print('   📤 Exit code: $exitCode');
    print('   📄 Stdout length: ${out.length} chars');

    if (exitCode != 0) {
      print('❌ get-datas falhou (code=$exitCode)');
      throw Exception(
        'Falha ao obter datas por documento (code=$exitCode): $err',
      );
    }

    try {
      // Com --quiet, o JSON deve estar limpo no stdout
      String jsonText;
      if (out.startsWith('{')) {
        final firstNewlineIndex = out.indexOf('\n');
        if (firstNewlineIndex > 0) {
          jsonText = out.substring(0, firstNewlineIndex);
        } else {
          jsonText = out;
        }
      } else {
        throw Exception('Output não começa com JSON válido');
      }

      final map = json.decode(jsonText) as Map<String, dynamic>;
      print('✅ JSON datas parseado com sucesso');
      print('   🗝️ Keys: ${map.keys.toList()}');
      print(map);
      return map;
    } catch (e) {
      print('❌ Erro ao parsear JSON de datas: $e');
      throw Exception('JSON inválido retornado pelo CLI get-datas: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // NOVO: análise via CLI (sem heurística no Flutter)
  // Retorna o JSON emitido pelo --get-options (documentos, planos_por_documento, datas)
  // ---------------------------------------------------------------------------
  @override
  Future<Map<String, dynamic>> analyzeFile(String path) async {
    log.info('🔎 Analisando arquivo via CLI (--get-options): $path');
    await _checkFileAvailable(path);
    await _killCurrentProcess();

    final exe = await _getExecutable();
    final args = ['--input', path, '--get-options', '--quiet'];

    final proc = await Process.start(
      exe.path,
      args,
      runInShell: true,
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _currentProcess = proc;

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final sub1 = proc.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdoutBuffer.write);
    final sub2 = proc.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderrBuffer.write);

    final exitCode = await proc.exitCode;
    await sub1.cancel();
    await sub2.cancel();

    final out = stdoutBuffer.toString();
    final err = stderrBuffer.toString();

    print('🔍 CLI analyzeFile executado:');
    print('   📤 Exit code: $exitCode');
    print('   📄 Stdout length: ${out.length} chars');
    print(
      '   📄 Stdout first 1000 chars: ${out.length > 1000 ? out.substring(0, 1000) + "..." : out}',
    );
    print(
      '   🔍 Stdout contains datas_por_documento: ${out.contains('datas_por_documento')}',
    );
    if (err.isNotEmpty) {
      print('   ❌ Stderr: $err');
    }

    if (exitCode != 0) {
      print('❌ get-options falhou (code=$exitCode)');
      throw Exception('Falha na análise do arquivo (code=$exitCode): $err');
    }

    // O CLI pode imprimir logs + JSON. Com --quiet, o JSON deve vir limpo no stdout.
    print('🔍 Extraindo JSON do output...');

    String? jsonText;

    // Com --quiet, o JSON deve estar limpo no stdout
    if (out.startsWith('{')) {
      // Encontra a primeira quebra de linha
      final firstNewlineIndex = out.indexOf('\n');
      if (firstNewlineIndex > 0) {
        jsonText = out.substring(0, firstNewlineIndex);
        print('   ✅ Extraído até primeira quebra de linha');
        print('   📏 Tamanho extraído: ${jsonText.length}');
      } else {
        // Se não tem quebra de linha, usa tudo
        jsonText = out;
        print('   ✅ Usando stdout completo (sem quebra de linha)');
        print('   📏 Tamanho stdout completo: ${jsonText.length}');
      }
    }

    // Se não encontrou ainda, usa método alternativo
    if (jsonText == null) {
      jsonText = _extractFirstJsonObject(out) ?? _extractFirstJsonObject(err);
      if (jsonText != null) {
        print('   ⚠️ Usando método alternativo de extração');
        print('   📏 Tamanho extraído: ${jsonText.length}');
      }
    }

    print('   📋 JSON encontrado: ${jsonText != null}');
    if (jsonText != null) {
      print(
        '   📄 JSON content (primeiros 500 chars): ${jsonText.length > 500 ? jsonText.substring(0, 500) + "..." : jsonText}',
      );
      print('   📏 JSON length: ${jsonText.length}');
      print(
        '   🔍 JSON contains datas_por_documento: ${jsonText.contains('datas_por_documento')}',
      );
    }

    if (jsonText == null || jsonText.trim().isEmpty) {
      log.severe('❌ Não foi possível localizar JSON válido no output do CLI');
      log.severe('📄 stdout: ${out.substring(0, out.length > 200 ? 200 : out.length)}');
      throw Exception(
        'Output do CLI não contém JSON válido. Verifique se o executável está correto.',
      );
    }

    try {
      print('🔧 Parseando JSON...');
      print('   📄 JSON to parse length: ${jsonText.length}');

      // Valida se parece com JSON antes de tentar decode
      if (!jsonText.trim().startsWith('{') || !jsonText.trim().endsWith('}')) {
        throw FormatException('Texto não parece ser um JSON válido: ${jsonText.substring(0, 50)}...');
      }

      final map = json.decode(jsonText) as Map<String, dynamic>;
      print('✅ JSON parseado com sucesso');
      print('   🗝️ Keys: ${map.keys.toList()}');
      print('   📄 Documentos: ${map['documentos']}');
      print('   📅 Datas count: ${(map['datas'] as List?)?.length ?? 0}');
      print(
        '   🔍 Has datas_por_documento key: ${map.containsKey('datas_por_documento')}',
      );

      // Debug: listar todas as chaves para verificar se há variações
      print('   🔍 All JSON keys detailed:');
      for (final key in map.keys) {
        print('     - "$key" (type: ${map[key].runtimeType})');
      }

      if (map.containsKey('datas_por_documento')) {
        final dpd = map['datas_por_documento'] as Map<String, String>?;
        print('   📋 datas_por_documento keys: ${dpd?.keys.take(3).toList()}');
        print(
          '   📋 Sample datas_por_documento entry: ${dpd?.entries.first.key}: ${(dpd?.entries.first.value as List?)?.take(3).toList()}',
        );
      } else {
        // Procurar chaves similares caso haja typo ou encoding
        final possibleKeys =
            map.keys
                .where((key) => key.toLowerCase().contains('data'))
                .toList();
        print('   🔍 Keys containing "data": $possibleKeys');
      }

      // Captura os docPlanos inválidos do output do CLI
      final invalidDocPlanos = _extractInvalidDocPlanos(out + err);
      map['invalidDocPlanos'] =
          invalidDocPlanos
              .map(
                (invalid) => {
                  'docPlano': invalid.docPlano,
                  'motivo': invalid.motivo,
                },
              )
              .toList();
      print('📋 DocPlanos inválidos encontrados: ${invalidDocPlanos.length}');
      for (final invalid in invalidDocPlanos) {
        print('   ❌ ${invalid.docPlano} - ${invalid.motivo}');
      }

      // Salva os dados do CLI para uso posterior
      _lastCliData = Map<String, dynamic>.from(map);
      _lastAnalyzedFile = path;
      print('✅ Dados do CLI salvos para: $path');
      print('🔍 CLI Data keys salvos: ${_lastCliData?.keys.toList()}');
      print(
        '🔍 Has datas_por_documento: ${_lastCliData?.containsKey('datas_por_documento')}',
      );

      return map;
    } catch (e) {
      print('❌ Erro ao parsear JSON de opções: $e');
      throw Exception('JSON inválido retornado pelo CLI: $e');
    }
  }

  List<InvalidDocPlano> _extractInvalidDocPlanos(String cliOutput) {
    final invalidDocPlanosMap =
        <String, List<String>>{}; // docPlano -> lista de motivos
    final lines = cliOutput.split('\n');

    for (final line in lines) {
      // Procura por padrões de blocos inválidos nos logs
      if (line.contains('possui 0 contratos válidos')) {
        // Exemplo: "Bloco ADTC-1.04.01.07 possui 0 contratos válidos."
        final match = RegExp(
          r'Bloco\s+([A-Z-]+\d+(?:\.\d+)*)\s+possui 0 contratos válidos',
        ).firstMatch(line);
        if (match != null) {
          final docPlano = match.group(1)!;
          invalidDocPlanosMap
              .putIfAbsent(docPlano, () => [])
              .add('Sem contratos válidos');
        }
      } else if (line.contains('não possui dados válidos (todos zerados)')) {
        // Exemplo: "Bloco ADTC-1.04.01.07 não possui dados válidos (todos zerados)"
        final match = RegExp(
          r'Bloco\s+([A-Z-]+\d+(?:\.\d+)*)\s+não possui dados válidos',
        ).firstMatch(line);
        if (match != null) {
          final docPlano = match.group(1)!;
          invalidDocPlanosMap
              .putIfAbsent(docPlano, () => [])
              .add('Dados zerados');
        }
      } else if (line.contains('Bloco inválido ou vazio')) {
        // Exemplo: "Bloco inválido ou vazio para REG-1.04.01.08 (coluna 8)."
        final match = RegExp(
          r'Bloco inválido ou vazio para\s+([A-Z-]+\d+(?:\.\d+)*(?:\.\d+)*)',
        ).firstMatch(line);
        if (match != null) {
          final docPlano = match.group(1)!;
          invalidDocPlanosMap
              .putIfAbsent(docPlano, () => [])
              .add('Bloco inválido ou vazio');
        }
      }
    }

    // Converte o map em lista, consolidando os motivos
    final invalidDocPlanos = <InvalidDocPlano>[];
    invalidDocPlanosMap.forEach((docPlano, motivos) {
      // Remove duplicatas e junta os motivos com " | "
      final motivosUnicos = motivos.toSet().toList();
      final motivoConsolidado = motivosUnicos.join(' | ');
      invalidDocPlanos.add(
        InvalidDocPlano(docPlano: docPlano, motivo: motivoConsolidado),
      );
    });

    return invalidDocPlanos;
  }

  // Extrai o primeiro objeto JSON bem-formado de um texto (balanceando chaves)
  String? _extractFirstJsonObject(String? text) {
    if (text == null || text.isEmpty) return null;
    int depth = 0;
    int? start;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '{') {
        depth++;
        start ??= i;
      } else if (ch == '}') {
        depth--;
        if (depth == 0 && start != null) {
          return text.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  // Extrai o primeiro objeto JSON completo de um texto
  String? _extractFirstCompleteJsonObject(String? text) {
    if (text == null || text.isEmpty) return null;

    int depth = 0;
    int? start;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '{') {
        depth++;
        start ??= i;
      } else if (ch == '}') {
        depth--;
        if (depth == 0 && start != null) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Apenas LEITURA para exibir a planilha (sem inferir colunas)
  // ---------------------------------------------------------------------------
  @override
  Future<ExcelData> loadExcelFile(String path) async {
    try {
      await _checkFileAvailable(path);
      final bytes = await File(path).readAsBytes(); // Assíncrono para não bloquear
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (!decoder.tables.containsKey('Layout')) {
        log.warning('A planilha "Layout" não foi encontrada.');
        throw Exception('A planilha "Layout" não foi encontrada no arquivo.');
      }

      final sheet = decoder.tables['Layout']!;
      if (sheet.rows.isEmpty) {
        log.warning('A planilha "Layout" está vazia.');
        throw Exception('A planilha "Layout" está vazia.');
      }

      // Escolhe a PRIMEIRA linha não vazia como cabeçalho visual
      int headerRowIdx = sheet.rows.indexWhere(
        (r) => r.any((c) => (c?.toString().trim() ?? '').isNotEmpty),
      );
      if (headerRowIdx < 0) headerRowIdx = 0;

      final headers =
          sheet.rows[headerRowIdx]
              .map((c) => (c?.toString() ?? '').trim())
              .toList();

      // Demais linhas com qualquer conteúdo
      final dataRows =
          sheet.rows
              .skip(headerRowIdx + 1)
              .where(
                (r) => r.any((c) => (c?.toString().trim() ?? '').isNotEmpty),
              )
              .map(
                (r) =>
                    r
                        .take(headers.length)
                        .map((c) => (c?.toString() ?? '').trim())
                        .toList(),
              )
              .toList();

      // Sem procurar Documento/Plano; UI só exibe
      return ExcelData(
        fileName: p.basename(path),
        headers: headers,
        rows: dataRows,
        docPlanos: const [], // mantemos vazio pois a análise vem do CLI
      );
    } catch (e) {
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
    log.info('🔍 Validação completa usando CLI para: $filePath');

    // Carrega dados básicos da planilha para verificações básicas
    ExcelData excelData;
    try {
      excelData = await loadExcelFile(filePath);
    } catch (e) {
      log.severe('Erro ao carregar arquivo para validação: $e');
      return [
        ValidationItem(
          title: 'Erro no arquivo',
          description: 'Não foi possível carregar o arquivo Excel',
          isValid: false,
          errorMessage: 'Erro ao carregar arquivo: $e',
        ),
      ];
    }

    try {
      // Usa dados salvos se disponíveis, senão analisa novamente
      Map<String, dynamic> cliData;
      if (hasCliDataFor(filePath)) {
        log.info('📋 Usando dados salvos do CLI para: $filePath');
        cliData = _lastCliData!;
      } else {
        log.info('🔍 Analisando arquivo com CLI: $filePath');
        cliData = await analyzeFile(filePath);
        print(cliData);
      }

      // Atualiza ExcelData com dados do CLI
      final updatedExcelData = ExcelData(
        fileName: excelData.fileName,
        headers: excelData.headers,
        rows: excelData.rows,
        docPlanos: _parseDocPlanos(cliData),
      );

      // Extrai informações dos dados do CLI
      final documentos =
          (cliData['documentos'] as List<dynamic>?)?.cast<String>() ?? [];
      final planosMap =
          (cliData['planos_por_documento'] as Map<String, dynamic>?) ?? {};
      final datas = (cliData['datas'] as List<dynamic>?)?.cast<String>() ?? [];

      // Extrai informações das colunas obrigatórias
      final colunasObrigatorias =
          (cliData['colunas_obrigatorias'] as Map<String, dynamic>?) ?? {};
      final todasColunasPresentes =
          colunasObrigatorias['todas_presentes'] as bool? ?? false;
      final colunasAusentes =
          (colunasObrigatorias['ausentes'] as List<dynamic>?)?.cast<String>() ??
          [];

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
          isValid: updatedExcelData.docPlanos.isNotEmpty,
          errorMessage:
              updatedExcelData.docPlanos.isEmpty
                  ? 'Nenhuma combinação Documento-Plano válida encontrada'
                  : null,
        ),
      ];
    } catch (e) {
      log.severe('Erro ao validar com dados do CLI: $e');
      // Fallback para validação básica se CLI falhar
      return [
        ValidationItem(
          title: 'Planilha "Layout" presente',
          description: 'Arquivo deve conter a aba Layout',
          isValid: true,
        ),
        ValidationItem(
          title: 'Dados na planilha',
          description: 'Verificar se há dados na planilha',
          isValid: excelData.rows.isNotEmpty,
          errorMessage:
              excelData.rows.isEmpty ? 'Arquivo não possui dados' : null,
        ),
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
    print('📊 getDetailedFileStats chamado para: $filePath');
    try {
      // Usa dados salvos se disponíveis, senão analisa novamente
      Map<String, dynamic> cliData;
      if (hasCliDataFor(filePath)) {
        print('📋 Usando dados salvos do CLI para estatísticas');
        cliData = _lastCliData!;
        print('   🗝️ Dados salvos keys: ${cliData.keys.toList()}');
      } else {
        print(
          '🔍 Dados não encontrados - analisando arquivo para estatísticas',
        );
        cliData = await analyzeFile(filePath);
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
        log.warning('Arquivo com colunas ausentes: ${ausentes.join(", ")}');

        return {
          'docPlanos': <DocPlano>[],
          'countsPerDocPlano': <String, int>{},
          'totalCombinations': 0,
          'nonEmptyCombinations': 0,
          'totalRecords': 0,
          'colunasObrigatorias': colunasObrigatorias,
          'erro': 'Colunas obrigatórias ausentes: ${ausentes.join(", ")}',
          'processingFilters': ProcessingFilters(
            selectedDocuments: [],
            selectedDates: [],
            availableDocuments: [],
            availableDates: [],
            availableDocPlanos: [],
            datesByDocument: {},
          ),
        };
      }

      // Usa contagens reais do CLI (se disponível)
      final blockCounts =
          (cliData['block_counts'] as Map<String, dynamic>?) ?? {};
      final Map<String, int> countsPerDocPlano = {};

      // Converte blockCounts para formato documento-plano
      blockCounts.forEach((blockName, count) {
        countsPerDocPlano[blockName] = count as int;
      });

      // Cria filtros baseados nos dados disponíveis
      print('🎯 Criando filtros com dados do CLI...');
      final documentos =
          (cliData['documentos'] as List<dynamic>?)?.cast<String>() ?? [];
      final datasRaw =
          (cliData['datas'] as List<dynamic>?)?.cast<String>() ?? [];
      print('📄 Documentos brutos do CLI: $documentos');
      print(
        '📅 Datas brutas do CLI (${datasRaw.length}): ${datasRaw.take(3).toList()}...',
      );

      // Usa datas por documento dos dados cached (getAllData já inclui isso)
      print('🗓️ Obtendo datas por documento dos dados cached...');
      Map<String, dynamic> datasPorDocumento = {};
      if (cliData.containsKey('datas_por_documento')) {
        datasPorDocumento =
            (cliData['datas_por_documento'] as Map<String, dynamic>?) ?? {};
        print(
          '✅ Datas por documento obtidas do cache: ${datasPorDocumento.keys.length} documentos',
        );
        print(
          '🔍 Primeiros documentos: ${datasPorDocumento.keys.take(3).toList()}...',
        );
      } else {
        print('⚠️ datas_por_documento não encontrado nos dados cached');
        print('   📋 Continuando sem datas específicas por documento');
      }

      // Converte datas de DD/MM/YYYY para YYYY-MM-DD
      final datas = datasRaw.map(_convertDateFromCli).toList();

      // Converte datas por documento
      print('   📋 datasPorDocumento keys: ${datasPorDocumento.keys.toList()}');
      print(
        '   📋 datasPorDocumento has data: ${datasPorDocumento.isNotEmpty}',
      );

      final Map<String, List<String>> datesByDocument = {};
      datasPorDocumento.forEach((documento, datasRawDoc) {
        print('   📄 Processando documento: $documento');
        print(
          '   📅 Dados brutos: ${datasRawDoc is List ? (datasRawDoc as List).length : "não é lista"}',
        );

        if (datasRawDoc is List) {
          final convertedDates =
              (datasRawDoc as List<dynamic>)
                  .cast<String>()
                  .map(_convertDateFromCli)
                  .toList();
          datesByDocument[documento] = convertedDates;
          print(
            '   ✅ ${convertedDates.length} datas convertidas para $documento',
          );
        }
      });
      print(
        '📋 Datas por documento processadas: ${datesByDocument.keys.length} documentos',
      );
      print(
        '📋 datesByDocument final: ${datesByDocument.keys.take(3).toList()}',
      );

      final docPlanos = _parseDocPlanos(cliData);
      print('📋 DocPlanos criados: ${docPlanos.length}');

      print('🔧 Criando ProcessingFilters...');
      final processingFilters = ProcessingFilters(
        selectedDocuments: [], // Inicia vazio para o usuário selecionar
        selectedDates: [], // Inicia vazio para o usuário selecionar
        availableDocuments: documentos,
        availableDates: datas,
        availableDocPlanos: docPlanos,
        datesByDocument: datesByDocument,
        recordCountsByDocument: countsPerDocPlano,
      );
      print('✅ ProcessingFilters criado com:');
      print(
        '   📄 ${processingFilters.availableDocuments.length} docs disponíveis',
      );
      print(
        '   📅 ${processingFilters.availableDates.length} datas disponíveis',
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
    } catch (e) {
      log.severe('Erro ao obter estatísticas detalhadas: $e');
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
          'availableDocPlanos': [],
          'datesByDocument': [],
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

      log.info('📦 Extraindo executável dos assets...');
      final assetPath =
          Platform.isWindows
              ? 'lib/assets/br_service_cli.exe'
              : 'lib/assets/br_service_cli';
      final bytes = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, executableName));

      await tempFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      log.info('Executável escrito em: ${tempFile.path}');

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
