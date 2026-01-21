// utils/error_handler.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

class ErrorHandler {
  static void setupGlobalErrorHandling() {
    // Captura erros não tratados
    FlutterError.onError = (FlutterErrorDetails details) {
      print('🚨 Flutter Error: ${details.exception}');
      print('📍 Stack: ${details.stack}');
      
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Captura erros de zona assíncrona
    PlatformDispatcher.instance.onError = (error, stack) {
      print('🚨 Platform Error: $error');
      print('📍 Stack: $stack');
      return true;
    };
  }

  static T runWithErrorHandling<T>(T Function() operation, [String? context]) {
    try {
      return operation();
    } catch (e, stackTrace) {
      print('❌ Erro${context != null ? ' em $context' : ''}: $e');
      print('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }

  static Future<T> runAsyncWithErrorHandling<T>(
    Future<T> Function() operation, [
    String? context
  ]) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      print('❌ Erro async${context != null ? ' em $context' : ''}: $e');
      print('📍 StackTrace: $stackTrace');
      rethrow;
    }
  }
}

// Extensão para facilitar o uso
extension SafeOperation<T> on T Function() {
  T safely([String? context]) {
    return ErrorHandler.runWithErrorHandling(this, context);
  }
}

extension SafeAsyncOperation<T> on Future<T> Function() {
  Future<T> safely([String? context]) {
    return ErrorHandler.runAsyncWithErrorHandling(this, context);
  }
}

/// Mapeamento de códigos de erro do CLI para mensagens amigáveis
class CliErrorMessages {
  /// Códigos de erro do CLI e suas mensagens amigáveis
  static const Map<String, String> _errorCodes = {
    'VALIDATION_ERROR': 'Alguns documentos ou dados são inválidos. Verifique o arquivo.',
    'FILE_NOT_FOUND': 'Arquivo não encontrado. Selecione outro arquivo.',
    'FILE_IN_USE': 'O arquivo está aberto em outro programa. Feche-o e tente novamente.',
    'LAYOUT_NOT_FOUND': 'A planilha "Layout" não foi encontrada no arquivo.',
    'COLUMN_MISSING': 'Colunas obrigatórias estão ausentes no arquivo.',
    'NO_DATA': 'Nenhum dado válido foi encontrado para processar.',
    'OUTPUT_ERROR': 'Erro ao salvar os arquivos de saída. Verifique a pasta de destino.',
    'PERMISSION_DENIED': 'Sem permissão para acessar o arquivo ou pasta.',
    'INVALID_FORMAT': 'Formato do arquivo inválido. Use arquivos .xlsx.',
    'PROCESS_TIMEOUT': 'O processamento demorou demais. Tente com um arquivo menor.',
  };

  /// Códigos de saída do CLI
  static const Map<int, String> _exitCodes = {
    0: 'Processamento concluído com sucesso.',
    1: 'Erro durante o processamento do arquivo.',
    2: 'Argumentos inválidos fornecidos ao CLI.',
  };

  /// Obtém mensagem amigável para um código de erro
  static String getMessageForCode(String code) {
    return _errorCodes[code] ?? 'Erro desconhecido: $code';
  }

  /// Obtém mensagem amigável para um código de saída
  static String getMessageForExitCode(int exitCode) {
    return _exitCodes[exitCode] ?? 'Processo finalizou com código: $exitCode';
  }

  /// Tenta extrair código de erro de uma mensagem JSON do CLI
  static String? extractErrorCode(String jsonOutput) {
    try {
      // Procura por padrão {"codigo": "..."}
      final match = RegExp(r'"codigo"\s*:\s*"([^"]+)"').firstMatch(jsonOutput);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Converte erro técnico em mensagem amigável
  static String toFriendlyMessage(String technicalError) {
    final lowerError = technicalError.toLowerCase();

    if (lowerError.contains('está aberto') || lowerError.contains('in use')) {
      return _errorCodes['FILE_IN_USE']!;
    }
    if (lowerError.contains('não encontrado') || lowerError.contains('not found')) {
      return _errorCodes['FILE_NOT_FOUND']!;
    }
    if (lowerError.contains('layout')) {
      return _errorCodes['LAYOUT_NOT_FOUND']!;
    }
    if (lowerError.contains('coluna') || lowerError.contains('column')) {
      return _errorCodes['COLUMN_MISSING']!;
    }
    if (lowerError.contains('permiss') || lowerError.contains('denied')) {
      return _errorCodes['PERMISSION_DENIED']!;
    }
    if (lowerError.contains('formato') || lowerError.contains('format')) {
      return _errorCodes['INVALID_FORMAT']!;
    }

    // Tenta extrair código de erro JSON
    final code = extractErrorCode(technicalError);
    if (code != null && _errorCodes.containsKey(code)) {
      return _errorCodes[code]!;
    }

    // Retorna o erro original se não conseguir traduzir
    return technicalError;
  }
}