import 'package:br_service_ui/bloc/events/file_events_bloc.dart';
import 'package:br_service_ui/bloc/file_processor_bloc.dart';
import 'package:br_service_ui/widgets/folder_selector_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/excel_data.dart';
import '../models/processing_filters.dart';
import '../models/validation_item.dart';
import 'processing_filters_component.dart';

class ValidationView extends StatefulWidget {
  final List<ValidationItem> validationItems;
  final ExcelData excelData;

  const ValidationView({
    super.key,
    required this.validationItems,
    required this.excelData,
  });

  @override
  State<ValidationView> createState() => _ValidationViewState();
}

class _ValidationViewState extends State<ValidationView> {
  late ProcessingFilters _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters =
        widget.excelData.processingFilters ??
        ProcessingFilters(
          selectedDocuments: [],
          selectedDates: [],
          availableDocuments: [],
          availableDates: [],
          availableDocPlanos: [], datesByDocument: {},
        );
  }

  void _handleFolderSelection(BuildContext context, String folderPath) {
    // Dispara o evento para o BLoC com os filtros aplicados
    context.read<FileProcessorBloc>().add(
      StartProcessingEvent(folderPath, filters: _currentFilters),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allValid = widget.validationItems.every((item) => item.isValid);

    return Scaffold(
      floatingActionButton:
          allValid
              ? FloatingActionButton.extended(
                onPressed: () async {
                  final folderPath =
                      await FilePicker.platform.getDirectoryPath();
                  if (folderPath != null && context.mounted) {
                    _handleFolderSelection(context, folderPath);
                  }
                },
                backgroundColor: Colors.green,
                tooltip: 'Selecionar Pasta',
                icon: const Icon(Icons.folder_open, color: Colors.white),
                label: const Text(
                  'Pasta de Destino',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Checklist de Validação',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            SizedBox(height: 16),
            SizedBox(
              height:
                  widget.validationItems.length * 80.0 +
                  20, // Estimativa de altura
              child: ListView.builder(
                itemCount: widget.validationItems.length,
                itemBuilder: (context, index) {
                  final item = widget.validationItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            item.isValid ? Colors.green : Colors.red,
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
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                              : const Icon(Icons.error, color: Colors.red),
                    ),
                  );
                },
              ),
            ),
            if (widget.validationItems.every((i) => i.isValid) &&
                widget.excelData.docPlanos.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Análise CLI Completa',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Documentos & Planos detectados:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children:
                                widget.excelData.docPlanos
                                    .map(
                                      (dp) => Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          '${dp.documento} → ${dp.plano}',
                                          style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.all(12),

                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Total: ${widget.excelData.docPlanos.length} combinações Documento-Plano validadas',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Componente de filtros (apenas se validação passou)
            Builder(
              builder: (context) {
                final allValid = widget.validationItems.every((i) => i.isValid);
                final hasFilters = widget.excelData.processingFilters != null;

                print('🔍 ValidationView Filter Debug:');
                print('   📋 All valid: $allValid');
                print('   📊 Has processingFilters: $hasFilters');
                print(
                  '   📄 Available documents: ${_currentFilters.availableDocuments}',
                );
                print(
                  '   📅 Available dates: ${_currentFilters.availableDates}',
                );
                print('   🎯 Should show filters: ${allValid && hasFilters}');

                if (allValid && hasFilters) {
                  return Column(
                    children: [
                      ProcessingFiltersWidget(
                        filters: _currentFilters,
                        onFiltersChanged: (newFilters) {
                          setState(() {
                            _currentFilters = newFilters;
                          });
                        },
                      ),
                      SizedBox(height: 60),
                    ],
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'DEBUG: Filtros não exibidos - allValid: $allValid, hasFilters: $hasFilters',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }
              },
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
        ),
      ),
    );
  }
}
