import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/app_update/app_update_launcher.dart';
import 'package:pontocerto/core/app_update/app_update_provider.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_experience.dart';
import 'package:pontocerto/core/company/company_runtime_summary_provider.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/privacy/presentation_money_mask_provider.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/device_consent/domain/device_consent.dart';
import 'package:pontocerto/features/device_consent/presentation/device_consent_provider.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/finance/domain/entities/debt.dart';
import 'package:pontocerto/features/finance/domain/entities/movement.dart';
import 'package:pontocerto/features/finance/domain/entities/payment.dart'
    as employee_finance;
import 'package:pontocerto/features/finance/presentation/providers/finance_streams_provider.dart';
import 'package:pontocerto/features/justifications/domain/justification.dart';
import 'package:pontocerto/features/justifications/presentation/justifications_provider.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';
import 'package:pontocerto/features/payments/presentation/payments_provider.dart';
import 'package:pontocerto/features/punch/presentation/punch_provider.dart';
import 'package:pontocerto/features/service_orders/domain/service_order.dart';
import 'package:pontocerto/features/service_orders/presentation/service_orders_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/urls/receita_official_urls.dart';
import 'package:url_launcher/url_launcher.dart';

class PaginaHome extends ConsumerStatefulWidget {
  const PaginaHome({super.key, this.acessoNegado = false});

  final bool acessoNegado;

  @override
  ConsumerState<PaginaHome> createState() => _PaginaHomeState();
}

class _PaginaHomeState extends ConsumerState<PaginaHome> {
  bool _snackExibido = false;
  String? _ultimaVersaoAvisada;
  bool _hideMoneyForLayout = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.acessoNegado && !_snackExibido) {
      _snackExibido = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.showUserError('Acesso negado.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    final appUpdateAsync = ref.watch(appUpdateConfigProvider);
    final currentVersion =
        ref.watch(currentAppVersionProvider).valueOrNull ?? '';

    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    _hideMoneyForLayout = ref.watch(presentationMoneyMaskProvider);

    final consents = sessao.role == Role.employee
        ? ref.watch(deviceConsentsProvider)
        : const <DeviceConsent>[];

    final appUpdate = appUpdateAsync.valueOrNull;
    if (appUpdate != null &&
        appUpdate.active &&
        currentVersion.isNotEmpty &&
        _isNewerVersion(appUpdate.latestVersion, currentVersion) &&
        _ultimaVersaoAvisada != appUpdate.latestVersion) {
      _ultimaVersaoAvisada = appUpdate.latestVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mostrarAvisoAtualizacao(context, appUpdate, currentVersion);
      });
    }

    final consentEmployee = sessao.role == Role.employee
        ? consents
              .where(
                (c) =>
                    c.employeeId == sessao.userId &&
                    c.companyId == sessao.companyId,
              )
              .firstOrNull
        : null;
    final employeeAutorizado =
        sessao.role != Role.employee || consentEmployee?.accepted == true;

    if (sessao.role == Role.employee) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
        header: AppWorkspaceHeader(
          title: 'Painel do funcionario',
          subtitle:
              'Veja apenas sua rotina de trabalho, seu financeiro pessoal, seus registros de ponto e o que esta pendente no seu dia.',
          chips: [
            AppHeaderChip('Rotina pessoal'),
            AppHeaderChip('Sem dados da empresa'),
          ],
        ),
      );
      return !employeeAutorizado
          ? _buildBloqueioAutorizacao(sessao)
          : _buildEmployeeHomeBody(context);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .snapshots(),
      builder: (context, settingsSnapshot) {
        final companySettings =
            settingsSnapshot.data?.data() ?? <String, dynamic>{};
        final companyExperience = CompanyExperience.fromSettings(
          companySettings,
        );
        final companyProfile =
            companySettings['companyOperationalProfile']?.toString() ??
            'small_business';
        ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
          header: AppWorkspaceHeader(
            title: sessao.role == Role.accountant
                ? 'Painel do contador'
                : 'Painel da empresa',
            subtitle: sessao.role == Role.accountant
                ? 'Veja faturamento, fiscal, relatorios e as empresas em que voce atende como contador.'
                : 'Veja o que entrou, o que saiu, o que esta pendente e os atalhos mais usados da empresa.',
            chips: sessao.role == Role.accountant
                ? const [
                    AppHeaderChip('Foco fiscal'),
                    AppHeaderChip('Empresas vinculadas'),
                  ]
                : const [
                    AppHeaderChip('Resumo do dia'),
                    AppHeaderChip('Leitura simples'),
                  ],
          ),
        );
        return !employeeAutorizado
            ? _buildBloqueioAutorizacao(sessao)
            : sessao.role == Role.accountant
                ? _buildAccountantHomeBody(
                    context,
                    companySettings: companySettings,
                  )
                : companyExperience.isMei
                    ? _buildMeiHomeBody(context, companySettings: companySettings)
                    : _buildCompanyHomeBody(
                        context,
                        companySettings: companySettings,
                        companyProfile: companyProfile,
                      );
      },
    );
  }

  Widget _buildEmployeeHomeBody(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final openTasks = tasks
        .where((t) => t.status != StatusTarefa.finalizado)
        .length;
    final doneTasks = tasks
        .where((t) => t.status == StatusTarefa.finalizado)
        .length;
    final orders = ref.watch(serviceOrdersProvider);
    final openOrders = orders
        .where((o) => o.status != ServiceOrderStatus.completed)
        .length;
    final justifications = ref.watch(justificationsProvider);
    final pendingJustifications = justifications
        .where((j) => j.status == JustificationStatus.pending)
        .length;
    final punches = ref.watch(punchProvider);
    final workedDays = ref.watch(workedDaysProvider);
    final payments = ref.watch(financeVisiblePaymentsProvider);
    final debts = ref.watch(financeVisibleDebtsProvider);
    final movements =
        ref.watch(financePersonalMovementsProvider).valueOrNull ??
        const <FinanceMovement>[];

    final receivablePayments = payments
        .where(
          (p) =>
              p.status == employee_finance.FinancePaymentStatus.pending ||
              p.status == employee_finance.FinancePaymentStatus.paid ||
              p.status == employee_finance.FinancePaymentStatus.confirmed,
        )
        .fold<int>(0, (total, p) => total + p.netCents);
    final openDebts = debts
        .where((d) => d.status == FinanceDebtStatus.open)
        .fold<int>(0, (total, d) => total + d.amountCents);
    final personalIncome = movements
        .where((m) => m.type == FinanceMovementType.income)
        .fold<int>(0, (total, m) => total + m.amountCents);
    final personalExpense = movements
        .where((m) => m.type == FinanceMovementType.expense)
        .fold<int>(0, (total, m) => total + m.amountCents);
    final personalBalance =
        receivablePayments + personalIncome - openDebts - personalExpense;

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            AppHorizontalCardGrid(
              minItemWidth: 220,
              maxColumns: 4,
              children: [
                AppMetricCard(
                  label: 'Minhas tarefas',
                  value: openTasks.toString(),
                  caption: 'Pendentes no seu fluxo',
                ),
                AppMetricCard(
                  label: 'Ordens abertas',
                  value: openOrders.toString(),
                  caption: 'Ordens ligadas a voce',
                ),
                AppMetricCard(
                  label: 'Saldo pessoal',
                  value: _money(personalBalance),
                  caption: 'Financeiro do funcionario',
                ),
                AppMetricCard(
                  label: 'Justificativas',
                  value: pendingJustifications.toString(),
                  caption: 'Aguardando resposta',
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppWorkspaceCard(
              title: 'Meu dia',
              subtitle:
                  'Leitura rapida da sua rotina sem misturar informacoes da empresa.',
              child: AppHorizontalCardGrid(
                minItemWidth: 240,
                maxColumns: 4,
                children: [
                  _employeeMiniCard(
                    title: 'Tarefas concluidas',
                    value: doneTasks.toString(),
                    details: 'Entregas que ja foram fechadas por voce.',
                    icon: Icons.assignment_turned_in_outlined,
                  ),
                  _employeeMiniCard(
                    title: 'Pontos registrados',
                    value: punches.length.toString(),
                    details: 'Marcacoes do seu historico.',
                    icon: Icons.punch_clock_outlined,
                  ),
                  _employeeMiniCard(
                    title: 'Dias trabalhados',
                    value: workedDays.length.toString(),
                    details: 'Dias com jornada registrada.',
                    icon: Icons.calendar_month_outlined,
                  ),
                  _employeeMiniCard(
                    title: 'Movimentos pessoais',
                    value: movements.length.toString(),
                    details: 'Lancamentos do seu controle.',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppWorkspaceCard(
              title: 'Atalhos do funcionario',
              subtitle:
                  'Acesso direto apenas ao que pertence a sua rotina operacional.',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/tasks'),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Tarefas'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/service-orders'),
                    icon: const Icon(Icons.build_circle_outlined),
                    label: const Text('Ordens'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/punch'),
                    icon: const Icon(Icons.punch_clock_outlined),
                    label: const Text('Ponto'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/justifications'),
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: const Text('Justificativas'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/finance'),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Meu financeiro'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/service-catalog'),
                    icon: const Icon(Icons.view_list_outlined),
                    label: const Text('Catalogo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/materials'),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Materiais'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountantHomeBody(
    BuildContext context, {
    required Map<String, dynamic> companySettings,
  }) {
    final summary = ref.watch(companyRuntimeSummaryProvider).valueOrNull;
    final summaryFinance =
        (summary?['finance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    int cents(String key) {
      final value = summaryFinance[key];
      if (value is num) return value.toInt();
      return 0;
    }

    final hasSummaryFinance = summaryFinance.isNotEmpty;
    final payments = hasSummaryFinance
        ? const <Payment>[]
        : ref.watch(paymentsProvider);
    final financeMovements = hasSummaryFinance
        ? const <FinanceMovement>[]
        : ref.watch(financeCompanyMovementsProvider).valueOrNull ??
              const <FinanceMovement>[];
    final payrollContestedAmount = hasSummaryFinance
        ? cents('contestedPayrollCents')
        : payments
              .where((p) => p.status == PaymentStatus.contestado)
              .fold<int>(0, (total, p) => total + p.valorCents);
    final operationalIncome = hasSummaryFinance
        ? cents('companyReceivablesCents')
        : financeMovements
              .where(
                (m) =>
                    m.type == FinanceMovementType.income &&
                    m.sourceModule != 'payments' &&
                    m.sourceModule != 'debts',
              )
              .fold<int>(0, (total, item) => total + item.amountCents);
    final operationalIncomeReceived = hasSummaryFinance
        ? cents('companyReceivablesReceivedCents')
        : financeMovements
              .where(
                (m) =>
                    m.type == FinanceMovementType.income &&
                    m.sourceModule != 'payments' &&
                    m.sourceModule != 'debts' &&
                    m.paymentStatus == FinanceMovementPaymentStatus.paid,
              )
              .fold<int>(0, (total, item) => total + item.amountCents);
    final operationalIncomePending =
        operationalIncome - operationalIncomeReceived;

    return AppGradientBackground(
      child: AppPageLayout(
        child: _buildPainelContador(
          context,
          companySettings: companySettings,
          billingPending: operationalIncomePending,
          billingReceived: operationalIncomeReceived,
          payrollContestedAmount: payrollContestedAmount,
        ),
      ),
    );
  }

  Widget _buildMeiHomeBody(
    BuildContext context, {
    required Map<String, dynamic> companySettings,
  }) {
    final summary = ref.watch(companyRuntimeSummaryProvider).valueOrNull;
    final summaryFinance =
        (summary?['finance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    int cents(String key) {
      final value = summaryFinance[key];
      if (value is num) return value.toInt();
      return 0;
    }

    final tasks = ref.watch(tasksProvider);
    final hasSummaryFinance = summaryFinance.isNotEmpty;
    final payments = hasSummaryFinance
        ? const <Payment>[]
        : ref.watch(paymentsProvider);
    final financeMovements = hasSummaryFinance
        ? const <FinanceMovement>[]
        : ref.watch(financeCompanyMovementsProvider).valueOrNull ??
              const <FinanceMovement>[];
    final pendingTasks = tasks
        .where((t) => t.status != StatusTarefa.finalizado)
        .length;
    final payrollPendingAmount = hasSummaryFinance
        ? cents('pendingPayrollCents') + cents('paidPayrollCents')
        : payments
              .where(
                (p) =>
                    p.status == PaymentStatus.pendente ||
                    p.status == PaymentStatus.pago,
              )
              .fold<int>(0, (total, p) => total + p.valorCents);
    final payrollConfirmedAmount = hasSummaryFinance
        ? cents('confirmedPayrollCents')
        : payments
              .where((p) => p.status == PaymentStatus.confirmado)
              .fold<int>(0, (total, p) => total + p.valorCents);
    final operationalExpense = hasSummaryFinance
        ? cents('companyPayablesCents')
        : financeMovements
              .where(
                (m) =>
                    m.type == FinanceMovementType.expense &&
                    m.sourceModule != 'payments' &&
                    m.sourceModule != 'debts',
              )
              .fold<int>(0, (total, item) => total + item.amountCents);

    return AppGradientBackground(
      child: AppPageLayout(
        child: _buildPainelMei(
          context,
          companySettings: companySettings,
          scheduledPayments: payrollPendingAmount,
          confirmedPayments: payrollConfirmedAmount,
          operationalExpense: operationalExpense,
          pendingTasks: pendingTasks,
        ),
      ),
    );
  }

  Widget _buildCompanyHomeBody(
    BuildContext context, {
    required Map<String, dynamic> companySettings,
    required String companyProfile,
  }) {
    final summary = ref.watch(companyRuntimeSummaryProvider).valueOrNull;
    final summaryFinance =
        (summary?['finance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    int cents(String key) {
      final value = summaryFinance[key];
      if (value is num) return value.toInt();
      return 0;
    }

    final people = ref.watch(employeesProvider);
    final employees = people.where((e) => e.isOperationalTeam).toList();
    final accountants = people.where((e) => e.isAccountant).toList();
    final tasks = ref.watch(tasksProvider);
    final hasSummaryFinance = summaryFinance.isNotEmpty;
    final payments = hasSummaryFinance
        ? const <Payment>[]
        : ref.watch(paymentsProvider);
    final financeDebts = hasSummaryFinance
        ? const <FinanceDebt>[]
        : ref.watch(financeDebtsStreamProvider).valueOrNull ??
              const <FinanceDebt>[];
    final financeMovements = hasSummaryFinance
        ? const <FinanceMovement>[]
        : ref.watch(financeCompanyMovementsProvider).valueOrNull ??
              const <FinanceMovement>[];
    final activeEmployees = employees.where((e) => e.ativo).length;
    final activeAccountants = accountants.where((e) => e.ativo).length;
    final pendingTasks = tasks
        .where((t) => t.status != StatusTarefa.finalizado)
        .length;
    final finishedTasks = tasks
        .where((t) => t.status == StatusTarefa.finalizado)
        .length;
    final payrollPendingAmount = hasSummaryFinance
        ? cents('pendingPayrollCents') + cents('paidPayrollCents')
        : payments
              .where(
                (p) =>
                    p.status == PaymentStatus.pendente ||
                    p.status == PaymentStatus.pago,
              )
              .fold<int>(0, (total, p) => total + p.valorCents);
    final payrollConfirmedAmount = hasSummaryFinance
        ? cents('confirmedPayrollCents')
        : payments
              .where((p) => p.status == PaymentStatus.confirmado)
              .fold<int>(0, (total, p) => total + p.valorCents);
    final payrollContestedAmount = hasSummaryFinance
        ? cents('contestedPayrollCents')
        : payments
              .where((p) => p.status == PaymentStatus.contestado)
              .fold<int>(0, (total, p) => total + p.valorCents);
    final operationalIncome = hasSummaryFinance
        ? cents('companyReceivablesCents')
        : financeMovements
              .where(
                (m) =>
                    m.type == FinanceMovementType.income &&
                    m.sourceModule != 'payments' &&
                    m.sourceModule != 'debts',
              )
              .fold<int>(0, (total, item) => total + item.amountCents);
    final operationalExpense = hasSummaryFinance
        ? cents('companyPayablesCents')
        : financeMovements
              .where(
                (m) =>
                    m.type == FinanceMovementType.expense &&
                    m.sourceModule != 'payments' &&
                    m.sourceModule != 'debts',
              )
              .fold<int>(0, (total, item) => total + item.amountCents);
    final openDebts = hasSummaryFinance
        ? cents('openDebtsCents') + cents('openAdvancesCents')
        : financeDebts
              .where((d) => d.status == FinanceDebtStatus.open)
              .fold<int>(0, (total, item) => total + item.amountCents);
    final executiveModules = _executiveModules(
      companySettings,
      tasks.length,
      pendingTasks,
      activeEmployees,
      employees.length,
      payrollPendingAmount,
      payrollConfirmedAmount,
      payrollContestedAmount,
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            AppHorizontalCardGrid(
              minItemWidth: 420,
              maxColumns: 2,
              children: [
                AppWorkspaceCard(
                  title: 'Mapa da operacao',
                  subtitle: 'Veja o ritmo geral da empresa em uma leitura unica.',
                  child: SizedBox(
                    height: 360,
                    child: _executiveOverviewChart(modules: executiveModules),
                  ),
                ),
                AppWorkspaceCard(
                  title: 'Resumo financeiro',
                  subtitle: 'Receita, despesa e obrigacoes em leitura horizontal.',
                  child: SizedBox(
                    height: 360,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _financeSummaryStat(
                                title: 'Receita',
                                value: _money(operationalIncome),
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _financeSummaryStat(
                                title: 'Despesa',
                                value: _money(operationalExpense),
                                color: const Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _financeSummaryStat(
                                title: 'Obrigacoes',
                                value: _money(openDebts),
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _dashboardBars(
                            items: [
                              _DashboardBarData(
                                label: 'Receita',
                                value: operationalIncome,
                                color: const Color(0xFF1D4ED8),
                              ),
                              _DashboardBarData(
                                label: 'Despesa',
                                value: operationalExpense,
                                color: const Color(0xFF059669),
                              ),
                              _DashboardBarData(
                                label: 'Obrigacoes',
                                value: openDebts,
                                color: const Color(0xFFD97706),
                              ),
                            ],
                            money: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppHorizontalCardGrid(
              minItemWidth: 240,
              maxColumns: 4,
              children: [
                _attentionCard(
                  'Veja aqui o que precisa da sua atencao antes de abrir cada modulo.',
                ),
                _attentionCard(
                  'Entradas, saidas, equipe e tarefas aparecem juntas para facilitar a decisao.',
                ),
                _attentionCard(
                  'Use este painel como leitura rapida do dia a dia da empresa.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppHorizontalCardGrid(
              minItemWidth: 220,
              maxColumns: 4,
              children: [
                _quickActionCard(
                  onPressed: () => context.go('/assistant'),
                  icon: Icons.auto_awesome_outlined,
                  title: 'Assistente',
                  subtitle: 'Abrir central inteligente',
                ),
                _quickActionCard(
                  onPressed: () => context.go('/tasks'),
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Tarefas',
                  subtitle: 'Ir para pendencias',
                ),
                _quickActionCard(
                  onPressed: () => context.go('/clients'),
                  icon: Icons.apartment_outlined,
                  title: 'Clientes',
                  subtitle: 'Gerenciar base ativa',
                ),
                _quickActionCard(
                  onPressed: () => context.go('/finance'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Financeiro',
                  subtitle: 'Ver caixa e lancamentos',
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppHorizontalCardGrid(
              minItemWidth: 240,
              maxColumns: 4,
              children: [
                _miniPanel(
                  title: 'Tarefas',
                  value: tasks.length.toString(),
                  subtitle: '$pendingTasks abertas e $finishedTasks concluidas',
                  icon: Icons.assignment_turned_in_outlined,
                ),
                _miniPanel(
                  title: 'Equipe',
                  value: activeEmployees.toString(),
                  subtitle:
                      '${employees.length - activeEmployees} sem uso agora',
                  icon: Icons.groups_2_outlined,
                ),
                _miniPanel(
                  title: 'Contabilidade',
                  value: activeAccountants.toString(),
                  subtitle:
                      '${accountants.length - activeAccountants} acessos sem uso',
                  icon: Icons.calculate_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppHorizontalCardGrid(
              minItemWidth: 260,
              maxColumns: 4,
              children: [
                _moduleStatusCard(
                  title: 'Financeiro',
                  icon: Icons.account_balance_wallet_outlined,
                  mode: _moduleModeLabel(
                    companySettings['financeMode']?.toString(),
                  ),
                  details: _financeStatusSummary(companySettings),
                ),
                _moduleStatusCard(
                  title: 'Trabalhista',
                  icon: Icons.groups_2_outlined,
                  mode: _moduleModeLabel(
                    companySettings['workforceMode']?.toString(),
                  ),
                  details: _workforceStatusSummary(companySettings),
                ),
                _moduleStatusCard(
                  title: 'Fiscal',
                  icon: Icons.receipt_long_outlined,
                  mode: _moduleModeLabel(
                    companySettings['fiscalMode']?.toString(),
                  ),
                  details: _fiscalStatusSummary(companySettings),
                ),
                for (final module in _secondaryModules(
                  companySettings,
                  tasks.length,
                  activeEmployees,
                ))
                  _moduleStatusCard(
                    title: module.title,
                    icon: module.icon,
                    mode: module.mode,
                    details: module.details,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppBrandColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _attentionCard(String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppBrandColors.ink,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _financeSummaryStat({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required VoidCallback onPressed,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppBrandColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppBrandColors.primaryDeep),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppBrandColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppBrandColors.softText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPanel({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
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
          Row(
            children: [
              Icon(icon, color: AppBrandColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppBrandColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _dashboardBars({
    required List<_DashboardBarData> items,
    required bool money,
  }) {
    final maxValue = items.fold<int>(
      1,
      (current, item) => item.value > current ? item.value : current,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    money ? _money(item.value) : item.value.toString(),
                    style: const TextStyle(
                      color: AppBrandColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 180,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: (item.value / maxValue) * 180,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AppBrandColors.softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _moduleStatusCard({
    required String title,
    required IconData icon,
    required String mode,
    required String details,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E6FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12003088),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppBrandColors.primaryDeep),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  mode,
                  style: const TextStyle(
                    color: AppBrandColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildBloqueioAutorizacao(Session sessao) {
    return AppGradientBackground(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLogo(size: 72, radius: 22),
                  const SizedBox(height: 16),
                  const Text(
                    'Autorizacao obrigatoria de uso do celular',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppBrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Para continuar usando o app, o funcionario deve autorizar o uso do celular proprio '
                    'como ferramenta de trabalho para registro de ponto e operacoes relacionadas no sistema.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Termo: declaro ciente e de acordo com o uso voluntario do dispositivo pessoal '
                    'para fins de trabalho no app, com registro de data/hora e versao do termo.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(deviceConsentsProvider.notifier)
                              .acceptOwnDeviceUse(
                                termsVersion: 'v2.0-2026-03-07',
                              );
                          if (!mounted) return;
                          context.showUserSuccess('Autorizacao registrada.');
                        } catch (e) {
                          if (!mounted) return;
                          context.showUserError(
                            AppErrorMapper.messageFrom(
                              e,
                              fallback:
                                  'Nao foi possivel registrar a autorizacao.',
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.verified_user),
                      label: const Text('Li e autorizo o uso do meu celular'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPainelMei(
    BuildContext context, {
    required Map<String, dynamic> companySettings,
    required int scheduledPayments,
    required int confirmedPayments,
    required int operationalExpense,
    required int pendingTasks,
  }) {
    final meiDasRaw = companySettings['meiDas'];
    final meiDas = meiDasRaw is Map
        ? meiDasRaw.cast<String, dynamic>()
        : <String, dynamic>{};
    final dasStatus = meiDas['status']?.toString() ?? 'pendente';
    final dasValue = (meiDas['estimatedValueCents'] as num?)?.toInt() ?? 0;
    final dueDate = meiDas['dueDate']?.toString() ?? '';
    final currentBalance = confirmedPayments - operationalExpense;

    return ListView(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            AppMetricCard(
              label: 'Entradas do mes',
              value: _money(confirmedPayments),
              caption: 'Receitas confirmadas no periodo',
            ),
            AppMetricCard(
              label: 'Saidas do mes',
              value: _money(operationalExpense),
              caption: 'Despesas registradas no periodo',
            ),
            AppMetricCard(
              label: 'Saldo atual',
              value: _money(currentBalance),
              caption: 'Leitura simples do caixa operacional',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'DAS do MEI',
          subtitle:
              'Controle simples do DAS. A emissao oficial continua no portal do Simples Nacional.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip('Status', _meiDasStatusLabel(dasStatus)),
                  _meiSummaryChip('Valor estimado', _money(dasValue)),
                  _meiSummaryChip(
                    'Vencimento',
                    dueDate.trim().isEmpty ? 'Nao informado' : dueDate,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _openDasPortal,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Emitir DAS oficial'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/tasks'),
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Criar tarefa'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/clients'),
                    icon: const Icon(Icons.apartment_outlined),
                    label: const Text('Cadastrar cliente'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/billing'),
                    icon: const Icon(Icons.autorenew_outlined),
                    label: const Text('Gerar cobranca'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Resumo rapido do MEI',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusPill(
                'O fluxo MEI mantem os modulos gerais do sistema. O que muda aqui e a leitura inicial mais simples, com destaque para DAS e operacao essencial.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Tarefas abertas no momento: $pendingTasks. Faturamento previsto: ${_money(scheduledPayments)}.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Financeiro, fiscal, faturamento, contador, assistente e demais modulos continuam disponiveis quando fizerem sentido para a empresa.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Use o assistente para lembretes, orientacao operacional e duvidas de uso do sistema.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openDasPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.pgmeiEmissaoDas);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEcacPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.ecacLogin);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPgdasPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.simplesNacionalPgdasGrupo);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReceitaFederalPaymentsPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.ecacLogin);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDctfWebPortal() async {
    final uri = Uri.parse(
      'https://servicos.receitafederal.gov.br/login?redirectUrl=https%3A%2F%2Fcav.receita.fazenda.gov.br%2FeCAC%2Fpublico%2Flogin.aspx%3Fsistema%3D126',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReceitaServicesPortal() async {
    final uri = Uri.parse('https://servicos.receitafederal.gov.br/home');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReceitaTaxAgendaPortal() async {
    final year = DateTime.now().year;
    final uri = Uri.parse(
      'https://www.gov.br/receitafederal/pt-br/assuntos/agenda-tributaria/$year',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReceitaFederalAuthorizationsPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.ecacLogin);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openIntegraContadorPortal() async {
    final uri = Uri.parse(
      'https://loja.serpro.gov.br/integracontador',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNfsePortal() async {
    final uri = Uri.parse('https://www.nfse.gov.br/EmissorNacional');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNfseApiDocsPortal() async {
    final uri = Uri.parse(
      'https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual/documentacao-atual',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNfseIntegrationPortal() async {
    final uri = Uri.parse(
      'https://www.gov.br/nfse/pt-br/municipios/produtos-disponiveis/api-de-integracao',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDasnSimeiPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.dasnSimei);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEsocialPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.esocialPortal);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openFgtsDigitalPortal() async {
    final uri = Uri.parse('https://www.gov.br/fgtsdigital');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleAccountantMonthlyChecklistItem({
    required BuildContext context,
    required String companyId,
    required String competenceKey,
    required _AccountantMonthlyChecklistItem item,
    required bool done,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(companyId)
          .set({
            'accountantMonthlyControl': {
              competenceKey: {
                item.id: {
                  'done': done,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': ref.read(sessionProvider)?.userId,
                  'updatedByName': ref.read(sessionProvider)?.nome,
                  'label': item.title,
                },
              },
            },
          }, SetOptions(merge: true));
      if (!context.mounted) return;
      context.showUserMessage(
        done
            ? '${item.title} marcada como feita.'
            : '${item.title} voltou para pendente.',
      );
    } catch (e) {
      if (!context.mounted) return;
      context.showUserError(
        AppErrorMapper.messageFrom(
          e,
          fallback:
              'Nao foi possivel salvar o controle mensal do escritorio.',
        ),
      );
    }
  }

  String _meiDasStatusLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'pago' => 'Pago',
      'atrasado' => 'Atrasado',
      _ => 'Pendente',
    };
  }

  Widget _meiSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD3DDF3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF51627E)),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPainelContador(
    BuildContext context, {
    required Map<String, dynamic> companySettings,
    required int billingPending,
    required int billingReceived,
    required int payrollContestedAmount,
  }) {
    final companyExperience = CompanyExperience.fromSettings(companySettings);
    final fiscalFeatures =
        (companySettings['fiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final realIntegration =
        (companySettings['fiscalRealIntegration'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final meiDasRaw = companySettings['meiDas'];
    final meiDas = meiDasRaw is Map
        ? meiDasRaw.cast<String, dynamic>()
        : const <String, dynamic>{};
    final fiscalReady =
        fiscalFeatures['enableOfficialInvoicePrep'] == true &&
        (realIntegration['provider']?.toString().isNotEmpty ?? false);
    final environment =
        realIntegration['environment']?.toString().trim().isNotEmpty == true
        ? realIntegration['environment']!.toString()
        : 'nao configurado';
    final provider =
        realIntegration['provider']?.toString().trim().isNotEmpty == true
        ? realIntegration['provider']!.toString()
        : 'nao configurado';
    final companyData =
        (companySettings['companyData'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final taxRegime = [
      companyData['regimeTributario']?.toString().trim() ?? '',
      companyData['taxRegime']?.toString().trim() ?? '',
      companySettings['taxRegime']?.toString().trim() ?? '',
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final isSimplesNacional =
        !companyExperience.isMei && taxRegime.toLowerCase().contains('simples');
    final meiDueDate = meiDas['dueDate']?.toString().trim() ?? '';
    final meiStatus = _meiDasStatusLabel(
      meiDas['status']?.toString() ?? 'pendente',
    );
    final meiEstimatedValue =
        (meiDas['estimatedValueCents'] as num?)?.toInt() ?? 0;
    final people = ref.watch(employeesProvider);
    final activeOperationalEmployees = people
        .where((employee) => employee.ativo && employee.isOperationalTeam)
        .length;
    final hasPayrollRoutine = activeOperationalEmployees > 0;
    final annualWorkflow = _buildAccountantAnnualWorkflow(
      companyExperience: companyExperience,
      isSimplesNacional: isSimplesNacional,
      hasPayrollRoutine: hasPayrollRoutine,
      activeOperationalEmployees: activeOperationalEmployees,
    );
    final complianceItems = _buildAccountantComplianceItems(
      companyExperience: companyExperience,
      companyData: companyData,
      isSimplesNacional: isSimplesNacional,
      hasPayrollRoutine: hasPayrollRoutine,
      activeOperationalEmployees: activeOperationalEmployees,
      fiscalReady: fiscalReady,
      meiStatus: meiStatus,
      meiDueDate: meiDueDate,
    );
    final complianceOkCount = complianceItems
        .where((item) => item.status == _AccountantComplianceStatus.ok)
        .length;
    final complianceActionCount = complianceItems
        .where((item) => item.status == _AccountantComplianceStatus.action)
        .length;
    final competenceKey = _currentCompetenceKey();
    final monthlyControl =
        (companySettings['accountantMonthlyControl'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final competenceControl =
        (monthlyControl[competenceKey] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final monthlyChecklist = _buildAccountantMonthlyChecklist(
      companyExperience: companyExperience,
      isSimplesNacional: isSimplesNacional,
      hasPayrollRoutine: hasPayrollRoutine,
      fiscalReady: fiscalReady,
      companyData: companyData,
      competenceControl: competenceControl,
    );
    final monthlyDoneCount = monthlyChecklist.where((item) => item.done).length;
    final receitaRadar =
        (companySettings['receitaFederalRadar'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final radarOfficialSource =
        receitaRadar['officialSource']?.toString().trim().isNotEmpty == true
        ? receitaRadar['officialSource']!.toString().trim()
        : 'Integra Contador / Receita Federal';
    final radarIntegrationActive =
        receitaRadar['integrationActive'] as bool? ?? false;
    final radarMonitoringActive =
        receitaRadar['automaticMonitoringActive'] as bool? ?? false;
    final radarProxyGranted = receitaRadar['proxyGranted'] as bool? ?? false;
    final radarCertificateReady =
        receitaRadar['certificateReady'] as bool? ?? false;
    final radarSerproContractActive =
        receitaRadar['serproContractActive'] as bool? ?? false;
    final radarApiCredentialsConfigured =
        receitaRadar['apiCredentialsConfigured'] as bool? ?? false;
    final radarServiceScopesReady =
        receitaRadar['serviceScopesReady'] as bool? ?? false;
    final radarParcelamentoMonitoring =
        receitaRadar['monitorParcelamentos'] as bool? ?? false;
    final radarPaymentsMonitoring =
        receitaRadar['monitorConfirmedPayments'] as bool? ?? false;
    final radarPendingMonitoring =
        receitaRadar['monitorPendencies'] as bool? ?? false;
    final radarLastSyncLabel =
        receitaRadar['lastSyncLabel']?.toString().trim().isNotEmpty == true
        ? receitaRadar['lastSyncLabel']!.toString().trim()
        : 'Sem sincronizacao oficial ainda';
    final nfseRadar =
        (companySettings['nfseRadar'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final nfseNationalApiActive =
        nfseRadar['nationalApiActive'] as bool? ?? false;
    final nfseCertificateA1Ready =
        nfseRadar['certificateA1Ready'] as bool? ?? false;
    final nfseAutomaticCollectionActive =
        nfseRadar['automaticCollectionActive'] as bool? ?? false;
    final nfseCloudSyncActive = nfseRadar['cloudSyncActive'] as bool? ?? false;
    final nfseLocalBackupAgentReady =
        nfseRadar['localBackupAgentReady'] as bool? ?? false;
    final nfseTakenInvoicesActive =
        nfseRadar['takenInvoicesActive'] as bool? ?? false;
    final nfseIssuedInvoicesActive =
        nfseRadar['issuedInvoicesActive'] as bool? ?? false;
    final nfseOtherMunicipalitiesActive =
        nfseRadar['otherMunicipalitiesActive'] as bool? ?? false;
    final nfseAccountingIntegrationLabel =
        nfseRadar['accountingIntegrationLabel']?.toString().trim().isNotEmpty ==
            true
        ? nfseRadar['accountingIntegrationLabel']!.toString().trim()
        : 'Exportacao / conectores a configurar';
    final nfseCoverageLabel =
        nfseRadar['coverageLabel']?.toString().trim().isNotEmpty == true
        ? nfseRadar['coverageLabel']!.toString().trim()
        : 'Ambiente nacional + municipios suportados';
    final nfseLastSyncLabel =
        nfseRadar['lastSyncLabel']?.toString().trim().isNotEmpty == true
        ? nfseRadar['lastSyncLabel']!.toString().trim()
        : 'Sem leitura automatica ainda';

    return ListView(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            AppMetricCard(
              label: 'A receber',
              value: _money(billingPending),
              caption: 'Entradas ainda em aberto',
            ),
            AppMetricCard(
              label: 'Recebido',
              value: _money(billingReceived),
              caption: 'Entradas ja registradas',
            ),
            AppMetricCard(
              label: 'Contestacoes',
              value: _money(payrollContestedAmount),
              caption: 'Pagamentos com revisao pendente',
            ),
            AppMetricCard(
              label: 'Fiscal',
              value: fiscalReady ? 'Pronto' : 'Revisar',
              caption: 'Ambiente $environment',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Acessos do contador',
          subtitle:
              'Esse perfil concentra carteira do escritorio, cadastro de empresa, apoio ao faturamento e rotina fiscal.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/billing'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Abrir faturamento'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/fiscal'),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Abrir fiscal'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/assistant'),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Abrir assistente'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/improvements'),
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: const Text('Abrir ideias'),
              ),
              if ((ref.watch(sessionProvider)) != null &&
                  hasSupremePlatformAccess(ref.watch(sessionProvider)!))
                FilledButton.icon(
                  onPressed: () => context.go('/runtime-incidents'),
                  icon: const Icon(Icons.sensors_outlined),
                  label: const Text('Abrir observabilidade'),
                ),
              FilledButton.icon(
                onPressed: () => context.go('/accountant-companies'),
                icon: const Icon(Icons.domain_outlined),
                label: const Text('Empresas do contador'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/accountant-fiscal-profile'),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Perfil fiscal'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/accountant-register-company'),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Cadastrar empresa'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Impostos e guias',
          subtitle: companyExperience.isMei
              ? 'Fluxo oficial do MEI para emissao do DAS e consulta de comprovantes pelos canais da Receita.'
              : isSimplesNacional
              ? 'Fluxo mais usado por contadores no Simples: PGDAS-D, DCTFWeb, comprovantes e autorizacoes da Receita.'
              : 'Fluxo oficial da Receita para empresa: e-CAC, DCTFWeb, comprovantes e autorizacoes de acesso.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: companyExperience.isMei
                    ? [
                        _meiSummaryChip('Perfil', 'MEI'),
                        _meiSummaryChip('Status do DAS', meiStatus),
                        _meiSummaryChip(
                          'Valor estimado',
                          _money(meiEstimatedValue),
                        ),
                        _meiSummaryChip(
                          'Vencimento',
                          meiDueDate.isEmpty ? 'Nao informado' : meiDueDate,
                        ),
                      ]
                    : [
                        _meiSummaryChip('Perfil', 'EMPRESA'),
                        _meiSummaryChip(
                          'Situacao fiscal',
                          fiscalReady ? 'Pronta para emissao' : 'Revisar base',
                        ),
                        _meiSummaryChip('Ambiente', environment),
                        _meiSummaryChip('Provedor', provider),
                      ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: companyExperience.isMei
                    ? [
                        FilledButton.icon(
                          onPressed: _openDasPortal,
                          icon: const Icon(Icons.open_in_new_outlined),
                          label: const Text('Emitir DAS oficial'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openReceitaFederalPaymentsPortal,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Consultar comprovantes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/fiscal'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Abrir fiscal'),
                        ),
                      ]
                    : [
                        FilledButton.icon(
                          onPressed: isSimplesNacional
                              ? _openPgdasPortal
                              : _openEcacPortal,
                          icon: const Icon(Icons.open_in_new_outlined),
                          label: Text(
                            isSimplesNacional ? 'Abrir PGDAS-D' : 'Entrar no e-CAC',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openDctfWebPortal,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('DCTFWeb'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openReceitaFederalPaymentsPortal,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Pagamentos e comprovantes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openReceitaFederalAuthorizationsPortal,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Procuracoes e autorizacoes'),
                        ),
                      ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: companyExperience.isMei
                    ? [
                        _statusPill(
                          '`Emitir DAS oficial` abre o PGMEI (emissao) no site da Receita: geracao da guia DAS do MEI.',
                        ),
                        const SizedBox(height: 10),
                        _statusPill(
                          '`Consultar comprovantes` abre o login do e-CAC; em Pagamentos e parcelamentos, use a consulta de comprovante de DAS/DARF.',
                        ),
                      ]
                    : [
                        _statusPill(
                          isSimplesNacional
                              ? '`Abrir PGDAS-D` entra no ambiente real de apuracao do Simples Nacional para calcular a receita da competencia e emitir o DAS.'
                              : '`Entrar no e-CAC` abre o ambiente oficial real da Receita para a rotina tributaria da empresa.',
                        ),
                        const SizedBox(height: 10),
                        _statusPill(
                          '`DCTFWeb` entra no fluxo real de fechamento, conferencia de totalizadores e emissao de DARF quando a obrigacao passar por essa trilha.',
                        ),
                        const SizedBox(height: 10),
                        _statusPill(
                          '`Procuracoes e autorizacoes` abre o login do e-CAC para procuracoes e liberacoes de acesso exigidas pela Receita.',
                        ),
                      ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Radar Receita Federal',
          subtitle:
              'Monitoramento oficial de pendencias, parcelamentos e comprovantes so deve rodar por integracao autorizada. Nada de scraping do e-CAC.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip(
                    'Contrato Serpro',
                    radarSerproContractActive ? 'Ativo' : 'Necessario',
                  ),
                  _meiSummaryChip('Fonte oficial', radarOfficialSource),
                  _meiSummaryChip(
                    'Integracao',
                    radarIntegrationActive ? 'Ativa' : 'Aguardando ativacao',
                  ),
                  _meiSummaryChip(
                    'Monitoramento',
                    radarMonitoringActive ? 'Automatico' : 'Ainda nao ativo',
                  ),
                  _meiSummaryChip('Ultima leitura', radarLastSyncLabel),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _openIntegraContadorPortal,
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('Abrir Integra Contador'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openReceitaFederalAuthorizationsPortal,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Procuracoes e-CAC'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openEcacPortal,
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Entrar no e-CAC'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip(
                    'Pendencias',
                    radarPendingMonitoring
                        ? 'Monitoradas'
                        : 'Preparar integracao',
                  ),
                  _meiSummaryChip(
                    'Parcelamentos',
                    radarParcelamentoMonitoring
                        ? 'Monitorados'
                        : 'Preparar integracao',
                  ),
                  _meiSummaryChip(
                    'Pagamentos',
                    radarPaymentsMonitoring
                        ? 'Comprovados automaticamente'
                        : 'Sem leitura oficial automatica',
                  ),
                  _meiSummaryChip(
                    'Procuracao',
                    radarProxyGranted ? 'Conferida' : 'Pendente',
                  ),
                  _meiSummaryChip(
                    'e-CNPJ',
                    radarCertificateReady ? 'Pronto' : 'Revisar certificado',
                  ),
                  _meiSummaryChip(
                    'Credenciais API',
                    radarApiCredentialsConfigured
                        ? 'Configuradas'
                        : 'Pendentes',
                  ),
                  _meiSummaryChip(
                    'Escopos oficiais',
                    radarServiceScopesReady
                        ? 'Liberados'
                        : 'Revisar contratacao',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statusPill(
                radarIntegrationActive
                    ? 'Com a integracao oficial ativa, este radar acompanha pendencias, parcelamentos e comprovantes no fluxo oficial autorizado.'
                    : 'Sem integracao oficial ativa, o sistema deve orientar apenas os acessos reais da Receita e do Serpro.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Para automatizar de verdade, o escritorio precisa de contratacao ativa no Integra Contador, certificado digital e-CNPJ e credenciais oficiais da API liberadas pelo Serpro. Essa base do escritorio pode ficar centralizada no Perfil fiscal e valer para todas as empresas vinculadas.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'A procuracao digital da empresa no e-CAC continua obrigatoria para os servicos que exigem autorizacao do contribuinte.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Login pessoal de gov.br ou senha de e-CAC do contador nao substituem a integracao oficial e nao devem ser armazenados no sistema.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Radar NFS-e do escritorio',
          subtitle:
              'Busca automatica de notas prestadas, tomadas e eventos fiscais deve seguir o ambiente nacional da NFS-e e os conectores municipais suportados.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip(
                    'API nacional',
                    nfseNationalApiActive ? 'Ativa' : 'Preparar integracao',
                  ),
                  _meiSummaryChip(
                    'Certificado A1',
                    nfseCertificateA1Ready ? 'Configurado' : 'Pendente',
                  ),
                  _meiSummaryChip(
                    'Coleta automatica',
                    nfseAutomaticCollectionActive ? 'Ativa' : 'Nao ativa',
                  ),
                  _meiSummaryChip('Cobertura', nfseCoverageLabel),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _openNfsePortal,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Portal NFS-e'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openNfseIntegrationPortal,
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('API NFS-e'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openNfseApiDocsPortal,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Documentacao'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip(
                    'Notas prestadas',
                    nfseIssuedInvoicesActive ? 'Monitoradas' : 'Nao ativas',
                  ),
                  _meiSummaryChip(
                    'Notas tomadas',
                    nfseTakenInvoicesActive ? 'Monitoradas' : 'Nao ativas',
                  ),
                  _meiSummaryChip(
                    'Outros municipios',
                    nfseOtherMunicipalitiesActive
                        ? 'Cobertos'
                        : 'Depende do conector',
                  ),
                  _meiSummaryChip(
                    'Nuvem',
                    nfseCloudSyncActive ? 'Sincronizada' : 'Nao configurada',
                  ),
                  _meiSummaryChip(
                    'Backup local',
                    nfseLocalBackupAgentReady
                        ? 'Agente pronto'
                        : 'Exige agente desktop',
                  ),
                  _meiSummaryChip(
                    'Integracao contabil',
                    nfseAccountingIntegrationLabel,
                  ),
                  _meiSummaryChip('Ultima leitura', nfseLastSyncLabel),
                ],
              ),
              const SizedBox(height: 12),
              _statusPill(
                'O fluxo real de consulta e emissao deve priorizar o Ambiente Nacional da NFS-e e usar conector municipal apenas quando o municipio nao estiver coberto ali.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'O certificado A1 do cliente deve ficar protegido em servico seguro. Nao faz sentido capturar esse certificado diretamente pelo navegador sem camada protegida.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Backup em nuvem pode ficar no servidor. Backup automatico na maquina do contador exige agente desktop instalado no computador do escritorio.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Integracao com sistemas contabeis depende de conector por fornecedor. O modulo deve centralizar a coleta e depois exportar ou sincronizar conforme o sistema do escritorio.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Rotina anual do escritorio',
          subtitle: companyExperience.isMei
              ? 'Organiza o que costuma cair na mesa do contador para manter o MEI regular durante o ano.'
              : 'Mostra a rotina tributaria e trabalhista mais comum do escritorio para manter a empresa em dia ao longo do ano.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip(
                    'Regime',
                    companyExperience.isMei
                        ? 'MEI'
                        : isSimplesNacional
                        ? 'Simples Nacional'
                        : 'Lucro presumido / outros',
                  ),
                  _meiSummaryChip(
                    'Equipe ativa',
                    activeOperationalEmployees == 0
                        ? 'Sem colaboradores'
                        : '$activeOperationalEmployees colaboradores',
                  ),
                  _meiSummaryChip(
                    'Folha oficial',
                    hasPayrollRoutine ? 'eSocial + FGTS' : 'Nao priorizada',
                  ),
                  _meiSummaryChip(
                    'Agenda fiscal',
                    'Ano ${DateTime.now().year}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _openReceitaTaxAgendaPortal,
                    icon: const Icon(Icons.event_note_outlined),
                    label: const Text('Abrir agenda tributaria'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openReceitaServicesPortal,
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Servicos da Receita'),
                  ),
                  if (hasPayrollRoutine) ...[
                    OutlinedButton.icon(
                      onPressed: _openEsocialPortal,
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('eSocial'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openFgtsDigitalPortal,
                      icon: const Icon(Icons.pix_outlined),
                      label: const Text('FGTS Digital'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in annualWorkflow)
                    _accountantRoutineCard(entry),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Fechamento da competencia atual',
          subtitle:
              'Controle persistente do que o escritorio ja fechou em ${_formatCompetenceLabel(competenceKey)} para esta empresa.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip(
                    'Competencia',
                    _formatCompetenceLabel(competenceKey),
                  ),
                  _meiSummaryChip(
                    'Feitos',
                    '$monthlyDoneCount de ${monthlyChecklist.length}',
                  ),
                  _meiSummaryChip(
                    'Pendentes',
                    '${monthlyChecklist.length - monthlyDoneCount}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in monthlyChecklist)
                    _accountantMonthlyChecklistCard(
                      context,
                      companyId: ref.read(sessionProvider)?.companyId ?? '',
                      competenceKey: competenceKey,
                      item: item,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Controle do escritorio',
          subtitle:
              'Leitura rapida do que esta em dia, do que pede acao agora e do que ainda depende de conferencia externa nos portais oficiais.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _meiSummaryChip('Em dia', complianceOkCount.toString()),
                  _meiSummaryChip(
                    'Pede acao',
                    complianceActionCount.toString(),
                  ),
                  _meiSummaryChip(
                    'Empresa atual',
                    companyData['nomeFantasia']?.toString().trim().isNotEmpty ==
                            true
                        ? companyData['nomeFantasia'].toString().trim()
                        : companyData['razaoSocial']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true
                        ? companyData['razaoSocial'].toString().trim()
                        : 'Sem nome confirmado',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in complianceItems)
                    _accountantComplianceCard(item),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppWorkspaceCard(
          title: 'Leitura fiscal da empresa',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusPill(
                fiscalReady
                    ? 'A empresa vinculada ja tem base fiscal pronta para conferencia e emissao.'
                    : 'A empresa vinculada ainda exige revisao de configuracao fiscal antes da emissao.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Esse painel nao mostra operacao de equipe, tarefas, contratos ou financeiro amplo da empresa.',
              ),
              const SizedBox(height: 10),
              _statusPill(
                'Use Faturamento para conferir a base da nota, Fiscal para emitir e Relatorios para leitura consolidada.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_AccountantRoutineEntry> _buildAccountantAnnualWorkflow({
    required CompanyExperience companyExperience,
    required bool isSimplesNacional,
    required bool hasPayrollRoutine,
    required int activeOperationalEmployees,
  }) {
    if (companyExperience.isMei) {
      return [
        _AccountantRoutineEntry(
          title: 'DAS do MEI',
          cadence: 'Todo mes',
          details:
              'Gerar a guia mensal no PGMEI e acompanhar comprovantes oficiais. O pagamento do DAS do MEI vence no dia 20.',
          actions: [
            _AccountantRoutineAction(
              label: 'Emitir DAS oficial',
              icon: Icons.open_in_new_outlined,
              onPressed: _openDasPortal,
            ),
            _AccountantRoutineAction(
              label: 'Comprovantes',
              icon: Icons.download_outlined,
              onPressed: _openReceitaFederalPaymentsPortal,
            ),
          ],
        ),
        _AccountantRoutineEntry(
          title: 'DASN-SIMEI',
          cadence: 'Todo ano',
          details:
              'Fechar a receita bruta do ano anterior e transmitir a declaracao anual do MEI ate o ultimo dia de maio.',
          actions: [
            _AccountantRoutineAction(
              label: 'Entregar DASN',
              icon: Icons.assignment_turned_in_outlined,
              onPressed: _openDasnSimeiPortal,
            ),
            _AccountantRoutineAction(
              label: 'Agenda anual',
              icon: Icons.event_note_outlined,
              onPressed: _openReceitaTaxAgendaPortal,
            ),
          ],
        ),
        if (hasPayrollRoutine)
          _AccountantRoutineEntry(
            title: 'MEI com empregado',
            cadence: 'Todo mes',
            details:
                'Fechar os eventos da folha no eSocial e recolher o FGTS no FGTS Digital para $activeOperationalEmployees colaborador(es) ativo(s).',
            actions: [
              _AccountantRoutineAction(
                label: 'Abrir eSocial',
                icon: Icons.badge_outlined,
                onPressed: _openEsocialPortal,
              ),
              _AccountantRoutineAction(
                label: 'Abrir FGTS',
                icon: Icons.pix_outlined,
                onPressed: _openFgtsDigitalPortal,
              ),
            ],
          ),
        _AccountantRoutineEntry(
          title: 'Acesso e regularidade',
          cadence: 'Sempre que entrar em nova empresa',
          details:
              'Formalizar procuracao e entrar nos servicos oficiais da Receita para revisar comprovantes, pendencias e acessos do escritorio.',
          actions: [
            _AccountantRoutineAction(
              label: 'Autorizacoes',
              icon: Icons.verified_user_outlined,
              onPressed: _openReceitaFederalAuthorizationsPortal,
            ),
            _AccountantRoutineAction(
              label: 'Servicos da Receita',
              icon: Icons.account_balance_outlined,
              onPressed: _openReceitaServicesPortal,
            ),
          ],
        ),
      ];
    }

    final entries = <_AccountantRoutineEntry>[
      _AccountantRoutineEntry(
        title: isSimplesNacional ? 'PGDAS-D e DAS' : 'Tributos federais',
        cadence: 'Todo mes',
        details: isSimplesNacional
            ? 'Apurar a receita no PGDAS-D e gerar o DAS da empresa, inclusive em mes sem faturamento.'
            : 'Entrar nos servicos oficiais da Receita para cumprir a rotina real dos tributos da empresa e acompanhar o que precisa ser apurado e recolhido.',
        actions: [
          _AccountantRoutineAction(
            label: isSimplesNacional ? 'Abrir PGDAS-D' : 'Servicos da Receita',
            icon: Icons.open_in_new_outlined,
            onPressed: isSimplesNacional
                ? _openPgdasPortal
                : _openReceitaServicesPortal,
          ),
          _AccountantRoutineAction(
            label: 'Agenda anual',
            icon: Icons.event_note_outlined,
            onPressed: _openReceitaTaxAgendaPortal,
          ),
        ],
      ),
      if (isSimplesNacional)
        _AccountantRoutineEntry(
          title: 'DEFIS',
          cadence: 'Todo ano',
          details:
              'Fechar os dados do ano anterior e entregar a DEFIS ate o ultimo dia de marco pelo mesmo ambiente do PGDAS-D.',
          actions: [
            _AccountantRoutineAction(
              label: 'DEFIS',
              icon: Icons.assignment_turned_in_outlined,
              onPressed: _openPgdasPortal,
            ),
            _AccountantRoutineAction(
              label: 'Agenda anual',
              icon: Icons.event_note_outlined,
              onPressed: _openReceitaTaxAgendaPortal,
            ),
          ],
        ),
      _AccountantRoutineEntry(
        title: 'DCTFWeb e regularidade',
        cadence: 'Todo mes',
        details:
            'Entrar na DCTFWeb para conferir totalizadores de eSocial/Reinf, emitir DARF quando aplicavel e revisar pendencias reais da empresa nos servicos da Receita.',
        actions: [
          _AccountantRoutineAction(
            label: 'DCTFWeb',
            icon: Icons.receipt_long_outlined,
            onPressed: _openDctfWebPortal,
          ),
          _AccountantRoutineAction(
            label: 'Servicos da Receita',
            icon: Icons.account_balance_outlined,
            onPressed: _openReceitaServicesPortal,
          ),
        ],
      ),
      _AccountantRoutineEntry(
        title: 'Procuracao do escritorio',
        cadence: 'Na entrada e troca de responsavel',
        details:
            'Garantir acesso formal do escritorio aos servicos da empresa para evitar bloqueio de operacao no meio do mes.',
        actions: [
          _AccountantRoutineAction(
            label: 'Autorizacoes',
            icon: Icons.verified_user_outlined,
            onPressed: _openReceitaFederalAuthorizationsPortal,
          ),
        ],
      ),
    ];

    if (hasPayrollRoutine) {
      entries.insert(
        isSimplesNacional ? 2 : 1,
        _AccountantRoutineEntry(
          title: 'Folha, eSocial e FGTS',
          cadence: 'Todo mes',
          details:
              'Fechar eventos trabalhistas no eSocial e recolher FGTS pelo FGTS Digital para $activeOperationalEmployees colaborador(es) ativo(s).',
          actions: [
            _AccountantRoutineAction(
              label: 'Abrir eSocial',
              icon: Icons.badge_outlined,
              onPressed: _openEsocialPortal,
            ),
            _AccountantRoutineAction(
              label: 'Abrir FGTS',
              icon: Icons.pix_outlined,
              onPressed: _openFgtsDigitalPortal,
            ),
          ],
        ),
      );
    }

    return entries;
  }

  List<_AccountantMonthlyChecklistItem> _buildAccountantMonthlyChecklist({
    required CompanyExperience companyExperience,
    required bool isSimplesNacional,
    required bool hasPayrollRoutine,
    required bool fiscalReady,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> competenceControl,
  }) {
    bool doneFor(String id) {
      final map = (competenceControl[id] as Map?)?.cast<String, dynamic>();
      return map?['done'] == true;
    }

    final companyHasMainData =
        !_isBlank(companyData['cnpj']?.toString()) &&
        !_isBlank(
          companyData['razaoSocial']?.toString().trim().isNotEmpty == true
              ? companyData['razaoSocial']?.toString()
              : companyData['nomeFantasia']?.toString(),
        );

    return [
      _AccountantMonthlyChecklistItem(
        id: 'cadastro_revisado',
        title: 'Cadastro revisado',
        details:
            'Confirme CNPJ, nome empresarial e dados principais antes do fechamento da competencia.',
        done: doneFor('cadastro_revisado'),
        ready: companyHasMainData,
        notApplicable: false,
      ),
      if (companyExperience.isMei)
        _AccountantMonthlyChecklistItem(
          id: 'das_mei',
          title: 'DAS do MEI conferido',
          details:
              'Competencia mensal do MEI conferida e pronta para emissao ou comprovacao.',
          done: doneFor('das_mei'),
          ready: true,
          notApplicable: false,
        )
      else
        _AccountantMonthlyChecklistItem(
          id: isSimplesNacional ? 'pgdas' : 'tributos_federais',
          title: isSimplesNacional
              ? 'PGDAS-D / DAS conferido'
              : 'Tributos federais conferidos',
          details: isSimplesNacional
              ? 'Receita da competencia revisada no PGDAS-D.'
              : 'Rotina tributaria principal revisada no Portal Receita.',
          done: doneFor(isSimplesNacional ? 'pgdas' : 'tributos_federais'),
          ready: companyHasMainData,
          notApplicable: false,
        ),
      if (!companyExperience.isMei)
        _AccountantMonthlyChecklistItem(
          id: 'base_fiscal',
          title: 'Base fiscal pronta',
          details:
              'Configuracao fiscal e integracao da empresa prontas para fechar a emissao da competencia.',
          done: doneFor('base_fiscal'),
          ready: fiscalReady,
          notApplicable: false,
        ),
      _AccountantMonthlyChecklistItem(
        id: 'dctfweb',
        title: 'DCTFWeb revisada',
        details:
            'Conferencia da trilha DCTFWeb quando a empresa usa esse fechamento na competencia.',
        done: doneFor('dctfweb'),
        ready: !companyExperience.isMei,
        notApplicable: companyExperience.isMei,
      ),
      _AccountantMonthlyChecklistItem(
        id: 'folha_oficial',
        title: 'Folha oficial revisada',
        details:
            'Eventos de eSocial e recolhimento de FGTS revisados para a competencia atual.',
        done: doneFor('folha_oficial'),
        ready: hasPayrollRoutine,
        notApplicable: !hasPayrollRoutine,
      ),
      _AccountantMonthlyChecklistItem(
        id: 'comprovantes',
        title: 'Comprovantes organizados',
        details:
            'Separar ou conferir comprovantes oficiais da competencia para a empresa e o escritorio.',
        done: doneFor('comprovantes'),
        ready: true,
        notApplicable: false,
      ),
    ];
  }

  List<_AccountantComplianceItem> _buildAccountantComplianceItems({
    required CompanyExperience companyExperience,
    required Map<String, dynamic> companyData,
    required bool isSimplesNacional,
    required bool hasPayrollRoutine,
    required int activeOperationalEmployees,
    required bool fiscalReady,
    required String meiStatus,
    required String meiDueDate,
  }) {
    final companyName =
        companyData['razaoSocial']?.toString().trim() ??
        companyData['nomeFantasia']?.toString().trim() ??
        '';
    final cnpj = companyData['cnpj']?.toString().trim() ?? '';
    final taxRegime =
        companyData['regimeTributario']?.toString().trim().isNotEmpty == true
        ? companyData['regimeTributario'].toString().trim()
        : companyData['taxRegime']?.toString().trim();
    final municipalRegistration =
        companyData['inscricaoMunicipal']?.toString().trim() ?? '';

    return [
      _AccountantComplianceItem(
        title: 'Cadastro principal',
        status: companyName.isNotEmpty && cnpj.isNotEmpty
            ? _AccountantComplianceStatus.ok
            : _AccountantComplianceStatus.action,
        summary: companyName.isNotEmpty && cnpj.isNotEmpty
            ? 'Empresa com identificacao principal salva para o escritorio operar.'
            : 'Falta confirmar nome empresarial ou CNPJ na configuracao da empresa.',
        nextStep: companyName.isNotEmpty && cnpj.isNotEmpty
            ? 'Usar os dados atuais para documentos e conferencias.'
            : 'Revisar o cadastro da empresa antes do fechamento fiscal.',
      ),
      _AccountantComplianceItem(
        title: 'Regime tributario',
        status: companyExperience.isMei || !_isBlank(taxRegime)
            ? _AccountantComplianceStatus.ok
            : _AccountantComplianceStatus.action,
        summary: companyExperience.isMei
            ? 'Empresa classificada como MEI.'
            : !_isBlank(taxRegime)
            ? 'Regime definido como $taxRegime.'
            : 'Regime ainda nao confirmado na configuracao da empresa.',
        nextStep: companyExperience.isMei
            ? 'Seguir a rotina de DAS mensal e DASN-SIMEI anual.'
            : !_isBlank(taxRegime)
            ? (isSimplesNacional
                  ? 'Entrar em PGDAS-D e DEFIS como fluxo real principal.'
                  : 'Entrar nos servicos da Receita e na DCTFWeb conforme a obrigacao.')
            : 'Validar o regime com a empresa antes de apurar os tributos.',
      ),
      _AccountantComplianceItem(
        title: companyExperience.isMei ? 'Guia mensal do MEI' : 'Base fiscal',
        status: companyExperience.isMei
            ? switch (meiStatus) {
                'Pago' => _AccountantComplianceStatus.ok,
                'Atrasado' => _AccountantComplianceStatus.action,
                _ => _AccountantComplianceStatus.monitor,
              }
            : fiscalReady
            ? _AccountantComplianceStatus.ok
            : _AccountantComplianceStatus.action,
        summary: companyExperience.isMei
            ? 'Status atual do DAS: $meiStatus${meiDueDate.isEmpty ? '' : ' | vencimento $meiDueDate'}.'
            : fiscalReady
            ? 'Ambiente fiscal configurado para preparacao e emissao.'
            : 'A base fiscal ainda precisa de revisao antes da emissao.',
        nextStep: companyExperience.isMei
            ? (meiStatus == 'Pago'
                  ? 'Manter comprovantes e seguir para a proxima competencia.'
                  : meiStatus == 'Atrasado'
                  ? 'Emitir a guia oficial e regularizar a competencia em aberto.'
                  : 'Conferir a competencia atual e emitir a guia no PGMEI.')
            : (fiscalReady
                  ? 'Usar Fiscal e Faturamento para fechar a nota da empresa.'
                  : 'Completar a configuracao fiscal e as integracoes oficiais da empresa.'),
      ),
      _AccountantComplianceItem(
        title: 'Inscricao municipal',
        status: companyExperience.isMei
            ? _AccountantComplianceStatus.notApplicable
            : municipalRegistration.isNotEmpty
            ? _AccountantComplianceStatus.ok
            : _AccountantComplianceStatus.action,
        summary: companyExperience.isMei
            ? 'Nao priorizada no fluxo padrao do MEI.'
            : municipalRegistration.isNotEmpty
            ? 'Inscricao municipal salva na configuracao da empresa.'
            : 'Nao ha inscricao municipal confirmada na base atual.',
        nextStep: companyExperience.isMei
            ? 'Seguir apenas com os canais oficiais do MEI quando aplicavel.'
            : municipalRegistration.isNotEmpty
            ? 'Usar o dado atual na conferencia de emissao.'
            : 'Conferir se a prefeitura exige esse dado para a emissao da empresa.',
      ),
      _AccountantComplianceItem(
        title: 'Folha oficial',
        status: hasPayrollRoutine
            ? _AccountantComplianceStatus.monitor
            : _AccountantComplianceStatus.notApplicable,
        summary: hasPayrollRoutine
            ? '$activeOperationalEmployees colaborador(es) ativo(s) pedem rotina mensal de eSocial e FGTS Digital.'
            : 'Sem colaboradores operacionais ativos no contexto atual.',
        nextStep: hasPayrollRoutine
            ? 'Fechar eventos no eSocial e recolher o FGTS no portal oficial.'
            : 'Nao ha fechamento mensal de folha priorizado para esta empresa agora.',
      ),
      const _AccountantComplianceItem(
        title: 'Acesso do escritorio',
        status: _AccountantComplianceStatus.monitor,
        summary:
            'O sistema ajuda na operacao, mas a procuracao e os acessos oficiais ainda dependem de conferencia no Gov.br / Receita.',
        nextStep:
            'Revisar autorizacoes e acesso real aos servicos da Receita antes de cada fechamento critico.',
      ),
    ];
  }

  Widget _accountantComplianceCard(_AccountantComplianceItem item) {
    final palette = switch (item.status) {
      _AccountantComplianceStatus.ok => const (
        bg: Color(0xFFE8F7EE),
        border: Color(0xFF9DD3B0),
        ink: Color(0xFF166534),
        label: 'Em dia',
      ),
      _AccountantComplianceStatus.action => const (
        bg: Color(0xFFFFF1E8),
        border: Color(0xFFF4B183),
        ink: Color(0xFF9A3412),
        label: 'Pede acao',
      ),
      _AccountantComplianceStatus.monitor => const (
        bg: Color(0xFFEAF2FF),
        border: Color(0xFFA8C5FF),
        ink: Color(0xFF1D4ED8),
        label: 'Acompanhar',
      ),
      _AccountantComplianceStatus.notApplicable => const (
        bg: Color(0xFFF4F6F8),
        border: Color(0xFFD7DEE7),
        ink: Color(0xFF51627E),
        label: 'Nao se aplica',
      ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD3DDF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                palette.label,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppBrandColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.summary,
              style: const TextStyle(
                height: 1.4,
                color: AppBrandColors.softText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.nextStep,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppBrandColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountantMonthlyChecklistCard(
    BuildContext context, {
    required String companyId,
    required String competenceKey,
    required _AccountantMonthlyChecklistItem item,
  }) {
    final palette = item.notApplicable
        ? const (
            bg: Color(0xFFF4F6F8),
            border: Color(0xFFD7DEE7),
            ink: Color(0xFF51627E),
            label: 'Nao se aplica',
          )
        : item.done
        ? const (
            bg: Color(0xFFE8F7EE),
            border: Color(0xFF9DD3B0),
            ink: Color(0xFF166534),
            label: 'Feito',
          )
        : item.ready
        ? const (
            bg: Color(0xFFFFF1E8),
            border: Color(0xFFF4B183),
            ink: Color(0xFF9A3412),
            label: 'Pendente',
          )
        : const (
            bg: Color(0xFFEAF2FF),
            border: Color(0xFFA8C5FF),
            ink: Color(0xFF1D4ED8),
            label: 'Depende de base',
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD3DDF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                palette.label,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppBrandColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.details,
              style: const TextStyle(
                height: 1.4,
                color: AppBrandColors.softText,
              ),
            ),
            const SizedBox(height: 12),
            if (!item.notApplicable)
              item.done
                  ? OutlinedButton.icon(
                      onPressed: () => _toggleAccountantMonthlyChecklistItem(
                        context: context,
                        companyId: companyId,
                        competenceKey: competenceKey,
                        item: item,
                        done: false,
                      ),
                      icon: const Icon(Icons.undo_outlined),
                      label: const Text('Voltar para pendente'),
                    )
                  : FilledButton.icon(
                      onPressed: item.ready
                          ? () => _toggleAccountantMonthlyChecklistItem(
                              context: context,
                              companyId: companyId,
                              competenceKey: competenceKey,
                              item: item,
                              done: true,
                            )
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        item.ready ? 'Marcar como feito' : 'Aguardar base',
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  String _currentCompetenceKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  String _formatCompetenceLabel(String value) {
    final parts = value.split('-');
    if (parts.length != 2) return value;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 0;
    const months = <String>[
      '',
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    final monthLabel = month >= 1 && month <= 12 ? months[month] : parts[1];
    return '$monthLabel/$year';
  }

  Widget _accountantRoutineCard(_AccountantRoutineEntry entry) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD3DDF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppBrandColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.cadence,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF51627E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              entry.details,
              style: const TextStyle(
                height: 1.4,
                color: AppBrandColors.softText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in entry.actions)
                  OutlinedButton.icon(
                    onPressed: () => action.onPressed(),
                    icon: Icon(action.icon),
                    label: Text(action.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _moduleModeLabel(String? mode) {
    return mode == 'advanced' ? 'Completo' : 'Simples';
  }

  String _financeStatusSummary(Map<String, dynamic> companySettings) {
    final raw = companySettings['financeFeatures'];
    final features = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final active = <String>[
      if (features['enablePayments'] as bool? ?? true) 'pagamentos',
      if (features['enableDebts'] as bool? ?? true) 'dividas',
      if (features['enableCompanyMovements'] as bool? ?? false) 'movimentos',
    ];
    return active.isEmpty
        ? 'Sem recursos operacionais ativos.'
        : 'Recursos ativos: ${active.join(', ')}.';
  }

  String _workforceStatusSummary(Map<String, dynamic> companySettings) {
    final raw = companySettings['workforceFeatures'];
    final features = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final active = <String>[
      if (features['enablePayrollClosures'] as bool? ?? false) 'fechamento',
      if (features['enableMonthlyDashboard'] as bool? ?? false) 'painel RH',
      if (features['enableContracts'] as bool? ?? false) 'contratos',
      if (features['enableAdvancedDocuments'] as bool? ?? false) 'documentos',
    ];
    return active.isEmpty
        ? 'Operacao trabalhista minima.'
        : 'Recursos ativos: ${active.join(', ')}.';
  }

  String _fiscalStatusSummary(Map<String, dynamic> companySettings) {
    final raw = companySettings['fiscalFeatures'];
    final features = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final active = <String>[
      if (features['enableOfficialInvoicePrep'] as bool? ?? true) 'NFS-e',
      if (features['enableRealInvoiceIntegration'] as bool? ?? false)
        'integracao real',
      if (features['enablePayrollTaxPrep'] as bool? ?? false) 'encargos',
      if (features['enableBenefits'] as bool? ?? false) 'beneficios',
    ];
    return active.isEmpty
        ? 'Operacao fiscal basica.'
        : 'Recursos ativos: ${active.join(', ')}.';
  }

  String _formatCurrency(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    final reaisTexto = reais.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'R\$ $reaisTexto,$centavos';
  }

  String _money(int cents) {
    if (_hideMoneyForLayout) {
      return r'R$ ••••';
    }
    return _formatCurrency(cents);
  }

  Widget _executiveOverviewChart({
    required List<_ExecutiveModuleMetric> modules,
  }) {
    final averageScore = modules.isEmpty
        ? 0
        : (modules.fold<double>(
                    0,
                    (totalScore, item) => totalScore + item.score,
                  ) /
                  modules.length)
              .round();
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: CustomPaint(
            painter: _ExecutiveRadarPainter(modules: modules),
            child: Center(
              child: Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.92),
                  border: Border.all(color: const Color(0xFFD8E6FF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12003088),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$averageScore%',
                      style: const TextStyle(
                        color: AppBrandColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ritmo medio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppBrandColors.softText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_ExecutiveModuleMetric> _executiveModules(
    Map<String, dynamic> companySettings,
    int tasksCount,
    int pendingTasks,
    int activeEmployees,
    int employeesCount,
    int scheduledPayments,
    int confirmedPayments,
    int contestedPayments,
  ) {
    final financeRatio = scheduledPayments <= 0
        ? 0.58
        : (confirmedPayments / scheduledPayments).clamp(0.0, 1.0);
    final contestedRatio = scheduledPayments <= 0
        ? 0.0
        : (contestedPayments / scheduledPayments).clamp(0.0, 0.4);
    final workforceRatio = employeesCount <= 0
        ? 0.35
        : (activeEmployees / employeesCount).clamp(0.0, 1.0);
    final tasksRatio = tasksCount <= 0
        ? 0.3
        : ((tasksCount - pendingTasks) / tasksCount).clamp(0.0, 1.0);
    final fiscalFeatures =
        (companySettings['fiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final realIntegration =
        (companySettings['fiscalRealIntegration'] as Map?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final fiscalReadiness =
        [
          fiscalFeatures['enableOfficialInvoicePrep'] == true,
          fiscalFeatures['enableRealInvoiceIntegration'] == true,
          (realIntegration['environment']?.toString().isNotEmpty ?? false),
          (realIntegration['provider']?.toString().isNotEmpty ?? false),
        ].where((value) => value).length /
        4;
    return [
      _ExecutiveModuleMetric(
        title: 'Financeiro',
        icon: Icons.account_balance_wallet_outlined,
        score: ((financeRatio - contestedRatio) * 100).clamp(18, 96).toDouble(),
        details:
            '${_money(confirmedPayments)} confirmados de ${_money(scheduledPayments)} previstos',
        color: const Color(0xFF2563EB),
      ),
      _ExecutiveModuleMetric(
        title: 'Pessoas',
        icon: Icons.groups_2_outlined,
        score: (workforceRatio * 100).clamp(22, 98).toDouble(),
        details: '$activeEmployees de $employeesCount colaboradores ativos',
        color: const Color(0xFF0F766E),
      ),
      _ExecutiveModuleMetric(
        title: 'Execucao',
        icon: Icons.assignment_turned_in_outlined,
        score: (tasksRatio * 100).clamp(20, 95).toDouble(),
        details: '$pendingTasks tarefas ainda exigem acao',
        color: const Color(0xFFD97706),
      ),
      _ExecutiveModuleMetric(
        title: 'Fiscal real',
        icon: Icons.receipt_long_outlined,
        score: (fiscalReadiness * 100).clamp(12, 92).toDouble(),
        details: fiscalReadiness >= 0.75
            ? 'Base pronta para conectar emissao real'
            : 'Preparacao de integracao fiscal em andamento',
        color: const Color(0xFF7C3AED),
      ),
    ];
  }

  List<_HomeSecondaryModule> _secondaryModules(
    Map<String, dynamic> companySettings,
    int tasksCount,
    int activeEmployees,
  ) {
    return [
      _HomeSecondaryModule(
        title: 'Ponto',
        icon: Icons.punch_clock_outlined,
        mode: activeEmployees > 0 ? 'Ativo' : 'Disponivel',
        details: activeEmployees > 0
            ? '$activeEmployees colaboradores usando a operacao da equipe.'
            : 'Disponivel para registrar jornada e leitura por ciclos.',
      ),
      _HomeSecondaryModule(
        title: 'Tarefas',
        icon: Icons.assignment_outlined,
        mode: tasksCount > 0 ? 'Ativo' : 'Disponivel',
        details:
            '$tasksCount tarefas conectadas ao fluxo comercial e operacional.',
      ),
    ];
  }

  Widget _employeeMiniCard({
    required String title,
    required String value,
    required String details,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppBrandColors.primaryDeep),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
        ],
      ),
    );
  }

  bool _isNewerVersion(String latest, String current) {
    int parseSafeInt(String value) {
      final match = RegExp(r'\d+').firstMatch(value.trim());
      if (match == null) return 0;
      return int.tryParse(match.group(0) ?? '0') ?? 0;
    }

    List<int> parse(String value) {
      final normalized = value.trim();
      final parts = normalized.split('+');
      final semver = parts.first.split('.');
      final build = parts.length > 1 ? parseSafeInt(parts[1]) : 0;
      final major = semver.isNotEmpty ? parseSafeInt(semver[0]) : 0;
      final minor = semver.length > 1 ? parseSafeInt(semver[1]) : 0;
      final patch = semver.length > 2 ? parseSafeInt(semver[2]) : 0;
      return [major, minor, patch, build];
    }

    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < l.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  Future<void> _mostrarAvisoAtualizacao(
    BuildContext context,
    AppUpdateConfig config,
    String currentVersion,
  ) {
    final hasUpdateLink =
        config.updateUrl != null && config.updateUrl!.isNotEmpty;
    return showDialog<void>(
      context: context,
      barrierDismissible: !config.force,
      builder: (ctx) => PopScope(
        canPop: !config.force,
        child: AlertDialog(
          title: const Text('Atualizacao disponivel'),
          content: Text(
            '${config.message}\n\n'
            'Versao atual: $currentVersion\n'
            'Nova versao: ${config.latestVersion}'
            '${hasUpdateLink ? '\nLink: ${config.updateUrl}' : ''}',
          ),
          actions: [
            if (!config.force)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Depois'),
              ),
            if (hasUpdateLink)
              TextButton(
                onPressed: () async {
                  final opened = await AppUpdateLauncher.open(
                    updateUrl: config.updateUrl,
                  );
                  if (opened) {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    return;
                  }
                  if (ctx.mounted) {
                    ctx.showUserError(
                      'Nao foi possivel abrir o link de atualizacao.',
                    );
                  }
                },
                child: const Text('Atualizar agora'),
              ),
            if (!config.force || !hasUpdateLink)
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(config.force ? 'Fechar' : 'Entendi'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountantRoutineEntry {
  const _AccountantRoutineEntry({
    required this.title,
    required this.cadence,
    required this.details,
    required this.actions,
  });

  final String title;
  final String cadence;
  final String details;
  final List<_AccountantRoutineAction> actions;
}

class _AccountantRoutineAction {
  const _AccountantRoutineAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
}

class _AccountantMonthlyChecklistItem {
  const _AccountantMonthlyChecklistItem({
    required this.id,
    required this.title,
    required this.details,
    required this.done,
    required this.ready,
    required this.notApplicable,
  });

  final String id;
  final String title;
  final String details;
  final bool done;
  final bool ready;
  final bool notApplicable;
}

enum _AccountantComplianceStatus { ok, action, monitor, notApplicable }

class _AccountantComplianceItem {
  const _AccountantComplianceItem({
    required this.title,
    required this.status,
    required this.summary,
    required this.nextStep,
  });

  final String title;
  final _AccountantComplianceStatus status;
  final String summary;
  final String nextStep;
}

class _DashboardBarData {
  const _DashboardBarData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _HomeSecondaryModule {
  const _HomeSecondaryModule({
    required this.title,
    required this.icon,
    required this.mode,
    required this.details,
  });

  final String title;
  final IconData icon;
  final String mode;
  final String details;
}

class _ExecutiveModuleMetric {
  const _ExecutiveModuleMetric({
    required this.title,
    required this.icon,
    required this.score,
    required this.details,
    required this.color,
  });

  final String title;
  final IconData icon;
  final double score;
  final String details;
  final Color color;
}

class _ExecutiveRadarPainter extends CustomPainter {
  const _ExecutiveRadarPainter({required this.modules});

  final List<_ExecutiveModuleMetric> modules;

  @override
  void paint(Canvas canvas, Size size) {
    if (modules.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.37;
    final gridPaint = Paint()
      ..color = const Color(0xFFD8E6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = const Color(0x332563EB)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var ring = 1; ring <= 4; ring++) {
      final radius = maxRadius * ring / 4;
      final path = Path();
      for (var i = 0; i < modules.length; i++) {
        final angle = (-90 + (360 / modules.length) * i) * 3.1415926535 / 180;
        final point = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final metricPath = Path();
    for (var i = 0; i < modules.length; i++) {
      final angle = (-90 + (360 / modules.length) * i) * 3.1415926535 / 180;
      final axisPoint = Offset(
        center.dx + maxRadius * cos(angle),
        center.dy + maxRadius * sin(angle),
      );
      canvas.drawLine(center, axisPoint, axisPaint);

      final radius = maxRadius * (modules[i].score / 100);
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      if (i == 0) {
        metricPath.moveTo(point.dx, point.dy);
      } else {
        metricPath.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 5, Paint()..color = modules[i].color);
    }
    metricPath.close();
    canvas.drawPath(metricPath, fillPaint);
    canvas.drawPath(metricPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ExecutiveRadarPainter oldDelegate) {
    return oldDelegate.modules != modules;
  }
}
