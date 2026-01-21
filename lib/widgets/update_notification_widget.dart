import 'package:flutter/material.dart';
import 'package:br_service_ui/services/update_service.dart';

/// Widget simples para exibir notificação de atualização disponível
class UpdateNotificationWidget extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const UpdateNotificationWidget({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  @override
  State<UpdateNotificationWidget> createState() =>
      _UpdateNotificationWidgetState();
}

class _UpdateNotificationWidgetState extends State<UpdateNotificationWidget> {
  bool _isUpdating = false;
  double _downloadProgress = 0.0;
  String _status = '';
  bool _hasError = false;
  bool _isInstalling = false;

  Future<void> _handleUpdate() async {
    setState(() {
      _isUpdating = true;
      _downloadProgress = 0.0;
      _status = 'Iniciando...';
      _hasError = false;
      _isInstalling = false;
    });

    try {
      final success = await UpdateService.downloadAndInstallUpdate(
        widget.updateInfo,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _status = status;
              _isInstalling =
                  status.contains('Instalando') ||
                  status.contains('Executando');
            });
          }
        },
      );

      if (!success && mounted) {
        setState(() {
          _hasError = true;
          _status = 'Falha na atualização';
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = 'Erro: $e';
          _isUpdating = false;
        });
      }
    }
  }

  void _handleDismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _hasError ? Icons.error : Icons.system_update,
                color: _hasError ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasError ? 'Erro na Atualização' : 'Nova Atualização',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _hasError
                          ? _status
                          : 'Versão ${widget.updateInfo.version}',
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progresso ou status
          if (_isUpdating) ...[
            const SizedBox(height: 16),
            Column(
              children: [
                Text(_status, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                if (!_isInstalling && _downloadProgress > 0) ...[
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12)
                  ),
                ] else if (_isInstalling) ...[
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      (_isUpdating && !_hasError) ? null : _handleDismiss,
                  child: const Text('Fechar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isUpdating
                          ? null
                          : (_hasError ? _handleUpdate : _handleUpdate),
                  child:
                      _isUpdating
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(_hasError ? 'Tentar Novamente' : 'Atualizar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget que verifica atualizações automaticamente e exibe notificação
class AutoUpdateChecker extends StatefulWidget {
  final Widget child;
  final Duration checkInterval;

  const AutoUpdateChecker({
    super.key,
    required this.child,
    this.checkInterval = const Duration(hours: 24),
  });

  @override
  State<AutoUpdateChecker> createState() => _AutoUpdateCheckerState();
}

class _AutoUpdateCheckerState extends State<AutoUpdateChecker> {
  UpdateInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();

    Stream.periodic(widget.checkInterval).listen((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    try {
      final updateInfo = await UpdateService.checkForUpdates();
      if (mounted && updateInfo != null) {
        setState(() {
          _availableUpdate = updateInfo;
        });
      }
    } catch (e) {
      // Ignorar erros silenciosamente
    }
  }

  void _dismissUpdate() {
    setState(() {
      _availableUpdate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        if (_availableUpdate != null)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: UpdateNotificationWidget(
              updateInfo: _availableUpdate!,
              onDismiss: _dismissUpdate,
            ),
          ),
      ],
    );
  }
}
