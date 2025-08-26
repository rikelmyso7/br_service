import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/file_processor_bloc.dart';
import '../bloc/events/file_events_bloc.dart';
import '../models/process_event.dart';

class ProcessingView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasError ? Icons.error : Icons.settings,
              color: hasError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              hasError ? 'Erro no processamento!' : 'Processando arquivo...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hasError ? Colors.red : null,
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
                            '$progress%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: hasError ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            currentOperation,
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
                          (isCompleted || hasError)
                              ? Icon(
                                hasError ? Icons.close : Icons.check,
                                color: hasError ? Colors.red : Colors.green,
                              )
                              : Icon(Icons.timer, color: Colors.grey.shade400),
                          CircularProgressIndicator(
                            value: progress / 100.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: hasError ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress / 100.0,
                  backgroundColor: Colors.grey.shade200,
                  color: hasError ? Colors.red : Colors.green,
                  minHeight: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Log detalhado:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Card(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            logs
                                .map(
                                  (log) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '[${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}]',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            log.message,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              if (isCompleted || hasError) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (hasError) {
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
                    icon: Icon(hasError ? Icons.error : Icons.arrow_forward),
                    label: Text(hasError ? 'Ver Erros' : 'Ver Resultados'),
                    iconAlignment: IconAlignment.end,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasError ? Colors.red : Colors.green,
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
