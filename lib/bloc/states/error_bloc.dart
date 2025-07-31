import 'file_processor_bloc.dart';

class ErrorState extends FileProcessorState {
  final String message;
  final String? details;

  const ErrorState(this.message, [this.details]);
}