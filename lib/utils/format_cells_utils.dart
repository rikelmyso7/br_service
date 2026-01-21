import 'package:intl/intl.dart';

String formatCell(dynamic cell, {String dateFormat = 'dd/MM/yyyy', String numberFormat = '#,##0.00', String locale = 'pt_BR', bool isNumericColumn = false,}) {
  if (cell == null) return '';
  
  try {
    if (cell is DateTime) {
      return DateFormat(dateFormat).format(cell);
    }
    if (cell is String) {
      final possibleFormats = [
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
      ];
      for (var fmt in possibleFormats) {
        try {
          return DateFormat(dateFormat).format(fmt.parse(cell));
        } catch (_) {}
      }
      return cell.trim();
    }
  } catch (_) {}

  if (cell is num && isNumericColumn) {
    return NumberFormat(numberFormat, locale).format(cell); // Formata números
  }
  
  return cell.toString().trim();
}