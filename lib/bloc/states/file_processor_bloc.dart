import '../../models/excel_data.dart';

abstract class FileProcessorState {
  const FileProcessorState();
}

class InitialState extends FileProcessorState {
  const InitialState();
}

class FilePreviewState extends FileProcessorState {
  final String filePath;
  final ExcelData excelData;

  const FilePreviewState({
    required this.filePath,
    required this.excelData,
  });
}