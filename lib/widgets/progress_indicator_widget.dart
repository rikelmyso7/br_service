import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/file_processor_bloc.dart';
import '../bloc/states/completed_bloc.dart';
import '../bloc/states/error_bloc.dart';
import '../bloc/states/file_processor_bloc.dart';
import '../bloc/states/processing_bloc.dart';
import '../bloc/states/validation_processor_bloc.dart';

class ProgressIndicatorWidget extends StatefulWidget {
  const ProgressIndicatorWidget({Key? key}) : super(key: key);

  @override
  _ProgressIndicatorWidgetState createState() =>
      _ProgressIndicatorWidgetState();
}

class _ProgressIndicatorWidgetState extends State<ProgressIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _updateProgress(double progress) {
    _progressController.animateTo(progress);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileProcessorBloc, FileProcessorState>(
      builder: (context, state) {
        int currentStep = 0;
        bool hasError = false;
        String statusMessage = 'Aguardando início...';

        // Determinar step atual e status
        switch (state.runtimeType) {
          case FilePreviewState:
            currentStep = 1;
            statusMessage = 'Analisando arquivo selecionado';
            break;
          case ValidationState:
            currentStep = 2;
            statusMessage = 'Validando estrutura dos dados';
            break;
          case ProcessingState:
            currentStep = 3;
            statusMessage = 'Processando e gerando arquivos';
            break;
          case ErrorState:
            currentStep = 4;
            hasError = true;
            statusMessage = 'Erro durante o processamento';
            break;
          case CompletedState:
            currentStep = 5;
            statusMessage = 'Processamento concluído com sucesso!';
            break;
        }

        // Atualizar animação do progresso
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateProgress(currentStep / 5.0);
        });

        final steps = [
          {
            'title': 'Início',
            'icon': Icons.upload_file,
            'desc': 'Carregar arquivo',
          },
          {
            'title': 'Checklist',
            'icon': Icons.preview,
            'desc': 'Analisar dados',
          },
          {
            'title': 'Validação',
            'icon': Icons.fact_check,
            'desc': 'Verificar estrutura',
          },
          {
            'title': 'Processamento',
            'icon': Icons.settings,
            'desc': 'Gerar saídas',
          },
          {
            'title': 'Finalizado',
            'icon': Icons.check_circle,
            'desc': 'Processo completo',
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Steps
            Row(
              children: List.generate(steps.length, (index) {
                final active = currentStep > index + 1;
                final current = currentStep == index + 1;
                final step = steps[index];

                return Expanded(
                  child: Column(
                    children: [
                      // Círculo do step com animação
                      AnimatedBuilder(
                        animation:
                            current
                                ? _pulseAnimation
                                : const AlwaysStoppedAnimation(1.0),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: current ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    active
                                        ? Colors.green[600]
                                        : current
                                        ? hasError && index == 4
                                            ? Colors.red[600]
                                            : Colors.blue[600]
                                        : Colors.grey[300],
                                shape: BoxShape.circle,
                                boxShadow:
                                    current
                                        ? [
                                          BoxShadow(
                                            color: (hasError && index == 4
                                                    ? Colors.red[600]!
                                                    : active
                                                    ? Colors.green[600]!
                                                    : Colors.blue[600]!)
                                                .withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                        : null,
                              ),
                              child:
                                  active
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                      : current &&
                                          index ==
                                              3 // Processing step
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(Colors.white),
                                        ),
                                      )
                                      : Icon(
                                        hasError && current && index == 4
                                            ? Icons.error
                                            : step['icon'] as IconData,
                                        color:
                                            current || active
                                                ? Colors.white
                                                : Colors.grey[600],
                                        size: 20,
                                      ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Título do step
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              current
                                  ? FontWeight.bold
                                  : active
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                          color:
                              active || current
                                  ? Colors.black87
                                  : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),
                      // Container(
                      //   height: 8,
                      //   decoration: BoxDecoration(
                      //     color: Colors.grey[200],
                      //     borderRadius: BorderRadius.circular(4),
                      //   ),
                      //   child: AnimatedBuilder(
                      //     animation: _progressAnimation,
                      //     builder: (context, child) {
                      //       return FractionallySizedBox(
                      //         alignment: Alignment.centerLeft,
                      //         widthFactor: _progressAnimation.value,
                      //         child: Container(
                      //           decoration: BoxDecoration(
                      //             gradient: LinearGradient(
                      //               colors:
                      //                   hasError
                      //                       ? [
                      //                         Colors.red[400]!,
                      //                         Colors.red[600]!,
                      //                       ]
                      //                       : currentStep == 5
                      //                       ? [
                      //                         Colors.green[400]!,
                      //                         Colors.green[600]!,
                      //                       ]
                      //                       : [
                      //                         Colors.blue[400]!,
                      //                         Colors.blue[600]!,
                      //                       ],
                      //             ),
                      //             borderRadius: BorderRadius.circular(4),
                      //             boxShadow: [
                      //               BoxShadow(
                      //                 color: (hasError
                      //                         ? Colors.red[400]!
                      //                         : currentStep == 5
                      //                         ? Colors.green[400]!
                      //                         : Colors.blue[400]!)
                      //                     .withOpacity(0.4),
                      //                 blurRadius: 4,
                      //                 offset: const Offset(0, 2),
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //       );
                      //     },
                      //   ),
                      // ),
                    ],
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
