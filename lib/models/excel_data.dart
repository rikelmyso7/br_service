class ExcelData {
  final List<String> headers;
  final List<List<String>> rows;
  final String fileName;
  final List<DocPlano> docPlanos;
  

  const ExcelData({
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.docPlanos,
  });
}

class DocPlano {
  final String documento;
  final String plano;
  const DocPlano(this.documento, this.plano);
}