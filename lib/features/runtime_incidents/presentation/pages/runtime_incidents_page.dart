import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/bytes_download.dart';
import 'package:pontocerto/core/utils/text_download.dart';
import 'package:pontocerto/features/runtime_incidents/domain/runtime_incident.dart';
import 'package:pontocerto/features/runtime_incidents/domain/system_issue.dart';
import 'package:pontocerto/features/runtime_incidents/presentation/runtime_incidents_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class RuntimeIncidentsPage extends ConsumerWidget {
  const RuntimeIncidentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final canAccess = session != null &&
        (session.role == Role.owner ||
            session.role == Role.manager ||
            session.role == Role.accountant);
    if (!canAccess) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(body: Center(child: Text('Acesso negado.')));
    }

    final incidentsAsync = ref.watch(runtimeIncidentsProvider);
    final issuesAsync = ref.watch(systemIssuesProvider);

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Incidentes do sistema',
        subtitle:
            'Cada registro e criado quando o app captura excecao; operacao estavel nao gera trilha. Colecao runtime_incidents por companyId.',
        chips: [
          AppHeaderChip('Seguranca operacional'),
          AppHeaderChip('Sem auto correcao irrestrita'),
        ],
      ),
    );
    return AppGradientBackground(
      child: AppPageLayout(
        child: incidentsAsync.when(
          data: (items) => issuesAsync.when(
            data: (issues) => _RuntimeIncidentsBody(
              items: items,
              issues: issues,
              session: session!,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Falha ao carregar problemas: $error'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Falha ao carregar incidentes: $error'),
          ),
        ),
      ),
    );
  }
}

class _RuntimeIncidentsBody extends ConsumerWidget {
  const _RuntimeIncidentsBody({
    required this.items,
    required this.issues,
    required this.session,
  });

  final List<RuntimeIncident> items;
  final List<SystemIssue> issues;
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openCount = items.where((e) => e.status == 'open').length;
    final resolvedCount = items.where((e) => e.status == 'resolved').length;
    final ignoredCount = items.where((e) => e.status == 'ignored').length;
    final trackedIssues = issues.where((e) => e.status != 'resolved').length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppWorkspaceCard(
          title: 'Panorama',
          subtitle:
              'Base para monitorar erros do app e preparar resposta assistida por IA com revisao humana.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: items.where((e) => e.status == 'open').isEmpty
                    ? null
                    : () => _cleanupOpenIncidents(context, ref),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Limpar abertos'),
              ),
              FilledButton.icon(
                onPressed: () => _exportSnapshot(context, ref),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Exportar snapshot'),
              ),
            ],
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              AppMetricCard(
                label: 'Em aberto',
                value: '$openCount',
                caption: 'Incidentes aguardando triagem',
              ),
              AppMetricCard(
                label: 'Resolvidos',
                value: '$resolvedCount',
                caption: 'Marcados manualmente como resolvidos',
              ),
              AppMetricCard(
                label: 'Ignorados',
                value: '$ignoredCount',
                caption: 'Ruido ou evento sem acao',
              ),
              AppMetricCard(
                label: 'Problemas ativos',
                value: '$trackedIssues',
                caption: 'Falhas confirmadas em acompanhamento',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppWorkspaceCard(
          title: 'Problemas confirmados',
          subtitle:
              'Registro persistente dos bugs e falhas conhecidas para acompanhar ate a resolucao definitiva.',
          child: Column(
            children: [
              if (issues.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nenhum problema consolidado ainda.'),
                )
              else
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IssueTile(issue: issue),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppWorkspaceCard(
          title: 'Fila de incidentes',
          subtitle:
              'Eventos recentes capturados pelo app. Owner e gerente podem classificar sem apagar historico.',
          child: Column(
            children: [
              if (items.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nenhum incidente ainda. Linhas aparecem após erros de rede, APIs ou excecoes de UI; '
                    'saida limpa (sem falhas) nao gera trilha. Use a exportacao acima se precisar de snapshot vazio para conferencia.',
                  ),
                )
              else
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IncidentTile(item: item),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _cleanupOpenIncidents(
  BuildContext context,
  WidgetRef ref,
) async {
  final shouldProceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Limpar incidentes em aberto'),
      content: const Text(
        'Isso vai marcar como resolvidos e apagar os incidentes atualmente em aberto da sua empresa suprema. Deseja continuar?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );

  if (shouldProceed != true || !context.mounted) return;

  final session = ref.read(sessionProvider);
  if (session == null) return;

  final actions = ref.read(runtimeIncidentsActionsProvider);
  try {
    final result = await actions.cleanupOpenIncidents(companyId: session.companyId);
    if (!context.mounted) return;
    context.showUserMessage(
      'Incidentes limpos: ${result.deletedCount}. Resumo encontrado: ${result.summary}.',
    );
  } catch (error) {
    if (!context.mounted) return;
    context.showUserError('Falha ao limpar incidentes: $error');
  }
}

Future<void> _exportSnapshot(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(sessionProvider);
  if (session == null) return;

  final actions = ref.read(runtimeIncidentsActionsProvider);
  try {
    final result = await actions.exportSnapshot(companyId: session.companyId);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.88,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Snapshot de observabilidade',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ExportContentView(content: result.textContent),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: result.textContent),
                        );
                        if (!sheetContext.mounted) return;
                        if (sheetContext.mounted) { sheetContext.showUserMessage('Texto copiado.'); }
                      },
                      child: const Text('Copiar texto'),
                    ),
                    FilledButton.tonal(
                      onPressed: result.textContent.trim().isEmpty
                          ? null
                          : () async {
                              await _downloadExportContent(
                                sheetContext,
                                filename:
                                    'observabilidade_${session.companyId}_${_timestampForFilename()}.txt',
                                content: result.textContent,
                                mimeType: 'text/plain;charset=utf-8',
                                successMessage:
                                    'Texto preparado para download.',
                              );
                            },
                      child: const Text('Baixar texto'),
                    ),
                    FilledButton.tonal(
                      onPressed: result.pdfBytes == null
                          ? null
                          : () async {
                              await _downloadPdfExport(
                                sheetContext,
                                filename:
                                    'observabilidade_${session.companyId}_${_timestampForFilename()}.pdf',
                                bytes: result.pdfBytes!,
                              );
                            },
                      child: const Text('Baixar PDF'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    context.showUserError('Falha ao exportar observabilidade: $error');
  }
}

Future<void> _downloadExportContent(
  BuildContext context, {
  required String filename,
  required String content,
  required String mimeType,
  required String successMessage,
}) async {
  try {
    await saveTextFile(
      filename: filename,
      content: content,
      mimeType: mimeType,
    );
    if (!context.mounted) return;
    context.showUserSuccess(successMessage);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    context.showUserError(
      'O navegador bloqueou o download. O conteudo foi copiado para a area de transferencia.',
    );
  }
}

Future<void> _downloadPdfExport(
  BuildContext context, {
  required String filename,
  required Uint8List bytes,
}) async {
  try {
    await saveBytesFile(
      filename: filename,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
    if (!context.mounted) return;
    if (context.mounted) { context.showUserMessage('PDF preparado para download.'); }
  } catch (_) {
    if (!context.mounted) return;
    context.showUserError('O navegador bloqueou o download do PDF.');
  }
}

String _timestampForFilename() {
  final now = DateTime.now();
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return '$year$month${day}_$hour$minute';
}

class _ExportContentView extends StatelessWidget {
  const _ExportContentView({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content.isEmpty ? 'Nenhum conteudo retornado.' : content,
          style: const TextStyle(
            color: AppBrandColors.softText,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _IncidentTile extends ConsumerWidget {
  const _IncidentTile({required this.item});

  final RuntimeIncident item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(runtimeIncidentsActionsProvider);
    final color = switch (item.severity) {
      'critical' => const Color(0xFFB91C1C),
      'warning' => const Color(0xFFD97706),
      _ => AppBrandColors.primary,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(item.statusLabel),
              _chip(item.source),
              _chip(item.category),
              _chip(item.reporterRole),
              if (item.occurrenceCount > 1) _chip('Ocorrencias ${item.occurrenceCount}'),
              if (item.screenLabel.isNotEmpty) _chip(item.screenLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Reporter: ${item.reporterName} | Severidade: ${item.severity}',
            style: const TextStyle(color: AppBrandColors.softText),
          ),
          if (item.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Capturado em ${_formatDateTime(item.createdAt!)}',
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
          if (item.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Observacao: ${item.resolutionNote}',
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
          if (item.assistantSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppBrandColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analise assistida',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.assistantSummary,
                    style: const TextStyle(color: AppBrandColors.softText),
                  ),
                  if (item.recommendedAction.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Acao recomendada: ${item.recommendedAction}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (item.recommendedActionType.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tipo: ${item.recommendedActionType}',
                      style: const TextStyle(color: AppBrandColors.softText),
                    ),
                  ],
                  if (item.autoFixStatus.isNotEmpty || item.autoFixAttempts > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Auto fix: ${item.autoFixStatus.isEmpty ? 'nao executado' : item.autoFixStatus} | tentativas: ${item.autoFixAttempts}',
                      style: const TextStyle(color: AppBrandColors.softText),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (item.stackTrace.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              item.stackTrace,
              style: const TextStyle(
                fontSize: 12,
                color: AppBrandColors.softText,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: item.status == 'resolved'
                    ? null
                    : () => _updateStatus(
                          context,
                          () => actions.updateStatus(
                            incidentId: item.id,
                            status: 'resolved',
                          ),
                        ),
                child: const Text('Marcar resolvido'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: item.status == 'ignored'
                    ? null
                    : () => _updateStatus(
                          context,
                          () => actions.updateStatus(
                            incidentId: item.id,
                            status: 'ignored',
                          ),
                        ),
                child: const Text('Ignorar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _updateStatus(
                  context,
                  () => actions.analyze(item.id),
                  successMessage: 'Incidente analisado.',
                ),
                child: Text(
                  item.assistantSummary.isEmpty ? 'Analisar' : 'Reanalisar',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: !item.autoFixEligible
                    ? null
                    : () => _updateStatus(
                          context,
                          () => actions.executeSafeAction(item.id),
                          successMessage: 'Correcao segura executada.',
                        ),
                child: const Text('Executar correcao segura'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _updateStatus(
                  context,
                  () => actions.promoteToIssue(item.id),
                  successMessage: 'Problema salvo para acompanhamento.',
                ),
                child: const Text('Salvar como problema'),
              ),
              const Spacer(),
              Icon(Icons.sensors_outlined, color: color),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    Future<void> Function() action, {
    String successMessage = 'Incidente atualizado.',
  }) async {
    try {
      await action();
      if (!context.mounted) return;
      context.showUserSuccess(successMessage);
    } catch (error) {
      if (!context.mounted) return;
      context.showUserError('Falha ao atualizar incidente: $error');
    }
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppBrandColors.softText,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _IssueTile extends ConsumerWidget {
  const _IssueTile({required this.issue});

  final SystemIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(runtimeIncidentsActionsProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _issueChip(issue.statusLabel),
              _issueChip(issue.fixStatusLabel),
              _issueChip(issue.module.isEmpty ? 'runtime' : issue.module),
              _issueChip('Ocorrencias ${issue.occurrenceCount}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (issue.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              issue.description,
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
          if (issue.assistantSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              issue.assistantSummary,
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
          if (issue.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Acao recomendada: ${issue.recommendedAction}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: issue.status == 'resolved'
                    ? null
                    : () => _handleIssueAction(
                          context,
                          () => actions.updateIssueStatus(
                            issueId: issue.id,
                            status: 'resolved',
                            fixStatus: 'done',
                          ),
                          'Problema marcado como resolvido.',
                        ),
                child: const Text('Resolver'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: issue.status == 'monitoring'
                    ? null
                    : () => _handleIssueAction(
                          context,
                          () => actions.updateIssueStatus(
                            issueId: issue.id,
                            status: 'monitoring',
                            fixStatus: 'investigating',
                          ),
                          'Problema colocado em monitoramento.',
                        ),
                child: const Text('Monitorar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleIssueAction(
    BuildContext context,
    Future<void> Function() action,
    String message,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      context.showUserSuccess(message);
    } catch (error) {
      if (!context.mounted) return;
      context.showUserError('Falha ao atualizar problema: $error');
    }
  }

  Widget _issueChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppBrandColors.softText,
        ),
      ),
    );
  }
}

extension on RuntimeIncident {
  String get statusLabel {
    switch (status) {
      case 'resolved':
        return 'Resolvido';
      case 'ignored':
        return 'Ignorado';
      default:
        return 'Em aberto';
    }
  }
}

extension on SystemIssue {
  String get statusLabel {
    switch (status) {
      case 'resolved':
        return 'Resolvido';
      case 'monitoring':
        return 'Monitorando';
      default:
        return 'Aberto';
    }
  }

  String get fixStatusLabel {
    switch (fixStatus) {
      case 'done':
        return 'Correcao concluida';
      case 'investigating':
        return 'Investigando';
      default:
        return 'Pendente';
    }
  }
}
