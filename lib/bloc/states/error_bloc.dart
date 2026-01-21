import '../../models/process_event.dart';
import 'file_processor_bloc.dart';

class ErrorState extends FileProcessorState {
  final String message;
  final String? details;

  const ErrorState(this.message, [this.details]);
}

class ErrorStateWithLogs extends ErrorState {
  final List<LogEvent> logs;
  final int progress;

  const ErrorStateWithLogs(
    super.message, 
    this.logs, 
    this.progress, 
    [super.details]
  );
}