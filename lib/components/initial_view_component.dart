import 'package:br_service_ui/bloc/events/file_events_bloc.dart';
import 'package:br_service_ui/bloc/file_processor_bloc.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InitialView extends StatefulWidget {
  final Function(String filePath)? onFileSelected;

  const InitialView({super.key, this.onFileSelected});

  @override
  _InitialViewState createState() => _InitialViewState();
}

class _InitialViewState extends State<InitialView>
    with TickerProviderStateMixin {
  bool _isDragging = false;

  void _handleFileSelection(String filePath) {
    if (widget.onFileSelected != null) {
      widget.onFileSelected!(filePath);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result?.files.single.path != null) {
      context.read<FileProcessorBloc>().add(
        SelectFileEvent(result!.files.single.path!),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Arquivo selecionado: $fileName')),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  bool _isValidFile(String fileName) {
    return fileName.toLowerCase().endsWith('.xlsx') ||
        fileName.toLowerCase().endsWith('.xls');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          child: DropTarget(
            onDragDone: (detail) async {
              setState(() => _isDragging = false);

              if (detail.files.isNotEmpty) {
                final file = detail.files.first;
                final fileName = file.name;

                if (_isValidFile(fileName)) {
                  _showSuccessSnackBar(fileName);
                  _handleFileSelection(file.path);
                } else {
                  _showErrorSnackBar(
                    'Formato não suportado. Use apenas arquivos .xlsx ou .xls',
                  );
                }
              }
            },
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500, minHeight: 300),
              decoration: BoxDecoration(
                color: _isDragging ? Colors.green[50] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDragging ? Colors.green[400]! : Colors.grey[300]!,
                  width: _isDragging ? 3 : 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        _isDragging
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    blurRadius: _isDragging ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                _isDragging
                                    ? Colors.green[100]
                                    : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isDragging
                                ? Icons.file_download
                                : Icons.upload_file,
                            size: 48,
                            color:
                                _isDragging
                                    ? Colors.green[600]
                                    : Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Título principal
                        Text(
                          _isDragging
                              ? 'Solte o arquivo aqui!'
                              : 'Arraste seu arquivo Excel aqui',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color:
                                _isDragging
                                    ? Colors.green[700]
                                    : Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Subtítulo
                        Text(
                          _isDragging
                              ? 'Arquivo será processado automaticamente'
                              : 'ou clique para selecionar um arquivo',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _isDragging
                                    ? Colors.green[600]
                                    : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Linha divisória
                        if (!_isDragging) ...[
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'OU',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Botão de seleção
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Selecionar Arquivo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Info sobre formatos
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Formatos suportados: .xlsx, .xls',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
