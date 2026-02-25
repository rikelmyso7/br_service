import 'dart:developer' as dev;

import 'package:br_service_ui/pages/home_page.dart';
import 'package:br_service_ui/repository/file_repository.dart';
import 'package:br_service_ui/repository/file_repository_impl.dart';
import 'package:br_service_ui/services/daemon_service.dart';
import 'package:br_service_ui/utils/error_handler.dart';
import 'package:br_service_ui/widgets/update_notification_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'bloc/file_processor_bloc.dart';

void _setupLogging() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final msg = '[${record.loggerName}] ${record.level.name}: ${record.message}';
    dev.log(
      msg,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
      time: record.time,
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();
  ErrorHandler.setupGlobalErrorHandling();

  // Inicia o daemon CLI em background — elimina cold start na primeira operação
  final repo = FileRepositoryImpl();
  repo.getExecutable().then((exe) {
    BRServiceDaemon.instance.warmUp(exe.path).catchError((e) {
      Logger('main').warning('Daemon warm-up falhou (será retentado no uso): $e');
    });
  });

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
          contrastLevel: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: MultiProvider(
          providers: [
            Provider<FileRepository>(create: (_) => FileRepositoryImpl()),
            BlocProvider(
              create:
                  (context) => FileProcessorBloc(context.read<FileRepository>()),
              child: HomePage(),
            ),
          ],
          child: HomePage(),
      ),
    );
  }
}
