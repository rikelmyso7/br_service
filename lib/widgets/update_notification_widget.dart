import 'package:flutter/material.dart';
import 'package:br_service_ui/services/update_service.dart';
import 'package:br_service_ui/utils/responsive_utils.dart';

/// Widget para exibir notificação de atualização disponível
class UpdateNotificationWidget extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const UpdateNotificationWidget({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  @override
  State<UpdateNotificationWidget> createState() => _UpdateNotificationWidgetState();
}

class _UpdateNotificationWidgetState extends State<UpdateNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  bool _isUpdating = false;
  String _updateStatus = '';
  double _downloadProgress = 0.0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isUpdating = true;
      _hasError = false;
      _downloadProgress = 0.0;
      _updateStatus = 'Iniciando...';
    });
    
    _pulseAnimationController.repeat(reverse: true);

    try {
      final success = await UpdateService.downloadAndInstallUpdate(
        widget.updateInfo,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _updateStatus = status;
              _progressAnimationController.animateTo(progress);
            });
          }
        },
      );
      
      if (!success && mounted) {
        _pulseAnimationController.stop();
        setState(() {
          _hasError = true;
          _updateStatus = 'Erro durante a atualização';
          _isUpdating = false;
          _downloadProgress = 0.0;
        });
        
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _updateStatus = '';
              _hasError = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _pulseAnimationController.stop();
        setState(() {
          _hasError = true;
          _updateStatus = 'Erro: $e';
          _isUpdating = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  void _handleDismiss() async {
    await _animationController.reverse();
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _showReleaseNotes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Novidades v${widget.updateInfo.version}'),
        content: SingleChildScrollView(
          child: ResponsiveContainer(
            maxWidth: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lançado em: ${_formatDate(widget.updateInfo.releaseDate)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.updateInfo.releaseNotes.isNotEmpty
                      ? widget.updateInfo.releaseNotes
                      : 'Nenhuma descrição disponível.',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              UpdateService.openReleasePage();
            },
            child: const Text('Ver no GitHub'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isUpdating && !_hasError ? _pulseAnimation.value : 1.0,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: ResponsiveUtils.getResponsivePadding(context),
                      decoration: BoxDecoration(
                        gradient: _isUpdating && !_hasError
                            ? LinearGradient(
                                colors: [Colors.green[600]!, Colors.green[400]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : _hasError
                                ? LinearGradient(
                                    colors: [Colors.red[600]!, Colors.red[400]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [Colors.green[600]!, Colors.green[400]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _isUpdating && !_hasError
                                ? Colors.green.withOpacity(0.3)
                                : _hasError
                                    ? Colors.red.withOpacity(0.3)
                                    : Colors.green.withOpacity(0.3),
                            blurRadius: _isUpdating ? 15 : 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ResponsiveContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Cabeçalho
                            Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(_isUpdating ? 0.3 : 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isUpdating && !_hasError
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : _hasError
                                            ? const Icon(
                                                Icons.error,
                                                color: Colors.white,
                                                size: 24,
                                                key: ValueKey('error'),
                                              )
                                            : const Icon(
                                                Icons.system_update,
                                                color: Colors.white,
                                                size: 24,
                                                key: ValueKey('update'),
                                              ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        child: Text(
                                          _isUpdating && !_hasError
                                              ? 'Atualizando...'
                                              : _hasError
                                                  ? 'Erro na Atualização'
                                                  : 'Atualização Disponível',
                                          key: ValueKey(_isUpdating ? 'updating' : _hasError ? 'error' : 'available'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        child: Text(
                                          _isUpdating
                                              ? 'Por favor, aguarde...'
                                              : _hasError
                                                  ? 'Tente novamente'
                                                  : 'Versão ${widget.updateInfo.version}',
                                          key: ValueKey(_isUpdating ? 'wait' : _hasError ? 'retry' : 'version'),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isUpdating ? null : _handleDismiss,
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),

                            if (_updateStatus.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _hasError 
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: _hasError 
                                      ? Border.all(color: Colors.red.withOpacity(0.5))
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        if (_isUpdating && !_hasError)
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              value: _downloadProgress > 0 ? _downloadProgress : null,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                              backgroundColor: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                        if (_hasError)
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        if (_isUpdating && !_hasError || _hasError) 
                                          const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _updateStatus,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (_isUpdating && !_hasError)
                                          Text(
                                            '${(_downloadProgress * 100).toInt()}%',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    
                                    // Barra de progresso
                                    if (_isUpdating && !_hasError) ...[
                                      const SizedBox(height: 12),
                                      AnimatedBuilder(
                                        animation: _progressAnimation,
                                        builder: (context, child) {
                                          return Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: _progressAnimation.value * _downloadProgress,
                                                backgroundColor: Colors.transparent,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  _downloadProgress >= 1.0 
                                                      ? Colors.green
                                                      : Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            if (!_isUpdating) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _showReleaseNotes,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Ver Detalhes'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _handleUpdate,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.green[600],
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'Atualizar Agora',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
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
  bool _hasChecked = false;

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
          _hasChecked = true;
        });
      } else if (mounted && !_hasChecked) {
        setState(() {
          _hasChecked = true;
        });
      }
    } catch (e) {
      if (mounted && !_hasChecked) {
        setState(() {
          _hasChecked = true;
        });
      }
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