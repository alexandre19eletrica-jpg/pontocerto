import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/app_update/app_update_launcher.dart';
import 'package:pontocerto/core/company/empresa_cache.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';

class PaginaInicio extends ConsumerWidget {
  const PaginaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nomeEmpresa = ref.watch(nomeEmpresaCacheProvider);
    final tema = Theme.of(context);
    final acessoFuncionarioNaWeb = !isWebPlatform;

    return Scaffold(
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
          children: [
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const HeroBanner(
                  tag: 'PAINEL PRINCIPAL',
                  title:
                      'Escritorio e empresa em um fluxo mais claro e direto.',
                  subtitle:
                      'O escritorio contabil entra primeiro, organiza o acesso inicial e depois cadastra as empresas da carteira no mesmo ambiente.',
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Center(child: BrandLogo(size: 110, radius: 28)),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ponto Certo',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppBrandColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Operacao administrativa, fiscal e comercial com entrada inicial do escritorio contabil e cadastro da empresa feito depois, por ele.',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: AppBrandColors.softText,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          HighlightChip(
                            label: 'Ponto inteligente',
                            icon: Icons.punch_clock_rounded,
                          ),
                          HighlightChip(
                            label: 'Equipe conectada',
                            icon: Icons.groups_rounded,
                          ),
                          HighlightChip(
                            label: 'Gestao financeira',
                            icon: Icons.auto_graph_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        readOnly: true,
                        initialValue: nomeEmpresa?.isNotEmpty == true
                            ? nomeEmpresa
                            : 'Empresa ainda nao cadastrada',
                        decoration: const InputDecoration(
                          labelText: 'Nome fantasia da empresa',
                          prefixIcon: Icon(Icons.business_center_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/login-empresa'),
                        icon: const Icon(Icons.apartment_rounded),
                        label: const Text('Entrar como Empresa'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/login-contador'),
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Entrar como Contador'),
                      ),
                      const SizedBox(height: 10),
                      if (acessoFuncionarioNaWeb)
                        OutlinedButton.icon(
                          onPressed: () => context.go('/login-funcionario'),
                          icon: const Icon(Icons.badge_rounded),
                          label: const Text('Entrar como Funcionario'),
                        ),
                      if (!acessoFuncionarioNaWeb)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD6E4FF)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No navegador, o acesso de funcionario permanece exclusivo do app da Play Store.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          metaFbqTrackStartTrialEscritorio();
                          context.go('/cadastro-escritorio-contabil');
                        },
                        child: const Text(
                          'Cadastrar escritorio de contabilidade',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isWebPlatform)
                        OutlinedButton.icon(
                          onPressed: () => _abrirAtualizacaoApp(context),
                          icon: const Icon(Icons.system_update_alt_rounded),
                          label: const Text('Atualizar app'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xD9FFFFFF),
                    border: Border.all(color: const Color(0xFFD6E4FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [AppBrandColors.gold, Color(0xFFFFE394)],
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppBrandColors.primaryDeep,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Entrada principal com foco em escritorio contabil, clareza operacional e cadastro da empresa feito depois pelo proprio escritorio.',
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: AppBrandColors.ink,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirAtualizacaoApp(BuildContext context) async {
    final abriu = await AppUpdateLauncher.open();
    if (!abriu && context.mounted) {
      context.showUserError('Nao foi possivel abrir a atualizacao do app.');
    }
  }
}
