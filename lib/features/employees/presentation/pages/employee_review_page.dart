import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/core/pdf/pdf_output.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';
import 'package:pontocerto/features/device_consent/domain/device_consent.dart';
import 'package:pontocerto/features/device_consent/presentation/device_consent_provider.dart';
import 'package:pontocerto/features/debts/domain/debt.dart';
import 'package:pontocerto/features/debts/presentation/debts_provider.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/justifications/domain/justification.dart';
import 'package:pontocerto/features/justifications/presentation/justifications_provider.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';
import 'package:pontocerto/features/payments/presentation/payments_provider.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_actions_service.dart';
import 'package:pontocerto/features/punch/domain/punch.dart';
import 'package:pontocerto/features/punch/presentation/punch_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/pages/tasks_page.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:pontocerto/features/work_entries/domain/work_entry.dart';
import 'package:pontocerto/features/work_entries/presentation/work_entries_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

Widget _workspaceSurface({
  required Widget child,
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
}) {
  return Container(
    margin: margin,
    decoration: BoxDecoration(
      color: const Color(0xFFFCFEFF),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFCCD9E5)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120F172A),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );
}

class EmployeeReviewPage extends ConsumerWidget {
  const EmployeeReviewPage({super.key, required this.employee});

  final Employee employee;
  static const List<String> _termoClausulas = <String>[
    '1. O colaborador autoriza, de forma livre e informada, o uso do celular proprio no app da empresa para atividades operacionais e de registro de ponto.',
    '2. O aceite e digital e fica vinculado ao usuario, com data/hora, versao do termo e metadados tecnicos de auditoria.',
    '3. O colaborador pode revogar o consentimento no app, ciente dos impactos operacionais definidos pela empresa.',
    '4. A empresa usa os dados somente para fins de gestao operacional, controle interno e cumprimento de obrigacoes legais.',
    '5. O registro de aceite pode ser exportado em PDF para arquivo e defesa administrativa/judicial, quando necessario.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessionProvider);
    final isEmpresa = sessao != null && sessao.role != Role.employee;
    final tasks = ref
        .watch(tasksProvider)
        .where((t) => t.autorId == employee.id)
        .toList();
    final consent = ref
        .watch(deviceConsentsProvider)
        .where((c) => c.employeeId == employee.id)
        .firstOrNull;
    final workEntries = ref
        .watch(workEntriesProvider)
        .where((e) => e.employeeId == employee.id)
        .toList();
    final punches = ref
        .watch(punchProvider)
        .where((p) => p.employeeId == employee.id)
        .toList();
    final workedDays = ref
        .watch(workedDaysProvider)
        .where((d) => d.employeeId == employee.id)
        .toList();
    final debts = ref
        .watch(debtsProvider)
        .where((d) => d.employeeId == employee.id)
        .toList();
    final payments = ref
        .watch(paymentsProvider)
        .where((p) => p.employeeId == employee.id)
        .toList();
    final justifications = ref
        .watch(justificationsProvider)
        .where((j) => j.employeeId == employee.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltarApp(),
        title: Text('Funcionario: ${employee.nomeCompleto}'),
        actions: [
          if (sessao != null &&
              sessao.role != Role.employee &&
              sessao.userId != employee.id &&
              !isSupremePlatformCompanyId(sessao.companyId) &&
              (sessao.role == Role.owner ||
                  sessao.role == Role.manager ||
                  sessao.role == Role.accountant))
            IconButton(
              tooltip: employee.ativo ? 'Inativar acesso' : 'Reativar acesso',
              icon: Icon(
                employee.ativo
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      employee.ativo
                          ? 'Inativar colaborador?'
                          : 'Reativar colaborador?',
                    ),
                    content: Text(
                      employee.ativo
                          ? 'O acesso ao sistema sera desativado.'
                          : 'O colaborador volta a ficar ativo nas rotinas.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await ref
                      .read(employeesProvider.notifier)
                      .toggleAtivo(employee.id);
                  if (!context.mounted) return;
                  context.showUserMessage('Status do colaborador atualizado.');
                  Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  context.showUserMessage(
                    AppErrorMapper.messageFrom(error),
                  );
                }
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _workspaceSurface(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFDDEBFF),
                  backgroundImage:
                      (employee.fotoUrl != null && employee.fotoUrl!.isNotEmpty)
                      ? NetworkImage(employee.fotoUrl!)
                      : null,
                  child: (employee.fotoUrl == null || employee.fotoUrl!.isEmpty)
                      ? const Icon(
                          Icons.badge_rounded,
                          color: Color(0xFF113A6B),
                        )
                      : null,
                ),
                title: Text(employee.nomeCompleto),
                subtitle: Text(
                  'Status: ${employee.ativo ? 'Ativo' : 'Inativo'}\n'
                  'Documento: ${employee.documento}\n'
                  'Cargo: ${employee.cargo ?? '-'}\n'
                  'Remuneracao: ${_compensationLabel(employee)}\n'
                  'Telefone: ${employee.telefone?.trim().isEmpty ?? true ? '-' : employee.telefone}\n'
                  'Email: ${employee.email?.trim().isEmpty ?? true ? '-' : employee.email}',
                ),
                isThreeLine: true,
              ),
            ),
            _menuCard(
              context,
              title: 'Ponto',
              count: punches.length,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _EmployeePunchModulePage(
                    employee: employee,
                    podeMarcarPonto: isEmpresa,
                  ),
                ),
              ),
            ),
            _menuCard(
              context,
              title: 'Autorizacao celular',
              count: 1,
              onTap: () => _openSimpleModule(
                context,
                'Autorizacao de uso do celular',
                [
                  ListTile(
                    title: Text(
                      consent?.accepted == true
                          ? 'Autorizada'
                          : 'Pendente/Nao autorizada',
                    ),
                    subtitle: Text(
                      consent?.accepted == true
                          ? 'Versao: ${consent?.termsVersion ?? 'v1'}\n'
                                'Aceita em: ${_dataHora(consent?.acceptedAt)}\n'
                                'Dispositivo: ${consent?.devicePlatform ?? '-'} | App: ${consent?.appVersion ?? '-'}\n'
                                'Fuso: ${consent?.timeZone ?? '-'}'
                          : 'Funcionario ainda nao aceitou o termo no app.',
                    ),
                    isThreeLine: true,
                  ),
                  ListTile(
                    title: const Text('Clausulas do termo de aceite'),
                    subtitle: const Text(
                      'O aceite abaixo registra autorizacao para uso do celular proprio como ferramenta de trabalho no app.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Visualizar clausulas',
                      onPressed: () => _mostrarClausulas(context),
                      icon: const Icon(Icons.description_outlined),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _mostrarClausulas(context),
                            icon: const Icon(Icons.visibility),
                            label: const Text('Ver termo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: consent == null
                                ? null
                                : () => _gerarPdfTermo(
                                    context,
                                    consent: consent,
                                    companyId: sessao?.companyId ?? '-',
                                  ),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Gerar PDF'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _menuCard(
              context,
              title: 'Dias trabalhados',
              count: workedDays.length,
              onTap: () => _openSimpleModule(
                context,
                'Dias trabalhados',
                workedDays.isEmpty
                    ? [
                        _buildEmptyReviewTile(
                          'Nenhum dia trabalhado registrado.',
                        ),
                      ]
                    : [
                        for (final d
                            in (workedDays
                              ..sort((a, b) => b.date.compareTo(a.date))))
                          _buildWorkedDayTile(d),
                      ],
              ),
            ),
            _menuCard(
              context,
              title: 'Apontamentos',
              count: workEntries.length,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _EmployeeWorkEntriesModulePage(
                    employee: employee,
                    somenteLeitura: !isEmpresa,
                  ),
                ),
              ),
            ),
            _menuCard(
              context,
              title: 'Dividas e adiantamentos',
              count: debts.length,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _EmployeeDebtsModulePage(
                    employee: employee,
                    somenteLeitura: !isEmpresa,
                  ),
                ),
              ),
            ),
            _menuCard(
              context,
              title: 'Pagamentos',
              count: payments.length,
              onTap: () => _openSimpleModule(
                context,
                'Pagamentos',
                payments.isEmpty
                    ? [
                        _buildEmptyReviewTile('Nenhum pagamento encontrado.'),
                      ]
                    : [
                        for (final p
                            in (payments..sort(
                              (a, b) =>
                                  b.dataRegistro.compareTo(a.dataRegistro),
                            )))
                          _buildPaymentReviewTile(p),
                      ],
              ),
            ),
            _menuCard(
              context,
              title: 'Justificativas',
              count: justifications.length,
              onTap: () => _openSimpleModule(
                context,
                'Justificativas',
                justifications.isEmpty
                    ? [
                        _buildEmptyReviewTile(
                          'Nenhuma justificativa encontrada.',
                        ),
                      ]
                    : [
                        for (final j
                            in (justifications
                              ..sort((a, b) => b.date.compareTo(a.date))))
                          _buildJustificationReviewTile(context, j),
                      ],
              ),
            ),
            _menuCard(
              context,
              title: 'Tarefas',
              count: tasks.length,
              onTap: () => _openSimpleModule(
                context,
                'Tarefas',
                tasks.isEmpty
                    ? [
                        _buildEmptyReviewTile('Nenhuma tarefa encontrada.'),
                      ]
                    : [
                        for (final t
                            in (tasks..sort(
                              (a, b) => (b.dataExecucao ?? DateTime(1900))
                                  .compareTo(a.dataExecucao ?? DateTime(1900)),
                            )))
                          _buildTaskReviewTile(context, t),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return _workspaceSurface(
      child: ListTile(
        title: Text(title),
        subtitle: Text('$count itens'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmptyReviewTile(String message) {
    return ListTile(title: Text(message));
  }

  Widget _buildWorkedDayTile(WorkedDay d) {
    return ListTile(
      title: Text('${_weekdayName(d.date)} - ${_data(d.date)}'),
      subtitle: Text(
        '${d.period == WorkedDayPeriod.fullDay ? 'Dia todo' : 'Meio dia'} | '
        '${d.hasEntry ? 'Entrada OK' : 'Sem entrada'} | '
        '${d.hasExit ? 'Saida OK' : 'Saida automatica'}\n'
        'Ciclo semanal: ${_cicloSemanal(d.date)} | '
        'Ciclo mensal: ${_cicloMensal(d.date)}',
      ),
      isThreeLine: true,
    );
  }

  Widget _buildPaymentReviewTile(Payment p) {
    return ListTile(
      title: Text('${p.competencia} - ${_moeda(p.valorCents)}'),
      subtitle: Text('Status: ${_statusPagamento(p.status)}'),
    );
  }

  Widget _buildJustificationReviewTile(
    BuildContext context,
    JustificationItem j,
  ) {
    return ListTile(
      title: Text('${_data(j.date)} - ${_statusJustification(j.status)}'),
      subtitle: Text(
        '${j.reason}\nComprovante: ${j.comprovanteNomeArquivo ?? 'Arquivo enviado'}',
      ),
      isThreeLine: true,
      onTap: j.comprovanteUrl.isEmpty
          ? null
          : () => _openProof(context, j.comprovanteUrl),
    );
  }

  Widget _buildTaskReviewTile(BuildContext context, TarefaItem t) {
    return ListTile(
      title: Text(t.nome),
      subtitle: Text(
        'Cliente: ${t.clienteNome.isEmpty ? '-' : t.clienteNome}\n'
        'Data: ${_data(t.dataExecucao)}\n'
        'Status: ${_statusTarefa(t.status)}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailsPage(taskId: t.id),
        ),
      ),
    );
  }

  void _openSimpleModule(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _EmployeeSimpleModulePage(title: title, children: children),
      ),
    );
  }

  void _mostrarClausulas(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Termo de aceite - uso do celular'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in _termoClausulas) ...[
                  Text(item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _gerarPdfTermo(
    BuildContext context, {
    required DeviceConsent consent,
    required String companyId,
  }) async {
    try {
      final pdf = pw.Document();
      final aceiteStatus = consent.accepted ? 'AUTORIZADO' : 'NAO AUTORIZADO';
      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Termo de aceite - uso do celular proprio',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Empresa: $companyId'),
            pw.Text('Funcionario: ${employee.nomeCompleto}'),
            pw.Text('Funcionario ID: ${employee.id}'),
            pw.Text('Documento: ${employee.documento}'),
            pw.SizedBox(height: 8),
            pw.Text('Status do aceite: $aceiteStatus'),
            pw.Text('Versao do termo: ${consent.termsVersion}'),
            pw.Text('Aceito em: ${_dataHora(consent.acceptedAt)}'),
            pw.Text('Declaracao aceita: ${consent.acceptedStatement}'),
            pw.Text('Dispositivo: ${consent.devicePlatform ?? '-'}'),
            pw.Text('Versao do app: ${consent.appVersion ?? '-'}'),
            pw.Text('Fuso horario: ${consent.timeZone ?? '-'}'),
            pw.Text('UID aceite: ${consent.acceptedByUid ?? '-'}'),
            pw.SizedBox(height: 16),
            pw.Text(
              'Clausulas do termo',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ..._termoClausulas.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(item),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Documento gerado no app para fins de arquivo e possivel defesa administrativa/judicial.',
            ),
          ],
        ),
      );

      await openPdfBytes(
        bytes: await pdf.save(),
        filename: 'termo-uso-celular-${employee.id}.pdf',
      );
    } catch (_) {
      if (!context.mounted) return;
      context.showUserError('Nao foi possivel gerar o PDF do termo.');
    }
  }

  String _statusTarefa(StatusTarefa status) {
    return switch (status) {
      StatusTarefa.orcamento => 'Orcamento',
      StatusTarefa.aprovado => 'Aprovado',
      StatusTarefa.iniciado => 'Iniciado',
      StatusTarefa.emAndamento => 'Em andamento',
      StatusTarefa.finalizado => 'Finalizado',
    };
  }

  String _statusPagamento(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.pendente => 'Pendente',
      PaymentStatus.pago => 'Pago',
      PaymentStatus.confirmado => 'Confirmado',
      PaymentStatus.contestado => 'Contestado',
      PaymentStatus.cancelado => 'Cancelado',
    };
  }

  String _statusJustification(JustificationStatus status) {
    return switch (status) {
      JustificationStatus.pending => 'Pendente',
      JustificationStatus.approved => 'Aprovada',
      JustificationStatus.rejected => 'Rejeitada',
    };
  }

  String _weekdayName(DateTime data) {
    const dias = <String>[
      'Segunda',
      'Terca',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sabado',
      'Domingo',
    ];
    return dias[data.weekday - 1];
  }

  String _moeda(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  String _compensationLabel(Employee employee) {
    return switch (employee.compensationType) {
      EmployeeCompensationType.monthly =>
        'Mensal ${_moeda(employee.salaryAmountCents ?? 0)}',
      EmployeeCompensationType.weekly =>
        'Semanal ${_moeda(employee.salaryAmountCents ?? 0)}',
      EmployeeCompensationType.daily =>
        'Diaria ${_moeda(employee.salaryAmountCents ?? 0)}',
      EmployeeCompensationType.commission =>
        'Comissao ${(employee.commissionPercent ?? 0).toStringAsFixed(2).replaceAll('.', ',')}%',
    };
  }

  String _data(DateTime? data) {
    if (data == null) return '-';
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    return '$d/$m/${data.year}';
  }

  String _dataHora(DateTime? data) {
    if (data == null) return '-';
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    final h = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$d/$m/${data.year} $h:$min';
  }

  String _cicloSemanal(DateTime data) {
    final base = DateTime(data.year, data.month, data.day);
    final inicio = base.subtract(
      Duration(days: data.weekday - DateTime.monday),
    );
    final fim = inicio.add(const Duration(days: 5));
    return '${_data(inicio)} a ${_data(fim)}';
  }

  String _cicloMensal(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    return '$mes/${data.year}';
  }

  static void _openProof(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: FutureBuilder<ImageProvider>(
          future: _resolverImagemProvider(url),
          builder: (_, snapshot) {
            if (snapshot.hasData) {
              return Image(image: snapshot.data!, fit: BoxFit.contain);
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nao foi possivel abrir o comprovante.'),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  static Future<ImageProvider> _resolverImagemProvider(String origem) async {
    if (origem.startsWith('http://') || origem.startsWith('https://')) {
      return NetworkImage(origem);
    }
    if (!origem.startsWith('gs://')) {
      return NetworkImage(origem);
    }
    final ref = FirebaseStorage.instance.refFromURL(origem);
    final url = await ref.getDownloadURL();
    return NetworkImage(url);
  }
}

class _EmployeeSimpleModulePage extends StatelessWidget {
  const _EmployeeSimpleModulePage({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [_workspaceSurface(child: Column(children: children))],
      ),
    );
  }
}

class _EmployeePunchModulePage extends ConsumerStatefulWidget {
  const _EmployeePunchModulePage({
    required this.employee,
    required this.podeMarcarPonto,
  });

  final Employee employee;
  final bool podeMarcarPonto;

  @override
  ConsumerState<_EmployeePunchModulePage> createState() =>
      _EmployeePunchModulePageState();
}

class _EmployeePunchModulePageState
    extends ConsumerState<_EmployeePunchModulePage> {
  final _obraOuClienteController = TextEditingController();

  @override
  void dispose() {
    _obraOuClienteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final punches =
        ref
            .watch(punchProvider)
            .where((p) => p.employeeId == widget.employee.id)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(title: const Text('Ponto')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.podeMarcarPonto) ...[
            TextField(
              controller: _obraOuClienteController,
              decoration: const InputDecoration(labelText: 'Obra ou cliente *'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final obraOuCliente = _obraOuClienteController.text.trim();
                  if (obraOuCliente.isEmpty) {
                    _msg(
                      context,
                      'Informe a obra ou cliente antes de marcar ponto.',
                    );
                    return;
                  }
                  try {
                    await ref
                        .read(punchProvider.notifier)
                        .register(
                          employeeId: widget.employee.id,
                          obraOuCliente: obraOuCliente,
                        );
                    if (!context.mounted) return;
                    _msg(context, 'Ponto marcado com sucesso.');
                  } catch (_) {
                    if (!context.mounted) return;
                    _msg(context, 'Erro ao marcar ponto.');
                  }
                },
                icon: const Icon(Icons.fingerprint),
                label: const Text('Marcar ponto do funcionario'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (punches.isEmpty)
            _workspaceSurface(
              child: const ListTile(
                title: Text('Nenhum registro de ponto encontrado.'),
              ),
            ),
          ...punches.map(
            (p) => _workspaceSurface(
              child: ListTile(
                title: Text(p.tipo == PunchType.entrada ? 'Entrada' : 'Saida'),
                subtitle: Text(
                  '${_dataHora(p.timestamp)}\nObra/Cliente: ${p.obraOuCliente.isEmpty ? '-' : p.obraOuCliente}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dataHora(DateTime data) {
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    final h = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$d/$m/${data.year} $h:$min';
  }

  void _msg(BuildContext context, String texto) {
    if (!context.mounted) return;
    context.showUserMessage(texto);
  }
}

class _EmployeeWorkEntriesModulePage extends ConsumerWidget {
  const _EmployeeWorkEntriesModulePage({
    required this.employee,
    required this.somenteLeitura,
  });

  final Employee employee;
  final bool somenteLeitura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista =
        ref
            .watch(workEntriesProvider)
            .where((e) => e.employeeId == employee.id)
            .toList()
          ..sort((a, b) => b.data.compareTo(a.data));

    return Scaffold(
      appBar: AppBar(title: const Text('Apontamentos')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (lista.isEmpty)
            _workspaceSurface(
              child: const ListTile(title: Text('Nenhum apontamento encontrado.')),
            ),
          ...lista.map(
            (item) => _workspaceSurface(
              child: ListTile(
                title: Text('${_data(item.data)} - ${item.horas}h'),
                subtitle: Text(
                  item.status == WorkEntryStatus.aprovado
                      ? 'Aprovado'
                      : 'Pendente',
                ),
                trailing:
                    somenteLeitura || item.status == WorkEntryStatus.aprovado
                    ? null
                    : TextButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(workEntriesProvider.notifier)
                                .approve(item.id);
                            if (!context.mounted) return;
                            _msg(context, 'Apontamento aprovado.');
                          } catch (_) {
                            if (!context.mounted) return;
                            _msg(context, 'Erro ao aprovar apontamento.');
                          }
                        },
                        child: const Text('Aprovar'),
                      ),
                onTap: somenteLeitura
                    ? null
                    : () =>
                          _abrirDialogo(context, ref, employee.id, item: item),
                onLongPress: somenteLeitura
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(workEntriesProvider.notifier)
                              .remove(item.id);
                          if (!context.mounted) return;
                          _msg(context, 'Apontamento removido.');
                        } catch (_) {
                          if (!context.mounted) return;
                          _msg(context, 'Erro ao remover apontamento.');
                        }
                      },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: somenteLeitura
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirDialogo(context, ref, employee.id),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            ),
    );
  }

  Future<void> _abrirDialogo(
    BuildContext context,
    WidgetRef ref,
    String employeeId, {
    WorkEntry? item,
  }) async {
    final horasController = TextEditingController(
      text: item?.horas.toString() ?? '',
    );
    DateTime dataSelecionada = item?.data ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(item == null ? 'Novo apontamento' : 'Editar apontamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Data: ${_data(dataSelecionada)}')),
                  TextButton(
                    onPressed: () async {
                      final escolhida = await showDatePicker(
                        context: ctx,
                        initialDate: dataSelecionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (escolhida != null) {
                        setStateDialog(() => dataSelecionada = escolhida);
                      }
                    },
                    child: const Text('Selecionar'),
                  ),
                ],
              ),
              TextField(
                controller: horasController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Horas'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final horas = int.tryParse(horasController.text.trim());
                if (horas == null || horas <= 0) {
                  _msg(context, 'Informe horas validas.');
                  return;
                }
                try {
                  if (item == null) {
                    await ref
                        .read(workEntriesProvider.notifier)
                        .add(employeeId, dataSelecionada, horas);
                  } else {
                    await ref
                        .read(workEntriesProvider.notifier)
                        .update(item.id, employeeId, dataSelecionada, horas);
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  _msg(context, 'Erro ao salvar apontamento.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    horasController.dispose();
  }

  static String _data(DateTime data) {
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    return '$d/$m/${data.year}';
  }

  static void _msg(BuildContext context, String texto) {
    if (!context.mounted) return;
    context.showUserMessage(texto);
  }
}

class _EmployeeDebtsModulePage extends ConsumerWidget {
  const _EmployeeDebtsModulePage({
    required this.employee,
    required this.somenteLeitura,
  });

  final Employee employee;
  final bool somenteLeitura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts =
        ref
            .watch(debtsProvider)
            .where((d) => d.employeeId == employee.id)
            .toList()
          ..sort((a, b) => b.data.compareTo(a.data));
    final isEmployee = ref.watch(sessionProvider)?.role == Role.employee;
    final actions = FinanceActionsService();

    return Scaffold(
      appBar: AppBar(title: const Text('Dividas e adiantamentos')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (debts.isEmpty)
            _workspaceSurface(
              child: const ListTile(
                title: Text('Nenhum registro financeiro encontrado.'),
              ),
            ),
          ...debts.map(
            (d) => _workspaceSurface(
              child: ListTile(
                title: Text(
                  '${d.tipo == DebtType.divida ? 'Divida' : 'Adiantamento'} - ${_moeda(d.valorCents)}',
                ),
                subtitle: Text(
                  '${_statusDebt(d.status)} | ${_data(d.data)}\n'
                  '${d.descricao}\n'
                  'Permissao editar: ${d.allowEmployeeEdit ? 'Sim' : 'Nao'} | '
                  'Permissao pagar: ${d.allowEmployeeSettle ? 'Sim' : 'Nao'}',
                ),
                isThreeLine: true,
                onTap:
                    (somenteLeitura ||
                        !d.allowEmployeeEdit ||
                        d.editRequestPending ||
                        d.status != DebtStatus.aberto)
                    ? null
                    : () => _abrirDialogoEdicao(context, ref, d),
                trailing: isEmployee
                    ? (d.status == DebtStatus.aberto && d.allowEmployeeSettle
                          ? TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(debtsProvider.notifier)
                                      .payByEmployee(d.id);
                                  if (!context.mounted) return;
                                  _msg(context, 'Pagamento registrado.');
                                } catch (_) {
                                  if (!context.mounted) return;
                                  _msg(context, 'Sem permissao para pagar.');
                                }
                              },
                              child: const Text('Pagar'),
                            )
                          : null)
                    : Wrap(
                        spacing: 4,
                        children: [
                          if (d.status == DebtStatus.aberto &&
                              d.editRequestPending) ...[
                            TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(debtsProvider.notifier)
                                      .approveEditRequest(d.id);
                                  if (!context.mounted) return;
                                  _msg(context, 'Solicitacao aprovada.');
                                } catch (_) {
                                  if (!context.mounted) return;
                                  _msg(context, 'Erro ao aprovar solicitacao.');
                                }
                              },
                              child: const Text('Aprovar'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(debtsProvider.notifier)
                                      .rejectEditRequest(d.id);
                                  if (!context.mounted) return;
                                  _msg(context, 'Solicitacao reprovada.');
                                } catch (_) {
                                  if (!context.mounted) return;
                                  _msg(
                                    context,
                                    'Erro ao reprovar solicitacao.',
                                  );
                                }
                              },
                              child: const Text('Reprovar'),
                            ),
                          ],
                          if (d.status == DebtStatus.aberto)
                            TextButton(
                              onPressed: () async {
                                try {
                                  await actions.settleDebt(d.id);
                                  if (!context.mounted) return;
                                  _msg(context, 'Recebimento registrado.');
                                } catch (_) {
                                  if (!context.mounted) return;
                                  _msg(context, 'Erro ao receber.');
                                }
                              },
                              child: const Text('Receber'),
                            ),
                          TextButton(
                            onPressed: () => _abrirPermissoes(context, ref, d),
                            child: const Text('Permissoes'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isEmployee
          ? FloatingActionButton.extended(
              onPressed: () => _abrirDialogoCriacao(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nova divida'),
            )
          : null,
    );
  }

  Future<void> _abrirPermissoes(
    BuildContext context,
    WidgetRef ref,
    Debt d,
  ) async {
    var allowEdit = d.allowEmployeeEdit;
    var allowSettle = d.allowEmployeeSettle;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Permissoes da divida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: allowEdit,
                onChanged: (v) => setDialogState(() => allowEdit = v),
                title: const Text('Permitir editar'),
              ),
              SwitchListTile(
                value: allowSettle,
                onChanged: (v) => setDialogState(() => allowSettle = v),
                title: const Text('Permitir pagar'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref
                      .read(debtsProvider.notifier)
                      .setEmployeePermissions(
                        debtId: d.id,
                        allowEmployeeEdit: allowEdit,
                        allowEmployeeSettle: allowSettle,
                      );
                } catch (_) {
                  if (!context.mounted) return;
                  _msg(context, 'Erro ao salvar permissoes.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                _msg(context, 'Permissoes salvas.');
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirDialogoEdicao(
    BuildContext context,
    WidgetRef ref,
    Debt d,
  ) async {
    final valorController = TextEditingController(
      text: _centsToInput(d.valorCents),
    );
    final descricaoController = TextEditingController(text: d.descricao);
    var tipo = d.tipo;
    DateTime data = d.data;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar divida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DebtType>(
                initialValue: tipo,
                items: const [
                  DropdownMenuItem(
                    value: DebtType.divida,
                    child: Text('Divida'),
                  ),
                  DropdownMenuItem(
                    value: DebtType.adiantamento,
                    child: Text('Adiantamento'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => tipo = v);
                },
              ),
              TextField(
                controller: valorController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: 'Descricao'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cents = _parseReaisParaCents(valorController.text);
                if (cents == null || cents <= 0) {
                  _msg(context, 'Valor invalido.');
                  return;
                }
                try {
                  final isEmployee =
                      ref.read(sessionProvider)?.role == Role.employee;
                  if (isEmployee) {
                    await ref
                        .read(debtsProvider.notifier)
                        .requestEdit(
                          debtId: d.id,
                          employeeId: d.employeeId,
                          tipo: tipo,
                          valorCents: cents,
                          descricao: descricaoController.text.trim(),
                          data: data,
                        );
                  } else {
                    await ref
                        .read(debtsProvider.notifier)
                        .update(
                          d.id,
                          d.employeeId,
                          tipo,
                          cents,
                          descricaoController.text.trim(),
                          data,
                        );
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  _msg(context, 'Sem permissao para editar.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                _msg(
                  context,
                  ref.read(sessionProvider)?.role == Role.employee
                      ? 'Solicitacao de edicao enviada.'
                      : 'Divida editada.',
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    valorController.dispose();
    descricaoController.dispose();
  }

  Future<void> _abrirDialogoCriacao(BuildContext context, WidgetRef ref) async {
    final valorController = TextEditingController();
    final descricaoController = TextEditingController();
    var tipo = DebtType.divida;
    DateTime data = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nova divida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DebtType>(
                initialValue: tipo,
                items: const [
                  DropdownMenuItem(
                    value: DebtType.divida,
                    child: Text('Divida'),
                  ),
                  DropdownMenuItem(
                    value: DebtType.adiantamento,
                    child: Text('Adiantamento'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => tipo = v);
                },
              ),
              TextField(
                controller: valorController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: 'Descricao'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cents = _parseReaisParaCents(valorController.text);
                if (cents == null || cents <= 0) {
                  _msg(context, 'Valor invalido.');
                  return;
                }
                try {
                  await ref
                      .read(debtsProvider.notifier)
                      .add(
                        employee.id,
                        tipo,
                        cents,
                        descricaoController.text.trim(),
                        data,
                      );
                } catch (_) {
                  if (!context.mounted) return;
                  _msg(context, 'Erro ao criar divida.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                _msg(context, 'Divida criada.');
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    valorController.dispose();
    descricaoController.dispose();
  }

  String _statusDebt(DebtStatus status) {
    return switch (status) {
      DebtStatus.aberto => 'Aberto',
      DebtStatus.baixado => 'Baixado',
      DebtStatus.cancelado => 'Cancelado',
    };
  }

  String _moeda(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  String _data(DateTime? data) {
    if (data == null) return '-';
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    return '$d/$m/${data.year}';
  }

  int? _parseReaisParaCents(String valor) {
    var texto = valor.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (texto.isEmpty) return null;
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    final parsed = double.tryParse(texto);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  String _centsToInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
  }

  static void _msg(BuildContext context, String texto) {
    if (!context.mounted) return;
    context.showUserMessage(texto);
  }
}
