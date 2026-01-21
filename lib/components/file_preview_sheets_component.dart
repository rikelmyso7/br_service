import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/events/file_events_bloc.dart';
import '../bloc/file_processor_bloc.dart';
import '../models/excel_data.dart';
import '../repository/file_repository.dart';
import '../widgets/excel_viewer.dart';
import '../widgets/numeric_sheets_popup.dart';

class FilePreviewSheets extends StatefulWidget {
  final ExcelData excelData;
  final String filePath;
  final List<String> numericSheetNames;
  final Map<String, dynamic>? contasAnalysis;

  const FilePreviewSheets({
    super.key,
    required this.excelData,
    required this.filePath,
    required this.numericSheetNames,
    this.contasAnalysis,
  });

  @override
  State<FilePreviewSheets> createState() =>
      _FilePreviewSheetsState();
}

class _FilePreviewSheetsState
    extends State<FilePreviewSheets> {
  String? selectedNumericSheet;
  bool isLoadingCli = false;

  @override
  void initState() {
    super.initState();
    print('🔍 FilePreviewSheets - initState chamado');
    print('🔍 Planilhas numéricas recebidas: ${widget.numericSheetNames}');
    // Mostra o popup automaticamente após o build apenas se não há erro de planilha e há contas disponíveis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasResumoContaError() && widget.numericSheetNames.isNotEmpty) {
        print('🔍 PostFrameCallback executado, chamando popup...');
        _showNumericSheetsPopup();
      } else {
        if (_hasResumoContaError()) {
          print('⚠️ Erro de planilha "Resumo por Conta" detectado - não exibindo popup');
        } else if (widget.numericSheetNames.isEmpty) {
          print('⚠️ Nenhuma conta numérica encontrada - não exibindo popup');
        }
        // Define como original para mostrar o ExcelViewer diretamente
        setState(() {
          selectedNumericSheet = 'original';
        });
      }
    });
  }

  /// Verifica se há erro específico da planilha 'Resumo por Conta' ou CLI falhou
  bool _hasResumoContaError() {
    if (widget.contasAnalysis == null) return false;

    final erro = widget.contasAnalysis!['erro'] as String?;
    if (erro != null) {
      // Verifica se contém erro específico da planilha Resumo por Conta
      if (erro.contains("Resumo por Conta not found") ||
          erro.contains("Worksheet named 'Resumo por Conta' not found")) {
        return true;
      }

      // Verifica se é um erro geral do CLI para análise de contas
      if (erro.contains("Erro ao analisar contas") ||
          erro.contains("CLI falhou")) {
        return true;
      }
    }

    return false;
  }

  void _showNumericSheetsPopup() async {
    final result = await NumericSheetsPopup.show(
      context: context,
      numericSheetNames: widget.numericSheetNames,
      contasAnalysis: widget.contasAnalysis,
      onSheetSelected: (sheetName) async {
        print('🏦 Usuário selecionou conta: $sheetName');

        // Inicia loading
        setState(() {
          isLoadingCli = true;
          selectedNumericSheet = null; // Remove exibição atual
        });

        try {
          // Chama o CLI com o número da conta selecionada
          final repository = context.read<FileRepository>();
          final accountNumber = sheetName;

          print('🔄 Chamando CLI com conta $accountNumber...');
          await (repository as dynamic).swapAccountNumber(
            widget.filePath,
            accountNumber,
          );

          // Só atualiza UI quando CLI terminar completamente
          setState(() {
            selectedNumericSheet = sheetName;
            isLoadingCli = false;
          });

          print('✅ CLI executado com sucesso para conta $accountNumber');
        } catch (e) {
          print('❌ Erro ao executar CLI com conta: $e');

          setState(() {
            isLoadingCli = false;
          });

          // Mostra erro para o usuário
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao processar conta $sheetName: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    // Esta parte não será executada quando uma conta é selecionada
    // pois o callback acima já trata isso
    if (result == null && !isLoadingCli) {
      // Se o usuário escolheu "Continuar sem selecionar",
      // carrega o ExcelViewer com a conta original do arquivo
      setState(() {
        selectedNumericSheet =
            'original'; // Marca que deve usar a conta original
      });
      print('📋 Continuando sem selecionar - usando conta original do arquivo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<FileProcessorBloc>().add(
            const ProceedToValidationEvent(),
          );
        },
        backgroundColor: Colors.green,
        label: Row(
          children: [
            const Text('Continuar', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visualização: ${widget.excelData.fileName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  isLoadingCli || _hasResumoContaError() || widget.numericSheetNames.isEmpty
                      ? SizedBox(width: 1)
                      : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: _showNumericSheetsPopup,
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: Text(
                          'Ver contas disponiveis (${widget.numericSheetNames.length})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      context.read<FileProcessorBloc>().add(const ResetEvent());
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Novo processamento'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Mostra loading quando CLI está executando
          if (isLoadingCli)
            Expanded(
              child: _buildCompactLoadingView(
                title: 'Alterando Conta',
                message: 'Aguarde enquanto o programa processa a nova conta selecionada',
                icon: Icons.swap_horiz,
              ),
            )
          // Só mostra o ExcelViewer após o usuário selecionar uma conta E o CLI terminar
          else if (selectedNumericSheet != null)
            Expanded(
              child: ExcelViewer(
                key: ValueKey('excel_viewer_$selectedNumericSheet'),
                filePath: widget.filePath,
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aguardando seleção da conta...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione uma conta numérica para visualizar os dados',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactLoadingView({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: CupertinoColors.systemGreen,
                ),
                const SizedBox(height: 12),
                const CupertinoActivityIndicator(radius: 10),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }
}
