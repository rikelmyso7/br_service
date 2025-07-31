
import 'package:br_service_ui/pages/home_page.dart';
import 'package:br_service_ui/repository/file_repository_impl.dart';
import 'package:br_service_ui/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'bloc/file_processor_bloc.dart';

// void main() {
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => ProcessService()),
//         ChangeNotifierProvider(create: (_) => AppState())
//       ],
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Excel Processor',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
//       home: HomePage(),
//     );
//   }
// }
void main() {

  ErrorHandler.setupGlobalErrorHandling();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerador de Arquivos BR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      home: BlocProvider(
        create: (context) => FileProcessorBloc(FileRepositoryImpl()),
        child: HomePage(),
      ),
    );
  }
}