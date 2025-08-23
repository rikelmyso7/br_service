import '../../models/processing_filters.dart';

abstract class FileProcessorEvent {
  const FileProcessorEvent();
}

class SelectFileEvent extends FileProcessorEvent {
  final String filePath;
  const SelectFileEvent(this.filePath);
}

class ProceedToValidationEvent extends FileProcessorEvent {
  const ProceedToValidationEvent();
}

class StartProcessingEvent extends FileProcessorEvent {
  final String outputDir;
  final ProcessingFilters? filters;
  const StartProcessingEvent(this.outputDir, {this.filters});
}

class ResetEvent extends FileProcessorEvent {
  const ResetEvent();
}

class BackToFilePreviewEvent extends FileProcessorEvent {
  const BackToFilePreviewEvent();
}

class BackToValidationEvent extends FileProcessorEvent {
  const BackToValidationEvent();
}

class ProceedToCompletedEvent extends FileProcessorEvent {
  const ProceedToCompletedEvent();
}