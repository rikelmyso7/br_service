import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/events/file_events_bloc.dart';
import '../bloc/file_processor_bloc.dart';
import '../bloc/states/file_processor_bloc.dart';
import '../bloc/states/validation_processor_bloc.dart';

class OutputDirButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileProcessorBloc, FileProcessorState>(
      builder: (context, state) {
        final enabled = state is ValidationState && state.canProceed;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? Colors.white : Colors.grey.shade400,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: enabled
                ? () async {
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir != null) {
                      context
                          .read<FileProcessorBloc>()
                          .add(StartProcessingEvent(dir));
                    }
                  }
                : null,
            icon: const Icon(Icons.folder_open),
            label: const Text('Pasta de destino'),
          ),
        );
      },
    );
  }
}