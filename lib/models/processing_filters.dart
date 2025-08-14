class ProcessingFilters {
  final List<String> selectedDocuments; // Agora no formato documento-plano (ex: AZ-1.01.02.01)
  final List<String> selectedDates;
  final List<String> availableDocuments; // Agora no formato documento-plano
  final List<String> availableDates;
  final List<DocPlano> availableDocPlanos; // Mantém para compatibilidade
  final Map<String, List<String>> datesByDocument; // Datas disponíveis por documento

  const ProcessingFilters({
    required this.selectedDocuments,
    required this.selectedDates,
    required this.availableDocuments,
    required this.availableDates,
    required this.availableDocPlanos,
    required this.datesByDocument,
  });

  ProcessingFilters copyWith({
    List<String>? selectedDocuments,
    List<String>? selectedDates,
    List<String>? availableDocuments,
    List<String>? availableDates,
    List<DocPlano>? availableDocPlanos,
    Map<String, List<String>>? datesByDocument,
  }) {
    return ProcessingFilters(
      selectedDocuments: selectedDocuments ?? this.selectedDocuments,
      selectedDates: selectedDates ?? this.selectedDates,
      availableDocuments: availableDocuments ?? this.availableDocuments,
      availableDates: availableDates ?? this.availableDates,
      availableDocPlanos: availableDocPlanos ?? this.availableDocPlanos,
      datesByDocument: datesByDocument ?? this.datesByDocument,
    );
  }

  bool get hasSelections =>
      selectedDocuments.isNotEmpty || selectedDates.isNotEmpty;

  // Retorna as datas disponíveis baseadas nos documentos selecionados
  List<String> get availableDatesForSelectedDocuments {
    if (selectedDocuments.isEmpty) {
      return []; // Não mostra datas se nenhum documento foi selecionado
    }
    
    final Set<String> allDates = <String>{};
    for (final document in selectedDocuments) {
      final dates = datesByDocument[document];
      if (dates != null) {
        allDates.addAll(dates.map(_convertDateFromCli));
      }
    }
    
    final sortedDates = allDates.toList()..sort();
    return sortedDates;
  }

  // Retorna informações detalhadas sobre quais documentos têm cada data
  Map<String, List<String>> get dateAvailabilityInfo {
    if (selectedDocuments.isEmpty) {
      return {};
    }
    
    final Map<String, List<String>> dateToDocuments = {};
    
    for (final document in selectedDocuments) {
      final dates = datesByDocument[document];
      if (dates != null) {
        for (final date in dates) {
          final convertedDate = _convertDateFromCli(date);
          dateToDocuments.putIfAbsent(convertedDate, () => []).add(document);
        }
      }
    }
    
    return dateToDocuments;
  }

  // Retorna quantos documentos têm uma data específica
  int getDocumentCountForDate(String date) {
    return dateAvailabilityInfo[date]?.length ?? 0;
  }

  // Verifica se uma data está disponível em todos os documentos selecionados
  bool isDateAvailableInAllSelectedDocuments(String date) {
    return getDocumentCountForDate(date) == selectedDocuments.length;
  }

  // Retorna apenas datas que estão em todos os documentos selecionados
  List<String> get datesAvailableInAllDocuments {
    final allDates = availableDatesForSelectedDocuments;
    return allDates.where(isDateAvailableInAllSelectedDocuments).toList();
  }

  // Retorna datas que estão apenas em alguns documentos
  List<String> get datesAvailableInSomeDocuments {
    final allDates = availableDatesForSelectedDocuments;
    return allDates.where((date) => !isDateAvailableInAllSelectedDocuments(date)).toList();
  }

  // Agora os documentos já vêm no formato documento-plano (ex: AZ-1.01.02.01)
  String get documentosForCli => selectedDocuments.join(',');
  String get datasForCli => selectedDates.map(_convertDateToCli).join(',');

  // Converte de YYYY-MM-DD para DD/MM/YYYY
  String _convertDateToCli(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (e) {
      // Se falhar, retorna a data original
    }
    return isoDate;
  }

  // Converte de DD/MM/YYYY para YYYY-MM-DD
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
}

class DocPlano {
  final String documento;
  final String plano;
  
  const DocPlano(this.documento, this.plano);
  
  String get combination => '$documento-$plano';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocPlano &&
          runtimeType == other.runtimeType &&
          documento == other.documento &&
          plano == other.plano;

  @override
  int get hashCode => documento.hashCode ^ plano.hashCode;
}