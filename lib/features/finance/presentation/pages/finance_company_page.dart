import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_runtime_summary_provider.dart';
import 'package:pontocerto/core/privacy/presentation_money_mask_provider.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/finance/domain/entities/debt.dart';
import 'package:pontocerto/features/finance/domain/entities/movement.dart';
import 'package:pontocerto/features/finance/domain/entities/payment.dart';
import 'package:pontocerto/features/finance/presentation/providers/finance_filters_provider.dart';
import 'package:pontocerto/features/finance/presentation/providers/finance_streams_provider.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_actions_service.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_cleanup_service.dart';
import 'package:pontocerto/features/finance/presentation/utils/money.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class FinanceCompanyPage extends ConsumerStatefulWidget {
  const FinanceCompanyPage({super.key});

  @override
  ConsumerState<FinanceCompanyPage> createState() => _FinanceCompanyPageState();
}

class _FinanceCompanyPageState extends ConsumerState<FinanceCompanyPage> {
  final _actions = FinanceActionsService();
  final _cleanup = FinanceCleanupService();
  _FinanceManagerPermissions? _managerPermissionsCache;
  bool _requireOwnerApprovalForCleanup = false;
  String Function(int) _formatMoneyCents = formatCents;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }
    final runtimeSummary = ref.watch(companyRuntimeSummaryProvider).valueOrNull;
    final summaryFinance =
        (runtimeSummary?['finance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final hideMoney = ref.watch(presentationMoneyMaskProvider);
        _formatMoneyCents = (c) => hideMoney ? r'R$ ••••' : formatCents(c);
        final companySettings = snapshot.data?.data() ?? <String, dynamic>{};
        final financeSettings = _FinanceModuleSettings.fromSettings(
          companySettings,
        );
        final managerPermissions = _FinanceManagerPermissions.fromSettings(
          companySettings,
        );
        final accountantPermissions = _FinanceAccountantPermissions.fromSettings(
          companySettings,
        );
        _managerPermissionsCache = managerPermissions;
        _requireOwnerApprovalForCleanup =
            companySettings['financeRequireOwnerApprovalForCleanup'] as bool? ??
            false;
        final isOwner = sessao.role == Role.owner;
        final isAccountant = sessao.role == Role.accountant;
        final canConfigureModule = isOwner;
        final canReadFinance = !isAccountant || accountantPermissions.allowFinanceRead;
        final canCreatePayments =
            isOwner || managerPermissions.allowCreatePayments;
        final canManageDebts = isOwner || managerPermissions.allowManageDebts;
        final canManageMovements =
            isOwner || managerPermissions.allowManageCompanyMovements;
        final canRunCleanup = isOwner || managerPermissions.allowFinanceCleanup;

        final competencia = ref.watch(financeFiltersProvider);
        final employees = ref
            .watch(employeesProvider)
            .where((e) => e.ativo && e.isOperationalTeam)
            .toList();
        final employeeNameById = <String, String>{
          for (final e in employees) e.id: e.nome,
        };
        final selectedEmployee = ref.watch(financeSelectedEmployeeProvider);
        final paymentsAsync = ref.watch(financePaymentsStreamProvider);
        final debtsAsync = ref.watch(financeDebtsStreamProvider);
        final movementsAsync = ref.watch(financeCompanyMovementsProvider);
        final payments = ref.watch(financeVisiblePaymentsProvider);
        final debts = ref.watch(financeVisibleDebtsProvider);
        final movements =
            ref.watch(financeCompanyMovementsProvider).valueOrNull ??
            const <FinanceMovement>[];

        int summaryCents(String key, int fallback) {
          final value = summaryFinance[key];
          if (value is num) return value.toInt();
          return fallback;
        }

        if (!canReadFinance) {
          ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
          return const Center(
            child: Text(
              'O contador desta empresa esta sem liberacao para consultar o financeiro.',
            ),
          );
        }

        if (selectedEmployee != null &&
            !employees.any((e) => e.id == selectedEmployee)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(financeSelectedEmployeeProvider.notifier).state = null;
          });
        }

        final payrollPending = summaryCents(
          'pendingPayrollCents',
          payments
            .where((p) => p.status == FinancePaymentStatus.pending)
            .fold<int>(0, (total, p) => total + p.netCents),
        );
        final payrollPaid = summaryCents(
          'paidPayrollCents',
          payments
            .where((p) => p.status == FinancePaymentStatus.paid)
            .fold<int>(0, (total, p) => total + p.netCents),
        );
        final payrollConfirmed = summaryCents(
          'confirmedPayrollCents',
          payments
            .where((p) => p.status == FinancePaymentStatus.confirmed)
            .fold<int>(0, (total, p) => total + p.netCents),
        );
        final employeeReceivables = summaryCents(
          'openDebtsCents',
          debts
            .where(
              (d) =>
                  d.status == FinanceDebtStatus.open &&
                  d.type == FinanceDebtType.debt,
            )
            .fold<int>(0, (total, d) => total + d.amountCents),
        );
        final employeeReceivablesSettled = summaryCents(
          'settledDebtsCents',
          debts
            .where(
              (d) =>
                  d.status == FinanceDebtStatus.settled &&
                  d.type == FinanceDebtType.debt,
            )
            .fold<int>(0, (total, d) => total + d.amountCents),
        );
        final employeeAdvances = summaryCents(
          'openAdvancesCents',
          debts
            .where(
              (d) =>
                  d.status == FinanceDebtStatus.open &&
                  d.type == FinanceDebtType.advance,
            )
            .fold<int>(0, (total, d) => total + d.amountCents),
        );
        final employeeAdvancesSettled = summaryCents(
          'settledAdvancesCents',
          debts
            .where(
              (d) =>
                  d.status == FinanceDebtStatus.settled &&
                  d.type == FinanceDebtType.advance,
            )
            .fold<int>(0, (total, d) => total + d.amountCents),
        );
        final companyReceivables = summaryCents(
          'companyReceivablesCents',
          movements
            .where(
              (m) =>
                  m.type == FinanceMovementType.income &&
                  m.sourceModule != 'payments' &&
                  m.sourceModule != 'debts',
            )
            .fold<int>(0, (total, m) => total + m.amountCents),
        );
        final companyReceivablesReceived = summaryCents(
          'companyReceivablesReceivedCents',
          movements
            .where(
              (m) =>
                  m.type == FinanceMovementType.income &&
                  m.sourceModule != 'payments' &&
                  m.sourceModule != 'debts' &&
                  m.paymentStatus == FinanceMovementPaymentStatus.paid,
            )
            .fold<int>(0, (total, m) => total + m.amountCents),
        );
        final companyPayables = summaryCents(
          'companyPayablesCents',
          movements
            .where(
              (m) =>
                  m.type == FinanceMovementType.expense &&
                  m.sourceModule != 'payments' &&
                  m.sourceModule != 'debts',
            )
            .fold<int>(0, (total, m) => total + m.amountCents),
        );
        final companyPayablesPaid = summaryCents(
          'companyPayablesPaidCents',
          movements
            .where(
              (m) =>
                  m.type == FinanceMovementType.expense &&
                  m.sourceModule != 'payments' &&
                  m.sourceModule != 'debts' &&
                  m.paymentStatus == FinanceMovementPaymentStatus.paid,
            )
            .fold<int>(0, (total, m) => total + m.amountCents),
        );
        final companyReceivablesPending =
            companyReceivables - companyReceivablesReceived;
        final companyPayablesPending = companyPayables - companyPayablesPaid;
        final payrollCommitted = payrollPaid + payrollConfirmed;
        final contasPagarTotal =
            companyPayablesPending + payrollPending + employeeAdvances;
        final contasReceberTotal =
            companyReceivablesPending + employeeReceivables;
        final saldoTotal = contasReceberTotal - contasPagarTotal;
        final saldoAtual =
            companyReceivablesReceived +
            employeeReceivablesSettled -
            companyPayablesPaid -
            payrollCommitted -
            employeeAdvancesSettled;
        final faturamentoTotal = companyReceivables;
        final hoje = DateTime.now();
        final overduePayments = payments
            .where(
              (p) =>
                  p.status == FinancePaymentStatus.pending &&
                  p.dueDate != null &&
                  p.dueDate!.isBefore(hoje),
            )
            .fold<int>(0, (total, p) => total + p.netCents);
        final overdueDebts = debts
            .where(
              (d) =>
                  d.status == FinanceDebtStatus.open &&
                  d.dueDate != null &&
                  d.dueDate!.isBefore(hoje),
            )
            .fold<int>(0, (total, d) => total + d.amountCents);
        final overdueMovements = movements
            .where(
              (m) =>
                  m.type == FinanceMovementType.expense &&
                  m.sourceModule != 'payments' &&
                  m.sourceModule != 'debts' &&
                  m.paymentStatus == FinanceMovementPaymentStatus.pending &&
                  m.dueDate != null &&
                  m.dueDate!.isBefore(hoje),
            )
            .fold<int>(0, (total, m) => total + m.amountCents);
        final overdueTotal =
            overduePayments + overdueDebts + overdueMovements;
        final dueNext7Days = payments
                .where(
                  (p) =>
                      p.status == FinancePaymentStatus.pending &&
                      p.dueDate != null &&
                      !p.dueDate!.isBefore(hoje) &&
                      p.dueDate!.isBefore(hoje.add(const Duration(days: 8))),
                )
                .fold<int>(0, (total, p) => total + p.netCents) +
            debts
                .where(
                  (d) =>
                      d.status == FinanceDebtStatus.open &&
                      d.dueDate != null &&
                      !d.dueDate!.isBefore(hoje) &&
                      d.dueDate!.isBefore(hoje.add(const Duration(days: 8))),
                )
                .fold<int>(0, (total, d) => total + d.amountCents) +
            movements
                .where(
                  (m) =>
                      m.type == FinanceMovementType.expense &&
                      m.paymentStatus == FinanceMovementPaymentStatus.pending &&
                      m.dueDate != null &&
                      !m.dueDate!.isBefore(hoje) &&
                      m.dueDate!.isBefore(hoje.add(const Duration(days: 8))),
                )
                .fold<int>(0, (total, m) => total + m.amountCents);
        final operatingBalance = companyReceivables - companyPayables;
        final entradasRealizadas =
            companyReceivablesReceived + employeeReceivablesSettled;
        final saidasRealizadas =
            companyPayablesPaid + payrollCommitted + employeeAdvancesSettled;
        final receivableCoverage = contasPagarTotal <= 0
            ? 1.0
            : (contasReceberTotal / contasPagarTotal).clamp(0.0, 9.9);
        final contestedCount = payments
            .where((p) => p.status == FinancePaymentStatus.contested)
            .length;

        ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
          header: AppWorkspaceHeader(
            title: 'Financeiro',
            subtitle:
                'Veja entradas, saidas, contas a pagar, contas a receber e saldo da empresa em um jeito simples.',
            chips: [
              AppHeaderChip(
                'Competencia ${competenceLabel(competencia.year, competencia.month)}',
              ),
              AppHeaderChip('Saldo atual ${_formatMoneyCents(saldoAtual)}'),
              AppHeaderChip('Saldo projetado ${_formatMoneyCents(saldoTotal)}'),
            ],
          ),
          beforeLogout: [
            IconButton(
              onPressed: financeSettings.enableCleanup && canRunCleanup
                  ? _confirmarLimpezaGeral
                  : null,
              icon: const Icon(
                Icons.cleaning_services_outlined,
                color: AppBrandColors.ink,
              ),
              tooltip: 'Limpar registros',
            ),
          ],
        );

        return AppGradientBackground(
            child: AppPageLayout(
              child: ListView(
                  children: [
                    _financeBand(
                      title: 'Resumo financeiro',
                      subtitle: 'Indicadores centrais do periodo.',
                      child: AppHorizontalCardGrid(
                        minItemWidth: 220,
                        maxColumns: 4,
                        children: [
                          _summaryValueCard(
                            title: 'Faturamento',
                            value: _formatMoneyCents(faturamentoTotal),
                            color: const Color(0xFF1D4ED8),
                          ),
                          _summaryValueCard(
                            title: 'Receber',
                            value: _formatMoneyCents(contasReceberTotal),
                            color: const Color(0xFF047857),
                          ),
                          _summaryValueCard(
                            title: 'Pagar',
                            value: _formatMoneyCents(contasPagarTotal),
                            color: const Color(0xFFB91C1C),
                          ),
                          _summaryValueCard(
                            title: 'Saldo',
                            value: _formatMoneyCents(saldoAtual),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeBand(
                      title: 'Configuracao',
                      subtitle: 'Modo e recursos do modulo.',
                      child: AppHorizontalCardGrid(
                        minItemWidth: 200,
                        maxColumns: 4,
                        children: [
                          _settingsOptionCard(
                            title: 'Modo',
                            label: 'Simples',
                            selected: financeSettings.mode == _FinanceMode.simple,
                            onTap: canConfigureModule
                                ? () => _saveFinanceModuleSettings(
                                    sessao,
                                    financeSettings.simplePreset(),
                                  )
                                : null,
                          ),
                          _settingsOptionCard(
                            title: 'Modo',
                            label: 'Completo',
                            selected:
                                financeSettings.mode == _FinanceMode.advanced,
                            onTap: canConfigureModule
                                ? () => _saveFinanceModuleSettings(
                                    sessao,
                                    financeSettings.advancedPreset(),
                                  )
                                : null,
                          ),
                          _featureToggleCard(
                            title: 'Recurso',
                            label: 'Pagamentos',
                            value: financeSettings.enablePayments,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceModuleSettings(
                                    sessao,
                                    financeSettings.copyWith(
                                      enablePayments: value,
                                    ),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Recurso',
                            label: 'Dividas',
                            value: financeSettings.enableDebts,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceModuleSettings(
                                    sessao,
                                    financeSettings.copyWith(enableDebts: value),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Recurso',
                            label: 'Movimentos',
                            value: financeSettings.enableCompanyMovements,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceModuleSettings(
                                    sessao,
                                    financeSettings.copyWith(
                                      enableCompanyMovements: value,
                                    ),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Recurso',
                            label: 'Limpeza',
                            value: financeSettings.enableCleanup,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceModuleSettings(
                                    sessao,
                                    financeSettings.copyWith(enableCleanup: value),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Regra',
                            label: 'Aprovacao do dono',
                            value: _requireOwnerApprovalForCleanup,
                            onChanged: canConfigureModule
                                ? (value) =>
                                    _saveFinanceCleanupApprovalSetting(
                                      sessao,
                                      value,
                                    )
                                : (_) {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeBand(
                      title: 'Permissoes',
                      subtitle: 'Alcada do gerente no financeiro.',
                      child: AppHorizontalCardGrid(
                        minItemWidth: 220,
                        maxColumns: 4,
                        children: [
                          _featureToggleCard(
                            title: 'Gerente',
                            label: 'Criar pagamentos',
                            value: managerPermissions.allowCreatePayments,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceManagerPermissions(
                                    sessao,
                                    managerPermissions.copyWith(
                                      allowCreatePayments: value,
                                    ),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Gerente',
                            label: 'Gerir dividas',
                            value: managerPermissions.allowManageDebts,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceManagerPermissions(
                                    sessao,
                                    managerPermissions.copyWith(
                                      allowManageDebts: value,
                                    ),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Gerente',
                            label: 'Gerir movimentos',
                            value: managerPermissions.allowManageCompanyMovements,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceManagerPermissions(
                                    sessao,
                                    managerPermissions.copyWith(
                                      allowManageCompanyMovements: value,
                                    ),
                                  )
                                : (_) {},
                          ),
                          _featureToggleCard(
                            title: 'Gerente',
                            label: 'Limpeza geral',
                            value: managerPermissions.allowFinanceCleanup,
                            onChanged: canConfigureModule
                                ? (value) => _saveFinanceManagerPermissions(
                                    sessao,
                                    managerPermissions.copyWith(
                                      allowFinanceCleanup: value,
                                    ),
                                  )
                                : (_) {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeBand(
                      title: 'Contexto atual',
                      subtitle: 'Competencia, colaborador e acao rapida.',
                      child: AppHorizontalCardGrid(
                        minItemWidth: 220,
                        maxColumns: 4,
                        children: [
                          _filterPanelCard(
                            competenciaLabel: competenceLabel(
                              competencia.year,
                              competencia.month,
                            ),
                            onPrevious: () {
                              ref
                                  .read(financeFiltersProvider.notifier)
                                  .goPreviousMonth();
                            },
                            onNext: () {
                              ref
                                  .read(financeFiltersProvider.notifier)
                                  .goNextMonth();
                            },
                          ),
                          _employeeFilterCard(
                            selectedEmployee: selectedEmployee,
                            employees: employees,
                            onChanged: (value) {
                              ref
                                  .read(financeSelectedEmployeeProvider.notifier)
                                  .state = value;
                            },
                          ),
                          if ((financeSettings.enablePayments &&
                                  canCreatePayments) ||
                              (financeSettings.enableCompanyMovements &&
                                  canManageMovements))
                            _actionPanelCard(
                              onPressed: () => _openNewEntrySheet(
                                employees,
                                financeSettings: financeSettings,
                                canCreatePayments: canCreatePayments,
                                canManageMovements: canManageMovements,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeStrip(
                      title: 'Tesouraria',
                      subtitle: 'Caixa e pressao imediata do periodo.',
                      child: _buildTreasurySnapshot(
                        operatingBalance: operatingBalance,
                        overdueTotal: overdueTotal,
                        dueNext7Days: dueNext7Days,
                        receivableCoverage: receivableCoverage,
                        contestedCount: contestedCount,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeStrip(
                      title: 'Risco',
                      subtitle: 'Sinais que exigem atencao do gestor.',
                      child: _buildFinanceRiskPanel(
                        overdueTotal: overdueTotal,
                        dueNext7Days: dueNext7Days,
                        receivableCoverage: receivableCoverage,
                        contestedCount: contestedCount,
                        saldoTotal: saldoTotal,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeStrip(
                      title: 'Agenda',
                      subtitle: 'Vencimentos e recebimentos do contexto atual.',
                      child: _buildFinancialAgenda(
                        payments: payments,
                        debts: debts,
                        movements: movements,
                        employeeNameById: employeeNameById,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _financeStrip(
                      title: 'Fluxo',
                      subtitle: 'Entradas, saidas e realizado.',
                      child: _buildCashFlowHighlights(
                        companyReceivablesPending:
                            companyReceivablesPending,
                        companyPayablesPending: companyPayablesPending,
                        employeeReceivables: employeeReceivables,
                        employeeAdvances: employeeAdvances,
                        payrollPending: payrollPending,
                        payrollCommitted: payrollCommitted,
                        entradasRealizadas: entradasRealizadas,
                        saidasRealizadas: saidasRealizadas,
                      ),
                    ),
                    if (financeSettings.enablePayments) ...[
                      const SizedBox(height: 18),
                      _financeStrip(
                        title: 'Pagamentos',
                        subtitle: 'Contas a pagar da operacao.',
                        child: _buildPaymentsSection(
                          paymentsAsync,
                          payments,
                          employeeNameById,
                        ),
                      ),
                    ],
                    if (financeSettings.enableDebts) ...[
                      const SizedBox(height: 18),
                      _financeStrip(
                        title: 'Dividas e adiantamentos',
                        subtitle: 'Obrigacoes e recebiveis com colaboradores.',
                        child: _buildDebtsSection(
                          debtsAsync,
                          debts,
                          employeeNameById,
                          canManageDebts,
                        ),
                      ),
                    ],
                    if (financeSettings.enableCompanyMovements) ...[
                      const SizedBox(height: 18),
                      _financeStrip(
                        title: 'Movimentos da empresa',
                        subtitle: 'Receitas, despesas e caixa do periodo.',
                        child: _buildMovementsSection(
                          movementsAsync,
                          movements,
                          employeeNameById,
                          canManageMovements,
                        ),
                      ),
                    ],
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _summaryValueCard({
    required String title,
    required String value,
    Color? color,
  }) {
    return _financeTile(
      title: title,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: color ?? AppBrandColors.ink,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _settingsOptionCard({
    required String title,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return _financeTile(
      title: title,
      child: _chipOptionCard(
        label: label,
        selected: selected,
        onTap: onTap,
      ),
    );
  }

  Widget _featureToggleCard({
    required String title,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _financeTile(
      title: title,
      child: _featureToggle(
        label: label,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _filterPanelCard({
    required String competenciaLabel,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    return _financeTile(
      title: 'Filtros da competencia',
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppBrandColors.border),
        ),
        child: Row(
          children: [
            IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                'Competencia: $competenciaLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ),
    );
  }

  Widget _employeeFilterCard({
    required String? selectedEmployee,
    required List<Employee> employees,
    required ValueChanged<String?> onChanged,
  }) {
    return _financeTile(
      title: 'Funcionario',
      child: SizedBox(
        height: 64,
        child: DropdownButtonFormField<String?>(
          initialValue: selectedEmployee,
          decoration: const InputDecoration(
            labelText: 'Funcionario (opcional)',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            ...employees.map(
              (e) => DropdownMenuItem<String?>(
                value: e.id,
                child: Text(e.nome),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _financeBand({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E3EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _financeTile({
    required String title,
    required Widget child,
  }) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _actionPanelCard({
    required VoidCallback onPressed,
  }) {
    return _financeTile(
      title: 'Acoes',
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: const Text('Novo lancamento'),
        ),
      ),
    );
  }

  Widget _analysisPanelCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _financeStrip({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E3EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFinancialAgenda({
    required List<FinancePayment> payments,
    required List<FinanceDebt> debts,
    required List<FinanceMovement> movements,
    required Map<String, String> employeeNameById,
  }) {
    final agenda = <_AgendaItem>[
      for (final p in payments)
        if (p.status == FinancePaymentStatus.pending ||
            p.status == FinancePaymentStatus.paid)
          _AgendaItem(
            title: 'Pagamento de ${employeeNameById[p.employeeId] ?? p.employeeId}',
            subtitle: 'Folha e pagamentos',
            amountCents: p.netCents,
            dueDate: p.dueDate,
            kindLabel: 'Pagar',
            kindColor: const Color(0xFFB91C1C),
          ),
      for (final d in debts)
        if (d.status == FinanceDebtStatus.open)
          _AgendaItem(
            title: d.title,
            subtitle: employeeNameById[d.employeeId] ?? d.employeeId,
            amountCents: d.amountCents,
            dueDate: d.dueDate,
            kindLabel: d.type == FinanceDebtType.debt ? 'Receber' : 'Pagar',
            kindColor: d.type == FinanceDebtType.debt
                ? const Color(0xFF047857)
                : const Color(0xFFB91C1C),
          ),
      for (final m in movements)
        _AgendaItem(
          title: m.title,
          subtitle: m.type == FinanceMovementType.income
              ? 'Receita da empresa'
              : 'Despesa da empresa',
          amountCents: m.amountCents,
          dueDate: m.dueDate,
          kindLabel: m.type == FinanceMovementType.income ? 'Receber' : 'Pagar',
          kindColor: m.type == FinanceMovementType.income
              ? const Color(0xFF047857)
              : const Color(0xFFB91C1C),
        ),
    ]..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));

    if (agenda.isEmpty) {
      return const Text('Nenhum vencimento relevante para a competencia atual.');
    }

    return AppHorizontalCardGrid(
      minItemWidth: 220,
      maxColumns: 4,
      children: [
        for (final item in agenda.take(4))
          _financeCompactCard(
            eyebrow: '${item.kindLabel} • ${_formatDate(item.dueDate)}',
            title: _formatMoneyCents(item.amountCents),
            subtitle: '${item.title} • ${item.subtitle}',
            tone: item.kindColor,
          ),
      ],
    );
  }

  Widget _buildCashFlowHighlights({
    required int companyReceivablesPending,
    required int companyPayablesPending,
    required int employeeReceivables,
    required int employeeAdvances,
    required int payrollPending,
    required int payrollCommitted,
    required int entradasRealizadas,
    required int saidasRealizadas,
  }) {
    return AppHorizontalCardGrid(
      minItemWidth: 220,
      maxColumns: 3,
      children: [
        _cashFlowTile(
          title: 'Entradas previstas',
          mainValue: _formatMoneyCents(
            companyReceivablesPending + employeeReceivables,
          ),
          lines: [
            'Empresa: ${_formatMoneyCents(companyReceivablesPending)}',
            'Colaboradores: ${_formatMoneyCents(employeeReceivables)}',
          ],
          color: const Color(0xFF047857),
        ),
        _cashFlowTile(
          title: 'Saidas previstas',
          mainValue: _formatMoneyCents(
            companyPayablesPending + employeeAdvances + payrollPending,
          ),
          lines: [
            'Empresa: ${_formatMoneyCents(companyPayablesPending)}',
            'Adiantamentos: ${_formatMoneyCents(employeeAdvances)}',
            'Folha: ${_formatMoneyCents(payrollPending)}',
          ],
          color: const Color(0xFFB91C1C),
        ),
        _cashFlowTile(
          title: 'Ja realizado',
          mainValue: _formatMoneyCents(entradasRealizadas - saidasRealizadas),
          lines: [
            'Entradas: ${_formatMoneyCents(entradasRealizadas)}',
            'Saidas: ${_formatMoneyCents(saidasRealizadas)}',
            'Folha paga: ${_formatMoneyCents(payrollCommitted)}',
          ],
          color: const Color(0xFF1D4ED8),
        ),
      ],
    );
  }

  Widget _cashFlowTile({
    required String title,
    required String mainValue,
    required List<String> lines,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            mainValue,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: AppBrandColors.softText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(
    AsyncValue<List<FinancePayment>> paymentsAsync,
    List<FinancePayment> payments,
    Map<String, String> employeeNameById,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAsyncState(
          paymentsAsync,
          empty: 'Nenhum pagamento na competencia.',
        ),
        if ((paymentsAsync.valueOrNull?.isNotEmpty ?? false) &&
            payments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Nenhum pagamento para o filtro selecionado.'),
          ),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppHorizontalCardGrid(
            minItemWidth: 260,
            maxColumns: 3,
            children: [
              for (final p in payments)
                _detailEntryCard(
                  eyebrow: 'Pagamento',
                  title: employeeNameById[p.employeeId] ?? p.employeeId,
                  amount: _formatMoneyCents(p.netCents),
                  lines: [
                    'Bruto: ${_formatMoneyCents(p.grossCents)}',
                    'Descontos: ${_formatMoneyCents(p.discountsCents)}',
                    'Status: ${_paymentStatusLabel(p.status)}',
                    'Vencimento: ${_formatDate(p.dueDate)}',
                  ],
                  actions: [
                    if (p.status == FinancePaymentStatus.pending)
                      TextButton(
                        onPressed: () => _runAction(
                          () => _actions.markPaid(p.id),
                          'Pagamento marcado como pago.',
                        ),
                        child: const Text('Marcar pago'),
                      ),
                    if (p.status != FinancePaymentStatus.canceled)
                      TextButton(
                        onPressed: () => _runAction(
                          () => _actions.cancelPayment(p.id),
                          'Pagamento cancelado.',
                        ),
                        child: const Text('Cancelar'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _runAction(
                        () => _actions.deletePayment(p.id),
                        'Pagamento excluido.',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDebtsSection(
    AsyncValue<List<FinanceDebt>> debtsAsync,
    List<FinanceDebt> debts,
    Map<String, String> employeeNameById,
    bool canManageDebts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAsyncState(debtsAsync, empty: 'Nenhuma divida de funcionario.'),
        if (debts.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppHorizontalCardGrid(
            minItemWidth: 260,
            maxColumns: 3,
            children: [
              for (final d in debts)
                _detailEntryCard(
                  eyebrow: d.type == FinanceDebtType.debt
                      ? 'Divida a receber'
                      : 'Adiantamento a pagar',
                  title: employeeNameById[d.employeeId] ?? d.employeeId,
                  amount: _formatMoneyCents(d.amountCents),
                  lines: [
                    'Status: ${_debtStatusLabel(d.status)}',
                    'Vencimento: ${_formatDate(d.dueDate)}',
                  ],
                  actions: [
                    if (d.status == FinanceDebtStatus.open && canManageDebts)
                      TextButton(
                        onPressed: () => _runAction(
                          () => _actions.settleDebt(d.id),
                          'Divida quitada.',
                        ),
                        child: const Text('Quitar'),
                      ),
                    if (d.status != FinanceDebtStatus.canceled &&
                        canManageDebts)
                      TextButton(
                        onPressed: () => _runAction(
                          () => _actions.cancelDebt(d.id),
                          'Divida cancelada.',
                        ),
                        child: const Text('Cancelar'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: canManageDebts
                          ? () => _runAction(
                              () => _actions.deleteDebt(d.id),
                              'Divida excluida.',
                            )
                          : null,
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMovementsSection(
    AsyncValue<List<FinanceMovement>> movementsAsync,
    List<FinanceMovement> movements,
    Map<String, String> employeeNameById,
    bool canManageMovements,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAsyncState(
          movementsAsync,
          empty: 'Nenhum lancamento de clientes/obras.',
        ),
        if (movements.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppHorizontalCardGrid(
            minItemWidth: 280,
            maxColumns: 3,
            children: [
              for (final m in movements)
                _detailEntryCard(
                  eyebrow: m.type == FinanceMovementType.income
                      ? 'Receita'
                      : 'Despesa',
                  title: m.title,
                  amount: _formatMoneyCents(m.amountCents),
                  lines: _movementDetailLines(m, employeeNameById),
                  actions: [
                    if (canManageMovements)
                      TextButton(
                        onPressed: () => _showMovementDialog(editing: m),
                        child: const Text('Editar'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: canManageMovements
                          ? () => _runAction(
                              () => _actions.deleteCompanyMovement(m.id),
                              'Movimentacao removida.',
                            )
                          : null,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _detailEntryCard({
    required String eyebrow,
    required String title,
    required String amount,
    required List<String> lines,
    List<Widget> actions = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: AppBrandColors.softText),
              ),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  String? _movementFiscalSourceLabel(FinanceMovement movement) {
    final invoiceId = movement.sourceInvoiceId?.trim() ?? '';
    if (invoiceId.isEmpty) return null;
    final taskId = movement.sourceTaskId?.trim() ?? '';
    return taskId.isEmpty
        ? 'Fiscal: nota $invoiceId'
        : 'Fiscal: nota $invoiceId | tarefa $taskId';
  }

  List<String> _movementDetailLines(
    FinanceMovement movement,
    Map<String, String> employeeNameById,
  ) {
    final fiscalSource = _movementFiscalSourceLabel(movement);
    return [
      movement.category.trim().isEmpty
          ? 'Categoria: Sem categoria'
          : 'Categoria: ${_movementCategoryLabel(movement.category)}',
      'Origem: ${_movementOwnerLabel(movement.ownerUserId, employeeNameById)}',
      'Data: ${_formatDate(movement.date)}',
      'Vencimento: ${_formatDate(movement.dueDate)}',
      'Status: ${_movementPaymentStatusLabel(movement.paymentStatus)}',
      if (fiscalSource != null) fiscalSource,
    ];
  }

  Widget _buildAsyncState<T>(
    AsyncValue<List<T>> value, {
    required String empty,
  }) {
    return value.when(
      data: (items) => items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(empty),
            )
          : const SizedBox.shrink(),
      error: (error, stackTrace) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('Sem registro no momento.'),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: LinearProgressIndicator(),
      ),
    );
  }

  Future<void> _openNewEntrySheet(
    List<Employee> employees, {
    required _FinanceModuleSettings financeSettings,
    required bool canCreatePayments,
    required bool canManageMovements,
  }) async {
    final tipo = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (financeSettings.enablePayments &&
                canCreatePayments &&
                employees.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Novo pagamento'),
                onTap: () => Navigator.of(context).pop('payment'),
              ),
            if (financeSettings.enableCompanyMovements && canManageMovements)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Receita de cliente/obra'),
                onTap: () => Navigator.of(context).pop('income'),
              ),
            if (financeSettings.enableCompanyMovements && canManageMovements)
              ListTile(
                leading: const Icon(Icons.request_quote_outlined),
                title: const Text('Divida da empresa / conta a pagar'),
                onTap: () => Navigator.of(context).pop('company_debt'),
              ),
            if (financeSettings.enableCompanyMovements && canManageMovements)
              ListTile(
                leading: const Icon(Icons.build_circle_outlined),
                title: const Text('Despesa operacional'),
                onTap: () => Navigator.of(context).pop('operational_expense'),
              ),
            if (financeSettings.enableCompanyMovements && canManageMovements)
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Outro lancamento da empresa'),
                onTap: () => Navigator.of(context).pop('movement'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || tipo == null) return;
    if (tipo == 'payment') {
      await _showCreatePaymentDialog(employees);
    } else if (tipo == 'income') {
      await _showMovementDialog(
        initialType: FinanceMovementType.income,
        initialCategory: 'client_income',
      );
    } else if (tipo == 'company_debt') {
      await _showMovementDialog(
        initialType: FinanceMovementType.expense,
        initialCategory: 'company_debt',
      );
    } else if (tipo == 'operational_expense') {
      await _showMovementDialog(
        initialType: FinanceMovementType.expense,
        initialCategory: 'operational_expense',
      );
    } else {
      await _showMovementDialog();
    }
  }

  Future<void> _showMovementDialog({
    FinanceMovement? editing,
    FinanceMovementType? initialType,
    String? initialCategory,
  }) async {
    final titleController = TextEditingController(text: editing?.title ?? '');
    final valueController = TextEditingController(
      text: editing == null
          ? ''
          : (editing.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    final notesController = TextEditingController(text: editing?.notes ?? '');
    var type = editing?.type ?? initialType ?? FinanceMovementType.expense;
    var category = _normalizeMovementCategory(
      editing?.category ?? initialCategory,
      type,
    );
    DateTime selectedDate = editing?.date ?? DateTime.now();
    DateTime? selectedDueDate = editing?.dueDate;
    var paymentStatus =
        editing?.paymentStatus ?? FinanceMovementPaymentStatus.pending;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            editing == null
                ? 'Novo lancamento da empresa'
                : 'Editar lancamento da empresa',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FinanceMovementType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: FinanceMovementType.expense,
                    child: Text('Gasto'),
                  ),
                  DropdownMenuItem(
                    value: FinanceMovementType.income,
                    child: Text('Receita'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setStateDialog(() {
                      type = value;
                      category = _normalizeMovementCategory(category, type);
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  if (type == FinanceMovementType.income)
                    const DropdownMenuItem(
                      value: 'client_income',
                      child: Text('Receita de cliente/obra'),
                    ),
                  if (type == FinanceMovementType.income)
                    const DropdownMenuItem(
                      value: 'other_income',
                      child: Text('Outra receita'),
                    ),
                  if (type == FinanceMovementType.expense)
                    const DropdownMenuItem(
                      value: 'company_debt',
                      child: Text('Divida da empresa / conta a pagar'),
                    ),
                  if (type == FinanceMovementType.expense)
                    const DropdownMenuItem(
                      value: 'operational_expense',
                      child: Text('Despesa operacional'),
                    ),
                  if (type == FinanceMovementType.expense)
                    const DropdownMenuItem(
                      value: 'tax_expense',
                      child: Text('Imposto / taxa'),
                    ),
                  if (type == FinanceMovementType.expense)
                    const DropdownMenuItem(
                      value: 'supplier_expense',
                      child: Text('Fornecedor / material'),
                    ),
                  const DropdownMenuItem(
                    value: 'other',
                    child: Text('Outro'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setStateDialog(() => category = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Observacao'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FinanceMovementPaymentStatus>(
                initialValue: paymentStatus,
                decoration: const InputDecoration(
                  labelText: 'Status de pagamento',
                ),
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
                  if (value != null) {
                    setStateDialog(() => paymentStatus = value);
                  }
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
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
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
                      if (picked != null) {
                        setStateDialog(() => selectedDueDate = picked);
                      }
                    },
                    child: const Text('Selecionar'),
                  ),
                  if (selectedDueDate != null)
                    TextButton(
                      onPressed: () =>
                          setStateDialog(() => selectedDueDate = null),
                      child: const Text('Limpar'),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
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
                    () => _actions.createCompanyMovement(
                      title: title,
                      type: type == FinanceMovementType.income
                          ? 'INCOME'
                          : 'EXPENSE',
                      category: category,
                      amountCents: amount,
                      date: selectedDate,
                      dueDate: selectedDueDate,
                      paymentStatus:
                          paymentStatus == FinanceMovementPaymentStatus.paid
                          ? 'PAID'
                          : 'PENDING',
                      notes: notesController.text.trim(),
                    ),
                    'Lancamento criado com sucesso.',
                  );
                } else {
                  await _runAction(
                    () => _actions.updateCompanyMovement(
                      movementId: editing.id,
                      title: title,
                      type: type == FinanceMovementType.income
                          ? 'INCOME'
                          : 'EXPENSE',
                      category: category,
                      amountCents: amount,
                      date: selectedDate,
                      dueDate: selectedDueDate,
                      paymentStatus:
                          paymentStatus == FinanceMovementPaymentStatus.paid
                          ? 'PAID'
                          : 'PENDING',
                      notes: notesController.text.trim(),
                    ),
                    'Lancamento atualizado com sucesso.',
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

  Future<void> _showCreatePaymentDialog(List<Employee> employees) async {
    if (employees.isEmpty) {
      _msg('Cadastre um funcionario ativo para criar pagamentos.');
      return;
    }
    String employeeId = employees.first.id;
    final grossController = TextEditingController();
    final discountsController = TextEditingController(text: '0');
    final competencia = ref.read(financeFiltersProvider);
    DateTime? selectedDueDate;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: employeeId,
                decoration: const InputDecoration(labelText: 'Funcionario'),
                items: [
                  for (final employee in employees)
                    DropdownMenuItem<String>(
                      value: employee.id,
                      child: Text(employee.nome),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) employeeId = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: grossController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor bruto (R\$)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: discountsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Descontos (R\$)'),
              ),
              const SizedBox(height: 8),
              Text(
                'Competencia: ${competenceLabel(competencia.year, competencia.month)}',
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
                        initialDate: selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDueDate = picked);
                      }
                    },
                    child: const Text('Selecionar'),
                  ),
                  if (selectedDueDate != null)
                    TextButton(
                      onPressed: () =>
                          setDialogState(() => selectedDueDate = null),
                      child: const Text('Limpar'),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final gross = _parseCents(grossController.text);
                final discounts = _parseCents(discountsController.text) ?? 0;
                if (gross == null || gross <= 0 || discounts < 0) {
                  _msg('Valores invalidos.');
                  return;
                }
                Navigator.of(context).pop();
                await _runAction(
                  () => _actions.createPayment(
                    employeeId: employeeId,
                    competenceYear: competencia.year,
                    competenceMonth: competencia.month,
                    grossCents: gross,
                    discountsCents: discounts,
                    dueDate: selectedDueDate,
                  ),
                  'Pagamento criado com sucesso.',
                );
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    grossController.dispose();
    discountsController.dispose();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      _msg(successMessage);
    } on FinanceActionException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('Nao foi possivel concluir a operacao.');
    }
  }

  Future<void> _confirmarLimpezaGeral() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar todos os registros?'),
        content: const Text(
          'Esta acao apaga registros operacionais da empresa e dos funcionarios '
          '(financeiro, ponto, tarefas, justificativas, auditoria e anexos).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final managerPermissions = _managerPermissionsCache;
      final canRunCleanup =
          sessao.role == Role.owner ||
          (managerPermissions?.allowFinanceCleanup ?? false);
      if (!canRunCleanup) {
        _msg('Sem permissao para executar a limpeza.');
        return;
      }
      if (_requireOwnerApprovalForCleanup && sessao.role != Role.owner) {
        final requestId = '${sessao.companyId}_finance_cleanup';
        await FirebaseFirestore.instance
            .collection('period_closes')
            .doc(requestId)
            .set({
              'companyId': sessao.companyId,
              'module': 'finance_cleanup',
              'competence': 'GLOBAL',
              'status': 'PENDING_APPROVAL',
              'requestedByUserId': sessao.userId,
              'requestedByUserName': sessao.nome,
              'requestedAt': FieldValue.serverTimestamp(),
              'note': 'Solicitacao de limpeza financeira geral',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        await _writeAuditLog(
          module: 'finance',
          action: 'cleanup_requested',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {'status': 'PENDING_APPROVAL'},
        );
        _msg('Solicitacao de limpeza enviada para aprovacao do dono.');
        return;
      }
      await _writeAuditLog(
        module: 'finance',
        action: 'cleanup_requested',
        entityPath: 'company_settings',
        entityId: 'cleanup',
      );
      await _cleanup.clearCompanyOperationalData();
      _msg('Limpeza concluida com sucesso.');
    } on FinanceCleanupException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('Nao foi possivel concluir a limpeza.');
    }
  }

  Future<void> _saveFinanceCleanupApprovalSetting(
    Session sessao,
    bool value,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'financeRequireOwnerApprovalForCleanup': value,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        module: 'finance',
        action: 'cleanup_approval_setting_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        after: {'financeRequireOwnerApprovalForCleanup': value},
      );
      _msg('Regra de aprovacao da limpeza atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a regra de aprovacao da limpeza.');
    }
  }

  Widget _buildTreasurySnapshot({
    required int operatingBalance,
    required int overdueTotal,
    required int dueNext7Days,
    required double receivableCoverage,
    required int contestedCount,
  }) {
    return AppHorizontalCardGrid(
      minItemWidth: 180,
      maxColumns: 5,
      children: [
        _financeCompactCard(
          eyebrow: 'Caixa operacional',
          title: _formatMoneyCents(operatingBalance),
          subtitle: operatingBalance >= 0
              ? 'Receitas acima das despesas'
              : 'Despesas acima das receitas',
          tone: operatingBalance >= 0
              ? const Color(0xFF047857)
              : const Color(0xFFB91C1C),
        ),
        _financeCompactCard(
          eyebrow: 'Vencido',
          title: _formatMoneyCents(overdueTotal),
          subtitle: 'Valores ja atrasados',
          tone: overdueTotal > 0
              ? const Color(0xFFB91C1C)
              : const Color(0xFF0F766E),
        ),
        _financeCompactCard(
          eyebrow: 'Proximos 7 dias',
          title: _formatMoneyCents(dueNext7Days),
          subtitle: 'Compromissos imediatos',
          tone: const Color(0xFFD97706),
        ),
        _financeCompactCard(
          eyebrow: 'Cobertura',
          title: '${(receivableCoverage * 100).round()}%',
          subtitle: 'Receber x pagar',
          tone: receivableCoverage >= 1
              ? const Color(0xFF1D4ED8)
              : const Color(0xFF7C2D12),
        ),
        _financeCompactCard(
          eyebrow: 'Contestacoes',
          title: contestedCount.toString(),
          subtitle: 'Pagamentos em revisao',
          tone: contestedCount > 0
              ? const Color(0xFFD97706)
              : const Color(0xFF475569),
        ),
      ],
    );
  }

  Widget _buildFinanceRiskPanel({
    required int overdueTotal,
    required int dueNext7Days,
    required double receivableCoverage,
    required int contestedCount,
    required int saldoTotal,
  }) {
    return AppHorizontalCardGrid(
      minItemWidth: 220,
      maxColumns: 4,
      children: [
        _financeRiskLine(
          label: 'Atrasos financeiros',
          healthy: overdueTotal <= 0,
          detail: overdueTotal <= 0
              ? 'Nenhum valor vencido agora.'
              : '${_formatMoneyCents(overdueTotal)} em atraso.',
        ),
        _financeRiskLine(
          label: 'Pressao de curto prazo',
          healthy: dueNext7Days <= (saldoTotal > 0 ? saldoTotal : 0),
          detail: '${_formatMoneyCents(dueNext7Days)} vencem nos proximos 7 dias.',
        ),
        _financeRiskLine(
          label: 'Cobertura de recebiveis',
          healthy: receivableCoverage >= 1,
          detail: receivableCoverage >= 1
              ? 'Receber cobre o passivo.'
              : 'Receber nao cobre o passivo.',
        ),
        _financeRiskLine(
          label: 'Pagamentos contestados',
          healthy: contestedCount == 0,
          detail: contestedCount == 0
              ? 'Sem divergencias abertas.'
              : '$contestedCount em contestacao.',
        ),
      ],
    );
  }

  Widget _financeCompactCard({
    required String eyebrow,
    required String title,
    required String subtitle,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppBrandColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeRiskLine({
    required String label,
    required bool healthy,
    required String detail,
  }) {
    final color = healthy
        ? const Color(0xFF0F766E)
        : const Color(0xFFB91C1C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: healthy ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: healthy ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            healthy ? Icons.verified_outlined : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppBrandColors.ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFinanceSettingsRequestDialog(
    Session sessao,
    _FinanceModuleSettings financeSettings,
    _FinanceManagerPermissions managerPermissions,
    bool requireOwnerApprovalForCleanup,
  ) async {
    var mode = financeSettings.mode;
    var enablePayments = financeSettings.enablePayments;
    var enableDebts = financeSettings.enableDebts;
    var enableCompanyMovements = financeSettings.enableCompanyMovements;
    var enableCleanup = financeSettings.enableCleanup;
    var allowCreatePayments = managerPermissions.allowCreatePayments;
    var allowManageDebts = managerPermissions.allowManageDebts;
    var allowManageCompanyMovements =
        managerPermissions.allowManageCompanyMovements;
    var allowFinanceCleanup = managerPermissions.allowFinanceCleanup;
    var cleanupOwnerApproval = requireOwnerApprovalForCleanup;
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar ajuste financeiro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<_FinanceMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Modo'),
                  items: const [
                    DropdownMenuItem(
                      value: _FinanceMode.simple,
                      child: Text('Simples'),
                    ),
                    DropdownMenuItem(
                      value: _FinanceMode.advanced,
                      child: Text('Completo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => mode = value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: enablePayments,
                  onChanged: (value) =>
                      setDialogState(() => enablePayments = value),
                  title: const Text('Pagamentos'),
                ),
                SwitchListTile(
                  value: enableDebts,
                  onChanged: (value) =>
                      setDialogState(() => enableDebts = value),
                  title: const Text('Dividas'),
                ),
                SwitchListTile(
                  value: enableCompanyMovements,
                  onChanged: (value) =>
                      setDialogState(() => enableCompanyMovements = value),
                  title: const Text('Movimentos empresa'),
                ),
                SwitchListTile(
                  value: enableCleanup,
                  onChanged: (value) =>
                      setDialogState(() => enableCleanup = value),
                  title: const Text('Limpeza financeira'),
                ),
                SwitchListTile(
                  value: cleanupOwnerApproval,
                  onChanged: (value) =>
                      setDialogState(() => cleanupOwnerApproval = value),
                  title: const Text('Aprovacao do dono na limpeza'),
                ),
                const Divider(),
                SwitchListTile(
                  value: allowCreatePayments,
                  onChanged: (value) =>
                      setDialogState(() => allowCreatePayments = value),
                  title: const Text('Gerente cria pagamentos'),
                ),
                SwitchListTile(
                  value: allowManageDebts,
                  onChanged: (value) =>
                      setDialogState(() => allowManageDebts = value),
                  title: const Text('Gerente gere dividas'),
                ),
                SwitchListTile(
                  value: allowManageCompanyMovements,
                  onChanged: (value) =>
                      setDialogState(() => allowManageCompanyMovements = value),
                  title: const Text('Gerente gere movimentos'),
                ),
                SwitchListTile(
                  value: allowFinanceCleanup,
                  onChanged: (value) =>
                      setDialogState(() => allowFinanceCleanup = value),
                  title: const Text('Gerente executa limpeza'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da solicitacao',
                  ),
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
                final requestId =
                    '${sessao.companyId}_finance_settings_${DateTime.now().millisecondsSinceEpoch}';
                await FirebaseFirestore.instance
                    .collection('period_closes')
                    .doc(requestId)
                    .set({
                      'companyId': sessao.companyId,
                      'module': 'finance_settings_change',
                      'competence': 'SETTINGS',
                      'status': 'PENDING_APPROVAL',
                      'requestedByUserId': sessao.userId,
                      'requestedByUserName': sessao.nome,
                      'requestedAt': FieldValue.serverTimestamp(),
                      'note': noteController.text.trim(),
                      'proposedFinanceMode': mode.name,
                      'proposedFinanceFeatures': {
                        'enablePayments': enablePayments,
                        'enableDebts': enableDebts,
                        'enableCompanyMovements': enableCompanyMovements,
                        'enableCleanup': enableCleanup,
                      },
                      'proposedFinanceManagerPermissions': {
                        'allowCreatePayments': allowCreatePayments,
                        'allowManageDebts': allowManageDebts,
                        'allowManageCompanyMovements':
                            allowManageCompanyMovements,
                        'allowFinanceCleanup': allowFinanceCleanup,
                      },
                      'proposedFinanceRequireOwnerApprovalForCleanup':
                          cleanupOwnerApproval,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                await _writeAuditLog(
                  module: 'finance',
                  action: 'settings_change_requested',
                  entityPath: 'period_closes',
                  entityId: requestId,
                  after: {
                    'module': 'finance_settings_change',
                    'note': noteController.text.trim(),
                  },
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('Solicitacao enviada para aprovacao do dono.');
              },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
  }

  Future<void> _saveFinanceModuleSettings(
    Session sessao,
    _FinanceModuleSettings settings,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'financeMode': settings.mode.name,
            'financeFeatures': settings.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        module: 'finance',
        action: 'settings_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'financeMode': settings.mode.name,
          'financeFeatures': settings.toMap(),
        },
      );
      _msg('Configuracao financeira atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a configuracao financeira.');
    }
  }

  Future<void> _saveFinanceManagerPermissions(
    Session sessao,
    _FinanceManagerPermissions permissions,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'financeManagerPermissions': permissions.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        module: 'finance',
        action: 'manager_permissions_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {'financeManagerPermissions': permissions.toMap()},
      );
      _msg('Permissoes do gerente atualizadas.');
    } catch (_) {
      _msg('Nao foi possivel salvar as permissoes do gerente.');
    }
  }

  Widget _featureToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 52,
      child: FilterChip(
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
        selected: value,
        onSelected: onChanged,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        showCheckmark: false,
      ),
    );
  }

  Widget _chipOptionCard({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppBrandColors.primaryDeep
                : AppBrandColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppBrandColors.primaryDeep
                : AppBrandColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
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

  String _movementPaymentStatusLabel(FinanceMovementPaymentStatus status) {
    return switch (status) {
      FinanceMovementPaymentStatus.pending => 'Pendente',
      FinanceMovementPaymentStatus.paid => 'Pago',
    };
  }

  String _normalizeMovementCategory(
    String? category,
    FinanceMovementType type,
  ) {
    final normalized = (category ?? '').trim();
    if (type == FinanceMovementType.income) {
      if (normalized == 'client_income' ||
          normalized == 'other_income' ||
          normalized == 'other') {
        return normalized;
      }
      return 'client_income';
    }
    if (normalized == 'company_debt' ||
        normalized == 'operational_expense' ||
        normalized == 'tax_expense' ||
        normalized == 'supplier_expense' ||
        normalized == 'other') {
      return normalized;
    }
    return 'operational_expense';
  }

  String _movementCategoryLabel(String category) {
    return switch (category) {
      'client_income' => 'Cliente/obra',
      'company_debt' => 'Divida da empresa',
      'operational_expense' => 'Operacional',
      'tax_expense' => 'Imposto/taxa',
      'supplier_expense' => 'Fornecedor/material',
      'other_income' => 'Outra receita',
      'other' => 'Outro',
      _ => category.trim().isEmpty ? 'Sem categoria' : category,
    };
  }

  String _debtStatusLabel(FinanceDebtStatus status) {
    return switch (status) {
      FinanceDebtStatus.open => 'Aberto',
      FinanceDebtStatus.settled => 'Quitado',
      FinanceDebtStatus.canceled => 'Cancelado',
    };
  }

  String _movementOwnerLabel(
    String ownerUserId,
    Map<String, String> employeeNameById,
  ) {
    if (ownerUserId == '__COMPANY__') return 'Empresa';
    return employeeNameById[ownerUserId] ?? ownerUserId;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _writeAuditLog({
    required String module,
    required String action,
    required String entityPath,
    required String entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    try {
      final sessao = ref.read(sessionProvider);
      if (sessao == null) return;
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'companyId': sessao.companyId,
        'actorUserId': sessao.userId,
        'actorRole': sessao.role.name,
        'module': module,
        'action': action,
        'entityPath': entityPath,
        'entityId': entityId,
        'before': before,
        'after': after,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Nao bloqueia o fluxo principal.
    }
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }
}

enum _FinanceMode { simple, advanced }

class _FinanceModuleSettings {
  const _FinanceModuleSettings({
    required this.mode,
    required this.enablePayments,
    required this.enableDebts,
    required this.enableCompanyMovements,
    required this.enableCleanup,
  });

  factory _FinanceModuleSettings.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final mode =
        (companySettings['financeMode']?.toString() ?? 'advanced') == 'simple'
        ? _FinanceMode.simple
        : _FinanceMode.advanced;
    final raw = companySettings['financeFeatures'];
    final features = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final fallback = mode == _FinanceMode.simple
        ? const _FinanceModuleSettings(
            mode: _FinanceMode.simple,
            enablePayments: true,
            enableDebts: false,
            enableCompanyMovements: false,
            enableCleanup: false,
          )
        : const _FinanceModuleSettings(
            mode: _FinanceMode.advanced,
            enablePayments: true,
            enableDebts: true,
            enableCompanyMovements: true,
            enableCleanup: true,
          );
    return fallback.copyWith(
      enablePayments:
          features['enablePayments'] as bool? ?? fallback.enablePayments,
      enableDebts: features['enableDebts'] as bool? ?? fallback.enableDebts,
      enableCompanyMovements:
          features['enableCompanyMovements'] as bool? ??
          fallback.enableCompanyMovements,
      enableCleanup:
          features['enableCleanup'] as bool? ?? fallback.enableCleanup,
    );
  }

  final _FinanceMode mode;
  final bool enablePayments;
  final bool enableDebts;
  final bool enableCompanyMovements;
  final bool enableCleanup;

  _FinanceModuleSettings copyWith({
    _FinanceMode? mode,
    bool? enablePayments,
    bool? enableDebts,
    bool? enableCompanyMovements,
    bool? enableCleanup,
  }) {
    return _FinanceModuleSettings(
      mode: mode ?? this.mode,
      enablePayments: enablePayments ?? this.enablePayments,
      enableDebts: enableDebts ?? this.enableDebts,
      enableCompanyMovements:
          enableCompanyMovements ?? this.enableCompanyMovements,
      enableCleanup: enableCleanup ?? this.enableCleanup,
    );
  }

  _FinanceModuleSettings simplePreset() {
    return const _FinanceModuleSettings(
      mode: _FinanceMode.simple,
      enablePayments: true,
      enableDebts: false,
      enableCompanyMovements: false,
      enableCleanup: false,
    );
  }

  _FinanceModuleSettings advancedPreset() {
    return const _FinanceModuleSettings(
      mode: _FinanceMode.advanced,
      enablePayments: true,
      enableDebts: true,
      enableCompanyMovements: true,
      enableCleanup: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enablePayments': enablePayments,
      'enableDebts': enableDebts,
      'enableCompanyMovements': enableCompanyMovements,
      'enableCleanup': enableCleanup,
    };
  }
}

class _FinanceManagerPermissions {
  const _FinanceManagerPermissions({
    required this.allowCreatePayments,
    required this.allowManageDebts,
    required this.allowManageCompanyMovements,
    required this.allowFinanceCleanup,
  });

  factory _FinanceManagerPermissions.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final raw = companySettings['financeManagerPermissions'];
    final settings = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return _FinanceManagerPermissions(
      allowCreatePayments: settings['allowCreatePayments'] as bool? ?? true,
      allowManageDebts: settings['allowManageDebts'] as bool? ?? true,
      allowManageCompanyMovements:
          settings['allowManageCompanyMovements'] as bool? ?? true,
      allowFinanceCleanup: settings['allowFinanceCleanup'] as bool? ?? false,
    );
  }

  final bool allowCreatePayments;
  final bool allowManageDebts;
  final bool allowManageCompanyMovements;
  final bool allowFinanceCleanup;

  _FinanceManagerPermissions copyWith({
    bool? allowCreatePayments,
    bool? allowManageDebts,
    bool? allowManageCompanyMovements,
    bool? allowFinanceCleanup,
  }) {
    return _FinanceManagerPermissions(
      allowCreatePayments: allowCreatePayments ?? this.allowCreatePayments,
      allowManageDebts: allowManageDebts ?? this.allowManageDebts,
      allowManageCompanyMovements:
          allowManageCompanyMovements ?? this.allowManageCompanyMovements,
      allowFinanceCleanup: allowFinanceCleanup ?? this.allowFinanceCleanup,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowCreatePayments': allowCreatePayments,
      'allowManageDebts': allowManageDebts,
      'allowManageCompanyMovements': allowManageCompanyMovements,
      'allowFinanceCleanup': allowFinanceCleanup,
    };
  }
}

class _FinanceAccountantPermissions {
  const _FinanceAccountantPermissions({
    required this.allowFinanceRead,
  });

  factory _FinanceAccountantPermissions.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final raw = companySettings['accountantPermissions'];
    final settings = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    return _FinanceAccountantPermissions(
      allowFinanceRead: settings['allowFinanceRead'] as bool? ?? true,
    );
  }

  final bool allowFinanceRead;
}

class _AgendaItem {
  const _AgendaItem({
    required this.title,
    required this.subtitle,
    required this.amountCents,
    required this.dueDate,
    required this.kindLabel,
    required this.kindColor,
  });

  final String title;
  final String subtitle;
  final int amountCents;
  final DateTime? dueDate;
  final String kindLabel;
  final Color kindColor;
}
