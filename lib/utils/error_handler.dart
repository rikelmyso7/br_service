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