// test/unit/bloc_parsing_test.dart
//
// Testes dos handlers do FileProcessorBloc via bloc_test.
// Foca nos métodos de parsing (_parseDocPlanosFromStats, _parseProcessingFiltersFromStats,
// _parseInvalidDocPlanos, _createFileStats) exercidos via eventos.
//
// Rodar: flutter test test/unit/bloc_parsing_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:br_service_ui/bloc/file_processor_bloc.dart';
import 'package:br_service_ui/bloc/events/file_events_bloc.dart';
import 'package:br_service_ui/bloc/states/file_processor_bloc.dart';
import 'package:br_service_ui/bloc/states/validation_processor_bloc.dart';
import 'package:br_service_ui/bloc/states/error_bloc.dart';
import 'package:br_service_ui/models/excel_data.dart';
import 'package:br_service_ui/models/validation_item.dart';
import 'package:br_service_ui/models/process_event.dart';
import 'package:br_service_ui/models/processing_filters.dart';
import 'package:br_service_ui/repository/file_repository.dart';

// ---------------------------------------------------------------------------
// Mock do repositório
// ---------------------------------------------------------------------------

class MockFileRepository extends Mock implements FileRepository {}

// ---------------------------------------------------------------------------
// Helpers para montar dados de teste
// ---------------------------------------------------------------------------

ExcelData _minimalExcelData() => const ExcelData(
      fileName: 'test.xlsx',
      headers: ['Contrato', 'Valor', 'Data Crédito'],
      rows: [],
      docPlanos: [],
    );

Map<String, dynamic> _cliDataSimples() => {
      'documentos': ['AZ-1.01.02.01'],
      'planos_por_documento': {
        'AZ-1.01.02.01': ['1.01.02.01'],
      },
      'datas': ['01/07/2025', '02/07/2025'],
      'contas_ativas': {'7': {}},
      'contas_inativas': <String, dynamic>{},
      'invalidDocPlanos': <dynamic>[],
    };

Map<String, dynamic> _detailedStatsSimples() => {
      'docPlanos': [
        {'documento': 'AZ', 'plano': '1.01.02.01'},
        {'documento': 'REG', 'plano': '1.04.01.08'},
      ],
      'countsPerDocPlano': <String, int>{'AZ-1.01.02.01': 408, 'REG-1.04.01.08': 127},
      'totalCombinations': 2,
      'nonEmptyCombinations': 2,
      'totalRecords': 535,
      'colunasObrigatorias': {'todas_presentes': true},
      'processingFilters': {
        'selectedDocuments': <String>[],
        'selectedDates': <String>[],
        'availableDocuments': ['AZ-1.01.02.01', 'REG-1.04.01.08'],
        'availableDates': ['2025-07-01', '2025-07-02'],
        'availableDocPlanos': [
          {'documento': 'AZ', 'plano': '1.01.02.01'},
          {'documento': 'REG', 'plano': '1.04.01.08'},
        ],
        'datesByDocument': {
          'AZ-1.01.02.01': ['2025-07-01'],
          'REG-1.04.01.08': ['2025-07-02'],
        },
        'recordCountsByDocument': <String, dynamic>{'AZ-1.01.02.01': 408, 'REG-1.04.01.08': 127},
      },
      'invalidDocPlanos': <dynamic>[],
    };

List<ValidationItem> _allValidItems() => [
      const ValidationItem(title: 'Planilha "Layout" presente', description: '', isValid: true),
      const ValidationItem(title: 'Documentos identificados', description: '', isValid: true),
      const ValidationItem(title: 'Planos por documento', description: '', isValid: true),
      const ValidationItem(title: 'Datas identificadas', description: '', isValid: true),
      const ValidationItem(title: 'Pares Documento-Plano', description: '', isValid: true),
    ];

// ---------------------------------------------------------------------------
// Testes do FileProcessorBloc
// ---------------------------------------------------------------------------

void main() {
  late MockFileRepository repo;

  setUp(() {
    repo = MockFileRepository();
    registerFallbackValue('');
  });

  // -------------------------------------------------------------------------
  // SelectFileEvent → FilePreviewState
  // -------------------------------------------------------------------------
  group('SelectFileEvent', () {
    blocTest<FileProcessorBloc, FileProcessorState>(
      'emite FileLoadingState e depois FilePreviewState com contas',
      build: () {
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
        return FileProcessorBloc(repo);
      },
      act: (bloc) => bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx')),
      expect: () => [
        isA<FileLoadingState>(),
        isA<FilePreviewState>().having((s) => s.numericSheetNames, 'contas', isNotEmpty),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'emite FilePreviewState vazio quando sem contas',
      build: () {
        final data = Map<String, dynamic>.from(_cliDataSimples());
        data['contas_ativas'] = <String, dynamic>{};
        data['contas_inativas'] = <String, dynamic>{};
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenAnswer((_) async => data);
        return FileProcessorBloc(repo);
      },
      act: (bloc) => bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx')),
      expect: () => [
        isA<FileLoadingState>(),
        isA<FilePreviewState>().having((s) => s.numericSheetNames, 'contas', isEmpty),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'emite ErrorState quando loadExcelFile lança exceção',
      build: () {
        when(() => repo.loadExcelFile(any())).thenThrow(Exception('Arquivo corrompido'));
        when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
        return FileProcessorBloc(repo);
      },
      act: (bloc) => bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx')),
      expect: () => [
        isA<FileLoadingState>(),
        isA<ErrorState>(),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'emite ErrorState quando getAllData lança exceção',
      build: () {
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenThrow(Exception('Daemon offline'));
        return FileProcessorBloc(repo);
      },
      act: (bloc) => bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx')),
      expect: () => [
        isA<FileLoadingState>(),
        isA<ErrorState>(),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // ProceedToValidationEvent → ValidationState
  // -------------------------------------------------------------------------
  group('ProceedToValidationEvent', () {
    FileProcessorBloc _blocWithFile() {
      when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
      when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
      when(() => repo.validateFile(any())).thenAnswer((_) async => _allValidItems());
      when(() => repo.getDetailedFileStats(any()))
          .thenAnswer((_) async => _detailedStatsSimples());
      return FileProcessorBloc(repo);
    }

    blocTest<FileProcessorBloc, FileProcessorState>(
      'parsing de docPlanos — extrai corretamente do detailedStats',
      build: _blocWithFile,
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2, // pula FileLoadingState e FilePreviewState
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ValidationState>().having(
          (s) => s.excelData.docPlanos.length,
          'docPlanos count',
          2,
        ),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'parsing de processingFilters — availableDocuments preenchido',
      build: _blocWithFile,
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2,
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ValidationState>().having(
          (s) => s.excelData.processingFilters?.availableDocuments,
          'availableDocuments',
          containsAll(['AZ-1.01.02.01', 'REG-1.04.01.08']),
        ),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'canProceed true quando todos validationItems são válidos',
      build: _blocWithFile,
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2,
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ValidationState>().having((s) => s.canProceed, 'canProceed', isTrue),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'canProceed false quando algum item é inválido',
      build: () {
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
        when(() => repo.validateFile(any())).thenAnswer((_) async => [
              const ValidationItem(
                title: 'Documentos identificados',
                description: '',
                isValid: false,
                errorMessage: 'Nenhum documento',
              ),
            ]);
        when(() => repo.getDetailedFileStats(any()))
            .thenAnswer((_) async => _detailedStatsSimples());
        return FileProcessorBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2,
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ValidationState>().having((s) => s.canProceed, 'canProceed', isFalse),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'parsing de recordCountsByDocument — suporta valores num (double)',
      build: () {
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
        when(() => repo.validateFile(any())).thenAnswer((_) async => _allValidItems());

        // Simula block_counts com doubles (como Python JSON pode enviar)
        final stats = Map<String, dynamic>.from(_detailedStatsSimples());
        final filters = Map<String, dynamic>.from(
            stats['processingFilters'] as Map<String, dynamic>);
        filters['recordCountsByDocument'] = <String, dynamic>{
          'AZ-1.01.02.01': 408.0,  // double
          'REG-1.04.01.08': 127,   // int
        };
        stats['processingFilters'] = filters;
        when(() => repo.getDetailedFileStats(any())).thenAnswer((_) async => stats);
        return FileProcessorBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2,
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ValidationState>().having(
          (s) => s.excelData.processingFilters?.recordCountsByDocument['AZ-1.01.02.01'],
          'recordCount AZ',
          408,
        ),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'parsing de invalidDocPlanos',
      build: () {
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
        when(() => repo.validateFile(any())).thenAnswer((_) async => _allValidItems());

        final stats = Map<String, dynamic>.from(_detailedStatsSimples());
        stats['invalidDocPlanos'] = [
          {'docPlano': 'TTT-1.04.01.19', 'motivo': 'Sem dados válidos'},
        ];
        when(() => repo.getDetailedFileStats(any())).thenAnswer((_) async => stats);
        return FileProcessorBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2,
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ValidationState>().having(
          (s) => s.excelData.invalidDocPlanos.length,
          'invalidDocPlanos count',
          1,
        ),
      ],
    );

    blocTest<FileProcessorBloc, FileProcessorState>(
      'emite ErrorState quando getDetailedFileStats lança',
      build: () {
        when(() => repo.loadExcelFile(any())).thenAnswer((_) async => _minimalExcelData());
        when(() => repo.getAllData(any())).thenAnswer((_) async => _cliDataSimples());
        when(() => repo.validateFile(any())).thenAnswer((_) async => _allValidItems());
        when(() => repo.getDetailedFileStats(any()))
            .thenThrow(Exception('Daemon timeout'));
        return FileProcessorBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SelectFileEvent('C:/test/arquivo.xlsx'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProceedToValidationEvent());
      },
      skip: 2,
      expect: () => [
        isA<ValidationLoadingState>(),
        isA<ErrorState>(),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // ResetEvent
  // -------------------------------------------------------------------------
  group('ResetEvent', () {
    blocTest<FileProcessorBloc, FileProcessorState>(
      'volta para InitialState',
      build: () => FileProcessorBloc(repo),
      act: (bloc) => bloc.add(const ResetEvent()),
      expect: () => [isA<InitialState>()],
    );
  });

  // -------------------------------------------------------------------------
  // ProceedToValidationEvent sem arquivo carregado
  // -------------------------------------------------------------------------
  group('ProceedToValidationEvent sem arquivo', () {
    blocTest<FileProcessorBloc, FileProcessorState>(
      'não emite estado quando _selectedFile é null',
      build: () => FileProcessorBloc(repo),
      act: (bloc) => bloc.add(const ProceedToValidationEvent()),
      expect: () => [],
    );
  });
}
