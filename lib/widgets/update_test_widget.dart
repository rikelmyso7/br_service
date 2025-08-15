import 'package:flutter/material.dart';
import 'package:br_service_ui/services/update_service.dart';
import 'package:br_service_ui/widgets/update_notification_widget.dart';

/// Widget personalizado que usa simulação em vez do UpdateService real
class TestUpdateNotificationWidget extends UpdateNotificationWidget {
  const TestUpdateNotificationWidget({
    super.key,
    required super.updateInfo,
    super.onDismiss,
  });

  @override
  State<TestUpdateNotificationWidget> createState() => _TestUpdateNotificationWidgetState();
}

class _TestUpdateNotificationWidgetState extends State<TestUpdateNotificationWidget>
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
      final success = await SimulatedUpdateService.simulateDownloadAndInstall(
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
          child: SizedBox(
            width: 500,
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
                      margin: const EdgeInsets.all(16),
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
                                    colors: [Colors.blue[600]!, Colors.blue[400]!],
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
                                    : Colors.blue.withOpacity(0.3),
                            blurRadius: _isUpdating ? 15 : 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
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
                                        foregroundColor: Colors.blue[600],
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

/// Widget de teste para simular atualizações e testar a interface
class UpdateTestWidget extends StatefulWidget {
  const UpdateTestWidget({super.key});

  @override
  State<UpdateTestWidget> createState() => _UpdateTestWidgetState();
}

class _UpdateTestWidgetState extends State<UpdateTestWidget> {
  UpdateInfo? _simulatedUpdate;
  bool _showNotification = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste de Atualizações'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Conteúdo principal
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simulador de Atualizações',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Use os botões abaixo para testar diferentes cenários de atualização:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),

                // Botão para simular nova versão disponível
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _simulateUpdateAvailable,
                    icon: const Icon(Icons.system_update),
                    label: const Text('Simular Nova Versão Disponível'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botão para simular atualização com progresso realista
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _simulateRealisticUpdate,
                    icon: const Icon(Icons.download),
                    label: const Text('Simular Download Realista (5s)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botão para simular erro
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _simulateError,
                    icon: const Icon(Icons.error),
                    label: const Text('Simular Erro de Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botão para ocultar notificação
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _hideNotification,
                    icon: const Icon(Icons.close),
                    label: const Text('Ocultar Notificação'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const Spacer(),

                // Informações de teste
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          const Text(
                            'Informações de Teste',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Versão atual simulada: 1.0.0\n'
                        '• Versão de teste: 1.1.0\n'
                        '• O download simula velocidades reais\n'
                        '• Todas as animações são testáveis\n'
                        '• Experimente redimensionar a janela!',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notificação de atualização (overlay)
          if (_showNotification && _simulatedUpdate != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: TestUpdateNotificationWidget(
                updateInfo: _simulatedUpdate!,
                onDismiss: _hideNotification,
              ),
            ),
        ],
      ),
    );
  }

  void _simulateUpdateAvailable() {
    setState(() {
      _simulatedUpdate = UpdateInfo(
        version: '1.1.0',
        downloadUrl: 'https://example.com/fake-download.exe',
        releaseNotes: '''
## 🆕 Novidades v1.1.0

### ✨ Recursos
- Container responsivo implementado
- Sistema de atualizações automáticas
- Melhorias na interface do usuário
- Animações suaves e feedback visual

### 🐛 Correções
- Corrigido crash ao redimensionar janela
- Melhorada performance de carregamento
- Corrigidos problemas de responsividade

### 🔧 Melhorias Técnicas
- Refatoração do código base
- Otimizações de performance
- Melhor tratamento de erros
        ''',
        releaseDate: DateTime.now().subtract(const Duration(hours: 2)),
      );
      _showNotification = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Simulação iniciada! Veja a notificação no topo.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _simulateRealisticUpdate() {
    if (_simulatedUpdate == null) {
      _simulateUpdateAvailable();
      // Aguarda um pouco para a notificação aparecer
      Future.delayed(const Duration(milliseconds: 500), () {
        _startRealisticSimulation();
      });
    } else {
      _startRealisticSimulation();
    }
  }

  void _startRealisticSimulation() {
    // Simula um download realista com callback de progresso
    _simulateDownloadWithProgress((progress, status) {
      // O callback é chamado automaticamente pelo UpdateNotificationWidget
      // quando o usuário clica em "Atualizar Agora"
    });
  }

  void _simulateError() {
    setState(() {
      _simulatedUpdate = UpdateInfo(
        version: '1.1.0',
        downloadUrl: 'https://example.com/invalid-url.exe',
        releaseNotes: 'Versão de teste para simular erro de download.',
        releaseDate: DateTime.now(),
      );
      _showNotification = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Simulação de erro preparada. Clique em "Atualizar Agora" para testar.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _hideNotification() {
    setState(() {
      _showNotification = false;
    });
  }

  // Simula um download com progresso realista
  Future<void> _simulateDownloadWithProgress(ProgressCallback onProgress) async {
    // Etapas do download simulado
    final steps = [
      (0.0, 'Iniciando download...'),
      (0.1, 'Conectando ao servidor...'),
      (0.15, 'Verificando disponibilidade...'),
      (0.2, 'Baixando... 0.5/25.3 MB'),
      (0.3, 'Baixando... 2.1/25.3 MB'),
      (0.4, 'Baixando... 5.8/25.3 MB'),
      (0.5, 'Baixando... 9.2/25.3 MB'),
      (0.6, 'Baixando... 13.7/25.3 MB'),
      (0.7, 'Baixando... 18.1/25.3 MB'),
      (0.8, 'Baixando... 22.4/25.3 MB'),
      (0.85, 'Baixando... 25.3/25.3 MB'),
      (0.9, 'Download concluído. Preparando instalação...'),
      (0.95, 'Extraindo arquivos...'),
      (0.98, 'Verificando integridade...'),
      (1.0, 'Instalação concluída! Reiniciando...'),
    ];

    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 300));
      onProgress(step.$1, step.$2);
    }
  }
}

/// Classe para facilitar a simulação
class SimulatedUpdateService {
  static Future<bool> simulateDownloadAndInstall(
    UpdateInfo updateInfo, {
    ProgressCallback? onProgress,
  }) async {
    if (updateInfo.downloadUrl.contains('invalid-url')) {
      // Simula erro
      await Future.delayed(const Duration(seconds: 1));
      onProgress?.call(0.0, 'Erro: Não foi possível conectar ao servidor');
      return false;
    }

    // Simula download bem-sucedido
    final steps = [
      (0.0, 'Iniciando download...'),
      (0.1, 'Conectando...'),
      (0.2, 'Baixando... 2.1/25.3 MB'),
      (0.4, 'Baixando... 8.7/25.3 MB'),
      (0.6, 'Baixando... 15.2/25.3 MB'),
      (0.8, 'Baixando... 21.8/25.3 MB'),
      (0.9, 'Download concluído'),
      (0.95, 'Instalando...'),
      (1.0, 'Concluído!'),
    ];

    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 400));
      onProgress?.call(step.$1, step.$2);
    }

    return true;
  }
}