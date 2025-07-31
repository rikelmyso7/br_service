import 'package:br_service_ui/components/processing_view_component.dart';
import 'package:br_service_ui/components/sucess_view_component.dart';
import 'package:br_service_ui/components/validation_view_component.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/file_processor_bloc.dart';
import '../bloc/states/completed_bloc.dart';
import '../bloc/states/error_bloc.dart';
import '../bloc/states/file_processor_bloc.dart';
import '../bloc/states/processing_bloc.dart';
import '../bloc/states/validation_processor_bloc.dart';
import 'error_view_component.dart';
import 'file_preview_component.dart';
import 'initial_view_component.dart';

class StateContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileProcessorBloc, FileProcessorState>(
      builder: (context, state) {
        print(state.runtimeType);
        switch (state.runtimeType) {
          case InitialState:
            return const InitialView();

          case FilePreviewState:
            final preview = state as FilePreviewState;
            return FilePreviewView(excelData: preview.excelData, filePath: preview.filePath);

          case ValidationState:
            final validation = state as ValidationState;
            return ValidationView(validationItems: validation.validationItems, excelData: validation.excelData,);

          case ProcessingState:
            final processing = state as ProcessingState;
            return ProcessingView(
              logs: processing.logs,
              progress: processing.progress,
              currentOperation: processing.currentOperation,
            );

          case ErrorState:
            final error = state as ErrorState;
            return ErrorView(
              message: error.message,
              details: error.details,
            );

          case CompletedState:
            final completed = state as CompletedState;
            return SuccessView(outputDir: completed.outputDir);

          default:
            return const Center(child: Text('Estado desconhecido'));
        }
      },
    );
  }
}