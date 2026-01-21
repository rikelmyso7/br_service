import '../../models/excel_data.dart';

abstract class FileProcessorState {
  const FileProcessorState();
}

class InitialState extends FileProcessorState {
  const InitialState();
}

class FileLoadingState extends FileProcessorState {
  final String filePath;
  final String message;
  
  const FileLoadingState({
    required this.filePath,
    this.message = 'Carregando arquivo...',
  });
}

class ValidationLoadingState extends FileProcessorState {
  final String filePath;
  final ExcelData excelData;
  final String message;
  
  const ValidationLoadingState({
    required this.filePath,
    required this.excelData,
    this.message = 'Analisando arquivo com CLI...',
  });
}

class FilePreviewState extends FileProcessorState {
  final String filePath;
  final ExcelData excelData;
  final List<String> numericSheetNames;
  final Map<String, dynamic>? contasAnalysis;

  const FilePreviewState({
    required this.filePath,
    required this.excelData,
    required this.numericSheetNames,
    this.contasAnalysis,
  });
}