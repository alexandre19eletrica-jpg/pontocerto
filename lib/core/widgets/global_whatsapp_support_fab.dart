import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_whatsapp_button.dart';

/// Botão flutuante WhatsApp para suporte (todas as rotas empilhadas no [MaterialApp.router]).
class GlobalWhatsappSupportFab extends StatelessWidget {
  const GlobalWhatsappSupportFab({super.key});

  /// Texto inicial enviado no `wa.me` (URI encoded).
  static const String mensagemInicialSuporte =
      'Ola, vim pelo Ponto Certo e quero tirar duvidas ou ter informacoes.';

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      end: 16,
      bottom: 16,
      child: SafeArea(
        minimum: EdgeInsets.zero,
        child: Semantics(
          button: true,
          label: 'Suporte pelo WhatsApp',
          child: Tooltip(
            message: 'Suporte e informações no WhatsApp',
            child: Material(
              elevation: 8,
              shape: const CircleBorder(),
              color: kWhatsappBrandGreen,
              clipBehavior: Clip.antiAlias,
              shadowColor: const Color(0x40000000),
              child: InkWell(
                onTap: () => abrirWhatsappVendas(
                  mensagemInicial: mensagemInicialSuporte,
                ),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
