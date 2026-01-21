import 'package:flutter/material.dart';
import '../models/processing_filters.dart';

class ProcessingFiltersWidget extends StatefulWidget {
  final ProcessingFilters filters;
  final Function(ProcessingFilters) onFiltersChanged;

  const ProcessingFiltersWidget({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<ProcessingFiltersWidget> createState() =>
      _ProcessingFiltersWidgetState();
}

class _ProcessingFiltersWidgetState extends State<ProcessingFiltersWidget> {
  late ProcessingFilters _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.filters;
  }

  void _updateFilters(ProcessingFilters newFilters) {
    setState(() {
      _currentFilters = newFilters;
    });
    widget.onFiltersChanged(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Filtros de Processamento',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Limpar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filtro de Documentos
            _buildDocumentFilter(),
            const SizedBox(height: 16),

            // Filtro de Datas
            _buildDateFilter(),

            if (_currentFilters.hasSelections) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtros aplicados: ${_getFilterSummary()}',
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
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documentos:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _currentFilters.availableDocuments.map((doc) {
                final isSelected = _currentFilters.selectedDocuments.contains(
                  doc,
                );
                final recordCount = _currentFilters.getRecordCount(doc);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(doc),
                      if (recordCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green.shade600 : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$recordCount',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    print('🔘 Documento clicado: $doc (selected: $selected)');
                    print(
                      '   📄 Documentos atuais: ${_currentFilters.selectedDocuments}',
                    );
                    print(
                      '   📋 datesByDocument keys: ${_currentFilters.datesByDocument.keys.toList()}',
                    );

                    final newSelected = List<String>.from(
                      _currentFilters.selectedDocuments,
                    );
                    if (selected) {
                      newSelected.add(doc);
                    } else {
                      newSelected.remove(doc);
                    }

                    print('   📄 Novos documentos selecionados: $newSelected');

                    // Criar filtros temporários para calcular as datas disponíveis
                    final tempFilters = _currentFilters.copyWith(
                      selectedDocuments: newSelected,
                    );
                    final availableDatesForSelection =
                        tempFilters.availableDatesForSelectedDocuments;

                    print(
                      '   📅 Datas disponíveis para seleção: ${availableDatesForSelection.length}',
                    );
                    print(
                      '   📅 Primeiras 3 datas: ${availableDatesForSelection.take(3).toList()}',
                    );

                    // Filtrar datas selecionadas para manter apenas as que ainda estão disponíveis
                    final filteredSelectedDates =
                        _currentFilters.selectedDates
                            .where(
                              (date) =>
                                  availableDatesForSelection.contains(date),
                            )
                            .toList();

                    _updateFilters(
                      _currentFilters.copyWith(
                        selectedDocuments: newSelected,
                        selectedDates: filteredSelectedDates,
                      ),
                    );
                  },
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green.shade700,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    final availableDates = _currentFilters.availableDatesForSelectedDocuments;
    final hasSelectedDocuments = _currentFilters.selectedDocuments.isNotEmpty;
    final hasMultipleDocuments = _currentFilters.selectedDocuments.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Datas:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            if (hasSelectedDocuments && availableDates.isNotEmpty)
              TextButton.icon(
                onPressed: _selectAllDates,
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Todas'),
                style: TextButton.styleFrom(foregroundColor: Colors.green[600]),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Informações sobre disponibilidade quando múltiplos documentos estão selecionados
        if (hasMultipleDocuments && availableDates.isNotEmpty) ...[
          _buildDateAvailabilityInfo(),
          const SizedBox(height: 12),
        ],

        if (!hasSelectedDocuments)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selecione um ou mais documentos-plano para ver as datas disponíveis',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (availableDates.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nenhuma data disponível para os documentos selecionados',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    availableDates.map((date) {
                      final isSelected = _currentFilters.selectedDates.contains(
                        date,
                      );
                      final documentCount = _currentFilters
                          .getDocumentCountForDate(date);
                      final isInAllDocuments = _currentFilters
                          .isDateAvailableInAllSelectedDocuments(date);

                      return Tooltip(
                        message:
                            hasMultipleDocuments
                                ? 'Disponível em $documentCount de ${_currentFilters.selectedDocuments.length} documento(s)'
                                : _formatDate(date),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatDate(date),
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (hasMultipleDocuments) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isInAllDocuments
                                      ? Icons.check_circle
                                      : Icons.textsms_sharp,
                                  size: 14,
                                  color:
                                      isInAllDocuments
                                          ? Colors.green.shade600
                                          : Colors.orange.shade600,
                                ),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            final newSelected = List<String>.from(
                              _currentFilters.selectedDates,
                            );
                            if (selected) {
                              newSelected.add(date);
                            } else {
                              newSelected.remove(date);
                            }
                            _updateFilters(
                              _currentFilters.copyWith(
                                selectedDates: newSelected,
                              ),
                            );
                          },
                          selectedColor: Colors.green.shade100,
                          checkmarkColor: Colors.green.shade700,
                          side:
                              hasMultipleDocuments && !isInAllDocuments
                                  ? BorderSide(
                                    color: Colors.orange.shade300,
                                    width: 1,
                                  )
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateAvailabilityInfo() {
    final datesInAll = _currentFilters.datesAvailableInAllDocuments;
    final datesInSome = _currentFilters.datesAvailableInSomeDocuments;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Disponibilidade das datas:',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (datesInAll.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${datesInAll.length} data(s) em todos os documentos',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (datesInSome.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.textsms_sharp,
                  color: Colors.orange.shade600,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${datesInSome.length} data disponiveis em um documento',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Passe o mouse sobre uma data para ver em quantos documentos ela está disponível.',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    _updateFilters(
      _currentFilters.copyWith(selectedDocuments: [], selectedDates: []),
    );
  }

  void _selectAllDates() {
    _updateFilters(
      _currentFilters.copyWith(
        selectedDates: List<String>.from(
          _currentFilters.availableDatesForSelectedDocuments,
        ),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}';
      }
    } catch (e) {
      // Se falhar, retorna a data original
    }
    return date;
  }

  String _getFilterSummary() {
    final parts = <String>[];
    if (_currentFilters.selectedDocuments.isNotEmpty) {
      parts.add('${_currentFilters.selectedDocuments.length} documento(s)');
    }
    if (_currentFilters.selectedDates.isNotEmpty) {
      parts.add('${_currentFilters.selectedDates.length} data(s)');
    }
    final totalRecords = _currentFilters.totalSelectedRecords;
    if (totalRecords > 0) {
      parts.add('~$totalRecords registro(s)');
    }
    return parts.join(', ');
  }
}
