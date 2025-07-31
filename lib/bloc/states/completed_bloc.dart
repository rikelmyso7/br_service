import 'file_processor_bloc.dart';

class CompletedState extends FileProcessorState {
  final String outputDir;
  const CompletedState(this.outputDir);
}