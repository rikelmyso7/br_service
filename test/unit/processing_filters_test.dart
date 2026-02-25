// test/unit/processing_filters_test.dart
//
// Testes unitários para ProcessingFilters e DocPlano.
// Não requer Flutter engine — rodar com: flutter test test/unit/processing_filters_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:br_service_ui/models/processing_filters.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DocPlano
  // ---------------------------------------------------------------------------
  group('DocPlano', () {
    test('combination retorna documento-plano', () {
      const dp = DocPlano('AZ', '1.01.02.01');
      expect(dp.combination, 'AZ-1.01.02.01');
    });

    test('igualdade por valor', () {
      const a = DocPlano('AZ', '1.01.02.01');
      const b = DocPlano('AZ', '1.01.02.01');
      expect(a, equals(b));
    });

    test('desigualdade com plano diferente', () {
      const a = DocPlano('AZ', '1.01.02.01');
      const b = DocPlano('AZ', '2.02.02.02');
      expect(a, isNot(equals(b)));
    });

    test('desigualdade com documento diferente', () {
      const a = DocPlano('AZ', '1.01.02.01');
      const b = DocPlano('REG', '1.01.02.01');
      expect(a, isNot(equals(b)));
    });

    test('hashCode igual para instâncias iguais', () {
      const a = DocPlano('AZ', '1.01.02.01');
      const b = DocPlano('AZ', '1.01.02.01');
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------------------
  // ProcessingFilters — conversão de datas
  // ---------------------------------------------------------------------------
  group('ProcessingFilters._convertDateFromCli', () {
    ProcessingFilters _filters({
      List<String> selectedDocs = const [],
      Map<String, List<String>> datesByDoc = const {},
    }) {
      return ProcessingFilters(
        selectedDocuments: selectedDocs,
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: datesByDoc,
      );
    }

    test('datasForCli converte YYYY-MM-DD para DD/MM/YYYY', () {
      final f = ProcessingFilters(
        selectedDocuments: const [],
        selectedDates: const ['2025-07-01', '2025-12-31'],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(f.datasForCli, '01/07/2025,31/12/2025');
    });

    test('datasForCli retorna string vazia quando sem seleção', () {
      final f = ProcessingFilters(
        selectedDocuments: const [],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(f.datasForCli, '');
    });

    test('datasForCli não lança exceção com data malformada', () {
      // Data sem hífens não tem 3 partes — é retornada original
      final f = ProcessingFilters(
        selectedDocuments: const [],
        selectedDates: const ['invalida'],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(() => f.datasForCli, returnsNormally);
      expect(f.datasForCli, 'invalida');
    });

    test('documentosForCli une com vírgula', () {
      final f = ProcessingFilters(
        selectedDocuments: const ['AZ-1.01.02.01', 'REG-1.04.01.08'],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(f.documentosForCli, 'AZ-1.01.02.01,REG-1.04.01.08');
    });
  });

  // ---------------------------------------------------------------------------
  // availableDatesForSelectedDocuments
  // ---------------------------------------------------------------------------
  group('ProcessingFilters.availableDatesForSelectedDocuments', () {
    final datesByDoc = {
      'TX-2.01.09.20': ['02/05/2025', '05/05/2025', '20/05/2025'],
      'ADTC-2.01.09.15': ['16/05/2025', '20/05/2025'],
      'AZ-1.01.02.01': ['02/05/2025', '06/05/2025'],
    };

    ProcessingFilters _f(List<String> selectedDocs) => ProcessingFilters(
          selectedDocuments: selectedDocs,
          selectedDates: const [],
          availableDocuments: const [],
          availableDates: const [],
          availableDocPlanos: const [],
          datesByDocument: datesByDoc,
        );

    test('retorna vazio quando nenhum documento selecionado', () {
      expect(_f([]).availableDatesForSelectedDocuments, isEmpty);
    });

    test('retorna datas convertidas para ISO de um documento', () {
      final dates = _f(['TX-2.01.09.20']).availableDatesForSelectedDocuments;
      expect(dates, containsAll(['2025-05-02', '2025-05-05', '2025-05-20']));
    });

    test('une datas de múltiplos documentos sem duplicatas', () {
      final dates = _f(['TX-2.01.09.20', 'ADTC-2.01.09.15'])
          .availableDatesForSelectedDocuments;
      // TX tem 20/05, ADTC também — deve aparecer uma vez
      expect(dates.where((d) => d == '2025-05-20').length, 1);
    });

    test('resultado ordenado crescentemente', () {
      final dates = _f(['TX-2.01.09.20', 'ADTC-2.01.09.15'])
          .availableDatesForSelectedDocuments;
      final sorted = [...dates]..sort();
      expect(dates, equals(sorted));
    });

    test('documento sem datas contribui com lista vazia', () {
      final f = ProcessingFilters(
        selectedDocuments: const ['DOC-SEM-DATA'],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {'DOC-SEM-DATA': []},
      );
      expect(f.availableDatesForSelectedDocuments, isEmpty);
    });

    test('padding de zeros em dia e mês', () {
      final f = ProcessingFilters(
        selectedDocuments: const ['DOC'],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {
          'DOC': ['1/5/2025'],  // sem padding
        },
      );
      // _convertDateFromCli deve aplicar padLeft
      final dates = f.availableDatesForSelectedDocuments;
      expect(dates.first, '2025-05-01');
    });
  });

  // ---------------------------------------------------------------------------
  // isDateAvailableInAllSelectedDocuments / datesAvailableInAllDocuments
  // ---------------------------------------------------------------------------
  group('ProcessingFilters — disponibilidade cruzada de datas', () {
    final f = ProcessingFilters(
      selectedDocuments: const ['DOC-A', 'DOC-B'],
      selectedDates: const [],
      availableDocuments: const [],
      availableDates: const [],
      availableDocPlanos: const [],
      datesByDocument: const {
        'DOC-A': ['01/07/2025', '02/07/2025'],
        'DOC-B': ['02/07/2025', '03/07/2025'],
      },
    );

    test('data comum a todos retorna true', () {
      expect(f.isDateAvailableInAllSelectedDocuments('2025-07-02'), isTrue);
    });

    test('data de apenas um documento retorna false', () {
      expect(f.isDateAvailableInAllSelectedDocuments('2025-07-01'), isFalse);
    });

    test('datesAvailableInAllDocuments contém apenas datas comuns', () {
      expect(f.datesAvailableInAllDocuments, equals(['2025-07-02']));
    });

    test('datesAvailableInSomeDocuments exclui datas comuns', () {
      final partial = f.datesAvailableInSomeDocuments;
      expect(partial, contains('2025-07-01'));
      expect(partial, contains('2025-07-03'));
      expect(partial, isNot(contains('2025-07-02')));
    });
  });

  // ---------------------------------------------------------------------------
  // totalSelectedRecords / getRecordCount
  // ---------------------------------------------------------------------------
  group('ProcessingFilters — contagens de registros', () {
    final f = ProcessingFilters(
      selectedDocuments: const ['AZ-1.01.02.01', 'REG-1.04.01.08'],
      selectedDates: const [],
      availableDocuments: const [],
      availableDates: const [],
      availableDocPlanos: const [],
      datesByDocument: const {},
      recordCountsByDocument: const {
        'AZ-1.01.02.01': 408,
        'REG-1.04.01.08': 127,
      },
    );

    test('getRecordCount retorna valor correto', () {
      expect(f.getRecordCount('AZ-1.01.02.01'), 408);
    });

    test('getRecordCount retorna 0 para documento sem registro', () {
      expect(f.getRecordCount('NAO-EXISTE'), 0);
    });

    test('totalSelectedRecords soma todos os selecionados', () {
      expect(f.totalSelectedRecords, 535);
    });

    test('totalSelectedRecords retorna 0 sem seleção', () {
      final empty = ProcessingFilters(
        selectedDocuments: const [],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
        recordCountsByDocument: const {'AZ-1.01.02.01': 408},
      );
      expect(empty.totalSelectedRecords, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // hasSelections
  // ---------------------------------------------------------------------------
  group('ProcessingFilters.hasSelections', () {
    test('false quando tudo vazio', () {
      final f = ProcessingFilters(
        selectedDocuments: const [],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(f.hasSelections, isFalse);
    });

    test('true quando há documentos selecionados', () {
      final f = ProcessingFilters(
        selectedDocuments: const ['AZ-1.01.02.01'],
        selectedDates: const [],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(f.hasSelections, isTrue);
    });

    test('true quando há datas selecionadas', () {
      final f = ProcessingFilters(
        selectedDocuments: const [],
        selectedDates: const ['2025-07-01'],
        availableDocuments: const [],
        availableDates: const [],
        availableDocPlanos: const [],
        datesByDocument: const {},
      );
      expect(f.hasSelections, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------
  group('ProcessingFilters.copyWith', () {
    const base = ProcessingFilters(
      selectedDocuments: ['DOC-A'],
      selectedDates: ['2025-07-01'],
      availableDocuments: ['DOC-A'],
      availableDates: ['2025-07-01'],
      availableDocPlanos: [],
      datesByDocument: {},
    );

    test('copia sem alteração retorna valores iguais', () {
      final copy = base.copyWith();
      expect(copy.selectedDocuments, base.selectedDocuments);
      expect(copy.selectedDates, base.selectedDates);
    });

    test('altera apenas selectedDocuments', () {
      final copy = base.copyWith(selectedDocuments: ['DOC-B']);
      expect(copy.selectedDocuments, ['DOC-B']);
      expect(copy.selectedDates, base.selectedDates);
    });
  });
}
