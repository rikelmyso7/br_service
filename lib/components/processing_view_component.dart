import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/file_processor_bloc.dart';
import '../bloc/events/file_events_bloc.dart';
import '../models/process_event.dart';

class ProcessingView extends StatefulWidget {
  final List<LogEvent> logs;
  final int progress;
  final String currentOperation;
  final bool isCompleted;
  final bool hasError;

  const ProcessingView({
    required this.logs,
    required this.progress,
    required this.currentOperation,
    this.isCompleted = false,
    this.hasError = false,
  });

  @override
  State<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<ProcessingView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  Set<_LogType> _visibleLogTypes = {
    _LogType.error,
    _LogType.warning,
    _LogType.success,
    _LogType.info,
    _LogType.debug,
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProcessingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll para o fim quando novos logs chegam
    if (_autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Detecta tipo de log baseado no conteúdo
  _LogType _getLogType(String message) {
    final lowerMsg = message.toLowerCase();
    if (lowerMsg.contains('erro') || lowerMsg.contains('error') || lowerMsg.contains('falha')) {
      return _LogType.error;
    } else if (lowerMsg.contains('aviso') || lowerMsg.contains('warning') || lowerMsg.contains('atenção')) {
      return _LogType.warning;
    } else if (lowerMsg.contains('sucesso') || lowerMsg.contains('concluído') || lowerMsg.contains('✓') || lowerMsg.contains('✅')) {
      return _LogType.success;
    } else if (lowerMsg.contains('processando') || lowerMsg.contains('carregando') || lowerMsg.contains('salvando')) {
      return _LogType.info;
    }
    return _LogType.debug;
  }

  Color _getLogColor(_LogType type) {
    switch (type) {
      case _LogType.error:
        return Colors.red.shade700;
      case _LogType.warning:
        return Colors.orange.shade700;
      case _LogType.success:
        return Colors.green.shade700;
      case _LogType.info:
        return Colors.blue.shade700;
      case _LogType.debug:
        return Colors.grey.shade700;
    }
  }

  IconData _getLogIcon(_LogType type) {
    switch (type) {
      case _LogType.error:
        return Icons.error_outline;
      case _LogType.warning:
        return Icons.warning_amber_outlined;
      case _LogType.success:
        return Icons.check_circle_outline;
      case _LogType.info:
        return Icons.info_outline;
      case _LogType.debug:
        return Icons.notes;
    }
  }

  String _getLogTypeName(_LogType type) {
    switch (type) {
      case _LogType.error:
        return 'Erros';
      case _LogType.warning:
        return 'Avisos';
      case _LogType.success:
        return 'Sucesso';
      case _LogType.info:
        return 'Info';
      case _LogType.debug:
        return 'Debug';
    }
  }

  // Conta logs por tipo
  Map<_LogType, int> _countLogsByType() {
    final counts = <_LogType, int>{};
    for (final type in _LogType.values) {
      counts[type] = 0;
    }
    for (final log in widget.logs) {
      final type = _getLogType(log.message);
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  // Filtra logs baseado nos tipos visíveis
  List<LogEvent> get _filteredLogs {
    return widget.logs.where((log) {
      final type = _getLogType(log.message);
      return _visibleLogTypes.contains(type);
    }).toList();
  }

  Widget _buildLogFilters() {
    final counts = _countLogsByType();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _LogType.values.map((type) {
          final isSelected = _visibleLogTypes.contains(type);
          final count = counts[type] ?? 0;
          final color = _getLogColor(type);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getLogIcon(type),
                    size: 14,
                    color: isSelected ? color : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_getLogTypeName(type)} ($count)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? color : Colors.grey,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _visibleLogTypes.add(type);
                  } else {
                    // Não permite desmarcar todos
                    if (_visibleLogTypes.length > 1) {
                      _visibleLogTypes.remove(type);
                    }
                  }
                });
              },
              selectedColor: color.withOpacity(0.15),
              checkmarkColor: color,
              side: BorderSide(
                color: isSelected ? color.withOpacity(0.5) : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.hasError ? Icons.error : Icons.settings,
              color: widget.hasError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              widget.hasError ? 'Erro no processamento!' : 'Processando arquivo...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.hasError ? Colors.red : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.progress}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: widget.hasError ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            widget.currentOperation,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          (widget.isCompleted || widget.hasError)
                              ? Icon(
                                widget.hasError ? Icons.close : Icons.check,
                                color: widget.hasError ? Colors.red : Colors.green,
                              )
                              : Icon(Icons.timer, color: Colors.grey.shade400),
                          CircularProgressIndicator(
                            value: widget.progress / 100.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: widget.hasError ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: widget.progress / 100.0,
                  backgroundColor: Colors.grey.shade200,
                  color: widget.hasError ? Colors.red : Colors.green,
                  minHeight: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Log detalhado:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // Toggle auto-scroll
            Row(
              children: [
                Icon(
                  _autoScroll ? Icons.arrow_downward : Icons.pause,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _autoScroll,
                  onChanged: (value) => setState(() => _autoScroll = value),
                  activeColor: Colors.green,
                ),
                Text(
                  'Auto-scroll',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Filtros de nível de log
        _buildLogFilters(),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Card(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                        final logType = _getLogType(log.message);
                        final color = _getLogColor(logType);
                        final icon = _getLogIcon(logType);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ícone baseado no tipo
                              Icon(
                                icon,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              // Timestamp
                              Text(
                                '[${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}]',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Mensagem com cor baseada no tipo
                              Expanded(
                                child: Text(
                                  log.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: color,
                                    fontWeight: logType == _LogType.error ||
                                            logType == _LogType.warning
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.isCompleted || widget.hasError) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.hasError) {
                        // Navegar para tela de erro
                        context.read<FileProcessorBloc>().add(
                          const ProceedToErrorEvent(),
                        );
                      } else {
                        context.read<FileProcessorBloc>().add(
                          const ProceedToCompletedEvent(),
                        );
                      }
                    },
                    icon: Icon(widget.hasError ? Icons.error : Icons.arrow_forward),
                    label: Text(widget.hasError ? 'Ver Erros' : 'Ver Resultados'),
                    iconAlignment: IconAlignment.end,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.hasError ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Enum para tipos de log
enum _LogType {
  error,
  warning,
  success,
  info,
  debug,
}
