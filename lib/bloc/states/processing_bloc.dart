import '../../models/process_event.dart';
import 'file_processor_bloc.dart';

class ProcessingState extends FileProcessorState {
  final String filePath;
  final String outputDir;
  final List<LogEvent> logs;
  final int progress;
  final String currentOperation;

  const ProcessingState({
    required this.filePath,
    required this.outputDir,
    required this.logs,
    this.progress = 0,
    this.currentOperation = 'Iniciando...',
  });

  ProcessingState copyWith({
    List<LogEvent>? logs,
    int? progress,
    String? currentOperation,
  }) {
    return ProcessingState(
      filePath: filePath,
      outputDir: outputDir,
      logs: logs ?? this.logs,
      progress: progress ?? this.progress,
      currentOperation: currentOperation ?? this.currentOperation,
    );
  }
}