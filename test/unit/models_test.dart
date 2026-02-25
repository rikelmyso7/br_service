// test/unit/models_test.dart
//
// Testes dos modelos de dados puros: FileStats, DocPlanoStat, InvalidDocPlano.
// Rodar: flutter test test/unit/models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:br_service_ui/models/file_stats.dart';
import 'package:br_service_ui/models/invalid_doc_plano.dart';
import 'package:br_service_ui/models/processing_filters.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DocPlanoStat
  // ---------------------------------------------------------------------------
  group('DocPlanoStat', () {
    test('combination retorna "documento → plano"', () {
      const stat = DocPlanoStat(
        documento: 'AZ',
        plano: '1.01.02.01',
        recordCount: 408,
        hasData: true,
      );
      expect(stat.combination, 'AZ → 1.01.02.01');
    });

    test('hasData false quando recordCount é 0', () {
      const stat = DocPlanoStat(
        documento: 'TTT',
        plano: '1.04.01.19',
        recordCount: 0,
        hasData: false,
      );
      expect(stat.hasData, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // FileStats
  // ---------------------------------------------------------------------------
  group('FileStats', () {
    test('armazena valores corretamente', () {
      const stats = FileStats(
        docPlanoStats: [],
        totalCombinations: 10,
        nonEmptyCombinations: 6,
        totalRecords: 535,
      );
      expect(stats.totalCombinations, 10);
      expect(stats.nonEmptyCombinations, 6);
      expect(stats.totalRecords, 535);
    });

    test('lista de docPlanoStats é preservada', () {
      const stats = FileStats(
        docPlanoStats: [
          DocPlanoStat(documento: 'AZ', plano: '1.01', recordCount: 100, hasData: true),
          DocPlanoStat(documento: 'REG', plano: '1.04', recordCount: 0, hasData: false),
        ],
        totalCombinations: 2,
        nonEmptyCombinations: 1,
        totalRecords: 100,
      );
      expect(stats.docPlanoStats.length, 2);
      expect(stats.docPlanoStats.first.documento, 'AZ');
    });
  });

  // ---------------------------------------------------------------------------
  // InvalidDocPlano
  // ---------------------------------------------------------------------------
  group('InvalidDocPlano', () {
    test('toString retorna formato correto', () {
      const inv = InvalidDocPlano(docPlano: 'TTT-1.04.01.19', motivo: 'Sem dados válidos');
      expect(inv.toString(), 'TTT-1.04.01.19 - Sem dados válidos');
    });

    test('campos são preservados', () {
      const inv = InvalidDocPlano(docPlano: 'COND-2.01.09.17', motivo: 'Bloco zerado');
      expect(inv.docPlano, 'COND-2.01.09.17');
      expect(inv.motivo, 'Bloco zerado');
    });
  });

  // ---------------------------------------------------------------------------
  // DocPlano
  // ---------------------------------------------------------------------------
  group('DocPlano', () {
    test('pode ser usado como chave de Map via hashCode/==', () {
      final map = <DocPlano, int>{};
      const dp = DocPlano('AZ', '1.01.02.01');
      map[dp] = 42;
      expect(map[const DocPlano('AZ', '1.01.02.01')], 42);
    });

    test('lista sem duplicatas usando Set', () {
      final set = {
        const DocPlano('AZ', '1.01.02.01'),
        const DocPlano('AZ', '1.01.02.01'),
        const DocPlano('REG', '1.04.01.08'),
      };
      expect(set.length, 2);
    });
  });
}
