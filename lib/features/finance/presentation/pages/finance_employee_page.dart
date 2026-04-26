import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/features/finance/domain/entities/debt.dart';
import 'package:pontocerto/features/finance/domain/entities/movement.dart';
import 'package:pontocerto/features/finance/domain/entities/payment.dart';
import 'package:pontocerto/features/finance/presentation/providers/finance_filters_provider.dart';
import 'package:pontocerto/features/finance/presentation/providers/finance_streams_provider.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_actions_service.dart';
import 'package:pontocerto/features/finance/presentation/utils/money.dart';
import 'package:pontocerto/features/finance/presentation/widgets/finance_summary_cards.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class FinanceEmployeePage extends ConsumerStatefulWidget {
  const FinanceEmployeePage({super.key});

  @override
  ConsumerState<FinanceEmployeePage> createState() => _FinanceEmployeePageState();
}

class _FinanceEmployeePageState extends ConsumerState<FinanceEmployeePage> {
  final _actions = FinanceActionsService();

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final competencia = ref.watch(financeFiltersProvider);
    final paymentsAsync = ref.watch(financePaymentsStreamProvider);
    final debtsAsync = ref.watch(financeDebtsStreamProvider);
    final movementsAsync = ref.watch(financePersonalMovementsProvider);
    final payments = ref.watch(financeVisiblePaymentsProvider);
    final debts = ref.watch(financeVisibleDebtsProvider);
    final movements = ref.watch(financePersonalMovementsProvider).valueOrNull ?? const <FinanceMovement>[];

    final openDebts = debts
        .where((d) => d.status == FinanceDebtStatus.open)
        .fold<int>(0, (sum, d) => sum + d.amountCents);
    final settledDebts = debts
        .where((d) => d.status == FinanceDebtStatus.settled)
        .fold<int>(0, (sum, d) => sum + d.amountCents);

    final pendingPayments = payments
        .where((p) => p.status == FinancePaymentStatus.pending)
        .fold<int>(0, (sum, p) => sum + p.netCents);
    final paidPayments = payments
        .where((p) => p.status == FinancePaymentStatus.paid)
        .fold<int>(0, (sum, p) => sum + p.netCents);
    final confirmedPayments = payments
        .where((p) => p.status == FinancePaymentStatus.confirmed)
        .fold<int>(0, (sum, p) => sum + p.netCents);
    final contestedPayments = payments
        .where((p) => p.status == FinancePaymentStatus.contested)
        .fold<int>(0, (sum, p) => sum + p.netCents);
    final movementReceitas = movements
        .where((m) => m.type == FinanceMovementType.income)
        .fold<int>(0, (sum, m) => sum + m.amountCents);
    final movementGastos = movements
        .where((m) => m.type == FinanceMovementType.expense)
        .fold<int>(0, (sum, m) => sum + m.amountCents);
    final contasReceberTotal = pendingPayments + paidPayments + confirmedPayments + movementReceitas;
    final contasPagarTotal = openDebts + movementGastos;
    final saldoTotal = contasReceberTotal - contasPagarTotal;
    final saldoPositivo = saldoTotal > 0 ? saldoTotal : 0;
    final totalLancamentos = payments.length + debts.length + movements.length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Meu financeiro',
        subtitle:
            'Leitura pessoal de pagamentos, dividas e movimentacoes com foco em competencia, saldo e pendencias.',
        chips: [
          AppHeaderChip(
            'Competencia ${competenceLabel(competencia.year, competencia.month)}',
          ),
          AppHeaderChip('Saldo ${formatCents(saldoTotal)}'),
          AppHeaderChip('Registros $totalLancamentos'),
        ],
      ),
      beforeLogout: [
        IconButton(
          onPressed: () => _openMovementDialog(),
          icon: const Icon(Icons.add_chart_outlined),
          tooltip: 'Novo movimento',
        ),
      ],
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
            children: [
              AppWorkspaceCard(
                title: 'Competencia e resumo',
                subtitle:
                    'Navegue entre competencias e acompanhe rapidamente contas, saldo e contestacoes.',
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppBrandColors.border),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              ref
                                  .read(financeFiltersProvider.notifier)
                                  .goPreviousMonth();
                            },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              competenceLabel(
                                competencia.year,
                                competencia.month,
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              ref
                                  .read(financeFiltersProvider.notifier)
                                  .goNextMonth();
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FinanceSummaryCards(
                      items: [
                        FinanceSummaryItem(
                          title: 'Contas a pagar',
                          value: formatCents(contasPagarTotal),
                        ),
                        FinanceSummaryItem(
                          title: 'Contas a receber',
                          value: formatCents(contasReceberTotal),
                        ),
                        FinanceSummaryItem(
                          title: 'Saldo total',
                          value: formatCents(saldoTotal),
                        ),
                        FinanceSummaryItem(
                          title: 'Resumo positivo',
                          value: formatCents(saldoPositivo),
                        ),
                        FinanceSummaryItem(
                          title: 'Dividas abertas',
                          value: formatCents(openDebts),
                        ),
                        FinanceSummaryItem(
                          title: 'Dividas quitadas',
                          value: formatCents(settledDebts),
                        ),
                        FinanceSummaryItem(
                          title: 'Pagamentos contestados',
                          value: formatCents(contestedPayments),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Meus pagamentos',
                subtitle:
                    'Acompanhe pagamentos por competencia, com acesso rapido para confirmar ou contestar quando aplicavel.',
                child: Column(
                  children: [
                    _buildAsyncState(
                      paymentsAsync,
                      empty: 'Nenhum pagamento nesta competencia.',
                    ),
                    if (payments.isNotEmpty)
                      ...payments.map(
                        (p) => _surface(
                          child: ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(
                              '${formatCents(p.netCents)} - ${_paymentStatusLabel(p.status)}',
                            ),
                            subtitle: Text(
                              'Bruto: ${formatCents(p.grossCents)} | Descontos: ${formatCents(p.discountsCents)}\n'
                              'Competencia: ${p.competenceLabel} | Venc.: ${_formatDate(p.dueDate)}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openPaymentDetail(p),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Minhas dividas e adiantamentos',
                subtitle:
                    'Leitura pessoal de valores em aberto, valores quitados e vencimentos relacionados ao seu historico.',
                child: Column(
                  children: [
                    _buildAsyncState(
                      debtsAsync,
                      empty: 'Nenhuma divida ou adiantamento encontrado.',
                    ),
                    if (debts.isNotEmpty)
                      ...debts.map(
                        (d) => _surface(
                          child: ListTile(
                            leading: Icon(
                              d.type == FinanceDebtType.debt
                                  ? Icons.request_quote_outlined
                                  : Icons.account_balance_wallet_outlined,
                            ),
                            title: Text(
                              '${d.title} - ${formatCents(d.amountCents)}',
                            ),
                            subtitle: Text(
                              'Tipo: ${d.type == FinanceDebtType.debt ? 'Divida' : 'Adiantamento'} | '
                              'Status: ${_debtStatusLabel(d.status)} | Venc.: ${_formatDate(d.dueDate)}',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Meu controle pessoal',
                subtitle:
                    'Registre receitas e gastos particulares ligados ao seu acompanhamento financeiro.',
                trailing: TextButton.icon(
                  onPressed: () => _openMovementDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
                child: Column(
                  children: [
                    _buildAsyncState(
                      movementsAsync,
                      empty: 'Nenhuma movimentacao pessoal.',
                    ),
                    if (movements.isNotEmpty)
                      ...movements.map(
                        (m) => _surface(
                          child: ListTile(
                            leading: Icon(
                              m.type == FinanceMovementType.income
                                  ? Icons.trending_up_outlined
                                  : Icons.trending_down_outlined,
                            ),
                            title: Text(
                              '${m.title} - ${formatCents(m.amountCents)}',
                            ),
                            subtitle: Text(
                              '${m.type == FinanceMovementType.income ? 'Receita' : 'Gasto'} | '
                              '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}\n'
                              'Venc.: ${_formatDate(m.dueDate)} | Status: ${_movementPaymentStatusLabel(m.paymentStatus)}',
                            ),
                            isThreeLine: true,
                            onTap: () => _openMovementDialog(editing: m),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _runAction(
                                () => _actions.deletePersonalMovement(m.id),
                                'Movimentacao removida.',
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildAsyncState<T>(AsyncValue<List<T>> value, {required String empty}) {
    return value.when(
      data: (items) => items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(empty),
              ),
            )
          : const SizedBox.shrink(),
      error: (error, stackTrace) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Sem registro no momento.'),
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: LinearProgressIndicator(),
      ),
    );
  }

  Future<void> _openPaymentDetail(FinancePayment payment) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pagamento ${payment.competenceLabel}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Liquido: ${formatCents(payment.netCents)}'),
              Text('Status: ${_paymentStatusLabel(payment.status)}'),
              if ((payment.contestReason ?? '').isNotEmpty)
                Text('Motivo contestacao: ${payment.contestReason}'),
              const SizedBox(height: 12),
              if (payment.status == FinancePaymentStatus.paid)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _runAction(
                          () => _actions.confirm(payment.id),
                          'Pagamento confirmado com sucesso.',
                        );
                      },
                      child: const Text('Confirmar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _openContestDialog(payment.id);
                      },
                      child: const Text('Contestar'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openContestDialog(String paymentId) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contestar pagamento'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                _msg('Informe o motivo da contestacao.');
                return;
              }
              Navigator.of(context).pop();
              await _runAction(
                () => _actions.contest(paymentId: paymentId, reason: reason),
                'Contestacao enviada com sucesso.',
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _runAction(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      _msg(successMessage);
    } on FinanceActionException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('Nao foi possivel concluir a operacao.');
    }
  }

  Future<void> _openMovementDialog({FinanceMovement? editing}) async {
    final titleController = TextEditingController(text: editing?.title ?? '');
    final valueController = TextEditingController(
      text: editing == null ? '' : (editing.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    final notesController = TextEditingController(text: editing?.notes ?? '');
    var type = editing?.type ?? FinanceMovementType.expense;
    DateTime selectedDate = editing?.date ?? DateTime.now();
    DateTime? selectedDueDate = editing?.dueDate;
    var paymentStatus = editing?.paymentStatus ?? FinanceMovementPaymentStatus.pending;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(editing == null ? 'Nova movimentacao pessoal' : 'Editar movimentacao'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 8),
              DropdownButtonFormField<FinanceMovementType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: FinanceMovementType.expense, child: Text('Gasto')),
                  DropdownMenuItem(value: FinanceMovementType.income, child: Text('Receita')),
                ],
                onChanged: (value) {
                  if (value != null) setStateDialog(() => type = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              const SizedBox(height: 8),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Observacao')),
              const SizedBox(height: 8),
              DropdownButtonFormField<FinanceMovementPaymentStatus>(
                initialValue: paymentStatus,
                decoration: const InputDecoration(labelText: 'Status de pagamento'),
                items: const [
                  DropdownMenuItem(
                    value: FinanceMovementPaymentStatus.pending,
                    child: Text('Pendente'),
                  ),
                  DropdownMenuItem(
                    value: FinanceMovementPaymentStatus.paid,
                    child: Text('Pago'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setStateDialog(() => paymentStatus = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Data: ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setStateDialog(() => selectedDate = picked);
                    },
                    child: const Text('Selecionar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Vencimento: ${_formatDate(selectedDueDate)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDueDate ?? selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setStateDialog(() => selectedDueDate = picked);
                    },
                    child: const Text('Selecionar'),
                  ),
                  if (selectedDueDate != null)
                    TextButton(
                      onPressed: () => setStateDialog(() => selectedDueDate = null),
                      child: const Text('Limpar'),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = _parseCents(valueController.text);
                if (title.isEmpty || amount == null || amount <= 0) {
                  _msg('Preencha os campos corretamente.');
                  return;
                }
                Navigator.of(context).pop();
                if (editing == null) {
                  await _runAction(
                    () => _actions.createPersonalMovement(
                      title: title,
                      type: type == FinanceMovementType.income ? 'INCOME' : 'EXPENSE',
                      amountCents: amount,
                      date: selectedDate,
                      dueDate: selectedDueDate,
                      paymentStatus: paymentStatus == FinanceMovementPaymentStatus.paid ? 'PAID' : 'PENDING',
                      notes: notesController.text.trim(),
                    ),
                    'Movimentacao criada com sucesso.',
                  );
                } else {
                  await _runAction(
                    () => _actions.updatePersonalMovement(
                      movementId: editing.id,
                      title: title,
                      type: type == FinanceMovementType.income ? 'INCOME' : 'EXPENSE',
                      amountCents: amount,
                      date: selectedDate,
                      dueDate: selectedDueDate,
                      paymentStatus: paymentStatus == FinanceMovementPaymentStatus.paid ? 'PAID' : 'PENDING',
                      notes: notesController.text.trim(),
                    ),
                    'Movimentacao atualizada com sucesso.',
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    valueController.dispose();
    notesController.dispose();
  }

  int? _parseCents(String valor) {
    var texto = valor.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (texto.isEmpty) return null;
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    final parsed = double.tryParse(texto);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  String _paymentStatusLabel(FinancePaymentStatus status) {
    return switch (status) {
      FinancePaymentStatus.pending => 'Pendente',
      FinancePaymentStatus.paid => 'Pago',
      FinancePaymentStatus.confirmed => 'Confirmado',
      FinancePaymentStatus.contested => 'Contestado',
      FinancePaymentStatus.canceled => 'Cancelado',
    };
  }

  String _debtStatusLabel(FinanceDebtStatus status) {
    return switch (status) {
      FinanceDebtStatus.open => 'Aberto',
      FinanceDebtStatus.settled => 'Quitado',
      FinanceDebtStatus.canceled => 'Cancelado',
    };
  }

  String _movementPaymentStatusLabel(FinanceMovementPaymentStatus status) {
    return switch (status) {
      FinanceMovementPaymentStatus.pending => 'Pendente',
      FinanceMovementPaymentStatus.paid => 'Pago',
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }
}

