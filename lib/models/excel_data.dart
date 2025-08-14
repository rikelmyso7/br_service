import 'file_stats.dart';
import 'processing_filters.dart';

class ExcelData {
  final List<String> headers;
  final List<List<String>> rows;
  final String fileName;
  final List<DocPlano> docPlanos;
  final FileStats? fileStats;
  final ProcessingFilters? processingFilters;

  const ExcelData({
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.docPlanos,
    this.fileStats,
    this.processingFilters,
  });
}