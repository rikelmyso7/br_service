import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/process_event.dart';

class ProcessingView extends StatelessWidget {
  final List<LogEvent> logs;
  final int progress;
  final String currentOperation;

  const ProcessingView({
    required this.logs,
    required this.progress,
    required this.currentOperation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.settings, color: Colors.green),
            const SizedBox(width: 8),
            const Text(
              'Processando arquivo...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            currentOperation,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey.shade200,
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
          child: Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: logs
                      .map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
