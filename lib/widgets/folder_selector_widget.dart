import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FolderSelector extends StatefulWidget {
  final Function(String folderPath) onFolderSelected;

  const FolderSelector({Key? key, required this.onFolderSelected})
      : super(key: key);

  @override
  _FolderSelectorState createState() => _FolderSelectorState();
}

class _FolderSelectorState extends State<FolderSelector> {
  bool _isLoading = false;

  Future<void> _selectFolder() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        widget.onFolderSelected(result);
      }
    } catch (e) {
      // Tratar erro se necessário
      debugPrint('Erro ao selecionar pasta: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _selectFolder,
      icon: _isLoading 
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.folder_open),
      label: Text(_isLoading ? 'Selecionando...' : 'Pasta de destino'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }
}