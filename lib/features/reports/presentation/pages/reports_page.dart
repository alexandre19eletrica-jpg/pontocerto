import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_runtime_summary_provider.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/debts/domain/debt.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/debts/presentation/debts_provider.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';
import 'package:pontocerto/features/payments/presentation/payments_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:pontocerto/features/work_entries/domain/work_entry.dart';
import 'package:pontocerto/features/work_entries/presentation/work_entries_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String? _employeeSelecionadoId;
  String? _usuarioTarefaSelecionadoId;
  String? _competenciaSelecionada;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final isEmployee = sessao.role == Role.employee;
    final runtimeSummary = ref.watch(companyRuntimeSummaryProvider).valueOrNull;
    final summaryFinance =
        (runtimeSummary?['finance'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final summaryFiscal =
        (runtimeSummary?['fiscal'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final employees = ref
        .watch(employeesProvider)
        .where((e) => e.ativo && e.isOperationalTeam)
        .toList();
    final todasTarefas = ref.watch(tasksProvider);

    String employeeId;
    if (isEmployee) {
      employeeId = currentUid;
    } else {
      if (employees.isEmpty) {
        ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
        return const Center(child: Text('Nenhum funcionario ativo cadastrado.'));
      }
      _employeeSelecionadoId ??= employees.first.id;
      if (!employees.any((e) => e.id == _employeeSelecionadoId)) {
        _employeeSelecionadoId = employees.first.id;
      }
      employeeId = _employeeSelecionadoId!;
    }

    final allWorkEntries = ref
        .watch(workEntriesProvider)
        .where((item) => item.employeeId == employeeId)
        .toList();
    final allDebts = ref
        .watch(debtsProvider)
        .where((item) => item.employeeId == employeeId)
        .toList();
    final allPayments = ref
        .watch(paymentsProvider)
        .where((item) => item.employeeId == employeeId)
        .toList();

    final usuariosTarefa = <String, String>{};
    for (final t in todasTarefas) {
      if (t.autorId.isNotEmpty) {
        usuariosTarefa[t.autorId] = t.autorNome.isEmpty ? t.autorId : t.autorNome;
      }
    }

    String usuarioTarefaId;
    if (isEmployee) {
      usuarioTarefaId = currentUid;
    } else {
      if (_usuarioTarefaSelecionadoId == null ||
          !usuariosTarefa.containsKey(_usuarioTarefaSelecionadoId)) {
        _usuarioTarefaSelecionadoId = usuariosTarefa.keys.isNotEmpty
            ? usuariosTarefa.keys.first
            : currentUid;
      }
      usuarioTarefaId = _usuarioTarefaSelecionadoId!;
    }

    final tarefasUsuario = todasTarefas
        .where((t) => t.autorId == usuarioTarefaId)
        .toList();
    final competenciasDisponiveis = _availableCompetences(
      workEntries: allWorkEntries,
      debts: allDebts,
      payments: allPayments,
      tasks: tarefasUsuario,
    );
    _competenciaSelecionada ??= competenciasDisponiveis.firstOrNull;
    if (_competenciaSelecionada == null ||
        !competenciasDisponiveis.contains(_competenciaSelecionada)) {
      _competenciaSelecionada =
          competenciasDisponiveis.isEmpty ? null : competenciasDisponiveis.first;
    }
    final competenciaSelecionada = _competenciaSelecionada;
    final currentCompetenceIndex = competenciaSelecionada == null
        ? -1
        : competenciasDisponiveis.indexOf(competenciaSelecionada);
    final competenciaAnterior = currentCompetenceIndex >= 0 &&
            currentCompetenceIndex + 1 < competenciasDisponiveis.length
        ? competenciasDisponiveis[currentCompetenceIndex + 1]
        : null;

    final workEntries = competenciaSelecionada == null
        ? allWorkEntries
        : allWorkEntries
            .where((item) => _competenceFromDate(item.data) == competenciaSelecionada)
            .toList();
    final debts = competenciaSelecionada == null
        ? allDebts
        : allDebts
            .where((item) => _competenceFromDate(item.data) == competenciaSelecionada)
            .toList();
    final payments = competenciaSelecionada == null
        ? allPayments
        : allPayments
            .where((item) => item.competencia == competenciaSelecionada)
            .toList();
    final tarefasCompetencia = competenciaSelecionada == null
        ? tarefasUsuario
        : tarefasUsuario
            .where(
              (t) =>
                  t.dataExecucao != null &&
                  _competenceFromDate(t.dataExecucao!) == competenciaSelecionada,
            )
            .toList();
    final tarefasEmpresaCompetencia = competenciaSelecionada == null
        ? todasTarefas
        : todasTarefas
            .where(
              (t) =>
                  t.dataExecucao != null &&
                  _competenceFromDate(t.dataExecucao!) == competenciaSelecionada,
            )
            .toList();
    final previousWorkEntries = competenciaAnterior == null
        ? const <WorkEntry>[]
        : allWorkEntries
            .where((item) => _competenceFromDate(item.data) == competenciaAnterior)
            .toList();
    final previousDebts = competenciaAnterior == null
        ? const <Debt>[]
        : allDebts
            .where((item) => _competenceFromDate(item.data) == competenciaAnterior)
            .toList();
    final previousPayments = competenciaAnterior == null
        ? const <Payment>[]
        : allPayments
            .where((item) => item.competencia == competenciaAnterior)
            .toList();
    final previousTasks = competenciaAnterior == null
        ? const <TarefaItem>[]
        : tarefasUsuario
            .where(
              (t) =>
                  t.dataExecucao != null &&
                  _competenceFromDate(t.dataExecucao!) == competenciaAnterior,
            )
            .toList();
    final previousCompanyTasks = competenciaAnterior == null
        ? const <TarefaItem>[]
        : todasTarefas
            .where(
              (t) =>
                  t.dataExecucao != null &&
                  _competenceFromDate(t.dataExecucao!) == competenciaAnterior,
            )
            .toList();

    final tarefasOrcamento =
        tarefasCompetencia.where((t) => t.status == StatusTarefa.orcamento).length;
    final tarefasAprovadas =
        tarefasCompetencia.where((t) => t.status == StatusTarefa.aprovado).length;
    final tarefasIniciadas =
        tarefasCompetencia.where((t) => t.status == StatusTarefa.iniciado).length;
    final tarefasAndamento =
        tarefasCompetencia.where((t) => t.status == StatusTarefa.emAndamento).length;
    final tarefasFinalizadas =
        tarefasCompetencia.where((t) => t.status == StatusTarefa.finalizado).length;
    final itensTotais = tarefasCompetencia.fold<int>(0, (s, t) => s + t.itens.length);
    final itensConcluidos = tarefasCompetencia.fold<int>(
      0,
      (s, t) => s + t.itens.where((i) => i.concluido).length,
    );
    final totalLancamentos = workEntries.length;
    final totalHoras =
        workEntries.fold<int>(0, (soma, item) => soma + item.horas);
    final lancAprovados = workEntries
        .where((item) => item.status == WorkEntryStatus.aprovado)
        .length;
    final lancPendentes = workEntries
        .where((item) => item.status == WorkEntryStatus.pendente)
        .length;

    final totalAberto = debts
        .where((item) => item.status == DebtStatus.aberto)
        .fold<int>(0, (soma, item) => soma + item.valorCents);
    final totalBaixado = debts
        .where((item) => item.status == DebtStatus.baixado)
        .fold<int>(0, (soma, item) => soma + item.valorCents);
    final totalCanceladoDividas = debts
        .where((item) => item.status == DebtStatus.cancelado)
        .fold<int>(0, (soma, item) => soma + item.valorCents);

    final totalPendente = payments
        .where((item) => item.status == PaymentStatus.pendente)
        .fold<int>(0, (soma, item) => soma + item.valorCents);
    final totalPago = payments
        .where((item) => item.status == PaymentStatus.pago)
        .fold<int>(0, (soma, item) => soma + item.valorCents);
    final totalConfirmado = payments
        .where((item) => item.status == PaymentStatus.confirmado)
        .fold<int>(0, (soma, item) => soma + item.valorCents);
    final totalContestado = payments
        .where((item) => item.status == PaymentStatus.contestado)
        .fold<int>(0, (soma, item) => soma + item.valorCents);
    final totalCanceladoPagamentos = payments
        .where((item) => item.status == PaymentStatus.cancelado)
        .fold<int>(0, (soma, item) => soma + item.valorCents);

    final qtdPendente = payments
        .where((item) => item.status == PaymentStatus.pendente)
        .length;
    final qtdPago = payments
        .where((item) => item.status == PaymentStatus.pago)
        .length;
    final qtdConfirmado = payments
        .where((item) => item.status == PaymentStatus.confirmado)
        .length;
    final qtdContestado = payments
        .where((item) => item.status == PaymentStatus.contestado)
        .length;
    final qtdCancelado = payments
        .where((item) => item.status == PaymentStatus.cancelado)
        .length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Relatorios',
        subtitle: 'Visao consolidada de apontamentos, pagamentos, dividas e tarefas por colaborador.',
        chips: [
          AppHeaderChip(isEmployee ? 'Meu painel' : 'Visao por colaborador'),
          if (competenciaSelecionada != null)
            AppHeaderChip('Competencia $competenciaSelecionada'),
          AppHeaderChip('Lancamentos $totalLancamentos'),
          AppHeaderChip('Tarefas ${tarefasCompetencia.length}'),
        ],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isEmployee)
                AppWorkspaceCard(
                  title: 'Filtro',
                  child: DropdownButtonFormField<String>(
                    initialValue: employeeId,
                    decoration: const InputDecoration(labelText: 'Funcionario'),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(value: employee.id, child: Text(employee.nome)),
                    ],
                    onChanged: (valor) {
                      if (valor != null) setState(() => _employeeSelecionadoId = valor);
                    },
                  ),
                ),
              if (!isEmployee) const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Recorte',
                subtitle:
                    'Escolha a competencia para transformar o relatorio em leitura mensal de operacao.',
                child: DropdownButtonFormField<String>(
                  initialValue: competenciaSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Competencia',
                  ),
                  items: [
                    for (final competencia in competenciasDisponiveis)
                      DropdownMenuItem(
                        value: competencia,
                        child: Text(competencia),
                      ),
                  ],
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() => _competenciaSelecionada = valor);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildExecutiveOverview(
                totalLancamentos: totalLancamentos,
                totalHoras: totalHoras,
                totalAberto: totalAberto,
                totalConfirmado: totalConfirmado,
                tarefasUsuario: tarefasCompetencia.length,
                tarefasFinalizadas: tarefasFinalizadas,
                itensConcluidos: itensConcluidos,
                itensTotais: itensTotais,
              ),
              const SizedBox(height: 16),
              _buildCompetenceComparisonCard(
                competenciaAtual: competenciaSelecionada,
                competenciaAnterior: competenciaAnterior,
                totalLancamentos: totalLancamentos,
                previousLancamentos: previousWorkEntries.length,
                totalHoras: totalHoras,
                previousHoras: previousWorkEntries.fold<int>(
                  0,
                  (totalValue, item) => totalValue + item.horas,
                ),
                totalAberto: totalAberto,
                previousAberto: previousDebts
                    .where((item) => item.status == DebtStatus.aberto)
                    .fold<int>(
                      0,
                      (totalValue, item) => totalValue + item.valorCents,
                    ),
                totalConfirmado: totalConfirmado,
                previousConfirmado: previousPayments
                    .where((item) => item.status == PaymentStatus.confirmado)
                    .fold<int>(
                      0,
                      (totalValue, item) => totalValue + item.valorCents,
                    ),
                tarefasFinalizadas: tarefasFinalizadas,
                previousTarefasFinalizadas: previousTasks
                    .where((t) => t.status == StatusTarefa.finalizado)
                    .length,
                companyOpenTasks: tarefasEmpresaCompetencia
                    .where((t) => t.status != StatusTarefa.finalizado)
                    .length,
                previousCompanyOpenTasks: previousCompanyTasks
                    .where((t) => t.status != StatusTarefa.finalizado)
                    .length,
              ),
              const SizedBox(height: 16),
              AppDesktopSplit(
                breakpoint: 980,
                sidebar: _buildExecutiveSignalsCard(
                  lancPendentes: lancPendentes,
                  totalAberto: totalAberto,
                  qtdPendente: qtdPendente,
                  qtdContestado: qtdContestado,
                  tarefasAndamento: tarefasAndamento,
                  tarefasFinalizadas: tarefasFinalizadas,
                  tarefasUsuario: tarefasCompetencia.length,
                ),
                content: _buildOperationalBalanceCard(
                  lancAprovados: lancAprovados,
                  lancPendentes: lancPendentes,
                  totalPendente: totalPendente,
                  totalConfirmado: totalConfirmado,
                  totalAberto: totalAberto,
                  tarefasOrcamento: tarefasOrcamento,
                  tarefasAprovadas: tarefasAprovadas,
                  tarefasIniciadas: tarefasIniciadas,
                  tarefasAndamento: tarefasAndamento,
                  tarefasFinalizadas: tarefasFinalizadas,
                ),
              ),
              const SizedBox(height: 16),
              AppDesktopSplit(
                breakpoint: 980,
                sidebar: _buildFiscalExecutiveCard(
                  sessao: sessao,
                  competencia: competenciaSelecionada,
                  summaryFiscal: summaryFiscal,
                ),
                content: _buildCompanyFinanceExecutiveCard(
                  sessao: sessao,
                  competencia: competenciaSelecionada,
                  summaryFinance: summaryFinance,
                ),
              ),
              const SizedBox(height: 16),
              if (!isEmployee) ...[
                _buildTaskDistributionExecutiveCard(
                  employees: employees,
                  tarefasEmpresaCompetencia: tarefasEmpresaCompetencia,
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              _sectionTitle('Apontamentos'),
              _infoCard(
                icon: Icons.assignment_outlined,
                title: 'Resumo de lancamentos',
                lines: [
                  'Lancamentos: $totalLancamentos',
                  'Horas totais: $totalHoras',
                  'Aprovados: $lancAprovados',
                  'Pendentes: $lancPendentes',
                ],
              ),
              _sectionTitle('Dividas e adiantamentos'),
              _infoCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Resumo financeiro',
                lines: [
                  'Total aberto: ${_formatarMoeda(totalAberto)}',
                  'Total baixado: ${_formatarMoeda(totalBaixado)}',
                  'Total cancelado: ${_formatarMoeda(totalCanceladoDividas)}',
                ],
              ),
              _sectionTitle('Pagamentos'),
              _infoCard(
                icon: Icons.payments_outlined,
                title: 'Status dos pagamentos',
                lines: [
                  'Pendente: ${_formatarMoeda(totalPendente)} ($qtdPendente)',
                  'Pago: ${_formatarMoeda(totalPago)} ($qtdPago)',
                  'Confirmado: ${_formatarMoeda(totalConfirmado)} ($qtdConfirmado)',
                  'Contestado: ${_formatarMoeda(totalContestado)} ($qtdContestado)',
                  'Cancelado: ${_formatarMoeda(totalCanceladoPagamentos)} ($qtdCancelado)',
                ],
              ),
              const SizedBox(height: 8),
              if (!isEmployee && usuariosTarefa.isNotEmpty)
                AppWorkspaceCard(
                  title: 'Filtro de tarefas',
                  child: DropdownButtonFormField<String>(
                    initialValue: usuarioTarefaId,
                    decoration: const InputDecoration(
                      labelText: 'Usuario para relatorio de tarefas',
                    ),
                    items: [
                      for (final e in usuariosTarefa.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => _usuarioTarefaSelecionadoId = valor);
                      }
                    },
                  ),
                ),
              if (!isEmployee && usuariosTarefa.isEmpty)
                const AppWorkspaceCard(
                  child: Text('Nenhuma tarefa cadastrada por usuarios ainda.'),
                ),
              if (!isEmployee) const SizedBox(height: 8),
              _sectionTitle('Tarefas executadas'),
              _infoCard(
                icon: Icons.task_alt,
                title: 'Evolucao das tarefas',
                lines: [
                  'Total de tarefas: ${tarefasUsuario.length}',
                  'Competencia: ${competenciaSelecionada ?? '-'}',
                  'Orcamentos: $tarefasOrcamento',
                  'Aprovadas: $tarefasAprovadas',
                  'Iniciadas: $tarefasIniciadas',
                  'Em andamento: $tarefasAndamento',
                  'Finalizadas: $tarefasFinalizadas',
                  'Itens concluidos: $itensConcluidos/$itensTotais',
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  List<String> _availableCompetences({
    required List<WorkEntry> workEntries,
    required List<Debt> debts,
    required List<Payment> payments,
    required List<TarefaItem> tasks,
  }) {
    final items = <String>{
      for (final item in workEntries) _competenceFromDate(item.data),
      for (final item in debts) _competenceFromDate(item.data),
      for (final item in payments)
        if (item.competencia.trim().isNotEmpty) item.competencia.trim(),
      for (final item in tasks)
        if (item.dataExecucao != null) _competenceFromDate(item.dataExecucao!),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    if (items.isEmpty) {
      items.add(_competenceFromDate(DateTime.now()));
    }
    return items;
  }

  String _competenceFromDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildExecutiveOverview({
    required int totalLancamentos,
    required int totalHoras,
    required int totalAberto,
    required int totalConfirmado,
    required int tarefasUsuario,
    required int tarefasFinalizadas,
    required int itensConcluidos,
    required int itensTotais,
  }) {
    final produtividade = itensTotais == 0
        ? '0%'
        : '${((itensConcluidos / itensTotais) * 100).round()}%';
    return AppWorkspaceCard(
      title: 'Panorama executivo',
      subtitle:
          'Leitura consolidada de operacao, financeiro e execucao por colaborador.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          AppMetricCard(
            label: 'Lancamentos',
            value: totalLancamentos.toString(),
            caption: 'Registros operacionais',
          ),
          AppMetricCard(
            label: 'Horas',
            value: totalHoras.toString(),
            caption: 'Carga acumulada',
          ),
          AppMetricCard(
            label: 'Dividas abertas',
            value: _formatarMoeda(totalAberto),
            caption: 'Saldo em aberto',
          ),
          AppMetricCard(
            label: 'Pagamentos confirmados',
            value: _formatarMoeda(totalConfirmado),
            caption: 'Baixado com confirmacao',
          ),
          AppMetricCard(
            label: 'Tarefas',
            value: '$tarefasFinalizadas/$tarefasUsuario',
            caption: 'Finalizadas no recorte',
          ),
          AppMetricCard(
            label: 'Produtividade',
            value: produtividade,
            caption: '$itensConcluidos de $itensTotais itens',
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSignalsCard({
    required int lancPendentes,
    required int totalAberto,
    required int qtdPendente,
    required int qtdContestado,
    required int tarefasAndamento,
    required int tarefasFinalizadas,
    required int tarefasUsuario,
  }) {
    final apontamentoStatus = lancPendentes > 0 ? 'Atencao' : 'Controlado';
    final financeiroStatus =
        totalAberto > 0 || qtdPendente > 0 || qtdContestado > 0
            ? 'Monitorar'
            : 'Saudavel';
    final execucaoStatus =
        tarefasUsuario == 0
            ? 'Sem tarefas'
            : tarefasFinalizadas >= tarefasAndamento
            ? 'Estavel'
            : 'Pressionada';

    return AppWorkspaceCard(
      title: 'Sinais executivos',
      subtitle: 'Leitura curta do que merece atencao imediata no recorte.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppHeaderChip('Apontamentos: $apontamentoStatus'),
              AppHeaderChip('Financeiro: $financeiroStatus'),
              AppHeaderChip('Execucao: $execucaoStatus'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _executiveSummary(
              lancPendentes: lancPendentes,
              totalAberto: totalAberto,
              qtdPendente: qtdPendente,
              qtdContestado: qtdContestado,
              tarefasAndamento: tarefasAndamento,
              tarefasFinalizadas: tarefasFinalizadas,
            ),
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalBalanceCard({
    required int lancAprovados,
    required int lancPendentes,
    required int totalPendente,
    required int totalConfirmado,
    required int totalAberto,
    required int tarefasOrcamento,
    required int tarefasAprovadas,
    required int tarefasIniciadas,
    required int tarefasAndamento,
    required int tarefasFinalizadas,
  }) {
    return AppWorkspaceCard(
      title: 'Quadro operacional',
      subtitle:
          'Distribuicao do recorte entre apontamento, financeiro e pipeline de execucao.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressRow(
            label: 'Apontamentos aprovados',
            current: lancAprovados,
            total: lancAprovados + lancPendentes,
            trailing:
                '$lancAprovados/${lancAprovados + lancPendentes == 0 ? 0 : lancAprovados + lancPendentes}',
            color: const Color(0xFF1D4ED8),
          ),
          const SizedBox(height: 12),
          _buildProgressRow(
            label: 'Pagamentos confirmados',
            current: totalConfirmado,
            total: totalConfirmado + totalPendente,
            trailing:
                '${_formatarMoeda(totalConfirmado)} / ${_formatarMoeda(totalConfirmado + totalPendente)}',
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 12),
          _buildProgressRow(
            label: 'Pipeline de tarefas fechadas',
            current: tarefasFinalizadas,
            total:
                tarefasOrcamento +
                tarefasAprovadas +
                tarefasIniciadas +
                tarefasAndamento +
                tarefasFinalizadas,
            trailing:
                '$tarefasFinalizadas/${tarefasOrcamento + tarefasAprovadas + tarefasIniciadas + tarefasAndamento + tarefasFinalizadas}',
            color: const Color(0xFFD97706),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _reportStatPill(
                label: 'Aberto em dividas',
                value: _formatarMoeda(totalAberto),
              ),
              _reportStatPill(
                label: 'Pendencia financeira',
                value: _formatarMoeda(totalPendente),
              ),
              _reportStatPill(
                label: 'Execucao em curso',
                value: (tarefasIniciadas + tarefasAndamento).toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required int current,
    required int total,
    required String trailing,
    required Color color,
  }) {
    final safeTotal = total <= 0 ? 1 : total;
    final progress = (current / safeTotal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppBrandColors.ink,
                ),
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                color: AppBrandColors.softText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _reportStatPill({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _executiveSummary({
    required int lancPendentes,
    required int totalAberto,
    required int qtdPendente,
    required int qtdContestado,
    required int tarefasAndamento,
    required int tarefasFinalizadas,
  }) {
    final parts = <String>[];
    if (lancPendentes > 0) {
      parts.add('$lancPendentes apontamentos ainda pendentes');
    } else {
      parts.add('apontamentos sem pendencia relevante');
    }
    if (totalAberto > 0 || qtdPendente > 0 || qtdContestado > 0) {
      parts.add(
        'financeiro com ${_formatarMoeda(totalAberto)} em aberto, $qtdPendente pagamentos pendentes e $qtdContestado contestados',
      );
    } else {
      parts.add('financeiro sem pressao relevante no recorte');
    }
    if (tarefasAndamento > tarefasFinalizadas) {
      parts.add('execucao com mais tarefas em curso do que fechadas');
    } else {
      parts.add('execucao com fechamento sustentado');
    }
    return '${parts.join('. ')}.';
  }

  Widget _buildCompetenceComparisonCard({
    required String? competenciaAtual,
    required String? competenciaAnterior,
    required int totalLancamentos,
    required int previousLancamentos,
    required int totalHoras,
    required int previousHoras,
    required int totalAberto,
    required int previousAberto,
    required int totalConfirmado,
    required int previousConfirmado,
    required int tarefasFinalizadas,
    required int previousTarefasFinalizadas,
    required int companyOpenTasks,
    required int previousCompanyOpenTasks,
  }) {
    if (competenciaAtual == null || competenciaAnterior == null) {
      return const AppWorkspaceCard(
        title: 'Comparativo de competencia',
        subtitle:
            'A comparacao executiva aparece quando existir pelo menos uma competencia anterior no recorte.',
        child: Text(
          'Ainda nao ha base suficiente para comparar a competencia atual com a anterior.',
          style: TextStyle(
            color: AppBrandColors.softText,
            height: 1.45,
          ),
        ),
      );
    }

    return AppWorkspaceCard(
      title: 'Comparativo de competencia',
      subtitle:
          'Leitura rapida de tendencia entre $competenciaAtual e $competenciaAnterior.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _reportStatPill(
            label: 'Lancamentos',
            value:
                '$totalLancamentos (${_deltaLabel(totalLancamentos - previousLancamentos)})',
          ),
          _reportStatPill(
            label: 'Horas',
            value: '$totalHoras (${_deltaLabel(totalHoras - previousHoras)})',
          ),
          _reportStatPill(
            label: 'Dividas abertas',
            value:
                '${_formatarMoeda(totalAberto)} (${_deltaCurrencyLabel(totalAberto - previousAberto)})',
          ),
          _reportStatPill(
            label: 'Pagamentos confirmados',
            value:
                '${_formatarMoeda(totalConfirmado)} (${_deltaCurrencyLabel(totalConfirmado - previousConfirmado)})',
          ),
          _reportStatPill(
            label: 'Tarefas fechadas',
            value:
                '$tarefasFinalizadas (${_deltaLabel(tarefasFinalizadas - previousTarefasFinalizadas)})',
          ),
          _reportStatPill(
            label: 'Fila aberta da empresa',
            value:
                '$companyOpenTasks (${_deltaLabel(companyOpenTasks - previousCompanyOpenTasks)})',
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDistributionExecutiveCard({
    required List<Employee> employees,
    required List<TarefaItem> tarefasEmpresaCompetencia,
  }) {
    final rows = employees
        .map(
          (employee) => _TaskDistributionRowData(
            employeeName: employee.nomeCompleto,
            total: tarefasEmpresaCompetencia
                .where((t) => t.autorId == employee.id)
                .length,
            open: tarefasEmpresaCompetencia
                .where(
                  (t) =>
                      t.autorId == employee.id &&
                      t.status != StatusTarefa.finalizado,
                )
                .length,
            late: tarefasEmpresaCompetencia
                .where(
                  (t) =>
                      t.autorId == employee.id &&
                      t.status != StatusTarefa.finalizado &&
                      t.dataExecucao != null &&
                      t.dataExecucao!.isBefore(
                        DateTime.now().subtract(const Duration(days: 1)),
                      ),
                )
                .length,
            inProgress: tarefasEmpresaCompetencia
                .where(
                  (t) =>
                      t.autorId == employee.id &&
                      (t.status == StatusTarefa.iniciado ||
                          t.status == StatusTarefa.emAndamento),
                )
                .length,
          ),
        )
        .where((row) => row.total > 0)
        .toList()
      ..sort((a, b) {
        final compareOpen = b.open.compareTo(a.open);
        if (compareOpen != 0) return compareOpen;
        return b.late.compareTo(a.late);
      });
    final totalOpen =
        rows.fold<int>(0, (totalValue, row) => totalValue + row.open);
    final totalLate =
        rows.fold<int>(0, (totalValue, row) => totalValue + row.late);
    final totalInProgress =
        rows.fold<int>(0, (totalValue, row) => totalValue + row.inProgress);
    final leader = rows.firstOrNull;

    return AppWorkspaceCard(
      title: 'Distribuicao de tarefas da empresa',
      subtitle:
          'Carga por responsavel no recorte, destacando fila aberta, atraso e execucao em curso.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _reportStatPill(
                label: 'Fila aberta',
                value: totalOpen.toString(),
              ),
              _reportStatPill(
                label: 'Atrasadas',
                value: totalLate.toString(),
              ),
              _reportStatPill(
                label: 'Em execucao',
                value: totalInProgress.toString(),
              ),
              _reportStatPill(
                label: 'Maior carga',
                value: leader?.employeeName ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Text(
              'Nenhuma tarefa distribuida no recorte selecionado.',
              style: TextStyle(
                color: AppBrandColors.softText,
                height: 1.45,
              ),
            )
          else
            ...rows.take(5).map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildProgressRow(
                  label: row.employeeName,
                  current: row.open,
                  total: row.total,
                  trailing:
                      '${row.open} abertas | ${row.late} atrasadas | ${row.inProgress} em execucao',
                  color: row.late > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF1D4ED8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiscalExecutiveCard({
    required Session sessao,
    required String? competencia,
    required Map<String, dynamic> summaryFiscal,
  }) {
    if (summaryFiscal.isNotEmpty) {
      int count(String key) {
        final value = summaryFiscal[key];
        if (value is num) return value.toInt();
        return 0;
      }

      int cents(String key) {
        final value = summaryFiscal[key];
        if (value is num) return value.toInt();
        return 0;
      }

      return AppWorkspaceCard(
        title: 'Fiscal da empresa',
        subtitle:
            'Resumo global mais leve da empresa, usando agregado materializado do fiscal.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _reportStatPill(
                  label: 'Notas autorizadas',
                  value: count('approvedInvoicesCount').toString(),
                ),
                _reportStatPill(
                  label: 'Bruto fiscal',
                  value: _formatarMoeda(cents('emittedGrossAmountCents')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Este card usa leitura resumida da empresa para abrir mais rapido. A analise detalhada por competencia continua disponivel no modulo Fiscal.',
              style: TextStyle(
                color: AppBrandColors.softText,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('service_invoices')
          .where('companyId', isEqualTo: sessao.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final invoices = docs.where((doc) {
          if (competencia == null) return true;
          return _competenceFromDate(_toDate(doc.data()['issueDate'])) ==
              competencia;
        }).toList();
        final approved = invoices
            .where((doc) {
              final status = (doc.data()['status']?.toString() ?? '').toUpperCase();
              return status == 'APPROVED' || status == 'EMITTED';
            })
            .length;
        final processing = invoices.where((doc) {
          final status = (doc.data()['status']?.toString() ?? '').toUpperCase();
          final attempt =
              (doc.data()['lastEmissionAttemptStatus']?.toString() ?? '')
                  .toUpperCase();
          return status == 'PROCESSING' ||
              status == 'PROCESSANDO' ||
              attempt == 'PROCESSING';
        }).length;
        final failed = invoices.where((doc) {
          final attempt =
              (doc.data()['lastEmissionAttemptStatus']?.toString() ?? '')
                  .toUpperCase();
          return attempt == 'FAILED' ||
              attempt == 'CANCEL_FAILED' ||
              attempt == 'QUERY_FAILED';
        }).length;
        final linkedFinance = invoices
            .where(
              (doc) =>
                  (doc.data()['financeMovementId']?.toString().trim() ?? '')
                      .isNotEmpty,
            )
            .length;
        final grossAmount = invoices.fold<int>(
          0,
          (totalAmount, doc) =>
              totalAmount + ((doc.data()['amountCents'] as num?)?.toInt() ?? 0),
        );

        return AppWorkspaceCard(
          title: 'Fiscal da empresa',
          subtitle:
              'Emissao, processamento, falha e ligacao financeira no recorte atual.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _reportStatPill(
                    label: 'Notas',
                    value: invoices.length.toString(),
                  ),
                  _reportStatPill(
                    label: 'Autorizadas',
                    value: approved.toString(),
                  ),
                  _reportStatPill(
                    label: 'Processando',
                    value: processing.toString(),
                  ),
                  _reportStatPill(
                    label: 'Falhas',
                    value: failed.toString(),
                  ),
                  _reportStatPill(
                    label: 'No financeiro',
                    value: linkedFinance.toString(),
                  ),
                  _reportStatPill(
                    label: 'Bruto fiscal',
                    value: _formatarMoeda(grossAmount),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _fiscalExecutiveSummary(
                  total: invoices.length,
                  emitted: approved,
                  processing: processing,
                  failed: failed,
                  linkedFinance: linkedFinance,
                ),
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanyFinanceExecutiveCard({
    required Session sessao,
    required String? competencia,
    required Map<String, dynamic> summaryFinance,
  }) {
    if (summaryFinance.isNotEmpty) {
      int cents(String key) {
        final value = summaryFinance[key];
        if (value is num) return value.toInt();
        return 0;
      }

      final receivables = cents('companyReceivablesCents');
      final receivablesReceived = cents('companyReceivablesReceivedCents');
      final receivablesPending = receivables - receivablesReceived;
      final payables = cents('companyPayablesCents');
      final payablesPaid = cents('companyPayablesPaidCents');
      final payablesPending = payables - payablesPaid;

      return AppWorkspaceCard(
        title: 'Financeiro da empresa',
        subtitle:
            'Resumo global mais leve da empresa, usando agregado materializado do financeiro.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _reportStatPill(
                  label: 'A receber',
                  value: _formatarMoeda(receivablesPending),
                ),
                _reportStatPill(
                  label: 'Recebido',
                  value: _formatarMoeda(receivablesReceived),
                ),
                _reportStatPill(
                  label: 'A pagar',
                  value: _formatarMoeda(payablesPending),
                ),
                _reportStatPill(
                  label: 'Pago',
                  value: _formatarMoeda(payablesPaid),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Este card usa leitura resumida da empresa para abrir mais rapido. O detalhamento por competencia continua disponivel no modulo Financeiro.',
              style: TextStyle(
                color: AppBrandColors.softText,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('finance_movements')
          .where('companyId', isEqualTo: sessao.companyId)
          .where('ownerUserId', isEqualTo: '__COMPANY__')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final movements = docs.where((doc) {
          if (competencia == null) return true;
          return _competenceFromDate(_toDate(doc.data()['date'])) == competencia;
        }).toList();
        final incomeAmount = movements
            .where((doc) => doc.data()['type']?.toString().toUpperCase() == 'INCOME')
            .fold<int>(
              0,
              (totalAmount, doc) => totalAmount +
                  ((doc.data()['amountCents'] as num?)?.toInt() ?? 0),
            );
        final expenseAmount = movements
            .where((doc) => doc.data()['type']?.toString().toUpperCase() == 'EXPENSE')
            .fold<int>(
              0,
              (totalAmount, doc) => totalAmount +
                  ((doc.data()['amountCents'] as num?)?.toInt() ?? 0),
            );
        final pendingAmount = movements
            .where(
              (doc) =>
                  doc.data()['paymentStatus']?.toString().toUpperCase() == 'PENDING',
            )
            .fold<int>(
              0,
              (totalAmount, doc) => totalAmount +
                  ((doc.data()['amountCents'] as num?)?.toInt() ?? 0),
            );
        final fiscalOriginCount = movements
            .where((doc) => doc.data()['sourceModule']?.toString() == 'fiscal')
            .length;

        return AppWorkspaceCard(
          title: 'Financeiro da empresa',
          subtitle:
              'Receita, despesa, pendencia e participacao da origem fiscal no recorte.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _reportStatPill(
                    label: 'Receitas',
                    value: _formatarMoeda(incomeAmount),
                  ),
                  _reportStatPill(
                    label: 'Despesas',
                    value: _formatarMoeda(expenseAmount),
                  ),
                  _reportStatPill(
                    label: 'Saldo',
                    value: _formatarMoeda(incomeAmount - expenseAmount),
                  ),
                  _reportStatPill(
                    label: 'Pendencias',
                    value: _formatarMoeda(pendingAmount),
                  ),
                  _reportStatPill(
                    label: 'Origem fiscal',
                    value: fiscalOriginCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _companyFinanceExecutiveSummary(
                  incomeAmount: incomeAmount,
                  expenseAmount: expenseAmount,
                  pendingAmount: pendingAmount,
                  fiscalOriginCount: fiscalOriginCount,
                ),
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fiscalExecutiveSummary({
    required int total,
    required int emitted,
    required int processing,
    required int failed,
    required int linkedFinance,
  }) {
    if (total == 0) {
      return 'Nao ha notas fiscais no recorte selecionado.';
    }
    return 'No recorte atual, $emitted notas ja foram emitidas, '
        '$processing seguem em processamento, $failed tiveram falha recente '
        'e $linkedFinance ja estao ligadas ao financeiro.';
  }

  String _companyFinanceExecutiveSummary({
    required int incomeAmount,
    required int expenseAmount,
    required int pendingAmount,
    required int fiscalOriginCount,
  }) {
    final saldo = incomeAmount - expenseAmount;
    return 'A empresa acumula ${_formatarMoeda(incomeAmount)} em receitas, '
        '${_formatarMoeda(expenseAmount)} em despesas e '
        '${_formatarMoeda(saldo)} de saldo operacional no recorte. '
        'Ha ${_formatarMoeda(pendingAmount)} pendentes e '
        '$fiscalOriginCount lancamentos com origem fiscal.';
  }

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required List<String> lines,
  }) {
    return AppWorkspaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppBrandColors.border),
            ),
            child: Icon(icon, color: AppBrandColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppBrandColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lines.join('\n'),
                  style: const TextStyle(
                    color: AppBrandColors.softText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarMoeda(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  String _deltaLabel(int delta) {
    if (delta == 0) return 'estavel';
    final prefix = delta > 0 ? '+' : '';
    return '$prefix$delta';
  }

  String _deltaCurrencyLabel(int delta) {
    if (delta == 0) return 'estavel';
    final prefix = delta > 0 ? '+' : '-';
    return '$prefix${_formatarMoeda(delta.abs())}';
  }
}

class _TaskDistributionRowData {
  const _TaskDistributionRowData({
    required this.employeeName,
    required this.total,
    required this.open,
    required this.late,
    required this.inProgress,
  });

  final String employeeName;
  final int total;
  final int open;
  final int late;
  final int inProgress;
}


