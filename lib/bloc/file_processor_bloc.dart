import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/excel_data.dart';
import '../models/process_event.dart';
import '../repository/file_repository.dart';
import '../repository/file_repository_impl.dart';
import 'events/file_events_bloc.dart';
import 'states/completed_bloc.dart';
import 'states/error_bloc.dart';
import 'states/file_processor_bloc.dart';
import 'states/processing_bloc.dart';
import 'states/validation_processor_bloc.dart';

class FileProcessorBloc extends Bloc<FileProcessorEvent, FileProcessorState> {
  final FileRepository _repository;
  String? _selectedFile;
  ExcelData? _excelData;

  FileProcessorBloc(this._repository) : super(const InitialState()) {
    on<SelectFileEvent>(_onFileSelected);
    on<ProceedToValidationEvent>(_onProceedToValidation);
    on<StartProcessingEvent>(_onStartProcessing);
    on<ResetEvent>(_onReset);
  }

  void _onFileSelected(
      SelectFileEvent event, Emitter<FileProcessorState> emit) async {
    try {
      _selectedFile = event.filePath;
      emit(const InitialState()); // Loading state

      _excelData = await _repository.loadExcelFile(event.filePath);
      emit(FilePreviewState(
        filePath: event.filePath,
        excelData: _excelData!,
      ));
    } catch (e) {
      emit(ErrorState('Erro ao carregar arquivo', e.toString()));
    }
  }

  void _onProceedToValidation(
      ProceedToValidationEvent event, Emitter<FileProcessorState> emit) async {
    if (_selectedFile == null || _excelData == null) return;

    try {
      final validationItems = await _repository.validateFile(_excelData!);
      final canProceed = validationItems.every((item) => item.isValid);

      emit(ValidationState(
        filePath: _selectedFile!,
        excelData: _excelData!,
        validationItems: validationItems,
        canProceed: canProceed,
      ));
    } catch (e) {
      emit(ErrorState('Erro na validação', e.toString()));
    }
  }

  void _onStartProcessing(
      StartProcessingEvent event, Emitter<FileProcessorState> emit) async {
    if (_selectedFile == null) return;

    emit(ProcessingState(
      filePath: _selectedFile!,
      outputDir: event.outputDir,
      logs: [],
    ));

    await emit.forEach(
      _repository.processFile(_selectedFile!, event.outputDir),
      onData: (ProcessEvent processEvent) {
        final currentState = state;
        if (currentState is! ProcessingState) return state;

        switch (processEvent.runtimeType) {
          case ProgressEvent:
            final progress = processEvent as ProgressEvent;
            return currentState.copyWith(
              progress: progress.percentage,
              currentOperation: progress.currentOperation,
            );

          case LogEvent:
            final log = processEvent as LogEvent;
            final newLogs = List<LogEvent>.from(currentState.logs)..add(log);
            return currentState.copyWith(logs: newLogs);

          case ErrorEvent:
            final error = processEvent as ErrorEvent;
            return ErrorState(error.message, error.details);

          case CompletedEvent:
            return CompletedState(event.outputDir);

          default:
            return currentState;
        }
      },
      onError: (error, stackTrace) =>
          ErrorState('Erro inesperado', error.toString()),
    );
  }

  void _onReset(ResetEvent event, Emitter<FileProcessorState> emit) {
    _selectedFile = null;
    _excelData = null;
    emit(const InitialState());
  }

  @override
  Future<void> close() {
    if (_repository is FileRepositoryImpl) {
      (_repository as FileRepositoryImpl).dispose();
    }
    return super.close();
  }
}
