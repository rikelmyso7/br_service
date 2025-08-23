import '../../models/process_event.dart';
import 'file_processor_bloc.dart';

class ProcessingCompletedState extends FileProcessorState {
  final String filePath;
  final String outputDir;
  final List<LogEvent> logs;

  const ProcessingCompletedState({
    required this.filePath,
    required this.outputDir,
    required this.logs,
  });
}