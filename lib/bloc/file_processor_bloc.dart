import 'package:br_service_ui/models/validation_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../models/excel_data.dart';
import '../models/file_stats.dart';
import '../models/process_event.dart';
import '../models/processing_filters.dart';
import '../repository/file_repository.dart';
import '../repository/file_repository_impl.dart';
import '../services/isolate_service.dart';
import 'events/file_events_bloc.dart';
import 'states/completed_bloc.dart';
import 'states/error_bloc.dart';
import 'states/file_processor_bloc.dart';
import 'states/processing_bloc.dart';
import 'states/processing_completed_bloc.dart';
import 'states/validation_processor_bloc.dart';
import '../models/invalid_doc_plano.dart';

class FileProcessorBloc extends Bloc<FileProcessorEvent, FileProcessorState> {
  final log = Logger('FileProcessorBloc');
  final FileRepository _repository;
  String? _selectedFile;
  ExcelData? _excelData;

  FileProcessorBloc(this._repository) : super(const InitialState()) {
    on<SelectFileEvent>(_onFileSelected);
    on<ProceedToValidationEvent>(_onProceedToValidation);
    on<StartProcessingEvent>(_onStartProcessing);
    on<ProceedToCompletedEvent>(_onProceedToCompleted);
    on<ProceedToErrorEvent>(_onProceedToError);
    on<ResetEvent>(_onReset);
  }

  void _onFileSelected(
      SelectFileEvent event, Emitter<FileProcessorState> emit) async {
    try {
      _selectedFile = event.filePath;

      emit(FileLoadingState(
        filePath: event.filePath,
        message: 'Carregando arquivo e executando análise',
      ));

      // Com o daemon já rodando, ambas as chamadas são rápidas e vão pela fila do daemon.
      // Rodamos em paralelo do ponto de vista do Dart — o daemon as processa em sequência.
      log.info('Carregando arquivo via daemon (get-all + get-preview)');
      final results = await Future.wait([
        _repository.loadExcelFile(event.filePath),
        _repository.getAllData(event.filePath),
      ]);

      _excelData = results[0] as ExcelData;
      final cliData = results[1] as Map<String, dynamic>;

      log.info('Todas as operações concluídas em paralelo (1 chamada CLI)');
      log.fine('CLI Data keys: ${cliData.keys.join(", ")}');
      log.fine('Documentos: ${cliData['documentos']}');
      log.fine('Datas: ${cliData['datas']}');

      // Extrair todas as contas (ativas + inativas) para o popup
      // getAllData já inclui os dados de contas
      final contasAtivas = (cliData['contas_ativas'] as Map<String, dynamic>?) ?? {};
      final contasInativas = (cliData['contas_inativas'] as Map<String, dynamic>?) ?? {};

      final todasContas = <String>[];
      todasContas.addAll(contasAtivas.keys);
      todasContas.addAll(contasInativas.keys);

      log.fine('Contas encontradas: ${todasContas.length}');
      log.fine('Ativas: ${contasAtivas.keys.toList()}');
      log.fine('Inativas: ${contasInativas.keys.toList()}');

      if (todasContas.isNotEmpty) {
        log.info('Emitindo FilePreviewState com ${todasContas.length} contas');
        emit(FilePreviewState(
          filePath: event.filePath,
          excelData: _excelData!,
          numericSheetNames: todasContas,
          contasAnalysis: {
            'contas_ativas': contasAtivas,
            'contas_inativas': contasInativas,
          },
        ));
      } else {
        log.info('Nenhuma conta encontrada, emitindo FilePreviewState vazio');
        emit(FilePreviewState(
          filePath: event.filePath,
          excelData: _excelData!,
          numericSheetNames: [],
        ));
      }
    } catch (e) {
      emit(ErrorState('Erro ao carregar arquivo', e.toString()));
    }
  }

  void _onProceedToValidation(
      ProceedToValidationEvent event, Emitter<FileProcessorState> emit) async {
    if (_selectedFile == null || _excelData == null) return;

    try {
      emit(ValidationLoadingState(
        filePath: _selectedFile!,
        excelData: _excelData!,
        message: 'Validando dados com análise...',
      ));
      
      log.info('Iniciando validação usando dados CLI cached');

      // Como a análise CLI já foi executada durante o carregamento, apenas usa os dados cached
      // Executa validação e estatísticas usando dados já processados
      final futures = await Future.wait([
        _repository.validateFile(_selectedFile!), // Thread principal - usa dados já salvos
        _repository.getDetailedFileStats(_selectedFile!), // Thread principal - precisa dos dados cached
      ]);
      log.info('Validação e estatísticas concluídas');

      final validationItems = futures[0] as List<ValidationItem>;
      final detailedStats = futures[1] as Map<String, dynamic>;
      log.fine('ValidationItems: ${validationItems.length}');
      log.fine('DetailedStats keys: ${detailedStats.keys.join(", ")}');

      // Debug validation items
      for (int i = 0; i < validationItems.length; i++) {
        final item = validationItems[i];
        log.finer('Validation $i: ${item.title} = ${item.isValid}');
      }
      
      final canProceed = validationItems.every((item) => item.isValid);

      // Cria ExcelData atualizado com dados do CLI
      log.fine('Reconstruindo ExcelData com dados do CLI');
      final docPlanos = _parseDocPlanosFromStats(detailedStats);
      final fileStats = _createFileStats(detailedStats);
      final processingFilters = _parseProcessingFiltersFromStats(detailedStats);

      log.fine('DocPlanos reconstruídos: ${docPlanos.length}');
      log.fine('ProcessingFilters: ${processingFilters != null ? "Criado" : "NULL"}');
      if (processingFilters != null) {
        log.finer('Available docs: ${processingFilters.availableDocuments}');
        log.finer('Available dates: ${processingFilters.availableDates}');
      }

      // Extrai os docPlanos inválidos dos dados detalhados
      final invalidDocPlanos = _parseInvalidDocPlanos(detailedStats);
      log.info('DocPlanos inválidos encontrados: ${invalidDocPlanos.length}');
      for (final invalid in invalidDocPlanos) {
        log.fine('${invalid.docPlano} - ${invalid.motivo}');
      }

      final updatedExcelData = ExcelData(
        fileName: _excelData!.fileName,
        headers: _excelData!.headers,
        rows: _excelData!.rows,
        docPlanos: docPlanos,
        fileStats: fileStats,
        processingFilters: processingFilters,
        invalidDocPlanos: invalidDocPlanos,
      );

      emit(ValidationState(
        filePath: _selectedFile!,
        excelData: updatedExcelData,
        validationItems: validationItems,
        canProceed: canProceed,
      ));
    } catch (e) {
      emit(ErrorState('Erro na validação', e.toString()));
    }
  }

  // Converte dados do CLI em DocPlanos
  List<DocPlano> _parseDocPlanos(Map<String, dynamic> cliData) {
    final List<DocPlano> docPlanos = [];
    final planosMap = (cliData['planos_por_documento'] as Map<String, dynamic>?) ?? {};
    
    planosMap.forEach((documento, planos) {
      final planList = (planos as List<dynamic>).cast<String>();
      for (final plano in planList) {
        docPlanos.add(DocPlano(documento, plano));
      }
    });
    
    return docPlanos;
  }

  // Reconstrói DocPlanos a partir de dados serializados do isolate
  List<DocPlano> _parseDocPlanosFromStats(Map<String, dynamic> detailedStats) {
    final docPlanosData = detailedStats['docPlanos'] as List<dynamic>? ?? [];
    return docPlanosData.map((item) {
      final map = item as Map<String, dynamic>;
      return DocPlano(map['documento'] as String, map['plano'] as String);
    }).toList();
  }

  // Reconstrói ProcessingFilters a partir de dados serializados do isolate
  ProcessingFilters _parseProcessingFiltersFromStats(Map<String, dynamic> detailedStats) {
    final filtersData = detailedStats['processingFilters'] as Map<String, dynamic>? ?? {};

    final availableDocPlanos =
        ((filtersData['availableDocPlanos'] as List<dynamic>?) ?? []).map((item) {
      final map = item as Map<String, dynamic>;
      return DocPlano(map['documento'] as String, map['plano'] as String);
    }).toList();

    final datesByDocumentRaw = filtersData['datesByDocument'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> datesByDocument = {};
    datesByDocumentRaw.forEach((key, value) {
      if (value is List) {
        datesByDocument[key] = (value as List<dynamic>).cast<String>();
      }
    });

    final recordCountsRaw = filtersData['recordCountsByDocument'] as Map<String, dynamic>? ?? {};
    final Map<String, int> recordCountsByDocument = {};
    recordCountsRaw.forEach((key, value) {
      if (value is int) {
        recordCountsByDocument[key] = value;
      } else if (value is num) {
        recordCountsByDocument[key] = value.toInt();
      }
    });

    return ProcessingFilters(
      selectedDocuments: (filtersData['selectedDocuments'] as List<dynamic>?)?.cast<String>() ?? [],
      selectedDates: (filtersData['selectedDates'] as List<dynamic>?)?.cast<String>() ?? [],
      availableDocuments: (filtersData['availableDocuments'] as List<dynamic>?)?.cast<String>() ?? [],
      availableDates: (filtersData['availableDates'] as List<dynamic>?)?.cast<String>() ?? [],
      availableDocPlanos: availableDocPlanos,
      datesByDocument: datesByDocument,
      recordCountsByDocument: recordCountsByDocument,
    );
  }

  // Extrai InvalidDocPlanos dos dados detalhados
  List<InvalidDocPlano> _parseInvalidDocPlanos(Map<String, dynamic> detailedStats) {
    final invalidData = detailedStats['invalidDocPlanos'] as List<dynamic>? ?? [];
    return invalidData.map((item) {
      final map = item as Map<String, dynamic>;
      return InvalidDocPlano(
        docPlano: map['docPlano'] as String,
        motivo: map['motivo'] as String,
      );
    }).toList();
  }

  // Cria FileStats a partir dos dados detalhados
  FileStats _createFileStats(Map<String, dynamic> detailedStats) {
    final countsMap = detailedStats['countsPerDocPlano'] as Map<String, int>;
    final docPlanos = _parseDocPlanosFromStats(detailedStats);
    
    final List<DocPlanoStat> stats = [];
    for (final docPlano in docPlanos) {
      final key = '${docPlano.documento}-${docPlano.plano}';
      final count = countsMap[key] ?? 0;
      stats.add(DocPlanoStat(
        documento: docPlano.documento,
        plano: docPlano.plano,
        recordCount: count,
        hasData: count > 0,
      ));
    }
    
    return FileStats(
      docPlanoStats: stats,
      totalCombinations: detailedStats['totalCombinations'] as int,
      nonEmptyCombinations: detailedStats['nonEmptyCombinations'] as int,
      totalRecords: detailedStats['totalRecords'] as int,
    );
  }

  void _onStartProcessing(
      StartProcessingEvent event, Emitter<FileProcessorState> emit) async {
    if (_selectedFile == null) return;

    emit(ProcessingState(
      filePath: _selectedFile!,
      outputDir: event.outputDir,
      logs: [],
    ));

    await emit.forEach(
      _repository.processFile(_selectedFile!, event.outputDir, filters: event.filters),
      onData: (ProcessEvent processEvent) {
        final currentState = state;
        if (currentState is! ProcessingState) return state;

        switch (processEvent.runtimeType) {
          case ProgressEvent:
            final progress = processEvent as ProgressEvent;
            return currentState.copyWith(
              progress: progress.percentage,
              currentOperation: progress.currentOperation,
            );

          case LogEvent:
            final log = processEvent as LogEvent;
            final newLogs = List<LogEvent>.from(currentState.logs)..add(log);
            return currentState.copyWith(logs: newLogs);

          case ErrorEvent:
            final error = processEvent as ErrorEvent;
            return ErrorStateWithLogs(
              error.message, 
              currentState.logs, 
              currentState.progress, 
              error.details
            );

          case CompletedEvent:
            return ProcessingCompletedState(
              filePath: currentState.filePath,
              outputDir: event.outputDir,
              logs: currentState.logs,
            );

          default:
            return currentState;
        }
      },
      onError: (error, stackTrace) =>
          ErrorState('Erro inesperado', error.toString()),
    );
  }

  void _onProceedToCompleted(
      ProceedToCompletedEvent event, Emitter<FileProcessorState> emit) {
    final currentState = state;
    if (currentState is ProcessingCompletedState) {
      emit(CompletedState(currentState.outputDir));
    }
  }

  void _onProceedToError(
      ProceedToErrorEvent event, Emitter<FileProcessorState> emit) {
    final currentState = state;
    if (currentState is ErrorState) {
      // Mantém o estado de erro atual
      emit(currentState);
    }
  }

  void _onReset(ResetEvent event, Emitter<FileProcessorState> emit) {
    _selectedFile = null;
    _excelData = null;
    emit(const InitialState());
  }

  @override
  Future<void> close() {
    if (_repository is FileRepositoryImpl) {
      (_repository as FileRepositoryImpl).dispose();
    }
    return super.close();
  }
}
