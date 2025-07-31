import '../models/excel_data.dart';
import '../models/process_event.dart';
import '../models/validation_item.dart';

abstract class FileRepository {
  Future<ExcelData> loadExcelFile(String path);
  Future<List<ValidationItem>> validateFile(ExcelData data);
  Stream<ProcessEvent> processFile(String inputPath, String outputDir);
}
