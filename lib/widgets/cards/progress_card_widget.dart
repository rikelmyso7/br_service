import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.progress,
    required this.currentOperation,
    required this.isCompleted,
  });

  final double progress; // 0.0 – 1.0
  final String currentOperation;
  final bool isCompleted;

  Color _progressColor(BuildContext context, double progress, bool isCompleted) {
    final scheme = Theme.of(context).colorScheme;
    if (isCompleted) return scheme.tertiary;
    if (progress < 0.3) return scheme.error;
    if (progress < 0.7) return scheme.primary;
    return scheme.secondary;
  }
  
  @override
  Widget build(BuildContext context) {
    final color = _progressColor(context, progress, isCompleted);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _Header(progress: progress, color: color, isCompleted: isCompleted),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress, color: color),
          ],
        ),
      ),
    );
  }
}

 class _Header extends StatelessWidget {
    final double progress;
    final Color color;
    final bool isCompleted;
  
    const _Header({
      Key? key,
      required this.progress,
      required this.color,
      required this.isCompleted,
    }) : super(key: key);
  
    @override
    Widget build(BuildContext context) {
      return Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.timelapse,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCompleted ? 'Completed' : 'In Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Text('${(progress * 100).toStringAsFixed(0)}%'),
        ],
      );
    }
  }