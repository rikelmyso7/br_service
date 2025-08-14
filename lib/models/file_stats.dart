class FileStats {
  final List<DocPlanoStat> docPlanoStats;
  final int totalCombinations;
  final int nonEmptyCombinations;
  final int totalRecords;

  const FileStats({
    required this.docPlanoStats,
    required this.totalCombinations,
    required this.nonEmptyCombinations,
    required this.totalRecords,
  });
}

class DocPlanoStat {
  final String documento;
  final String plano;
  final int recordCount;
  final bool hasData;

  const DocPlanoStat({
    required this.documento,
    required this.plano,
    required this.recordCount,
    required this.hasData,
  });

  String get combination => '$documento → $plano';
}