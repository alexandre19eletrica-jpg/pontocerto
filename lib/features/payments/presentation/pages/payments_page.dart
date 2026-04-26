import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_actions_service.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';
import 'package:pontocerto/features/payments/presentation/payments_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  String? _employeeSelecionadoId;
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

    final isEmployee = sessao.role == Role.employee;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final pagamentos = ref.watch(paymentsProvider);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .snapshots(),
      builder: (context, settingsSnapshot) {
        final companySettings =
            settingsSnapshot.data?.data() ?? <String, dynamic>{};

        if (isEmployee) {
          final employeeId = currentUid;
          final lista =
              pagamentos.where((item) => item.employeeId == employeeId).toList()
                ..sort((a, b) => b.dataRegistro.compareTo(a.dataRegistro));
          final pagos = lista
              .where((p) => p.status == PaymentStatus.pago)
              .length;
          final pendentes = lista
              .where((p) => p.status == PaymentStatus.pendente)
              .length;

          ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
            header: AppWorkspaceHeader(
              title: 'Meus pagamentos',
              subtitle:
                  'Acompanhe pagamentos recebidos, pendencias e confirmacoes da sua competencia atual.',
              chips: [
                AppHeaderChip('Total ${lista.length}'),
                AppHeaderChip('Pendentes $pendentes'),
                AppHeaderChip('Pagos $pagos'),
              ],
            ),
          );

          return AppGradientBackground(
            child: AppPageLayout(
              child: ListView(
                children: [
                  AppWorkspaceCard(
                    title: 'Resumo',
                    subtitle:
                        'Leitura pessoal dos pagamentos liberados, pendentes ou pagos.',
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        AppMetricCard(
                          label: 'Total',
                          value: lista.length.toString(),
                          caption: 'Pagamentos encontrados',
                        ),
                        AppMetricCard(
                          label: 'Pendentes',
                          value: pendentes.toString(),
                          caption: 'Ainda sem confirmacao final',
                        ),
                        AppMetricCard(
                          label: 'Pagos',
                          value: pagos.toString(),
                          caption: 'Disponiveis para conferencia',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppWorkspaceCard(
                    title: 'Lista de pagamentos',
                    subtitle:
                        'Consulte competencia, valor, status e eventual motivo de contestacao.',
                    child: lista.isEmpty
                        ? const ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Nenhum pagamento encontrado.'),
                          )
                        : Column(
                            children: [
                              for (final item in lista)
                                _surface(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Competencia: ${item.competencia}',
                                        ),
                                        Text(
                                          'Valor: ${_formatarMoeda(item.valorCents)}',
                                        ),
                                        Text(
                                          'Status: ${_textoStatus(item.status)}',
                                        ),
                                        if (item.motivoContestacao != null &&
                                            item.motivoContestacao!.isNotEmpty)
                                          Text(
                                            'Motivo: ${item.motivoContestacao}',
                                          ),
                                        if (item.status == PaymentStatus.pago)
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () async {
                                                  try {
                                                    await _actions.confirm(
                                                      item.id,
                                                    );
                                                    _ok(
                                                      'Pagamento confirmado com sucesso.',
                                                    );
                                                  } on FinanceActionException catch (
                                                    e
                                                  ) {
                                                    _ok(e.message);
                                                  } catch (_) {
                                                    _ok(
                                                      'Erro ao confirmar pagamento.',
                                                    );
                                                  }
                                                },
                                                child: const Text('Confirmar'),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                onPressed: () =>
                                                    _abrirDialogoContestacao(
                                                      context,
                                                      item.id,
                                                    ),
                                                child: const Text(
                                                  'Contestar',
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
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

        final employees = ref
            .watch(employeesProvider)
            .where((e) => e.ativo)
            .toList();
        if (employees.isEmpty) {
          ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
          return const Center(
              child: Text('Nenhum funcionario ativo cadastrado.'),
          );
        }

        _employeeSelecionadoId ??= employees.first.id;
        if (!employees.any((e) => e.id == _employeeSelecionadoId)) {
          _employeeSelecionadoId = employees.first.id;
        }

        final lista =
            pagamentos
                .where((item) => item.employeeId == _employeeSelecionadoId)
                .toList()
              ..sort((a, b) => b.dataRegistro.compareTo(a.dataRegistro));
        final pagos = lista.where((p) => p.status == PaymentStatus.pago).length;
        final pendentes = lista
            .where((p) => p.status == PaymentStatus.pendente)
            .length;

        ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
          header: AppWorkspaceHeader(
            title: 'Pagamentos',
            subtitle: 'Controle de pagamentos por colaborador e por competencia.',
            chips: [
              AppHeaderChip('Total ${lista.length}'),
              AppHeaderChip('Pendentes $pendentes'),
              AppHeaderChip('Pagos $pagos'),
            ],
          ),
          beforeLogout: [
            IconButton(
              onPressed: () => _abrirDialogoCadastroMultiplo(
                context,
                employees: employees,
                companySettings: companySettings,
              ),
              icon: const Icon(Icons.group_add_outlined),
              tooltip: 'Lancar pagamentos multiplos',
            ),
            IconButton(
              onPressed: () => _abrirDialogoCadastro(
                context,
                employeeId: _employeeSelecionadoId!,
                companySettings: companySettings,
              ),
              icon: const Icon(Icons.add),
              tooltip: 'Novo pagamento',
            ),
          ],
        );

        return AppGradientBackground(
          child: AppPageLayout(
            child: ListView(
              children: [
                AppWorkspaceCard(
                  title: 'Filtro',
                  subtitle:
                      'Escolha o colaborador para concentrar a leitura e a operacao da competencia.',
                  child: DropdownButtonFormField<String>(
                    initialValue: _employeeSelecionadoId,
                    decoration: const InputDecoration(
                      labelText: 'Funcionario',
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(employee.nome),
                        ),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => _employeeSelecionadoId = valor);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AppWorkspaceCard(
                  title: 'Resumo',
                  subtitle:
                      'Volume atual de pagamentos filtrados para o colaborador selecionado.',
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      AppMetricCard(
                        label: 'Total',
                        value: lista.length.toString(),
                        caption: 'No filtro atual',
                      ),
                      AppMetricCard(
                        label: 'Pendentes',
                        value: pendentes.toString(),
                        caption: 'Aguardando baixa',
                      ),
                      AppMetricCard(
                        label: 'Pagos',
                        value: pagos.toString(),
                        caption: 'Lancados',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppWorkspaceCard(
                  title: 'Pagamentos do colaborador',
                  subtitle:
                      'Consulte competencia, valor, status e restricoes de fechamento da folha.',
                  child: lista.isEmpty
                      ? const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Nenhum pagamento para este funcionario.',
                          ),
                        )
                      : Column(
                          children: [
                            for (final item in lista)
                              Builder(
                                builder: (context) {
                                  final pendente =
                                      item.status == PaymentStatus.pendente;
                                  final closed = _isPayrollClosed(
                                    companySettings,
                                    item.competencia,
                                  );
                                  return _surface(
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                      title: Text(
                                        'Competencia ${item.competencia}',
                                      ),
                                      subtitle: Text(
                                        '${_formatarMoeda(item.valorCents)} - ${_textoStatus(item.status)}'
                                        '${closed ? '\nCompetencia fechada: edicao/remocao bloqueadas' : ''}',
                                      ),
                                      isThreeLine: closed,
                                      onTap: closed
                                          ? () => _ok(
                                                'Competencia fechada. Edicao bloqueada.',
                                              )
                                          : () => _abrirDialogoCadastro(
                                                context,
                                                employeeId: item.employeeId,
                                                item: item,
                                                companySettings:
                                                    companySettings,
                                              ),
                                      onLongPress: () async {
                                        if (closed) {
                                          _ok(
                                            'Competencia fechada. Remocao bloqueada.',
                                          );
                                          return;
                                        }
                                        if (sessao.role == Role.employee) {
                                          _ok(
                                            'Sem permissao para cancelar pagamentos.',
                                          );
                                          return;
                                        }
                                        try {
                                          await _actions.cancelPayment(
                                            item.id,
                                          );
                                          _ok(
                                            'Pagamento removido com sucesso.',
                                          );
                                        } on FinanceActionException catch (
                                          e
                                        ) {
                                          _ok(e.message);
                                        } catch (_) {
                                          _ok(
                                            'Erro ao remover pagamento.',
                                          );
                                        }
                                      },
                                      trailing: pendente
                                          ? TextButton(
                                              onPressed: () async {
                                                try {
                                                  await _actions.markPaid(
                                                    item.id,
                                                  );
                                                  _ok(
                                                    'Pagamento marcado como pago.',
                                                  );
                                                } on FinanceActionException catch (
                                                  e
                                                ) {
                                                  _ok(e.message);
                                                } catch (_) {
                                                  _ok(
                                                    'Erro ao marcar pagamento.',
                                                  );
                                                }
                                              },
                                              child: const Text(
                                                'Marcar como pago',
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirDialogoCadastro(
    BuildContext context, {
    required String employeeId,
    required Map<String, dynamic> companySettings,
    Payment? item,
  }) async {
    final employees = ref.read(employeesProvider).where((e) => e.ativo).toList();
    final selectedEmployee =
        employees.where((e) => e.id == employeeId).firstOrNull;
    var paymentType = selectedEmployee?.compensationType;
    final competenciaController = TextEditingController(
      text: item?.competencia ?? '',
    );
    final valorController = TextEditingController(
      text: item == null ? '' : _centsParaInput(item.valorCents),
    );
    DateTime? selectedPaymentDate;
    var markAsPaid = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: Text(item == null ? 'Novo pagamento' : 'Editar pagamento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: competenciaController,
                  decoration: const InputDecoration(
                    labelText: 'Competencia (YYYY-MM)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                ),
                if (item == null && paymentType != null) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<dynamic>(
                    initialValue: paymentType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo do pagamento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: EmployeeCompensationType.daily,
                        child: Text('Diaria'),
                      ),
                      DropdownMenuItem(
                        value: EmployeeCompensationType.weekly,
                        child: Text('Semanal'),
                      ),
                      DropdownMenuItem(
                        value: EmployeeCompensationType.monthly,
                        child: Text('Mensal'),
                      ),
                      DropdownMenuItem(
                        value: EmployeeCompensationType.commission,
                        child: Text('Comissao'),
                      ),
                    ],
                    onChanged: (value) {
                      setLocalState(() => paymentType = value);
                    },
                  ),
                ],
                if (item == null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: markAsPaid,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Marcar como pago ao lancar'),
                    subtitle: Text(
                      markAsPaid
                          ? 'Vai refletir hoje no financeiro da empresa como saida/despesa.'
                          : 'Se desmarcado, informe a data prevista do pagamento.',
                    ),
                    onChanged: (value) {
                      setLocalState(() {
                        markAsPaid = value;
                        if (markAsPaid) {
                          selectedPaymentDate = null;
                        }
                      });
                    },
                  ),
                  if (!markAsPaid)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Data prevista do pagamento: ${_formatDate(selectedPaymentDate)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedPaymentDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setLocalState(() => selectedPaymentDate = picked);
                            }
                          },
                          child: const Text('Selecionar'),
                        ),
                        if (selectedPaymentDate != null)
                          TextButton(
                            onPressed: () => setLocalState(() => selectedPaymentDate = null),
                            child: const Text('Limpar'),
                          ),
                      ],
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final competencia = competenciaController.text.trim();
                  final valorCents = _parseReaisParaCents(valorController.text);
                  if (!_competenciaValida(competencia) ||
                      valorCents == null ||
                      valorCents <= 0) {
                    _ok('Preencha os campos corretamente.');
                    return;
                  }
                  if (_isPayrollClosed(companySettings, competencia)) {
                    _ok('Competencia fechada. Edicao/criacao bloqueada.');
                    return;
                  }

                  if (item == null) {
                    final ym = _parseCompetencia(competencia);
                    if (ym == null) {
                      _ok('Competencia invalida.');
                      return;
                    }
                    try {
                      await _actions.createPayment(
                        employeeId: employeeId,
                        competenceYear: ym.$1,
                        competenceMonth: ym.$2,
                        grossCents: valorCents,
                        discountsCents: 0,
                        dueDate: selectedPaymentDate,
                        paymentType: _paymentTypeApiValue(paymentType),
                        markAsPaid: markAsPaid,
                      );
                    } on FinanceActionException catch (e) {
                      _ok(e.message);
                      return;
                    } catch (_) {
                      _ok('Erro ao salvar pagamento.');
                      return;
                    }
                  } else {
                    try {
                      final ym = _parseCompetencia(competencia);
                      if (ym == null) {
                        _ok('Competencia invalida.');
                        return;
                      }
                      await _actions.updatePayment(
                        paymentId: item.id,
                        employeeId: employeeId,
                        competenceYear: ym.$1,
                        competenceMonth: ym.$2,
                        grossCents: valorCents,
                        discountsCents: 0,
                      );
                    } catch (_) {
                      _ok('Erro ao salvar pagamento.');
                      return;
                    }
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  _ok('Dados salvos com sucesso.');
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );

    competenciaController.dispose();
    valorController.dispose();
  }

  Future<void> _abrirDialogoCadastroMultiplo(
    BuildContext context, {
    required List<dynamic> employees,
    required Map<String, dynamic> companySettings,
  }) async {
    final employeeList = ref.read(employeesProvider).where((e) => e.ativo).toList();
    final competenciaController = TextEditingController();
    final valorController = TextEditingController();
    final selecionados = <String>{
      for (final employee in employees) employee.id.toString(),
    };
    DateTime? selectedPaymentDate;
    var markAsPaid = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Lancar pagamentos multiplos'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: competenciaController,
                        decoration: const InputDecoration(
                          labelText: 'Competencia (YYYY-MM)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: valorController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor para cada funcionario (R\$)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: markAsPaid,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Marcar pagamentos como pagos ao lancar'),
                        subtitle: Text(
                          markAsPaid
                              ? 'Vai refletir hoje no financeiro da empresa como saida/despesa.'
                              : 'Se desmarcado, informe a data prevista do pagamento.',
                        ),
                        onChanged: (value) {
                          setLocalState(() {
                            markAsPaid = value;
                            if (markAsPaid) {
                              selectedPaymentDate = null;
                            }
                          });
                        },
                      ),
                      if (!markAsPaid) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Data prevista do pagamento: ${_formatDate(selectedPaymentDate)}',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedPaymentDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setLocalState(() => selectedPaymentDate = picked);
                                }
                              },
                              child: const Text('Selecionar'),
                            ),
                            if (selectedPaymentDate != null)
                              TextButton(
                                onPressed: () => setLocalState(() => selectedPaymentDate = null),
                                child: const Text('Limpar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              setLocalState(() {
                                selecionados
                                  ..clear()
                                  ..addAll(
                                    employees.map((item) => item.id.toString()),
                                  );
                              });
                            },
                            child: const Text('Marcar todos'),
                          ),
                          TextButton(
                            onPressed: () {
                              setLocalState(selecionados.clear);
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final employee in employees)
                        CheckboxListTile(
                          value: selecionados.contains(employee.id.toString()),
                          contentPadding: EdgeInsets.zero,
                          title: Text(employee.nome.toString()),
                          onChanged: (value) {
                            setLocalState(() {
                              if (value == true) {
                                selecionados.add(employee.id.toString());
                              } else {
                                selecionados.remove(employee.id.toString());
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final competencia = competenciaController.text.trim();
                    final valorCents = _parseReaisParaCents(valorController.text);
                    final parsedCompetence = _parseCompetencia(competencia);
                    if (parsedCompetence == null ||
                        valorCents == null ||
                        valorCents <= 0) {
                      _ok('Preencha competencia e valor corretamente.');
                      return;
                    }
                    if (_isPayrollClosed(companySettings, competencia)) {
                      _ok('Competencia fechada. Lancamento bloqueado.');
                      return;
                    }
                    if (selecionados.isEmpty) {
                      _ok('Selecione ao menos um funcionario.');
                      return;
                    }

                    try {
                      for (final employeeId in selecionados) {
                        final employee = employeeList
                            .where((item) => item.id.toString() == employeeId)
                            .firstOrNull;
                        await _actions.createPayment(
                          employeeId: employeeId,
                          competenceYear: parsedCompetence.$1,
                          competenceMonth: parsedCompetence.$2,
                          grossCents: valorCents,
                          discountsCents: 0,
                          dueDate: selectedPaymentDate,
                          paymentType: _paymentTypeApiValue(employee?.compensationType),
                          markAsPaid: markAsPaid,
                        );
                      }
                    } on FinanceActionException catch (e) {
                      _ok(e.message);
                      return;
                    } catch (_) {
                      _ok('Nao foi possivel lancar os pagamentos.');
                      return;
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    _ok(
                      selecionados.length == 1
                          ? 'Pagamento lancado.'
                          : '${selecionados.length} pagamentos lancados.',
                    );
                  },
                  child: const Text('Lancar'),
                ),
              ],
            );
          },
        );
      },
    );

    competenciaController.dispose();
    valorController.dispose();
  }

  Future<void> _abrirDialogoContestacao(BuildContext context, String id) async {
    final motivoController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contestar pagamento'),
          content: TextField(
            controller: motivoController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final motivo = motivoController.text.trim();
                if (motivo.isEmpty) {
                  _ok('Informe o motivo da contestacao.');
                  return;
                }
                try {
                  await _actions.contest(paymentId: id, reason: motivo);
                } on FinanceActionException catch (e) {
                  _ok(e.message);
                  return;
                } catch (_) {
                  _ok('Erro ao enviar contestacao.');
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _ok('Contestacao enviada com sucesso.');
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    motivoController.dispose();
  }

  String _textoStatus(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.pendente => 'Pendente',
      PaymentStatus.pago => 'Pago',
      PaymentStatus.confirmado => 'Confirmado',
      PaymentStatus.contestado => 'Contestado',
      PaymentStatus.cancelado => 'Cancelado',
    };
  }

  String _formatarMoeda(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  String _centsParaInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
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

  bool _competenciaValida(String competencia) {
    final regex = RegExp(r'^\d{4}-\d{2}$');
    if (!regex.hasMatch(competencia)) return false;
    final mes = int.tryParse(competencia.substring(5, 7));
    return mes != null && mes >= 1 && mes <= 12;
  }

  (int, int)? _parseCompetencia(String competencia) {
    if (!_competenciaValida(competencia)) return null;
    final year = int.tryParse(competencia.substring(0, 4));
    final month = int.tryParse(competencia.substring(5, 7));
    if (year == null || month == null) return null;
    return (year, month);
  }

  void _ok(String msg) {
    if (!mounted) return;
    if (!context.mounted) return;
    context.showUserMessage(msg);
  }

  bool _isPayrollClosed(Map<String, dynamic> settings, String competencia) {
    final raw = settings['closedPayrollCompetences'];
    if (raw is! List) return false;
    return raw.map((e) => e.toString()).contains(competencia);
  }

  String? _paymentTypeApiValue(dynamic compensationType) {
    return switch (compensationType) {
      EmployeeCompensationType.daily => 'DAILY',
      EmployeeCompensationType.weekly => 'WEEKLY',
      EmployeeCompensationType.monthly => 'MONTHLY',
      EmployeeCompensationType.commission => 'COMMISSION',
      _ => null,
    };
  }
}
