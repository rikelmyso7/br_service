import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/material.dart';

import '../repository/file_repository_impl.dart';

class ExcelViewer extends StatefulWidget {
  final String filePath;
  final String sheetName;

  const ExcelViewer({
    Key? key,
    required this.filePath,
    this.sheetName = 'Layout',
  }) : super(key: key);

  @override
  _ExcelViewerState createState() => _ExcelViewerState();
}

class _ExcelViewerState extends State<ExcelViewer> {
  late Future<_PreviewData> _load;

  @override
  void initState() {
    super.initState();
    _load = _loadPreview();
  }

  Future<_PreviewData> _loadPreview() async {
    try {
      final exe = await FileRepositoryImpl().getExecutable();
      final exePath = exe.path;
      dev.log('Carregando preview: ${widget.filePath}', name: 'ExcelViewer');

      final result = await Process.run(
        exePath,
        ['--input', widget.filePath, '--get-preview', '--quiet'],
        runInShell: true,
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );

      if (result.exitCode != 0) {
        final msg = 'CLI --get-preview falhou (code=${result.exitCode}): ${result.stderr}';
        dev.log(msg, name: 'ExcelViewer', level: 1000);
        throw Exception(msg);
      }

      final raw = result.stdout.toString().trim();
      final data = json.decode(raw) as Map<String, dynamic>;
      if (data.containsKey('erro')) {
        dev.log('Erro retornado pelo CLI: ${data['erro']}', name: 'ExcelViewer', level: 1000);
        throw Exception(data['erro']);
      }

      final headers = (data['headers'] as List<dynamic>).cast<String>();
      final rows = (data['rows'] as List<dynamic>)
          .map((r) => (r as List<dynamic>).cast<String>())
          .toList();

      dev.log('Preview carregado: ${headers.length} colunas, ${rows.length} linhas', name: 'ExcelViewer');
      return _PreviewData(headers: headers, rows: rows);
    } catch (e, st) {
      dev.log('Falha ao carregar preview', name: 'ExcelViewer', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PreviewData>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorCard(
            message: 'Erro ao carregar arquivo',
            details: '${snap.error}',
            onRetry: () => setState(() => _load = _loadPreview()),
          );
        }

        final res = snap.data!;
        final source = _PreviewDataSource(rows: res.rows, headers: res.headers);

        final columns = res.headers
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

        final rowsPerPage = _pickInitialRowsPerPage(res.rows.length);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
                      Icon(Icons.table_chart, size: 20, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Dados da planilha (${res.rows.length} registros)',
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
                      width: (res.headers.length * 140.0).clamp(600.0, double.infinity),
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
                          availableRowsPerPage: const [10, 25, 50, 100, 200, 500],
                          onRowsPerPageChanged: (v) {
                            if (v != null) setState(() {});
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
    if (total <= 100) return 50;
    return 100;
  }
}

class _PreviewData {
  final List<String> headers;
  final List<List<String>> rows;
  _PreviewData({required this.headers, required this.rows});
}

class _PreviewDataSource extends DataTableSource {
  final List<String> headers;
  final List<List<String>> rows;

  _PreviewDataSource({required this.headers, required this.rows});

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= rows.length) return null;
    final row = rows[index];
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

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
