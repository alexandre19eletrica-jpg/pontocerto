import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class BotaoVoltarApp extends StatelessWidget {
  const BotaoVoltarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        final rotaAtual = GoRouterState.of(context).matchedLocation;
        if (rotaAtual == '/home') {
          context.go('/inicio');
          return;
        }

        if (rotaAtual == '/login-empresa' ||
            rotaAtual == '/login-funcionario' ||
            rotaAtual == '/cadastro-empresa' ||
            rotaAtual == '/login') {
          context.go('/inicio');
          return;
        }

        context.go('/home');
      },
    );
  }
}
