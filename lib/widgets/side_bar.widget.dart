import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:br_service_ui/widgets/update_test_widget.dart';

import 'output_dir_button.dart';
import 'file_picker_widget.dart';

class Sidebar extends StatelessWidget {
  const Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width > 600 ? 260 : 200,
      color: const Color(0xFF007547),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('lib/assets/br.png'),
          const SizedBox(height: 28),
          Text(
            'Como utilizar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '- 1. Selecione o arquivo Excel (.xlsx) que será usado para gerar os outros arquivos',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- 2. Requisitos do arquivo: Tabela Layout, colunas Contrato Valor e Data Crédito, deve haver Documento e Plano financeiro na tabela layout',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- 3. Nos filtros você pode selecionar os Documuentos que deseja exportar e as datas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '- 4. Selecione a pasta de destino onde os arquivos gerados serão salvos',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          
          // // Botão de teste de atualizações
          // Container(
          //   margin: const EdgeInsets.only(bottom: 16),
          //   child: ElevatedButton.icon(
          //     onPressed: () {
          //       Navigator.of(context).push(
          //         MaterialPageRoute(
          //           builder: (context) => const UpdateTestWidget(),
          //         ),
          //       );
          //     },
          //     icon: const Icon(Icons.bug_report, size: 16),
          //     label: const Text(
          //       'Testar Updates',
          //       style: TextStyle(fontSize: 12),
          //     ),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.white.withOpacity(0.1),
          //       foregroundColor: Colors.white,
          //       side: BorderSide(color: Colors.white.withOpacity(0.3)),
          //       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          //     ),
          //   ),
          // ),
          
          const Divider(color: Colors.white70),
          const Text(
            'Desenvolvido por\nRikelmy R.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
