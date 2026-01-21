import 'package:br_service_ui/models/excel_data.dart';
import 'package:equatable/equatable.dart';

abstract class FileProcessorEvent extends Equatable {
  const FileProcessorEvent();
  @override
  List<Object?> get props => [];
}

// Usuário escolheu o arquivo (abrir + preview)
class OpenFileEvent extends FileProcessorEvent {
  final String inputPath;
  const OpenFileEvent(this.inputPath);
  @override
  List<Object?> get props => [inputPath];
}

// Carregar opções do CLI (--get-options)
class LoadOptionsEvent extends FileProcessorEvent {
  final String inputPath;
  const LoadOptionsEvent(this.inputPath);
  @override
  List<Object?> get props => [inputPath];
}

// Selecionar documento
class SelectDocumentEvent extends FileProcessorEvent {
  final String? document;
  const SelectDocumentEvent(this.document);
  @override
  List<Object?> get props => [document];
}

// Selecionar datas (múltiplas)
class SelectDatesEvent extends FileProcessorEvent {
  final List<String> dates;
  const SelectDatesEvent(this.dates);
  @override
  List<Object?> get props => [dates];
}

// Selecionar pasta de saída
class SelectOutputDirEvent extends FileProcessorEvent {
  final String outputDir;
  const SelectOutputDirEvent(this.outputDir);
  @override
  List<Object?> get props => [outputDir];
}

// Validar via CLI
class ValidateFileEvent extends FileProcessorEvent {
  final ExcelData excelData;
  const ValidateFileEvent(this.excelData);
  @override
  List<Object?> get props => [excelData];
}

// Iniciar processamento
class StartProcessingEvent extends FileProcessorEvent {
  final String inputPath;
  final String outputDir;
  final List<String>? documentos;
  final List<String>? datas;
  final String? nomePasta;

  const StartProcessingEvent({
    required this.inputPath,
    required this.outputDir,
    this.documentos,
    this.datas,
    this.nomePasta,
  });

  @override
  List<Object?> get props => [inputPath, outputDir, documentos, datas, nomePasta];
}
