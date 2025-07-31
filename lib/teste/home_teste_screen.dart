// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:file_picker/file_picker.dart';
// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
// import 'package:excel/excel.dart' hide Border;
// import 'package:flutter_bloc/flutter_bloc.dart';

// // domain/models/excel_data.dart
// class ExcelData {
//   final List<String> headers;
//   final List<List<String>> rows;
//   final String fileName;

//   const ExcelData({
//     required this.headers,
//     required this.rows,
//     required this.fileName,
//   });
// }

// // domain/models/validation_item.dart
// class ValidationItem {
//   final String title;
//   final String description;
//   final bool isValid;
//   final String? errorMessage;

//   const ValidationItem({
//     required this.title,
//     required this.description,
//     required this.isValid,
//     this.errorMessage,
//   });
// }

// // domain/models/process_event.dart
// abstract class ProcessEvent {
//   const ProcessEvent();
// }

// class ProgressEvent extends ProcessEvent {
//   final int percentage;
//   final String currentOperation;
//   const ProgressEvent(this.percentage, this.currentOperation);
// }

// class ErrorEvent extends ProcessEvent {
//   final String message;
//   final String? details;
//   const ErrorEvent(this.message, [this.details]);
// }

// class CompletedEvent extends ProcessEvent {
//   const CompletedEvent();
// }

// class LogEvent extends ProcessEvent {
//   final String message;
//   final DateTime timestamp;
//   LogEvent(this.message) : timestamp = DateTime.now();
// }

// // domain/repositories/file_repository.dart
// abstract class FileRepository {
//   Future<ExcelData> loadExcelFile(String path);
//   Future<List<ValidationItem>> validateFile(ExcelData data);
//   Stream<ProcessEvent> processFile(String inputPath, String outputDir);
// }

// // infrastructure/repositories/file_repository_impl.dart

// class FileRepositoryImpl implements FileRepository {
//   Process? _currentProcess;

//   @override
//   Future<ExcelData> loadExcelFile(String path) async {
//     try {
//       final bytes = File(path).readAsBytesSync();
//       final excel = Excel.decodeBytes(bytes);

//       if (excel.tables.isEmpty) {
//         throw Exception('Arquivo Excel não contém planilhas');
//       }

//       final sheet = excel.tables[excel.tables.keys.first]!;
//       final rows = sheet.rows;
//       if (rows.isEmpty) {
//         throw Exception('Planilha está vazia');
//       }

//       // Primeira linha como cabeçalho
//       final headers = rows[0]
//           .map((cell) => cell?.value?.toString() ?? '')
//           .where((header) => header.isNotEmpty)
//           .toList();

//       // Demais linhas como dados
//       final dataRows = rows
//           .skip(1)
//           .where((row) => row.any((cell) => cell?.value != null))
//           .map((row) => row
//               .take(headers.length)
//               .map((cell) => cell?.value?.toString() ?? '')
//               .toList())
//           .toList();

//       return ExcelData(
//         fileName: p.basename(path),
//         headers: headers,
//         rows: dataRows,
//       );
//     } catch (e) {
//       throw Exception('Erro ao ler arquivo Excel: $e');
//     }
//   }

// @override
//   Future<List<ValidationItem>> validateFile(ExcelData data) async {
//     await Future.delayed(const Duration(milliseconds: 300));

//     return [
//       ValidationItem(
//         title: 'Estrutura do arquivo',
//         description: 'Verificar se o arquivo possui as colunas obrigatórias',
//         isValid: data.headers.length >= 4,
//         errorMessage: data.headers.length < 4
//             ? 'Arquivo deve ter pelo menos 4 colunas'
//             : null,
//       ),
//       ValidationItem(
//         title: 'Dados válidos',
//         description: 'Verificar se os dados estão no formato correto',
//         isValid: data.rows.isNotEmpty,
//         errorMessage: data.rows.isEmpty ? 'Arquivo não possui dados' : null,
//       ),
//       ValidationItem(
//         title: 'Coluna Contrato',
//         description: 'Verificar se existe coluna Contrato',
//         isValid: data.headers.contains('Contrato'),
//         errorMessage: !data.headers.contains('Contrato')
//             ? 'Coluna Contrato é obrigatória'
//             : null,
//       ),
//       ValidationItem(
//         title: 'Coluna Data Crédito',
//         description: 'Verificar se existe coluna Data Crédito',
//         isValid: data.headers.contains('Data Crédito'),
//         errorMessage: !data.headers.contains('Data Crédito')
//             ? 'Coluna Data Crédito é obrigatória'
//             : null,
//       ),
//       ValidationItem(
//         title: 'Coluna Data Crédito',
//         description: 'Verificar se existe coluna Data Crédito',
//         isValid: data.headers.contains('Data Crédito'),
//         errorMessage: !data.headers.contains('Data Crédito')
//             ? 'Coluna Data Crédito é obrigatória'
//             : null,
//       ),
//     ];
//   }

//   @override
//   Stream<ProcessEvent> processFile(String inputPath, String outputDir) async* {
//     try {
//       await _killCurrentProcess();

//       final executable = await _getExecutable();
//       _currentProcess = await Process.start(
//         executable.path,
//         ['--input', inputPath, '--output-dir', outputDir, '--json'],
//       );

//       await for (final line in _currentProcess!.stdout
//           .transform(utf8.decoder)
//           .transform(const LineSplitter())) {
//         final event = _parseProcessOutput(line);
//         yield event;

//         if (event is ErrorEvent || event is CompletedEvent) {
//           await _killCurrentProcess();
//           break;
//         }
//       }
//     } catch (e) {
//       yield ErrorEvent('Falha ao iniciar processo', e.toString());
//     }
//   }

//   Future<File> _getExecutable() async {
//     final exeDir = File(Platform.resolvedExecutable).parent;
//     final localExe = File(p.join(exeDir.path, 'br_service_cli.exe'));

//     if (await localExe.exists()) {
//       return localExe;
//     }

//     final bytes = await rootBundle.load('lib/assets/br_service_cli.exe');
//     final tempDir = await getTemporaryDirectory();
//     final tempFile = File(p.join(tempDir.path, 'br_service_cli.exe'));

//     await tempFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

//     if (!Platform.isWindows) {
//       await Process.run('chmod', ['+x', tempFile.path]);
//     }

//     return tempFile;
//   }

//   ProcessEvent _parseProcessOutput(String line) {
//     try {
//       final json = jsonDecode(line);
//       switch (json['event'] as String) {
//         case 'progresso':
//           return ProgressEvent(json['pct'] as int? ?? 0,
//               json['operation'] as String? ?? 'Processando...');
//         case 'erro':
//           return ErrorEvent(
//             json['msg'] as String? ?? 'Erro desconhecido',
//             json['details'] as String?,
//           );
//         case 'finalizado':
//           return const CompletedEvent();
//         default:
//           return LogEvent(line);
//       }
//     } catch (_) {
//       return LogEvent(line);
//     }
//   }

//   Future<void> _killCurrentProcess() async {
//     if (_currentProcess != null) {
//       _currentProcess!.kill();
//       await _currentProcess!.exitCode;
//       _currentProcess = null;
//     }
//   }

//   void dispose() {
//     _killCurrentProcess();
//   }
// }

// // application/bloc/file_processor_bloc.dart

// // States
// abstract class FileProcessorState {
//   const FileProcessorState();
// }

// class InitialState extends FileProcessorState {
//   const InitialState();
// }

// class FilePreviewState extends FileProcessorState {
//   final String filePath;
//   final ExcelData excelData;

//   const FilePreviewState({
//     required this.filePath,
//     required this.excelData,
//   });
// }

// class ValidationState extends FileProcessorState {
//   final String filePath;
//   final ExcelData excelData;
//   final List<ValidationItem> validationItems;
//   final bool canProceed;

//   const ValidationState({
//     required this.filePath,
//     required this.excelData,
//     required this.validationItems,
//     required this.canProceed,
//   });
// }

// class ProcessingState extends FileProcessorState {
//   final String filePath;
//   final String outputDir;
//   final List<LogEvent> logs;
//   final int progress;
//   final String currentOperation;

//   const ProcessingState({
//     required this.filePath,
//     required this.outputDir,
//     required this.logs,
//     this.progress = 0,
//     this.currentOperation = 'Iniciando...',
//   });

//   ProcessingState copyWith({
//     List<LogEvent>? logs,
//     int? progress,
//     String? currentOperation,
//   }) {
//     return ProcessingState(
//       filePath: filePath,
//       outputDir: outputDir,
//       logs: logs ?? this.logs,
//       progress: progress ?? this.progress,
//       currentOperation: currentOperation ?? this.currentOperation,
//     );
//   }
// }

// class ErrorState extends FileProcessorState {
//   final String message;
//   final String? details;

//   const ErrorState(this.message, [this.details]);
// }

// class CompletedState extends FileProcessorState {
//   final String outputDir;
//   const CompletedState(this.outputDir);
// }

// // Events
// abstract class FileProcessorEvent {
//   const FileProcessorEvent();
// }

// class SelectFileEvent extends FileProcessorEvent {
//   final String filePath;
//   const SelectFileEvent(this.filePath);
// }

// class ProceedToValidationEvent extends FileProcessorEvent {
//   const ProceedToValidationEvent();
// }

// class StartProcessingEvent extends FileProcessorEvent {
//   final String outputDir;
//   const StartProcessingEvent(this.outputDir);
// }

// class ResetEvent extends FileProcessorEvent {
//   const ResetEvent();
// }

// // Bloc
// class FileProcessorBloc extends Bloc<FileProcessorEvent, FileProcessorState> {
//   final FileRepository _repository;
//   String? _selectedFile;
//   ExcelData? _excelData;

//   FileProcessorBloc(this._repository) : super(const InitialState()) {
//     on<SelectFileEvent>(_onFileSelected);
//     on<ProceedToValidationEvent>(_onProceedToValidation);
//     on<StartProcessingEvent>(_onStartProcessing);
//     on<ResetEvent>(_onReset);
//   }

//   void _onFileSelected(
//       SelectFileEvent event, Emitter<FileProcessorState> emit) async {
//     try {
//       _selectedFile = event.filePath;
//       emit(const InitialState()); // Loading state

//       _excelData = await _repository.loadExcelFile(event.filePath);
//       emit(FilePreviewState(
//         filePath: event.filePath,
//         excelData: _excelData!,
//       ));
//     } catch (e) {
//       emit(ErrorState('Erro ao carregar arquivo', e.toString()));
//     }
//   }

//   void _onProceedToValidation(
//       ProceedToValidationEvent event, Emitter<FileProcessorState> emit) async {
//     if (_selectedFile == null || _excelData == null) return;

//     try {
//       final validationItems = await _repository.validateFile(_excelData!);
//       final canProceed = validationItems.every((item) => item.isValid);

//       emit(ValidationState(
//         filePath: _selectedFile!,
//         excelData: _excelData!,
//         validationItems: validationItems,
//         canProceed: canProceed,
//       ));
//     } catch (e) {
//       emit(ErrorState('Erro na validação', e.toString()));
//     }
//   }

//   void _onStartProcessing(
//       StartProcessingEvent event, Emitter<FileProcessorState> emit) async {
//     if (_selectedFile == null) return;

//     emit(ProcessingState(
//       filePath: _selectedFile!,
//       outputDir: event.outputDir,
//       logs: [],
//     ));

//     await emit.forEach(
//       _repository.processFile(_selectedFile!, event.outputDir),
//       onData: (ProcessEvent processEvent) {
//         final currentState = state;
//         if (currentState is! ProcessingState) return state;

//         switch (processEvent.runtimeType) {
//           case ProgressEvent:
//             final progress = processEvent as ProgressEvent;
//             return currentState.copyWith(
//               progress: progress.percentage,
//               currentOperation: progress.currentOperation,
//             );

//           case LogEvent:
//             final log = processEvent as LogEvent;
//             final newLogs = List<LogEvent>.from(currentState.logs)..add(log);
//             return currentState.copyWith(logs: newLogs);

//           case ErrorEvent:
//             final error = processEvent as ErrorEvent;
//             return ErrorState(error.message, error.details);

//           case CompletedEvent:
//             return CompletedState(event.outputDir);

//           default:
//             return currentState;
//         }
//       },
//       onError: (error, stackTrace) =>
//           ErrorState('Erro inesperado', error.toString()),
//     );
//   }

//   void _onReset(ResetEvent event, Emitter<FileProcessorState> emit) {
//     _selectedFile = null;
//     _excelData = null;
//     emit(const InitialState());
//   }

//   @override
//   Future<void> close() {
//     if (_repository is FileRepositoryImpl) {
//       (_repository as FileRepositoryImpl).dispose();
//     }
//     return super.close();
//   }
// }

// // presentation/pages/home_page.dart

// class HomePage extends StatelessWidget {
//   const HomePage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Row(
//         children: [
//           const _Sidebar(),
//           const VerticalDivider(width: 1),
//           Expanded(child: _ContentArea()),
//         ],
//       ),
//     );
//   }
// }

// class _Sidebar extends StatelessWidget {
//   const _Sidebar();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 260,
//       color: const Color(0xFF007547),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//       child: Column(
//         children: [
//           Image.asset(
//             'lib/assets/br.png',
//           ),
//           const SizedBox(height: 48),
//           _FilePickerButton(),
//           const SizedBox(height: 16),
//           _OutputDirButton(),
//           const Spacer(),
//           const Divider(color: Colors.white70),
//           const Text(
//             'Desenvolvido por\nRikelmy R.',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.white70),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _FilePickerButton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//         ),
//         onPressed: () async {
//           final result = await FilePicker.platform.pickFiles(
//             type: FileType.custom,
//             allowedExtensions: ['xlsx'],
//           );

//           if (result?.files.single.path != null) {
//             context
//                 .read<FileProcessorBloc>()
//                 .add(SelectFileEvent(result!.files.single.path!));
//           }
//         },
//         icon: const Icon(Icons.upload_file),
//         label: const Text('Selecionar arquivo'),
//       ),
//     );
//   }
// }

// class _OutputDirButton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<FileProcessorBloc, FileProcessorState>(
//       builder: (context, state) {
//         final enabled = state is ValidationState && state.canProceed;

//         return SizedBox(
//           width: double.infinity,
//           child: ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: enabled ? Colors.white : Colors.grey.shade400,
//               foregroundColor: Colors.black,
//               padding: const EdgeInsets.symmetric(vertical: 12),
//             ),
//             onPressed: enabled
//                 ? () async {
//                     final dir = await FilePicker.platform.getDirectoryPath();
//                     if (dir != null) {
//                       context
//                           .read<FileProcessorBloc>()
//                           .add(StartProcessingEvent(dir));
//                     }
//                   }
//                 : null,
//             icon: const Icon(Icons.folder_open),
//             label: const Text('Pasta de destino'),
//           ),
//         );
//       },
//     );
//   }
// }

// class _ContentArea extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(24.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Gerador de arquivos 📋',
//             style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           _ProgressIndicator(),
//           const SizedBox(height: 24),
//           Expanded(child: _StateContent()),
//         ],
//       ),
//     );
//   }
// }

// class _ProgressIndicator extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<FileProcessorBloc, FileProcessorState>(
//       builder: (context, state) {
//         int currentStep = 0;

//         switch (state.runtimeType) {
//           case FilePreviewState:
//             currentStep = 1;
//             break;
//           case ValidationState:
//             currentStep = 2;
//             break;
//           case ProcessingState:
//             currentStep = 3;
//             break;
//           case ErrorState:
//             currentStep = 4;
//             break;
//           case CompletedState:
//             currentStep = 5;
//             break;
//         }

//         final steps = [
//           'Início',
//           'Visualização',
//           'Validação',
//           'Processamento',
//           'Erro/Sucesso'
//         ];

//         return Column(
//           children: [
//             Row(
//               children: List.generate(5, (index) {
//                 final active = currentStep > index;
//                 final current = currentStep == index + 1;

//                 return Expanded(
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           children: [
//                             CircleAvatar(
//                               radius: 16,
//                               backgroundColor: active
//                                   ? Colors.green
//                                   : current
//                                       ? Colors.blue
//                                       : Colors.grey.shade300,
//                               child: Text(
//                                 '${index + 1}',
//                                 style: TextStyle(
//                                   color: active || current
//                                       ? Colors.white
//                                       : Colors.black54,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               steps[index],
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: active || current
//                                     ? Colors.black87
//                                     : Colors.grey,
//                                 fontWeight: current
//                                     ? FontWeight.bold
//                                     : FontWeight.normal,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ],
//                         ),
//                       ),
//                       if (index < 4)
//                         Container(
//                           width: 30,
//                           height: 2,
//                           color: active ? Colors.green : Colors.grey.shade300,
//                         ),
//                     ],
//                   ),
//                 );
//               }),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class _StateContent extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<FileProcessorBloc, FileProcessorState>(
//       builder: (context, state) {
//         switch (state.runtimeType) {
//           case InitialState:
//             return const _InitialView();

//           case FilePreviewState:
//             final preview = state as FilePreviewState;
//             return _FilePreviewView(excelData: preview.excelData);

//           case ValidationState:
//             final validation = state as ValidationState;
//             return _ValidationView(validationItems: validation.validationItems);

//           case ProcessingState:
//             final processing = state as ProcessingState;
//             return _ProcessingView(
//               logs: processing.logs,
//               progress: processing.progress,
//               currentOperation: processing.currentOperation,
//             );

//           case ErrorState:
//             final error = state as ErrorState;
//             return _ErrorView(
//               message: error.message,
//               details: error.details,
//             );

//           case CompletedState:
//             final completed = state as CompletedState;
//             return _SuccessView(outputDir: completed.outputDir);

//           default:
//             return const Center(child: Text('Estado desconhecido'));
//         }
//       },
//     );
//   }
// }

// class _InitialView extends StatelessWidget {
//   const _InitialView();

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.upload_file,
//             size: 64,
//             color: Colors.grey.shade400,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Selecione um arquivo Excel para começar',
//             style: TextStyle(
//               fontSize: 18,
//               color: Colors.grey.shade600,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Arquivo deve estar no formato .xlsx',
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey.shade500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _FilePreviewView extends StatelessWidget {
//   final ExcelData excelData;

//   const _FilePreviewView({required this.excelData});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(Icons.table_chart, color: Colors.green),
//             const SizedBox(width: 8),
//             Text(
//               'Visualização: ${excelData.fileName}',
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const Spacer(),
//             ElevatedButton.icon(
//               onPressed: () {
//                 context
//                     .read<FileProcessorBloc>()
//                     .add(const ProceedToValidationEvent());
//               },
//               icon: const Icon(Icons.arrow_forward),
//               label: const Text('Continuar'),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Expanded(
//           child: Card(
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Cabeçalhos encontrados (${excelData.headers.length}):',
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 4,
//                     children: excelData.headers
//                         .map((header) => Chip(
//                               label: Text(header),
//                               backgroundColor: Colors.blue.shade50,
//                             ))
//                         .toList(),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Primeiras linhas (${excelData.rows.length} registros):',
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   Expanded(
//                     child: SingleChildScrollView(
//                       scrollDirection: Axis.vertical,
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.horizontal,
//                         child: DataTable(
//                           columns: excelData.headers
//                               .map((header) => DataColumn(label: Text(header)))
//                               .toList(),
//                           rows: excelData.rows
//                               .take(10)
//                               .map((row) => DataRow(
//                                     cells: row
//                                         .map((cell) => DataCell(Text(cell)))
//                                         .toList(),
//                                   ))
//                               .toList(),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _ValidationView extends StatelessWidget {
//   final List<ValidationItem> validationItems;

//   const _ValidationView({required this.validationItems});

//   @override
//   Widget build(BuildContext context) {
//     final allValid = validationItems.every((item) => item.isValid);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(
//               allValid ? Icons.check_circle : Icons.warning,
//               color: allValid ? Colors.green : Colors.orange,
//             ),
//             const SizedBox(width: 8),
//             const Text(
//               'Checklist de Validação',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Expanded(
//           child: ListView.builder(
//             itemCount: validationItems.length,
//             itemBuilder: (context, index) {
//               final item = validationItems[index];
//               return Card(
//                 margin: const EdgeInsets.only(bottom: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: item.isValid ? Colors.green : Colors.red,
//                     child: Icon(
//                       item.isValid ? Icons.check : Icons.close,
//                       color: Colors.white,
//                     ),
//                   ),
//                   title: Text(
//                     item.title,
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(item.description),
//                       if (item.errorMessage != null)
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4),
//                           child: Text(
//                             item.errorMessage!,
//                             style: const TextStyle(
//                               color: Colors.red,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                   trailing: item.isValid
//                       ? const Icon(Icons.check_circle, color: Colors.green)
//                       : const Icon(Icons.error, color: Colors.red),
//                 ),
//               );
//             },
//           ),
//         ),
//         if (!allValid)
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.orange.shade50,
//               border: Border.all(color: Colors.orange.shade200),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Column(
//               children: [
//                 const Icon(Icons.warning, color: Colors.orange, size: 32),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Arquivo não passou na validação',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.orange,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 const Text(
//                   'Corrija os problemas acima antes de continuar',
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
// }

// class _ProcessingView extends StatelessWidget {
//   final List<LogEvent> logs;
//   final int progress;
//   final String currentOperation;

//   const _ProcessingView({
//     required this.logs,
//     required this.progress,
//     required this.currentOperation,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(Icons.settings, color: Colors.blue),
//             const SizedBox(width: 8),
//             const Text(
//               'Processando arquivo...',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Card(
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             '$progress%',
//                             style: const TextStyle(
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.blue,
//                             ),
//                           ),
//                           Text(
//                             currentOperation,
//                             style: TextStyle(
//                               color: Colors.grey.shade600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(
//                       width: 60,
//                       height: 60,
//                       child: CircularProgressIndicator(
//                         value: progress / 100,
//                         strokeWidth: 6,
//                         backgroundColor: Colors.grey.shade200,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 LinearProgressIndicator(
//                   value: progress / 100,
//                   backgroundColor: Colors.grey.shade200,
//                   minHeight: 8,
//                 ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 16),
//         const Text(
//           'Log detalhado:',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 8),
//         Expanded(
//           child: Card(
//             child: Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: logs
//                       .map((log) => Padding(
//                             padding: const EdgeInsets.only(bottom: 4),
//                             child: Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   '[${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}]',
//                                   style: TextStyle(
//                                     color: Colors.grey.shade600,
//                                     fontSize: 12,
//                                     fontFamily: 'monospace',
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: Text(
//                                     log.message,
//                                     style: const TextStyle(
//                                       fontSize: 12,
//                                       fontFamily: 'monospace',
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ))
//                       .toList(),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _ErrorView extends StatelessWidget {
//   final String message;
//   final String? details;

//   const _ErrorView({
//     required this.message,
//     this.details,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.error_outline,
//             color: Colors.red,
//             size: 72,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Erro no processamento',
//             style: const TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.red,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Card(
//             color: Colors.red.shade50,
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     message,
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w500,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   if (details != null) ...[
//                     const SizedBox(height: 12),
//                     const Divider(),
//                     const SizedBox(height: 8),
//                     const Text(
//                       'Detalhes técnicos:',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 14,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade100,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Text(
//                         details!,
//                         style: const TextStyle(
//                           fontSize: 12,
//                           fontFamily: 'monospace',
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 24),
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 24,
//                 vertical: 12,
//               ),
//             ),
//             onPressed: () {
//               context.read<FileProcessorBloc>().add(const ResetEvent());
//             },
//             icon: const Icon(Icons.home),
//             label: const Text('Voltar ao início'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SuccessView extends StatelessWidget {
//   final String outputDir;

//   const _SuccessView({required this.outputDir});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.check_circle_outline,
//             color: Colors.green,
//             size: 72,
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'Processamento concluído!',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.green,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Arquivo processado com sucesso',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.grey.shade600,
//             ),
//           ),
//           const SizedBox(height: 24),
//           Card(
//             color: Colors.green.shade50,
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   const Icon(
//                     Icons.folder_open,
//                     color: Colors.green,
//                     size: 32,
//                   ),
//                   const SizedBox(height: 8),
//                   const Text(
//                     'Arquivos salvos em:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(4),
//                       border: Border.all(color: Colors.green.shade200),
//                     ),
//                     child: Text(
//                       outputDir,
//                       style: const TextStyle(
//                         fontFamily: 'monospace',
//                         fontSize: 12,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 24),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               ElevatedButton.icon(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 12,
//                   ),
//                 ),
//                 onPressed: () async {
//                   try {
//                     if (Platform.isWindows) {
//                       await Process.run('explorer', [outputDir]);
//                     } else if (Platform.isMacOS) {
//                       await Process.run('open', [outputDir]);
//                     } else {
//                       await Process.run('xdg-open', [outputDir]);
//                     }
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Erro ao abrir pasta: $e'),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                 },
//                 icon: const Icon(Icons.folder_open),
//                 label: const Text('Abrir pasta'),
//               ),
//               const SizedBox(width: 16),
//               ElevatedButton.icon(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 12,
//                   ),
//                 ),
//                 onPressed: () {
//                   context.read<FileProcessorBloc>().add(const ResetEvent());
//                 },
//                 icon: const Icon(Icons.home),
//                 label: const Text('Novo processamento'),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
