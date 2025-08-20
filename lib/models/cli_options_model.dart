class CliOptions {
  final List<String> documentos;
  final Map<String, List<String>> planosPorDocumento;
  final List<String> datas;
  CliOptions({
    required this.documentos,
    required this.planosPorDocumento,
    required this.datas,
  });
}