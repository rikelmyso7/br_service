import 'dart:io';
import 'package:flutter/material.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ExcelViewer extends StatefulWidget {
  final String filePath;

  const ExcelViewer({Key? key, required this.filePath}) : super(key: key);

  @override
  _ExcelViewerState createState() => _ExcelViewerState();
}

class _ExcelViewerState extends State<ExcelViewer> {
  late Future<SpreadsheetDecoder> _excelData;

  @override
  void initState() {
    super.initState();
    _excelData = _loadExcelData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<SpreadsheetDecoder>(
        future: _excelData,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final excel = snapshot.data!;

            if (!excel.tables.containsKey('Layout')) {
              return Center(
                child: Card(
                  margin: EdgeInsets.all(20),
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
            final headers = sheet.rows[0];
            final dataRows = sheet.rows.skip(1).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
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
                        color: Colors.blue[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.table_chart,
                            color: Colors.green[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dados da Planilha (${dataRows.length} registros)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tabela scrollável
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.grey[300]),
                            child: DataTable(
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
                              headingRowColor: MaterialStateProperty.all(
                                Colors.grey[100],
                              ),
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              columns:
                                  headers.map((header) {
                                    return DataColumn(
                                      label: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 100,
                                        ),
                                        child: Text(
                                          header.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              rows:
                                  dataRows.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final row = entry.value;

                                    return DataRow(
                                      color: MaterialStateProperty.resolveWith<
                                        Color?
                                      >((Set<MaterialState> states) {
                                        if (states.contains(
                                          MaterialState.hovered,
                                        )) {
                                          return Colors.blue[50];
                                        }
                                        // Cores alternadas para as linhas
                                        return index.isEven
                                            ? Colors.white
                                            : Colors.grey[25];
                                      }),
                                      cells:
                                          row.map((cell) {
                                            return DataCell(
                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 100,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  cell?.toString() ?? '',
                                                  style: TextStyle(
                                                    color:
                                                        cell == null
                                                            ? Colors.grey[400]
                                                            : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
