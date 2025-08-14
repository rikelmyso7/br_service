import 'dart:io';
import 'package:br_service_ui/utils/format_cells_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ExcelViewer extends StatefulWidget {
  final String filePath;
  final String sheetName;
  final String? dateFormat;

  const ExcelViewer({
    Key? key,
    required this.filePath,
    this.sheetName = 'Layout',
    this.dateFormat = 'dd/MM/yyyy',
  }) : super(key: key);

  @override
  _ExcelViewerState createState() => _ExcelViewerState();
}

class _ExcelViewerState extends State<ExcelViewer> {
  late Future<_ExcelLoadResult> _load;

  @override
  void initState() {
    super.initState();
    _load = _loadExcel();
  }

  @override
  void dispose() {
    _load.then((result) => result.decoder); // Se a biblioteca suportar
    super.dispose();
  }

  Future<_ExcelLoadResult> _loadExcel() async {
    final bytes = await File(widget.filePath).readAsBytes();
    final decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);

    if (!decoder.tables.containsKey(widget.sheetName)) {
      throw Exception(
        'A aba "${widget.sheetName}" não foi encontrada no arquivo.',
      );
    }

    final table = decoder.tables[widget.sheetName]!;
    if (table.rows.isEmpty) {
      throw Exception('A aba "${widget.sheetName}" está vazia.');
    }

    // Detecta a primeira linha não-vazia como cabeçalho (robusto p/ seus layouts)
    int headerRowIdx = table.rows.indexWhere(
      (r) => r.any((c) => (c?.toString().trim() ?? '').isNotEmpty),
    );
    if (headerRowIdx < 0) headerRowIdx = 0;

    final headers =
        table.rows[headerRowIdx]
            .map(
              (cell) => formatCell(
                cell,
                dateFormat: widget.dateFormat ?? 'dd/MM/yyyy',
              ),
            )
            .toList();

    final firstDataRow = headerRowIdx + 1;
    final totalDataRows = (table.rows.length - firstDataRow).clamp(
      0,
      table.rows.length,
    );

    return _ExcelLoadResult(
      decoder: decoder,
      table: table,
      headers: headers,
      headerRowIndex: headerRowIdx,
      firstDataRowIndex: firstDataRow,
      dataRowCount: totalDataRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExcelLoadResult>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCard(
            message: 'Erro ao carregar arquivo',
            details: '${snap.error}',
            onRetry: () => setState(() => _load = _loadExcel()),
          );
        }

        final res = snap.data!;
        final source = _ExcelDataSource(
          table: res.table,
          headers: res.headers,
          firstDataRowIndex: res.firstDataRowIndex,
          totalRows: res.dataRowCount,
          dateFormat: widget.dateFormat ?? 'dd/MM/yyyy',
        );

        final columns =
            res.headers
                .map(
                  (h) => DataColumn(
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: Text(
                        h.isEmpty ? '—' : h,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
                .toList();

        int rowsPerPage = _pickInitialRowsPerPage(res.dataRowCount);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(
                        Icons.table_chart,
                        size: 20,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dados da planilha (${res.dataRowCount} registros)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[600],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Aba: ${widget.sheetName}',
                        style: TextStyle(color: Colors.green[600]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      // largura grande para permitir rolagem horizontal sem quebrar
                      width: (res.headers.length * 140.0).clamp(
                        600.0,
                        double.infinity,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          cardTheme: CardThemeData(margin: EdgeInsets.zero),
                          dividerColor: Colors.grey[300],
                        ),
                        child: PaginatedDataTable(
                          header: const SizedBox.shrink(),
                          columns: columns,
                          source: source,
                          initialFirstRowIndex: 0,
                          rowsPerPage: rowsPerPage,
                          availableRowsPerPage: const [
                            10,
                            25,
                            50,
                            100,
                            200,
                            500,
                          ],
                          onRowsPerPageChanged: (v) {
                            if (v != null) {
                              setState(() {
                                // recria a tabela apenas com outra densidade de página
                                // (a fonte continua a mesma)
                              });
                            }
                          },
                          showFirstLastButtons: true,
                          columnSpacing: 24,
                          horizontalMargin: 16,
                          dataRowMaxHeight: 52,
                          dataRowMinHeight: 48,
                          showCheckboxColumn: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _pickInitialRowsPerPage(int total) {
    if (total <= 25) return 25;
    if (total <= 50) return 50;
    if (total <= 100) return 100;
    return 200;
  }
}

class _ExcelLoadResult {
  final SpreadsheetDecoder decoder;
  final SpreadsheetTable table;
  final List<String> headers;
  final int headerRowIndex;
  final int firstDataRowIndex;
  final int dataRowCount;

  _ExcelLoadResult({
    required this.decoder,
    required this.table,
    required this.headers,
    required this.headerRowIndex,
    required this.firstDataRowIndex,
    required this.dataRowCount,
  });
}

/// DataTableSource que entrega somente as linhas da página atual.
/// Não materializa *widgets* para tudo — apenas para os índices visíveis.
class _ExcelDataSource extends DataTableSource {
  final SpreadsheetTable table;
  final List<String> headers;
  final int firstDataRowIndex;
  final int totalRows;
  final String dateFormat;

  _ExcelDataSource({
    required this.table,
    required this.headers,
    required this.firstDataRowIndex,
    required this.totalRows,
    this.dateFormat = 'dd/MM/yyyy',
  });

  // Cache LRU simples por índice de linha da planilha → valores já tratados
  final Map<int, List<String>> _rowCache = {};
  static const int _maxCache = 1000; // ajuste conforme necessário

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= rowCount) return null;

    final sheetIndex = firstDataRowIndex + index;
    final row = _getRowValues(sheetIndex);

    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.resolveWith<Color?>((states) {
        if (states.contains(MaterialState.hovered)) return Colors.blue[50];
        return (index % 2 == 0) ? Colors.white : Colors.grey[100];
      }),
      cells: List.generate(headers.length, (col) {
        final val = (col < row.length) ? row[col] : '';
        return DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: Text(
              val,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: val.isEmpty ? Colors.grey[400] : Colors.black87,
              ),
            ),
          ),
        );
      }),
    );
  }

  List<String> _getRowValues(int sheetIndex) {
    final cached = _rowCache[sheetIndex];
    if (cached != null) return cached;

    final raw = table.rows[sheetIndex];
    final values = List<String>.generate(headers.length, (i) {
      final cell = (i < raw.length) ? raw[i] : null;
      return formatCell(cell, dateFormat: dateFormat);
    });

    // guarda em cache com política simples
    _rowCache[sheetIndex] = values;
    if (_rowCache.length > _maxCache) {
      _rowCache.remove(_rowCache.keys.first);
    }
    return values;
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => totalRows;

  @override
  int get selectedRowCount => 0;
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, this.details, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.orange[700]),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
