void main() {
  // Simula os dados do CLI
  final datesByDocument = {
    "TX-2.01.09.20": ["02/05/2025", "05/05/2025", "07/05/2025", "09/05/2025", "13/05/2025", "20/05/2025", "23/05/2025"],
    "ADTC-2.01.09.15": ["16/05/2025", "20/05/2025"],
    "AZ-1.01.02.01": ["02/05/2025", "05/05/2025", "06/05/2025", "07/05/2025", "08/05/2025"]
  };
  
  final selectedDocuments = ["TX-2.01.09.20", "ADTC-2.01.09.15"];
  
  // Simula a lógica do availableDatesForSelectedDocuments
  final Set<String> allDates = <String>{};
  for (final document in selectedDocuments) {
    final dates = datesByDocument[document];
    if (dates != null) {
      allDates.addAll(dates.map(_convertDateFromCli));
    }
  }
  
  final sortedDates = allDates.toList()..sort();
  
  print('Documentos selecionados: $selectedDocuments');
  print('Datas disponíveis: ${sortedDates}');
  
  // Verifica se as datas específicas estão corretas:
  // TX-2.01.09.20 tem: 02/05, 05/05, 07/05, 09/05, 13/05, 20/05, 23/05
  // ADTC-2.01.09.15 tem: 16/05, 20/05
  // Resultado esperado: 02/05, 05/05, 07/05, 09/05, 13/05, 16/05, 20/05, 23/05 (em ISO)
}

String _convertDateFromCli(String cliDate) {
  try {
    final parts = cliDate.split('/');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
  } catch (e) {
    // Se falhar, retorna a data original
  }
  return cliDate;
}