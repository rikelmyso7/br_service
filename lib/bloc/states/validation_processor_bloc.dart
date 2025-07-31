import '../../models/excel_data.dart';
import '../../models/validation_item.dart';
import 'file_processor_bloc.dart';

class ValidationState extends FileProcessorState {
  final String filePath;
  final ExcelData excelData;
  final List<ValidationItem> validationItems;
  final bool canProceed;

  const ValidationState({
    required this.filePath,
    required this.excelData,
    required this.validationItems,
    required this.canProceed,
  });
}