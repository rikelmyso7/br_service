import 'dart:io';
import 'package:flutter/material.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ExtractedCellInfo {
  final int row;
  final int column;
  final String value;
  final String type; // 'header', 'data', 'docPlano'

  const ExtractedCellInfo({
    required this.row,
    required this.column,
    required this.value,
    required this.type,
  });
}

class ExcelViewer extends StatefulWidget {
  final String filePath;
  final List<ExtractedCellInfo> extractedCells;
  final bool showExtractedOnly;

  const ExcelViewer({
    Key? key, 
    required this.filePath,
    this.extractedCells = const [],
    this.showExtractedOnly = false,
  }) : super(key: key);

  @override
  _ExcelViewerState createState() => _ExcelViewerState();
}

class _ExcelViewerState extends State<ExcelViewer> with TickerProviderStateMixin {
  late Future<SpreadsheetDecoder> _excelData;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;
  bool _showLegend = true;

  @override
  void initState() {
    super.initState();
    _excelData = _loadExcelData();
    
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _highlightAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));
    
    // Inicia a animação de destaque
    _highlightController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  Future<SpreadsheetDecoder> _loadExcelData() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      return SpreadsheetDecoder.decodeBytes(bytes, update: true);
    } on SpreadsheetDecoder catch (e) {
      throw Exception('Falha ao decodificar o Excel: ${e}');
    } on FileSystemException catch (e) {
      throw Exception('Não foi possível ler o arquivo: ${e.message}');
    } catch (e) {
      throw Exception('Erro desconhecido: $e');
    }
  }

  Color _getCellColor(int rowIndex, int colIndex) {
    final extracted = widget.extractedCells.firstWhere(
      (cell) => cell.row == rowIndex && cell.column == colIndex,
      orElse: () => ExtractedCellInfo(row: -1, column: -1, value: '', type: ''),
    );

    if (extracted.row == -1) return Colors.transparent;

    switch (extracted.type) {
      case 'header':
        return Colors.blue.withOpacity(0.3);
      case 'data':
        return Colors.green.withOpacity(0.3);
      case 'docPlano':
        return Colors.orange.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  bool _isCellExtracted(int rowIndex, int colIndex) {
    return widget.extractedCells.any(
      (cell) => cell.row == rowIndex && cell.column == colIndex,
    );
  }

  Widget _buildLegend() {
    if (!_showLegend || widget.extractedCells.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Células Extraídas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _showLegend = false),
                tooltip: 'Fechar legenda',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(Colors.blue, 'Cabeçalhos', Icons.table_rows),
              _buildLegendItem(Colors.green, 'Dados', Icons.data_array),
              _buildLegendItem(Colors.orange, 'Documento/Plano', Icons.description),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<SpreadsheetDecoder>(
        future: _excelData,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final excel = snapshot.data!;

            if (!excel.tables.containsKey('Layout')) {
              return Center(
                child: Card(
                  margin: const EdgeInsets.all(20),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.orange[600],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aba não encontrada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A aba "Layout" não foi encontrada no arquivo Excel.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final sheet = excel.tables['Layout']!;
            final allRows = sheet.rows;

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Legenda
                  _buildLegend(),
                  
                  // Card da tabela
                  Expanded(
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header da tabela
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[50]!, Colors.blue[100]!],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _highlightAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _highlightAnimation.value,
                                      child: Icon(
                                        Icons.table_chart,
                                        color: Colors.green[600],
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Planilha Layout',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                      Text(
                                        '${allRows.length} linhas • ${widget.extractedCells.length} células extraídas',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.extractedCells.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green[300]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Extraído',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Tabela scrollável
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: AnimatedBuilder(
                                    animation: _highlightAnimation,
                                    builder: (context, child) {
                                      return DataTable(
                                        headingRowHeight: 56,
                                        dataRowHeight: 52,
                                        horizontalMargin: 16,
                                        columnSpacing: 24,
                                        headingTextStyle: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                        ),
                                        dataTextStyle: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                        border: TableBorder(
                                          horizontalInside: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        columns: allRows.isNotEmpty
                                            ? allRows.first.asMap().entries.map((entry) {
                                                final colIndex = entry.key;
                                                final header = entry.value;
                                                
                                                return DataColumn(
                                                  label: Container(
                                                    constraints: const BoxConstraints(
                                                      minWidth: 120,
                                                    ),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _getCellColor(0, colIndex),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: _isCellExtracted(0, colIndex)
                                                          ? Border.all(
                                                              color: Colors.green,
                                                              width: 2,
                                                            )
                                                          : null,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (_isCellExtracted(0, colIndex))
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 16,
                                                            color: Colors.green[700],
                                                          ),
                                                        if (_isCellExtracted(0, colIndex))
                                                          const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            header?.toString() ?? '',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              color: _isCellExtracted(0, colIndex)
                                                                  ? Colors.green[800]
                                                                  : Colors.grey[800],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList()
                                            : [],
                                        rows: allRows.skip(1).toList().asMap().entries.map((entry) {
                                          final rowIndex = entry.key + 1;
                                          final row = entry.value;

                                          return DataRow(
                                            color: MaterialStateProperty.resolveWith<Color?>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.hovered)) {
                                                  return Colors.blue[50];
                                                }
                                                return rowIndex.isEven
                                                    ? Colors.white
                                                    : Colors.grey[25];
                                              },
                                            ),
                                            cells: row.asMap().entries.map((cellEntry) {
                                              final colIndex = cellEntry.key;
                                              final cell = cellEntry.value;
                                              final isExtracted = _isCellExtracted(rowIndex, colIndex);
                                              final cellColor = _getCellColor(rowIndex, colIndex);

                                              return DataCell(
                                                Container(
                                                  constraints: const BoxConstraints(
                                                    minWidth: 120,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isExtracted
                                                        ? cellColor.withOpacity(
                                                            _highlightAnimation.value * 0.5,
                                                          )
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: isExtracted
                                                        ? Border.all(
                                                            color: Colors.green.withOpacity(
                                                              _highlightAnimation.value,
                                                            ),
                                                            width: 2,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (isExtracted)
                                                        Transform.scale(
                                                          scale: _highlightAnimation.value,
                                                          child: Icon(
                                                            Icons.check_circle,
                                                            size: 14,
                                                            color: Colors.green[700],
                                                          ),
                                                        ),
                                                      if (isExtracted) const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          cell?.toString() ?? '',
                                                          style: TextStyle(
                                                            color: isExtracted
                                                                ? Colors.green[800]
                                                                : (cell == null
                                                                    ? Colors.grey[400]
                                                                    : Colors.black87),
                                                            fontWeight: isExtracted
                                                                ? FontWeight.w600
                                                                : FontWeight.normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red[600]),
                      const SizedBox(height: 16),
                      const Text(
                        'Erro ao carregar arquivo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _excelData = _loadExcelData();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                ),
                const SizedBox(height: 16),
                Text(
                  'Carregando planilha...',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}