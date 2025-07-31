abstract class ProcessEvent {
  const ProcessEvent();
}

class ProgressEvent extends ProcessEvent {
  final int percentage;
  final String currentOperation;
  const ProgressEvent(this.percentage, this.currentOperation);
}

class ErrorEvent extends ProcessEvent {
  final String message;
  final String? details;
  const ErrorEvent(this.message, [this.details]);
}

class CompletedEvent extends ProcessEvent {
  const CompletedEvent();
}

class LogEvent extends ProcessEvent {
  final String message;
  final DateTime timestamp;
  LogEvent(this.message) : timestamp = DateTime.now();
}