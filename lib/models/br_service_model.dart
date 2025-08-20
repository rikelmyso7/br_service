// lib/models/br_service_models.dart
// Modelos robustos para mapear as saídas do CLI do BR_SERVICE.
// Suporta múltiplos formatos de JSON:
// 1) Flat: {
//      "documentos": [...],
//      "datas": [...],
//      "planos_por_documento": { "DOC1": ["PL1","PL2"], ... }, // opcional
//      "datas_por_documento":  { "DOC1": ["01/01/2025"], ... } // opcional
//    }
// 2) Aninhado (com "dados/opcoes/opcoes_documentos"):
//    { "dados": { "opcoes": {
//        "opcoes_documentos": [
//           {"document":"DOC1", "dates":["01/01/2025"]},
//           {"documento":"DOC2", "datas":["02/01/2025","03/01/2025"]}
//        ]
//    }}} 
// 3) Resultados de extração/geração:
//    { "dados": { "dados_extraidos": { "DOC1": [ {...}, {...} ] } } }
//    { "dados": { "arquivos_gerados": ["path/a.xls","path/b.xls"] } }

import 'dart:convert';

/// Representa um documento e suas datas disponíveis para processamento.
class DocumentOption {
  final String document;
  final List<String> dates;

  const DocumentOption({
    required this.document,
    required this.dates,
  });

  DocumentOption copyWith({
    String? document,
    List<String>? dates,
  }) {
    return DocumentOption(
      document: document ?? this.document,
      dates: dates ?? this.dates,
    );
  }

  Map<String, dynamic> toJson() => {
        'document': document,
        'dates': dates,
      };

  /// Aceita map com chaves em inglês/português: (document/documento) e (dates/datas)
  factory DocumentOption.fromJson(dynamic json) {
    if (json is String) {
      // formato minimalista: apenas o nome do documento
      return DocumentOption(document: json, dates: const []);
    }
    if (json is Map<String, dynamic>) {
      final doc =
          (json['document'] ?? json['documento'] ?? json['doc'] ?? '').toString();
      final dates = _asStringList(json['dates'] ?? json['datas']);
      return DocumentOption(document: doc, dates: dates);
    }
    throw FormatException('Formato inválido para DocumentOption: $json');
  }

  @override
  String toString() => 'DocumentOption(document: $document, dates: $dates)';

  @override
  bool operator ==(Object other) =>
      other is DocumentOption &&
      other.document == document &&
      _listEquals(other.dates, dates);

  @override
  int get hashCode => Object.hash(document, dates.join('|'));
}

/// Conjunto de opções retornado por `--get-options`.
class ProcessingOptions {
  final List<DocumentOption> documentOptions;

  const ProcessingOptions({required this.documentOptions});

  ProcessingOptions copyWith({List<DocumentOption>? documentOptions}) {
    return ProcessingOptions(
      documentOptions: documentOptions ?? this.documentOptions,
    );
  }

  Map<String, dynamic> toJson() => {
        'documentOptions': documentOptions.map((e) => e.toJson()).toList(),
      };

  /// Parser robusto para múltiplos formatos.
  factory ProcessingOptions.fromJson(Map<String, dynamic> json) {
    // 1) Tente caminho aninhado: dados -> opcoes -> opcoes_documentos
    final nested = _getIn(json, ['dados', 'opcoes', 'opcoes_documentos']);
    if (nested is List) {
      final list = nested
          .map((e) => DocumentOption.fromJson(e))
          .where((e) => e.document.isNotEmpty)
          .toList();
      return ProcessingOptions(documentOptions: list);
    }

    // 2) Tente formato flat: documentos + (datas | datas_por_documento | planos_por_documento)
    final documentos = _asStringList(json['documentos']);
    final datasGlobais = _asStringList(json['datas']);
    final datasPorDocRaw = json['datas_por_documento'];
    final planosPorDocRaw = json['planos_por_documento']; // opcional, caso exista

    // Se houver uma coleção já “mapeada” de documentos
    final opcoesDoc = json['opcoes_documentos'];
    if (opcoesDoc is List) {
      final list = opcoesDoc
          .map((e) => DocumentOption.fromJson(e))
          .where((e) => e.document.isNotEmpty)
          .toList();
      return ProcessingOptions(documentOptions: list);
    }

    // Constrói a partir de documentos, preferindo datas_por_documento
    if (documentos.isNotEmpty) {
      final docOptions = <DocumentOption>[];

      Map<String, List<String>> datasPorDoc = {};
      if (datasPorDocRaw is Map) {
        datasPorDoc = datasPorDocRaw.map((k, v) =>
            MapEntry(k.toString(), _asStringList(v)));
      }

      for (final doc in documentos) {
        final dates = datasPorDoc[doc] ??
            (datasGlobais.isNotEmpty ? datasGlobais : <String>[]);
        docOptions.add(DocumentOption(document: doc, dates: dates));
      }

      return ProcessingOptions(documentOptions: docOptions);
    }

    // 3) Se vier só uma lista crua (ex.: já pronta), tente inferir
    if (json['documentOptions'] is List) {
      final list = (json['documentOptions'] as List)
          .map((e) => DocumentOption.fromJson(e))
          .where((e) => e.document.isNotEmpty)
          .toList();
      return ProcessingOptions(documentOptions: list);
    }

    // 4) Nada casou → vazio
    return const ProcessingOptions(documentOptions: []);
  }

  @override
  String toString() => 'ProcessingOptions(documentOptions: $documentOptions)';
}

/// Resultado da extração (ex.: dados lidos do Excel por documento).
class ExtractionResult {
  /// Mapa: documento → lista de registros (cada registro é um Map de colunas)
  final Map<String, List<Map<String, dynamic>>> recordsByDocument;

  const ExtractionResult({required this.recordsByDocument});

  ExtractionResult copyWith({
    Map<String, List<Map<String, dynamic>>>? recordsByDocument,
  }) {
    return ExtractionResult(
      recordsByDocument: recordsByDocument ?? this.recordsByDocument,
    );
  }

  Map<String, dynamic> toJson() => {
        'recordsByDocument': recordsByDocument,
      };

  /// Aceita:
  /// - { "dados": { "dados_extraidos": { "DOC1": [ {...}, ... ] } } }
  /// - { "dados_extraidos": { "DOC1": [ {...} ] } }
  /// - { "recordsByDocument": { ... } }
  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    dynamic root = json;
    // sobe para camada "dados" se existir
    final dados = _getIn(json, ['dados']);
    if (dados is Map<String, dynamic>) {
      root = dados;
    }
    final extracted =
        _getIn(root, ['dados_extraidos']) ?? root['recordsByDocument'];

    final map = <String, List<Map<String, dynamic>>>{};
    if (extracted is Map) {
      extracted.forEach((key, value) {
        final doc = key.toString();
        final list = <Map<String, dynamic>>[];
        if (value is List) {
          for (final item in value) {
            if (item is Map) {
              list.add(item.cast<String, dynamic>());
            }
          }
        }
        map[doc] = list;
      });
    }
    return ExtractionResult(recordsByDocument: map);
  }

  @override
  String toString() =>
      'ExtractionResult(recordsByDocument: ${recordsByDocument.keys.toList()})';
}

/// Resultado de geração de arquivos (ex.: planilhas exportadas).
class FileGenerationResult {
  final List<String> generatedFiles;

  const FileGenerationResult({required this.generatedFiles});

  FileGenerationResult copyWith({List<String>? generatedFiles}) {
    return FileGenerationResult(
      generatedFiles: generatedFiles ?? this.generatedFiles,
    );
  }

  Map<String, dynamic> toJson() => {
        'generatedFiles': generatedFiles,
      };

  /// Aceita:
  /// - { "dados": { "arquivos_gerados": ["path1","path2"] } }
  /// - { "arquivos_gerados": ["path1","path2"] }
  /// - { "generatedFiles": ["path1","path2"] }
  /// - { "files": ["path1","path2"] }
  factory FileGenerationResult.fromJson(Map<String, dynamic> json) {
    // tenta "dados/arquivos_gerados"
    final nested = _getIn(json, ['dados', 'arquivos_gerados']);
    if (nested is List) {
      return FileGenerationResult(generatedFiles: _asStringList(nested));
    }

    // tenta planos alternativos
    final a = _asStringList(json['arquivos_gerados']);
    if (a.isNotEmpty) return FileGenerationResult(generatedFiles: a);

    final b = _asStringList(json['generatedFiles']);
    if (b.isNotEmpty) return FileGenerationResult(generatedFiles: b);

    final c = _asStringList(json['files']);
    if (c.isNotEmpty) return FileGenerationResult(generatedFiles: c);

    return const FileGenerationResult(generatedFiles: []);
  }

  @override
  String toString() => 'FileGenerationResult(generatedFiles: $generatedFiles)';
}

/// ---------------------- Helpers ----------------------

List<String> _asStringList(dynamic value) {
  if (value == null) return <String>[];
  if (value is List) {
    return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    // também aceita CSV simples ("A,B,C")
    if (value.contains(',')) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [value.trim()];
  }
  return <String>[];
}

dynamic _getIn(Map<String, dynamic> map, List<String> path) {
  dynamic cur = map;
  for (final key in path) {
    if (cur is Map && cur.containsKey(key)) {
      cur = cur[key];
    } else {
      return null;
    }
  }
  return cur;
}

bool _listEquals(List a, List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Utilitários para serializar/deserializar com segurança.

ProcessingOptions processingOptionsFromJsonString(String source) {
  final Map<String, dynamic> m = json.decode(source) as Map<String, dynamic>;
  return ProcessingOptions.fromJson(m);
}

ExtractionResult extractionResultFromJsonString(String source) {
  final Map<String, dynamic> m = json.decode(source) as Map<String, dynamic>;
  return ExtractionResult.fromJson(m);
}

FileGenerationResult fileGenerationResultFromJsonString(String source) {
  final Map<String, dynamic> m = json.decode(source) as Map<String, dynamic>;
  return FileGenerationResult.fromJson(m);
}
