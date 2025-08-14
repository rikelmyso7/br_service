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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<FileProcessorBloc>().add(
            const ProceedToValidationEvent(),
          );
        },
        backgroundColor: Colors.green,
        label: Row(
          children: [
            const Text('Continuar', style: TextStyle(color: Colors.white)),
            SizedBox(width: 5),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visualização: ${excelData.fileName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  context.read<FileProcessorBloc>().add(const ResetEvent());
                },
                icon: const Icon(Icons.home),
                label: const Text('Novo processamento'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: ExcelViewer(filePath: filePath)),
        ],
      ),
    );
  }
}
