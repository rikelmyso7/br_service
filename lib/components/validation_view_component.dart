import 'package:br_service_ui/bloc/events/file_events_bloc.dart';
import 'package:br_service_ui/bloc/file_processor_bloc.dart';
import 'package:br_service_ui/widgets/folder_selector_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/excel_data.dart';
import '../models/validation_item.dart';

class ValidationView extends StatelessWidget {
  final List<ValidationItem> validationItems;
  final ExcelData excelData;

  const ValidationView({
    super.key,
    required this.validationItems,
    required this.excelData,
  });

  void _handleFolderSelection(BuildContext context, String folderPath) {
    // Dispara o evento para o BLoC
    context.read<FileProcessorBloc>().add(
      StartProcessingEvent(folderPath),
    );
    
    // Mostra feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pasta selecionada: ${folderPath.split('/').last.split('\\').last}',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allValid = validationItems.every((item) => item.isValid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Checklist de Validação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (validationItems.every((i) => i.isValid) &&
                excelData.docPlanos.isNotEmpty)
              FolderSelector(
                onFolderSelected: (folderPath) => _handleFolderSelection(context, folderPath),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: validationItems.length,
            itemBuilder: (context, index) {
              final item = validationItems[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isValid ? Colors.green : Colors.red,
                    child: Icon(
                      item.isValid ? Icons.check : Icons.close,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description),
                      if (item.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing:
                      item.isValid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.error, color: Colors.red),
                ),
              );
            },
          ),
        ),
        if (validationItems.every((i) => i.isValid) &&
            excelData.docPlanos.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Documentos & Planos encontrados',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        excelData.docPlanos
                            .map(
                              (dp) => Chip(
                                label: Text(
                                  '${dp.documento} - ${dp.plano}',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
        if (!allValid)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Arquivo não passou na validação',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Corrija os problemas acima antes de continuar',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
