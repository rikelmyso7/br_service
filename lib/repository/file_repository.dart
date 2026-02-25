import '../models/excel_data.dart';
import '../models/process_event.dart';
import '../models/processing_filters.dart';
import '../models/validation_item.dart';

abstract class FileRepository {
  Future<ExcelData> loadExcelFile(String path, {String? executablePath});
  Future<List<ValidationItem>> validateFile(String filePath);
  Future<Map<String, dynamic>> analyzeFile(String path);
  Future<Map<String, dynamic>> getAllData(String path);
  Future<Map<String, dynamic>> getDetailedFileStats(String filePath);
  Stream<ProcessEvent> processFile(String inputPath, String outputDir, {ProcessingFilters? filters});
  Future<Map<String, dynamic>> getContasAnalysis(String path);
}
