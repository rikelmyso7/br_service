import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final jsonString = File('./debug_json.json').readAsStringSync();
    print('JSON string length: ${jsonString.length}');
    print('Contains datas_por_documento: ${jsonString.contains('datas_por_documento')}');
    
    final Map<String, dynamic> decoded = json.decode(jsonString);
    print('Decoded keys: ${decoded.keys.toList()}');
    print('Has datas_por_documento: ${decoded.containsKey('datas_por_documento')}');
    
    // Verifica se há dados válidos com datas_por_documento
    final dadosValidos = decoded['dados_validos'] as Map<String, dynamic>?;
    if (dadosValidos != null && dadosValidos.containsKey('datas_por_documento')) {
      print('datas_por_documento está dentro de dados_validos!');
      final dpd = dadosValidos['datas_por_documento'] as Map<String, dynamic>?;
      print('Keys in dados_validos.datas_por_documento: ${dpd?.keys.take(3).toList()}');
    }
    
  } catch (e) {
    print('Erro: $e');
  }
}