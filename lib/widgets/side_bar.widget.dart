import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'output_dir_button.dart';
import 'file_picker_widget.dart';

class Sidebar extends StatelessWidget {
  const Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF007547),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            '- 2. Requisitos do arquivo: Tabela Layout, colunas Contrato Valor e Data Crédito, deve haver Documento e Plano financeiro na tabela layout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            '- 3. Selecione a pasta de destino onde os arquivos gerados serão salvos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
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
