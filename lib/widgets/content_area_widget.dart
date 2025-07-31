import 'package:br_service_ui/widgets/progress_indicator_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../components/state_content_component.dart';

class ContentArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gerador de arquivos 📋',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ProgressIndicatorWidget(),
          const SizedBox(height: 24),
          Expanded(child: StateContent()),
        ],
      ),
    );
  }
}