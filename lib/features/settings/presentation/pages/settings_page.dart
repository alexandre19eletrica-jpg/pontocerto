import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/app_update/app_update_provider.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/settings/presentation/settings_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessionProvider);
    final config = ref.watch(settingsProvider);
    final appUpdate = ref.watch(appUpdateSettingsProvider).valueOrNull;
    final versaoAtual = ref.watch(currentAppVersionProvider).valueOrNull ?? '-';
    final canUseSupremeAccess = hasSupremePlatformAccess(sessao);

    if (sessao == null || sessao.role != Role.owner) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(body: Center(child: Text('Acesso negado.')));
    }

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Configuracoes',
        subtitle:
            'Controles gerais da empresa, regras de uso e parametros de atualizacao do aplicativo.',
        chips: [
          AppHeaderChip('Somente dono'),
          AppHeaderChip('Versao $versaoAtual'),
        ],
      ),
    );
    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppWorkspaceCard(
              title: 'Panorama',
              subtitle:
                  'Controles sensiveis do ambiente empresarial, com governanca restrita ao dono da conta.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  const AppMetricCard(
                    label: 'Perfil',
                    value: 'Owner',
                    caption: 'Acesso exclusivo do dono',
                  ),
                  AppMetricCard(
                    label: 'Versao',
                    value: versaoAtual,
                    caption: 'Versao atual do aplicativo',
                  ),
                  AppMetricCard(
                    label: 'Atualizacao',
                    value: appUpdate?.active == true ? 'Ativa' : 'Inativa',
                    caption: 'Regra atual de distribuicao',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Regras operacionais',
              subtitle:
                  'Ajustes de uso diario que impactam ponto, justificativas e sugestoes operacionais.',
              child: Column(
                children: [
                  SwitchListTile(
                    value: config.enableGpsCameraPunch,
                    onChanged: (_) async {
                      try {
                        await ref.read(settingsProvider.notifier).toggleGpsCameraPunch();
                        if (!context.mounted) return;
                        _ok(context, 'Configuracao salva com sucesso.');
                      } catch (_) {
                        if (!context.mounted) return;
                        _ok(context, 'Erro ao salvar configuracao.');
                      }
                    },
                    title: const Text('Ponto com GPS e camera'),
                    subtitle: const Text('Exige localizacao e foto no registro de ponto.'),
                  ),
                  SwitchListTile(
                    value: config.enableEmployeeDebtSuggestion,
                    onChanged: (_) async {
                      try {
                        await ref.read(settingsProvider.notifier).toggleDebtSuggestion();
                        if (!context.mounted) return;
                        _ok(context, 'Configuracao salva com sucesso.');
                      } catch (_) {
                        if (!context.mounted) return;
                        _ok(context, 'Erro ao salvar configuracao.');
                      }
                    },
                    title: const Text('Sugestao de divida para funcionario'),
                    subtitle: const Text('Permite sugestoes de descontos.'),
                  ),
                  SwitchListTile(
                    value: config.enableAttachmentsOnJustification,
                    onChanged: (_) async {
                      try {
                        await ref.read(settingsProvider.notifier).toggleAttachments();
                        if (!context.mounted) return;
                        _ok(context, 'Configuracao salva com sucesso.');
                      } catch (_) {
                        if (!context.mounted) return;
                        _ok(context, 'Erro ao salvar configuracao.');
                      }
                    },
                    title: const Text('Anexos em justificativas'),
                    subtitle: const Text('Permite anexar comprovantes nas justificativas.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Atualizacao do aplicativo',
              subtitle:
                  'Controle de ativacao e exigencia de atualizacao para a base instalada.',
              child: ListTile(
                title: const Text('Atualizacao do aplicativo'),
                subtitle: Text(
                  appUpdate == null || appUpdate.latestVersion.trim().isEmpty
                      ? 'Nenhuma versao configurada.'
                      : 'Ativo: ${appUpdate.active ? 'Sim' : 'Nao'} | '
                          'Versao: ${appUpdate.latestVersion} | '
                          'Forcada: ${appUpdate.force ? 'Sim' : 'Nao'}',
                ),
                trailing: const Icon(Icons.system_update_alt_rounded),
                onTap: () => _abrirDialogoAtualizacao(
                  context,
                  ref,
                  appUpdate,
                  versaoAtual,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (canUseSupremeAccess) ...[
              AppWorkspaceCard(
                title: 'Governanca da plataforma',
                subtitle:
                    'Painel SaaS para acompanhar empresas, planos e aprovacao. Este acesso supremo fica vinculado somente a empresa dona da plataforma.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/platform-admin'),
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('Abrir painel da plataforma'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Observabilidade',
                subtitle:
                    'Fila de incidentes e correcoes seguras da plataforma, visivel somente para a empresa suprema.',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/runtime-incidents'),
                    icon: const Icon(Icons.sensors_outlined),
                    label: const Text('Abrir incidentes do sistema'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _ok(BuildContext context, String msg) {
    if (!context.mounted) return;
    context.showUserMessage(msg);
  }

  Future<void> _abrirDialogoAtualizacao(
    BuildContext context,
    WidgetRef ref,
    AppUpdateSettings? atual,
    String versaoAtual,
  ) async {
    var ativo = atual?.active ?? true;
    var forcar = atual?.force ?? false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Atualizacao do aplicativo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Versao atual do app: $versaoAtual'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Link da ultima atualizacao: '
                    '${(atual?.updateUrl.isNotEmpty == true) ? atual!.updateUrl : 'Play Store padrao'}',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: ativo,
                  onChanged: (v) => setDialogState(() => ativo = v),
                  title: const Text('Atualizacao ativa'),
                  subtitle: const Text('Se desativado, nenhum aviso sera exibido.'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: forcar,
                  onChanged: (v) => setDialogState(() => forcar = v),
                  title: const Text('Atualizacao forcada'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(settingsProvider.notifier).saveAppUpdateSettings(
                        active: ativo,
                        force: forcar,
                      );
                } catch (_) {
                  if (!context.mounted) return;
                  _ok(context, 'Erro ao salvar configuracao de atualizacao.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                _ok(context, 'Configuracao de atualizacao salva.');
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

