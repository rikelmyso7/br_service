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
  const StartProcessingEvent(this.outputDir);
}

class ResetEvent extends FileProcessorEvent {
  const ResetEvent();
}