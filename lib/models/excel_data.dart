import 'file_stats.dart';
import 'processing_filters.dart';
import 'invalid_doc_plano.dart';

class ExcelData {
  final List<String> headers;
  final List<List<String>> rows;
  final String fileName;
  final List<DocPlano> docPlanos;
  final FileStats? fileStats;
  final ProcessingFilters? processingFilters;
  final List<InvalidDocPlano> invalidDocPlanos;

  const ExcelData({
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.docPlanos,
    this.fileStats,
    this.processingFilters,
    this.invalidDocPlanos = const [],
  });
}