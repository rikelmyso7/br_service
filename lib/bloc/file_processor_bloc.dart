import 'package:br_service_ui/models/validation_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final FileRepository _repository;
  String? _selectedFile;
  ExcelData? _excelData;

  FileProcessorBloc(this._repository) : super(const InitialState()) {
    on<SelectFileEvent>(_onFileSelected);
    on<ProceedToValidationEvent>(_onProceedToValidation);
    on<StartProcessingEvent>(_onStartProcessing);
    on<ProceedToCompletedEvent>(_onProceedToCompleted);
    on<ResetEvent>(_onReset);
  }

  void _onFileSelected(
      SelectFileEvent event, Emitter<FileProcessorState> emit) async {
    try {
      _selectedFile = event.filePath;
      
      emit(FileLoadingState(
        filePath: event.filePath,
        message: 'Carregando arquivo e executando análise CLI...',
      ));

      // Executa carregamento básico e análise CLI em paralelo
      print('🔄 Iniciando carregamento e análise em paralelo...');
      final futures = await Future.wait([
        IsolateService.loadExcelFileInIsolate(event.filePath), // Carregamento básico
        _repository.analyzeFile(event.filePath), // Análise CLI em background
      ]);
      
      _excelData = futures[0] as ExcelData;
      final cliData = futures[1] as Map<String, dynamic>;
      
      print('✅ Carregamento e análise CLI concluídos em paralelo');
      print('📊 CLI Data keys: ${cliData.keys.join(", ")}');
      print('📄 Documentos do CLI: ${cliData['documentos']}');
      print('📅 Datas do CLI: ${cliData['datas']}');
      
      emit(FilePreviewState(
        filePath: event.filePath,
        excelData: _excelData!,
      ));
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
        message: 'Validando dados com análise CLI...',
      ));
      
      print('🔍 Iniciando validação usando dados CLI já processados: $_selectedFile');
      
      // Como a análise CLI já foi executada durante o carregamento, apenas usa os dados cached
      // Executa validação e estatísticas usando dados já processados
      final futures = await Future.wait([
        _repository.validateFile(_selectedFile!), // Thread principal - usa dados já salvos
        _repository.getDetailedFileStats(_selectedFile!), // Thread principal - precisa dos dados cached
      ]);
      print('✅ Validação e estatísticas concluídas usando dados cached');
      
      final validationItems = futures[0] as List<ValidationItem>;
      final detailedStats = futures[1] as Map<String, dynamic>;
      print('📋 ValidationItems: ${validationItems.length}');
      print('📊 DetailedStats keys: ${detailedStats.keys.join(", ")}');
      
      // Debug validation items
      for (int i = 0; i < validationItems.length; i++) {
        final item = validationItems[i];
        print('   ✓ Validation $i: ${item.title} = ${item.isValid}');
      }
      
      final canProceed = validationItems.every((item) => item.isValid);

      // Cria ExcelData atualizado com dados do CLI
      print('🔧 Reconstruindo ExcelData com dados do CLI...');
      final docPlanos = _parseDocPlanosFromStats(detailedStats);
      final fileStats = _createFileStats(detailedStats);
      final processingFilters = _parseProcessingFiltersFromStats(detailedStats);
      
      print('📄 DocPlanos reconstruídos: ${docPlanos.length}');
      print('📊 ProcessingFilters: ${processingFilters != null ? "✅ Criado" : "❌ NULL"}');
      if (processingFilters != null) {
        print('   📄 Available docs: ${processingFilters.availableDocuments}');
        print('   📅 Available dates: ${processingFilters.availableDates}');
      }
      
      // Extrai os docPlanos inválidos dos dados detalhados
      final invalidDocPlanos = _parseInvalidDocPlanos(detailedStats);
      print('❌ DocPlanos inválidos encontrados: ${invalidDocPlanos.length}');
      for (final invalid in invalidDocPlanos) {
        print('   • ${invalid.docPlano} - ${invalid.motivo}');
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
    print('🔍 _parseProcessingFiltersFromStats iniciado');
    print('   🗝️ detailedStats keys: ${detailedStats.keys.toList()}');
    
    final filtersData = detailedStats['processingFilters'] as Map<String, dynamic>? ?? {};
    print('   🎯 filtersData keys: ${filtersData.keys.toList()}');
    print('   📄 availableDocuments raw: ${filtersData['availableDocuments']}');
    print('   📅 availableDates raw: ${filtersData['availableDates']}');
    
    final availableDocPlanosData = filtersData['availableDocPlanos'] as List<dynamic>? ?? [];
    print('   📋 availableDocPlanosData length: ${availableDocPlanosData.length}');
    
    final availableDocPlanos = availableDocPlanosData.map((item) {
      final map = item as Map<String, dynamic>;
      return DocPlano(map['documento'] as String, map['plano'] as String);
    }).toList();
    
    // Extrai datesByDocument corretamente dos dados
    final datesByDocumentRaw = filtersData['datesByDocument'] as Map<String, dynamic>? ?? {};
    print('   📋 datesByDocument raw keys: ${datesByDocumentRaw.keys.toList()}');
    
    final Map<String, List<String>> datesByDocument = {};
    datesByDocumentRaw.forEach((key, value) {
      if (value is List) {
        datesByDocument[key] = (value as List<dynamic>).cast<String>();
      }
    });
    print('   📋 datesByDocument processed: ${datesByDocument.keys.length} documentos');
    
    final result = ProcessingFilters(
      selectedDocuments: (filtersData['selectedDocuments'] as List<dynamic>?)?.cast<String>() ?? [],
      selectedDates: (filtersData['selectedDates'] as List<dynamic>?)?.cast<String>() ?? [],
      availableDocuments: (filtersData['availableDocuments'] as List<dynamic>?)?.cast<String>() ?? [],
      availableDates: (filtersData['availableDates'] as List<dynamic>?)?.cast<String>() ?? [],
      availableDocPlanos: availableDocPlanos,
      datesByDocument: datesByDocument,
    );
    
    print('✅ ProcessingFilters construído:');
    print('   📄 ${result.availableDocuments.length} docs: ${result.availableDocuments}');
    print('   📅 ${result.availableDates.length} dates: ${result.availableDates.take(3).toList()}...');
    print('   📋 ${result.datesByDocument.keys.length} docs com datas: ${result.datesByDocument.keys.take(3).toList()}');
    
    return result;
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
            return ErrorState(error.message, error.details);

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
