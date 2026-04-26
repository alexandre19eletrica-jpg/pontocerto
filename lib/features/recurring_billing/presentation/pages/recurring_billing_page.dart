import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/features/clients/presentation/clients_provider.dart';
import 'package:pontocerto/features/finance/presentation/providers/finance_streams_provider.dart';
import 'package:pontocerto/features/finance/presentation/utils/money.dart';
import 'package:pontocerto/features/fiscal/domain/invoice_customer.dart';
import 'package:pontocerto/features/recurring_billing/domain/recurring_billing_profile.dart';
import 'package:pontocerto/features/recurring_billing/presentation/recurring_billing_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class RecurringBillingPage extends ConsumerStatefulWidget {
  const RecurringBillingPage({super.key});

  @override
  ConsumerState<RecurringBillingPage> createState() =>
      _RecurringBillingPageState();
}

class _RecurringBillingPageState extends ConsumerState<RecurringBillingPage> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final profiles = ref.watch(recurringBillingProvider);
    final activeCount = profiles.where((item) => item.isActive).length;
    final generatedThisMonth = profiles.where((item) {
      final last = item.lastGeneratedAt;
      if (last == null) return false;
      final now = DateTime.now();
      return last.year == now.year && last.month == now.month;
    }).length;
    final overdueCount = profiles.where((item) {
      if (!item.isActive) return false;
      return _dateOnly(item.nextDueDate).isBefore(_dateOnly(DateTime.now()));
    }).length;

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Faturamento recorrente e cobranca',
        subtitle:
            'Camada comercial para recorrencia de servicos, geracao de cobrancas e preparo para automacao fiscal.',
        chips: [
          AppHeaderChip('ERP de servicos'),
          AppHeaderChip('Ligado ao financeiro'),
        ],
      ),
    );
    return AppGradientBackground(
      child: ref.watch(financeCompanyMovementsProvider).when(
        loading: () => AppPageLayout(
          child: ListView(
            children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        error: (error, _) => AppPageLayout(
          child: ListView(
            children: [
              AppWorkspaceCard(
                title: 'Faturamento indisponivel',
                subtitle:
                    'Nao foi possivel carregar as movimentacoes financeiras da empresa.',
                child: Text(
                  error.toString(),
                  style: const TextStyle(color: AppBrandColors.softText),
                ),
              ),
            ],
          ),
        ),
        data: (movements) {
          final faturamentoTotal = movements
              .where((item) => item.type.name == 'income')
              .fold<int>(0, (total, item) => total + item.amountCents);
          final faturamentoRecebido = movements
              .where(
                (item) =>
                    item.type.name == 'income' &&
                    item.paymentStatus.name == 'paid',
              )
              .fold<int>(0, (total, item) => total + item.amountCents);
          final faturamentoEmAberto = faturamentoTotal - faturamentoRecebido;

          return AppPageLayout(
            child: ListView(
              children: [
                AppWorkspaceCard(
                  title: 'Resumo de recorrencias',
                  subtitle:
                      'Base para assinatura mensal, cobranca recorrente e futura automacao nota + contrato.',
                  trailing:
                      session.role == Role.employee || session.role == Role.accountant
                          ? null
                          : TextButton.icon(
                              onPressed: _submitting ? null : _openCreateDialog,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Nova recorrencia'),
                            ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      AppMetricCard(
                        label: 'Faturado',
                        value: formatCents(faturamentoTotal),
                        caption: 'Mesma base do financeiro da empresa',
                      ),
                      AppMetricCard(
                        label: 'Recebido',
                        value: formatCents(faturamentoRecebido),
                        caption: 'Entradas ja baixadas',
                      ),
                      AppMetricCard(
                        label: 'Em aberto',
                        value: formatCents(faturamentoEmAberto),
                        caption: 'Ainda pendente de receber',
                      ),
                      AppMetricCard(
                        label: 'Ativas',
                        value: activeCount.toString(),
                        caption: 'Prontas para cobranca',
                      ),
                      AppMetricCard(
                        label: 'Geradas no mes',
                        value: generatedThisMonth.toString(),
                        caption: 'Movimentos criados',
                      ),
                      AppMetricCard(
                        label: 'Em atraso',
                        value: overdueCount.toString(),
                        caption: 'Recorrencias vencidas',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppWorkspaceCard(
                  title: 'Carteira recorrente',
                  subtitle:
                      'Perfis de faturamento ligados a cliente e valor mensal, trimestral ou anual.',
                  child: profiles.isEmpty
                      ? const Text(
                          'Nenhuma recorrencia cadastrada ainda.',
                          style: TextStyle(color: AppBrandColors.softText),
                        )
                      : Column(
                          children: [
                            for (final profile in profiles) ...[
                              _RecurringProfileTile(
                                profile: profile,
                                readOnly: session.role == Role.accountant,
                                onGenerate: _submitting
                                    ? null
                                    : () => _generateCharge(profile, session),
                                onToggleStatus: _submitting
                                    ? null
                                    : () => _toggleStatus(profile),
                                onEdit: _submitting || session.role == Role.accountant
                                    ? null
                                    : () => _openCreateDialog(
                                          existing: profile,
                                        ),
                                onDelete: _submitting || session.role == Role.accountant
                                    ? null
                                    : () => _confirmDelete(profile),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreateDialog({RecurringBillingProfile? existing}) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final clients = ref.read(clientsProvider);
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final contractController = TextEditingController(
      text: existing?.contractReference ?? '',
    );
    final amountController = TextEditingController(
      text: existing == null ? '' : _formatMoneyInput(existing.amountCents),
    );
    String clientId = existing?.clientId ?? '';
    String clientName = existing?.clientName ?? '';
    var cadence = existing?.cadence ?? RecurringBillingCadence.monthly;
    DateTime nextDueDate = existing?.nextDueDate ?? DateTime.now();
    var autoCreateFiscalDraft = existing?.autoCreateFiscalDraft ?? false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Nova recorrencia' : 'Editar recorrencia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: clientId.isEmpty ? null : clientId,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: [
                      for (final client in clients)
                        DropdownMenuItem<String>(
                          value: client.id,
                          child: Text(_clientLabel(client)),
                        ),
                    ],
                    onChanged: (value) {
                      final selected = _findClient(clients, value);
                      setDialogState(() {
                        clientId = selected?.id ?? '';
                        clientName = selected == null ? '' : _clientLabel(selected);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor em reais',
                      hintText: 'Ex: 720,00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RecurringBillingCadence>(
                    initialValue: cadence,
                    decoration: const InputDecoration(labelText: 'Periodicidade'),
                    items: const [
                      DropdownMenuItem(
                        value: RecurringBillingCadence.monthly,
                        child: Text('Mensal'),
                      ),
                      DropdownMenuItem(
                        value: RecurringBillingCadence.quarterly,
                        child: Text('Trimestral'),
                      ),
                      DropdownMenuItem(
                        value: RecurringBillingCadence.yearly,
                        child: Text('Anual'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => cadence = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Proximo vencimento'),
                    subtitle: Text(_formatDate(nextDueDate)),
                    trailing: IconButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                          initialDate: nextDueDate,
                        );
                        if (picked != null) {
                          setDialogState(() => nextDueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contractController,
                    decoration: const InputDecoration(
                      labelText: 'Referencia de contrato',
                      hintText: 'Opcional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descricao de cobranca',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: autoCreateFiscalDraft,
                    title: const Text('Preparar rascunho fiscal no futuro'),
                    subtitle: const Text(
                      'Mantem a recorrencia pronta para a proxima etapa nota + cobranca.',
                    ),
                    onChanged: (value) {
                      setDialogState(() => autoCreateFiscalDraft = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final amountCents = _parseMoneyToCents(amountController.text);
                  if (title.isEmpty || clientId.isEmpty || amountCents <= 0) {
                    return;
                  }
                  final controller = ref.read(recurringBillingProvider.notifier);
                  if (existing == null) {
                    await controller.add(
                      RecurringBillingProfile(
                        id: 'rb_${DateTime.now().microsecondsSinceEpoch}',
                        companyId: session.companyId,
                        title: title,
                        clientId: clientId,
                        clientName: clientName,
                        amountCents: amountCents,
                        cadence: cadence,
                        nextDueDate: nextDueDate,
                        status: RecurringBillingStatus.active,
                        createdByUserId: session.userId,
                        description: descriptionController.text.trim(),
                        contractReference: contractController.text.trim().isEmpty
                            ? null
                            : contractController.text.trim(),
                        autoCreateFiscalDraft: autoCreateFiscalDraft,
                      ),
                    );
                  } else {
                    await controller.update(
                      existing.copyWith(
                        title: title,
                        clientId: clientId,
                        clientName: clientName,
                        amountCents: amountCents,
                        cadence: cadence,
                        nextDueDate: nextDueDate,
                        description: descriptionController.text.trim(),
                        contractReference: contractController.text.trim(),
                        autoCreateFiscalDraft: autoCreateFiscalDraft,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      contractController.dispose();
      amountController.dispose();
    }
  }

  Future<void> _toggleStatus(RecurringBillingProfile profile) async {
    final next = profile.status == RecurringBillingStatus.active
        ? RecurringBillingStatus.paused
        : RecurringBillingStatus.active;
    await ref.read(recurringBillingProvider.notifier).update(
          profile.copyWith(
            status: next,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _generateCharge(
    RecurringBillingProfile profile,
    Session session,
  ) async {
    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      final movementId = 'fm_${DateTime.now().microsecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('finance_movements')
          .doc(movementId)
          .set({
            'companyId': session.companyId,
            'ownerUserId': '__COMPANY__',
            'title': profile.title,
            'category': 'FATURAMENTO_RECORRENTE',
            'type': 'INCOME',
            'amountCents': profile.amountCents,
            'date': Timestamp.fromDate(now),
            'dueDate': Timestamp.fromDate(profile.nextDueDate),
            'paymentStatus': 'PENDING',
            'notes':
                'Cobranca recorrente para ${profile.clientName}${(profile.contractReference ?? '').isEmpty ? '' : ' | Contrato: ${profile.contractReference}'}',
            'sourceModule': 'recurring_billing',
            'sourceCustomerId': profile.clientId,
            'sourceCustomerName': profile.clientName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      await ref.read(recurringBillingProvider.notifier).update(
            profile.copyWith(
              lastGeneratedAt: now,
              lastGeneratedMovementId: movementId,
              lastGeneratedPeriodKey: _periodKey(now),
              nextDueDate: _advanceDate(profile.nextDueDate, profile.cadence),
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      context.showUserSuccess(
        'Cobranca gerada no financeiro para ${profile.clientName}.',
      );
    } catch (_) {
      if (!mounted) return;
      context.showUserError(
        'Nao foi possivel gerar a cobranca no financeiro com este perfil.',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _confirmDelete(RecurringBillingProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir recorrencia'),
        content: Text(
          'Deseja excluir o faturamento recorrente "${profile.title}"? Essa acao remove o perfil recorrente, sem apagar cobrancas ja geradas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recurringBillingProvider.notifier).remove(profile);
    if (!mounted) return;
    if (context.mounted) { context.showUserMessage('Recorrencia excluida.'); }
  }

  InvoiceCustomer? _findClient(List<InvoiceCustomer> clients, String? id) {
    for (final client in clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  String _clientLabel(InvoiceCustomer client) {
    return client.legalName.isNotEmpty ? client.legalName : client.tradeName;
  }

  int _parseMoneyToCents(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.').trim();
    final value = double.tryParse(normalized);
    if (value == null) return 0;
    return (value * 100).round();
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  String _formatMoneyInput(int cents) {
    final raw = (cents / 100).toStringAsFixed(2);
    return raw.replaceAll('.', ',');
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _periodKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  DateTime _advanceDate(
    DateTime value,
    RecurringBillingCadence cadence,
  ) {
    return switch (cadence) {
      RecurringBillingCadence.monthly => DateTime(
        value.year,
        value.month + 1,
        value.day,
      ),
      RecurringBillingCadence.quarterly => DateTime(
        value.year,
        value.month + 3,
        value.day,
      ),
      RecurringBillingCadence.yearly => DateTime(
        value.year + 1,
        value.month,
        value.day,
      ),
    };
  }
}

class _RecurringProfileTile extends StatelessWidget {
  const _RecurringProfileTile({
    required this.profile,
    required this.readOnly,
    required this.onGenerate,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  final RecurringBillingProfile profile;
  final bool readOnly;
  final VoidCallback? onGenerate;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = profile.status == RecurringBillingStatus.active
        ? AppBrandColors.accent
        : AppBrandColors.softText;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppBrandColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  profile.status == RecurringBillingStatus.active
                      ? 'Ativa'
                      : 'Pausada',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.clientName} | ${formatCents(profile.amountCents)} | ${_cadenceLabel(profile.cadence)}',
            style: const TextStyle(color: AppBrandColors.softText),
          ),
          const SizedBox(height: 6),
          Text(
            'Proximo vencimento: ${_formatDate(profile.nextDueDate)}',
            style: const TextStyle(color: AppBrandColors.softText),
          ),
          const SizedBox(height: 6),
          Text(
            _dueStatusLabel(profile),
            style: TextStyle(
              color: _dueStatusColor(profile),
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((profile.contractReference ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Contrato: ${profile.contractReference}',
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
          if ((profile.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              profile.description!,
              style: const TextStyle(color: AppBrandColors.ink),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: readOnly ? null : onToggleStatus,
                icon: const Icon(Icons.pause_circle_outline),
                label: Text(
                  profile.status == RecurringBillingStatus.active
                      ? 'Pausar'
                      : 'Reativar',
                ),
              ),
              ElevatedButton.icon(
                onPressed:
                    readOnly || profile.status != RecurringBillingStatus.active
                    ? null
                    : onGenerate,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Gerar cobranca'),
              ),
              OutlinedButton.icon(
                onPressed: readOnly ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              TextButton.icon(
                onPressed: readOnly ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir'),
              ),
            ],
          ),
          if (profile.lastGeneratedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Ultima geracao: ${_formatDate(profile.lastGeneratedAt!)}',
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
        ],
      ),
    );
  }

  String _cadenceLabel(RecurringBillingCadence cadence) {
    return switch (cadence) {
      RecurringBillingCadence.monthly => 'Mensal',
      RecurringBillingCadence.quarterly => 'Trimestral',
      RecurringBillingCadence.yearly => 'Anual',
    };
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  String _dueStatusLabel(RecurringBillingProfile profile) {
    if (!profile.isActive) {
      return 'Recorrencia pausada';
    }
    final today = DateTime.now();
    final dueDate = DateTime(
      profile.nextDueDate.year,
      profile.nextDueDate.month,
      profile.nextDueDate.day,
    );
    final diff = dueDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (diff < 0) {
      return 'Vencida ha ${diff.abs()} dia(s)';
    }
    if (diff == 0) {
      return 'Vence hoje';
    }
    if (diff <= 7) {
      return 'Vence em $diff dia(s)';
    }
    return 'Em dia';
  }

  Color _dueStatusColor(RecurringBillingProfile profile) {
    if (!profile.isActive) {
      return AppBrandColors.softText;
    }
    final today = DateTime.now();
    final dueDate = DateTime(
      profile.nextDueDate.year,
      profile.nextDueDate.month,
      profile.nextDueDate.day,
    );
    final diff = dueDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (diff < 0) {
      return const Color(0xFFB42318);
    }
    if (diff <= 7) {
      return const Color(0xFFB54708);
    }
    return AppBrandColors.accent;
  }
}
