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
import '../bloc/states/processing_completed_bloc.dart';
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

          case FileLoadingState:
            final loading = state as FileLoadingState;
            return _buildCompactLoadingView(
              title: 'Carregando Arquivo',
              message: loading.message,
              icon: CupertinoIcons.doc_text,
            );

          case ValidationLoadingState:
            final loading = state as ValidationLoadingState;
            return _buildCompactLoadingView(
              title: 'Analisando Arquivo',
              message: loading.message,
              icon: CupertinoIcons.checkmark_shield,
            );

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

          case ProcessingCompletedState:
            final completed = state as ProcessingCompletedState;
            return ProcessingView(
              logs: completed.logs,
              progress: 100,
              currentOperation: 'Processamento concluído com sucesso!',
              isCompleted: true,
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

  Widget _buildCompactLoadingView({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: CupertinoColors.systemGreen,
                ),
                const SizedBox(height: 12),
                const CupertinoActivityIndicator(radius: 10),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Aguarde, processando dados...',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}