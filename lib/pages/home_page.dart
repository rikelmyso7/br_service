import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/content_area_widget.dart';
import '../widgets/side_bar.widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(),
          VerticalDivider(width: 1),
          Expanded(child: ContentArea()),
        ],
      ),
    );
  }
}