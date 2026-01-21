import 'package:flutter/material.dart';

class NumericSheetsPopup extends StatelessWidget {
  final List<String> numericSheetNames;
  final Function(String)? onSheetSelected;
  final Map<String, dynamic>? contasAnalysis;

  const NumericSheetsPopup({
    super.key,
    required this.numericSheetNames,
    this.onSheetSelected,
    this.contasAnalysis,
  });

  // Separa as contas entre disponíveis e indisponíveis com base na análise CLI
  List<String> get _availableAccounts {
    if (contasAnalysis == null) return numericSheetNames;

    final contasAtivas =
        (contasAnalysis!['contas_ativas'] as Map<String, dynamic>?) ?? {};
    return contasAtivas.keys.toList();
  }

  List<String> get _unavailableAccounts {
    if (contasAnalysis == null) return [];

    final contasInativas =
        (contasAnalysis!['contas_inativas'] as Map<String, dynamic>?) ?? {};
    return contasInativas.keys.toList();
  }

  bool _isContaAtiva(String conta) {
    if (contasAnalysis == null) return true;
    final contasAtivas =
        (contasAnalysis!['contas_ativas'] as Map<String, dynamic>?) ?? {};
    return contasAtivas.containsKey(conta);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green[600], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Foram encontradas diferentes contas numéricas no arquivo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selecione a conta desejada para prosseguir',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Foram encontradas ${numericSheetNames.length} contas',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Grid de botões com os nomes numéricos
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 120,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 2.5,
                            ),
                        itemCount: numericSheetNames.length,
                        itemBuilder: (context, index) {
                          final sheetName = numericSheetNames[index];
                          final isAtiva = _isContaAtiva(sheetName);

                          return ElevatedButton(
                            onPressed:
                                isAtiva
                                    ? () {
                                      if (onSheetSelected != null) {
                                        onSheetSelected!(sheetName);
                                      }
                                      Navigator.of(context).pop(sheetName);
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isAtiva ? Colors.green[600] : Colors.red[400],
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[400],
                              disabledForegroundColor: Colors.grey[600],
                              elevation: isAtiva ? 1 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color:
                                      isAtiva
                                          ? Colors.green[300]!
                                          : Colors.grey[200]!,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  sheetName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isAtiva)
                                  Text(
                                    'Sem dados',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          isAtiva
                                              ? Colors.white
                                              : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer com botões de ação
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Continuar sem selecionar',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Método estático para mostrar o popup
  static Future<String?> show({
    required BuildContext context,
    required List<String> numericSheetNames,
    Function(String)? onSheetSelected,
    Map<String, dynamic>? contasAnalysis,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NumericSheetsPopup(
            numericSheetNames: numericSheetNames,
            onSheetSelected: onSheetSelected,
            contasAnalysis: contasAnalysis,
          ),
    );
  }
}
