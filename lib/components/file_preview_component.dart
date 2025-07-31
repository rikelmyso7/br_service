import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/events/file_events_bloc.dart';
import '../bloc/file_processor_bloc.dart';
import '../models/excel_data.dart';
import '../widgets/excel_viewer.dart';

class FilePreviewView extends StatelessWidget {
  final ExcelData excelData;
  final String filePath;

  const FilePreviewView({required this.excelData, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Visualização: ${excelData.fileName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.read<FileProcessorBloc>().add(
                  const ProceedToValidationEvent(),
                );
              },
              label: const Text(
                'Continuar',
                style: TextStyle(color: Colors.green),
              ),
              icon: const Icon(Icons.arrow_forward, color: Colors.green),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: ExcelViewer(filePath: filePath)),
      ],
    );
  }
}
