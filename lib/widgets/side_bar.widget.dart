import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:br_service_ui/widgets/update_test_widget.dart';
import 'package:br_service_ui/services/update_service.dart';
import 'package:br_service_ui/widgets/update_notification_widget.dart';

import 'output_dir_button.dart';
import 'file_picker_widget.dart';

class Sidebar extends StatefulWidget {
  const Sidebar();

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  UpdateInfo? _availableUpdate;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final updateInfo = await UpdateService.checkForUpdates();
      if (mounted) {
        setState(() {
          _availableUpdate = updateInfo;
        });
      }
    } catch (e) {
      // Ignorar erros silenciosamente
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _showUpdateDialog() {
    if (_availableUpdate == null) return;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(16),
              child: UpdateNotificationWidget(
                updateInfo: _availableUpdate!,
                onDismiss: () => Navigator.of(context).pop(),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width > 600 ? 260 : 200,
      color: const Color(0xFF007547),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('lib/assets/br.png'),
          const SizedBox(height: 28),
          Text(
            'Como utilizar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '- 1. Selecione o arquivo Excel (.xlsx) que será usado para gerar os outros arquivos',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- 2. Requisitos do arquivo: Tabela Layout, colunas Contrato Valor e Data Crédito, deve haver Documento e Plano financeiro na tabela layout',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- 3. Nos filtros você pode selecionar os Documuentos que deseja exportar e as datas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- 4. Selecione a pasta de destino onde os arquivos gerados serão salvos',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const Spacer(),

          // Card de atualização (ocultar em telas pequenas)
          if (_availableUpdate != null &&
              (MediaQuery.of(context).size.width >= 800 &&
                  MediaQuery.of(context).size.height >= 680))
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.system_update,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Atualização',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${_availableUpdate!.version}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showUpdateDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF007547),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Atualizar'),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(color: Colors.white70),
          const Text(
            'Desenvolvido por\nRikelmy R.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
