import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/features/platform_admin/presentation/platform_admin_section.dart';

/// Menu principal da governança: cada cartão abre um painel dedicado (`?v=`).
class GovernanceHub extends StatelessWidget {
  const GovernanceHub({super.key});

  void _go(BuildContext context, String panel) {
    final v = Uri.encodeQueryComponent(panel);
    context.go('$kPlatformAdminGovernancaPath?v=$v');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 960 ? 3 : (w >= 560 ? 2 : 1);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols == 1 ? 2.9 : 1.45,
          children: [
            _card(
              context,
              title: 'Funil comercial',
              subtitle: 'Page views da landing, pré-cadastro e leads internos.',
              icon: Icons.insights_rounded,
              panel: 'funil',
            ),
            _card(
              context,
              title: 'Pré-cadastro empresas',
              subtitle: 'Entrada leve sem escritório (antes do perfil completo).',
              icon: Icons.storefront_outlined,
              panel: 'precadastro_empresas',
            ),
            _card(
              context,
              title: 'Pré-cadastro escritórios',
              subtitle: 'Escritório só em modo entrada leve / sandbox.',
              icon: Icons.account_balance_outlined,
              panel: 'precadastro_escritorios',
            ),
            _card(
              context,
              title: 'Cadastro completo',
              subtitle: 'Empresas e escritórios após onboarding real (Passo C).',
              icon: Icons.verified_outlined,
              panel: 'cadastro_completo',
            ),
            _card(
              context,
              title: 'Demos públicos',
              subtitle: 'Contagens agregadas de acesso ao demo (IP só deduplica).',
              icon: Icons.ondemand_video_rounded,
              panel: 'demo',
            ),
            _card(
              context,
              title: 'Links de campanha',
              subtitle: 'URLs com origem fixa para testes A/B e anúncios.',
              icon: Icons.link_rounded,
              panel: 'links',
            ),
            _card(
              context,
              title: 'E-mail em massa',
              subtitle: 'Reunir e-mails da base, excluir destinatários e enviar texto simples.',
              icon: Icons.mark_email_unread_outlined,
              panel: 'email_massa',
            ),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String panel,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _go(context, panel),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppBrandColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: AppBrandColors.ink),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppBrandColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppBrandColors.softText,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
