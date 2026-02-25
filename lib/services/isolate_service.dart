import 'dart:isolate';
import 'dart:async';

import '../models/excel_data.dart';
import '../models/validation_item.dart';
import '../repository/file_repository_impl.dart';

/// Parâmetros para operações em isolate
class IsolateParams {
  final String filePath;
  final SendPort sendPort;
  final String? executablePath;

  IsolateParams(this.filePath, this.sendPort, {this.executablePath});
}

/// Parâmetros específicos para validação
class ValidationIsolateParams {
  final String filePath;
  final SendPort sendPort;
  final Map<String, dynamic>? cliData; // Dados já obtidos do CLI
  
  ValidationIsolateParams(this.filePath, this.sendPort, this.cliData);
}

/// Resultado das operações em isolate
class IsolateResult<T> {
  final T? data;
  final String? error;
  final bool success;
  
  IsolateResult.success(this.data) : error = null, success = true;
  IsolateResult.error(this.error) : data = null, success = false;
}

/// Serviço para executar operações pesadas em isolates separados
class IsolateService {
  
  /// Carrega arquivo Excel em isolate separado
  static Future<ExcelData> loadExcelFileInIsolate(
    String filePath, {
    String? executablePath,
  }) async {
    final receivePort = ReceivePort();
    final params = IsolateParams(
      filePath,
      receivePort.sendPort,
      executablePath: executablePath,
    );

    await Isolate.spawn(_loadExcelFileIsolate, params);
    
    final result = await receivePort.first as IsolateResult<ExcelData>;
    receivePort.close();
    
    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.error ?? 'Erro desconhecido no isolate');
    }
  }
  
  /// Valida arquivo com CLI em isolate separado
  static Future<List<ValidationItem>> validateFileInIsolate(String filePath) async {
    final receivePort = ReceivePort();
    final params = IsolateParams(filePath, receivePort.sendPort);
    
    await Isolate.spawn(_validateFileIsolate, params);
    
    final result = await receivePort.first as IsolateResult<List<ValidationItem>>;
    receivePort.close();
    
    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.error ?? 'Erro desconhecido na validação');
    }
  }
  
  /// Obtém estatísticas detalhadas em isolate separado
  static Future<Map<String, dynamic>> getDetailedStatsInIsolate(String filePath) async {
    final receivePort = ReceivePort();
    final params = IsolateParams(filePath, receivePort.sendPort);
    
    await Isolate.spawn(_getDetailedStatsIsolate, params);
    
    final result = await receivePort.first as IsolateResult<Map<String, dynamic>>;
    receivePort.close();
    
    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.error ?? 'Erro desconhecido ao obter estatísticas');
    }
  }
  
  /// Isolate para carregar arquivo Excel
  static void _loadExcelFileIsolate(IsolateParams params) async {
    try {
      final repository = FileRepositoryImpl();
      final excelData = await repository.loadExcelFile(
        params.filePath,
        executablePath: params.executablePath,
      );
      params.sendPort.send(IsolateResult.success(excelData));
    } catch (e) {
      params.sendPort.send(IsolateResult<ExcelData>.error(e.toString()));
    }
  }
  
  /// Isolate para validar arquivo
  static void _validateFileIsolate(IsolateParams params) async {
    try {
      final repository = FileRepositoryImpl();
      final validationItems = await repository.validateFile(params.filePath);
      params.sendPort.send(IsolateResult.success(validationItems));
    } catch (e) {
      params.sendPort.send(IsolateResult<List<ValidationItem>>.error(e.toString()));
    }
  }
  
  /// Isolate para obter estatísticas detalhadas
  static void _getDetailedStatsIsolate(IsolateParams params) async {
    try {
      final repository = FileRepositoryImpl();
      final stats = await repository.getDetailedFileStats(params.filePath);
      params.sendPort.send(IsolateResult.success(stats));
    } catch (e) {
      params.sendPort.send(IsolateResult<Map<String, dynamic>>.error(e.toString()));
    }
  }
}