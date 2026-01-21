import 'package:br_service_ui/models/br_service_model.dart';
import 'package:br_service_ui/models/excel_data.dart';
import 'package:br_service_ui/models/process_event.dart';
import 'package:br_service_ui/models/validation_item.dart';
import 'package:equatable/equatable.dart';

abstract class FileProcessorState extends Equatable {
  const FileProcessorState();
  @override
  List<Object?> get props => [];
}

class InitialState extends FileProcessorState {
  const InitialState();
}

class FileLoadedState extends FileProcessorState {
  final ExcelData excelData;
  const FileLoadedState(this.excelData);
  @override
  List<Object?> get props => [excelData];
}

class ValidationState extends FileProcessorState {
  final ExcelData excelData;
  final ProcessingOptions options;
  final List<ValidationItem> validationItems;

  final String? selectedDocument;
  final List<String> selectedDates;

  final String? outputDir;

  const ValidationState({
    required this.excelData,
    required this.options,
    required this.validationItems,
    required this.selectedDocument,
    required this.selectedDates,
    required this.outputDir,
  });

  ValidationState copyWith({
    ExcelData? excelData,
    ProcessingOptions? options,
    List<ValidationItem>? validationItems,
    String? selectedDocument,
    List<String>? selectedDates,
    String? outputDir,
  }) {
    return ValidationState(
      excelData: excelData ?? this.excelData,
      options: options ?? this.options,
      validationItems: validationItems ?? this.validationItems,
      selectedDocument: selectedDocument ?? this.selectedDocument,
      selectedDates: selectedDates ?? this.selectedDates,
      outputDir: outputDir ?? this.outputDir,
    );
  }

  @override
  List<Object?> get props =>
      [excelData, options, validationItems, selectedDocument, selectedDates, outputDir];
}

class ProcessingState extends FileProcessorState {
  final int progress; // 0..100
  final String currentOperation;
  final List<LogEvent> logs;

  const ProcessingState({
    required this.progress,
    required this.currentOperation,
    required this.logs,
  });

  ProcessingState copyWith({
    int? progress,
    String? currentOperation,
    List<LogEvent>? logs,
  }) {
    return ProcessingState(
      progress: progress ?? this.progress,
      currentOperation: currentOperation ?? this.currentOperation,
      logs: logs ?? this.logs,
    );
  }

  @override
  List<Object?> get props => [progress, currentOperation, logs];
}

class CompletedState extends FileProcessorState {
  final String outputDir;
  const CompletedState(this.outputDir);
  @override
  List<Object?> get props => [outputDir];
}

class ErrorState extends FileProcessorState {
  final String message;
  final String? details;
  const ErrorState(this.message, [this.details]);
  @override
  List<Object?> get props => [message, details];
}
