import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/debts/domain/debt.dart';
import 'package:pontocerto/features/debts/presentation/debts_provider.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_actions_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});

  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage> {
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
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }
    final isEmployee = sessao.role == Role.employee;
    final employees = ref.watch(employeesProvider).where((e) => e.ativo).toList();
    final debts = ref.watch(debtsProvider);

    if (!isEmployee && employees.isEmpty) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Center(child: Text('Nenhum funcionario ativo cadastrado.'));
    }

    if (isEmployee) {
      _employeeSelecionadoId = sessao.userId;
    } else {
      _employeeSelecionadoId ??= employees.first.id;
      if (!employees.any((e) => e.id == _employeeSelecionadoId)) {
        _employeeSelecionadoId = employees.first.id;
      }
    }

    final lista = debts.where((item) => item.employeeId == _employeeSelecionadoId).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    final qtdAbertos = lista.where((d) => d.status == DebtStatus.aberto).length;
    final qtdBaixados = lista.where((d) => d.status == DebtStatus.baixado).length;
    final qtdCancelados = lista.where((d) => d.status == DebtStatus.cancelado).length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Dividas e adiantamentos',
        subtitle: isEmployee
            ? 'Acompanhe seus registros, pedidos de edicao e pagamentos liberados pela empresa.'
            : 'Controle de valores em aberto, baixas e permissoes por colaborador.',
        chips: [
          AppHeaderChip('Total ${lista.length}'),
          AppHeaderChip('Abertos $qtdAbertos'),
          AppHeaderChip('Baixados $qtdBaixados'),
          AppHeaderChip('Cancelados $qtdCancelados'),
        ],
      ),
      beforeLogout: [
        IconButton(
          onPressed: _employeeSelecionadoId == null
              ? null
              : () => _abrirDialogo(context, employeeId: _employeeSelecionadoId!),
          icon: const Icon(Icons.add),
          tooltip: 'Novo registro',
        ),
      ],
    );
    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            if (!isEmployee)
              AppWorkspaceCard(
                title: 'Filtro',
                subtitle:
                    'Selecione o colaborador para visualizar os registros e agir no contexto correto.',
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
            if (!isEmployee) const SizedBox(height: 16),
            AppWorkspaceCard(
              title: 'Resumo',
              subtitle:
                  'Visao consolidada dos registros atuais para o colaborador selecionado.',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Panorama dos registros'),
                subtitle: Text(
                  'Total de registros: ${lista.length}\n'
                  'Abertos: $qtdAbertos | Baixados: $qtdBaixados | Cancelados: $qtdCancelados',
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 16),
            AppWorkspaceCard(
              title: isEmployee ? 'Meus registros' : 'Registros do colaborador',
              subtitle: isEmployee
                  ? 'Acompanhe suas dividas e adiantamentos, com acesso rapido para pagar quando estiver liberado.'
                  : 'Gerencie registros, permissoes e solicitacoes de edicao sem sair do fluxo principal.',
              trailing: TextButton.icon(
                onPressed: _employeeSelecionadoId == null
                    ? null
                    : () => _abrirDialogo(
                          context,
                          employeeId: _employeeSelecionadoId!,
                        ),
                icon: const Icon(Icons.add),
                label: const Text('Novo'),
              ),
              child: lista.isEmpty
                  ? const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Nenhum registro para este funcionario.'),
                    )
                  : Column(
                      children: [
                        for (final item in lista)
                          _buildDebtTile(
                            context: context,
                            isEmployee: isEmployee,
                            item: item,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtTile({
    required BuildContext context,
    required bool isEmployee,
    required Debt item,
  }) {
    final estaAberto = item.status == DebtStatus.aberto;
    final pendenteAprovacao = item.editRequestPending;
    final podeEditarFuncionario =
        isEmployee &&
        item.status == DebtStatus.aberto &&
        item.allowEmployeeEdit &&
        !item.editRequestPending;
    final podePagarFuncionario =
        isEmployee &&
        item.status == DebtStatus.aberto &&
        item.allowEmployeeSettle;

    return _surface(
      child: ListTile(
        leading: Icon(
          item.tipo == DebtType.divida
              ? Icons.trending_down_outlined
              : Icons.account_balance_wallet_outlined,
        ),
        title: Text('${_textoTipo(item.tipo)} - ${_formatarMoeda(item.valorCents)}'),
        subtitle: Text(
          '${_formatarData(item.data)} - ${_textoStatus(item.status)}'
          '${pendenteAprovacao ? ' | Edicao pendente de autorizacao' : ''}\n${item.descricao}',
        ),
        isThreeLine: true,
        onTap: !isEmployee || podeEditarFuncionario
            ? () => _abrirDialogo(
                  context,
                  employeeId: item.employeeId,
                  item: item,
                )
            : null,
        onLongPress: isEmployee
            ? null
            : () async {
                try {
                  await _actions.cancelDebt(item.id);
                  _ok('Registro removido com sucesso.');
                } on FinanceActionException catch (e) {
                  _ok(e.message);
                } catch (_) {
                  _ok('Erro ao remover registro.');
                }
              },
        trailing: isEmployee
            ? Wrap(
                spacing: 4,
                children: [
                  if (podePagarFuncionario)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(debtsProvider.notifier)
                              .payByEmployee(item.id);
                          _ok('Pagamento registrado com sucesso.');
                        } catch (_) {
                          _ok('Sem permissao para pagar esta divida.');
                        }
                      },
                      child: const Text('Pagar'),
                    ),
                ],
              )
            : Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () async {
                      await _abrirPermissoesEmpresa(context, item);
                    },
                    child: const Text('Permissoes'),
                  ),
                  if (estaAberto && pendenteAprovacao) ...[
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(debtsProvider.notifier)
                              .approveEditRequest(item.id);
                          _ok('Solicitacao aprovada e aplicada.');
                        } catch (_) {
                          _ok('Erro ao aprovar solicitacao.');
                        }
                      },
                      child: const Text('Aprovar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(debtsProvider.notifier)
                              .rejectEditRequest(item.id);
                          _ok('Solicitacao reprovada.');
                        } catch (_) {
                          _ok('Erro ao reprovar solicitacao.');
                        }
                      },
                      child: const Text('Reprovar'),
                    ),
                  ],
                  if (estaAberto && !pendenteAprovacao)
                    TextButton(
                      onPressed: () async {
                        try {
                          await _actions.settleDebt(item.id);
                          _ok('Registro baixado com sucesso.');
                        } on FinanceActionException catch (e) {
                          _ok(e.message);
                        } catch (_) {
                          _ok('Erro ao baixar registro.');
                        }
                      },
                      child: const Text('Baixar'),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _abrirDialogo(BuildContext context, {required String employeeId, Debt? item}) async {
    final isEmployee = ref.read(sessionProvider)?.role == Role.employee;
    var tipoSelecionado = item?.tipo ?? DebtType.divida;
    final valorController = TextEditingController(text: item == null ? '' : _centsParaInput(item.valorCents));
    final descricaoController = TextEditingController(text: item?.descricao ?? '');
    DateTime dataSelecionada = item?.data ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(item == null ? 'Novo registro' : 'Editar registro'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<DebtType>(
                    initialValue: tipoSelecionado,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: DebtType.divida, child: Text('Divida')),
                      DropdownMenuItem(value: DebtType.adiantamento, child: Text('Adiantamento')),
                    ],
                    onChanged: (valor) {
                      if (valor != null) setStateDialog(() => tipoSelecionado = valor);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: valorController,
                    inputFormatters: [CurrencyPtBrInputFormatter()],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descricaoController,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Data: ${_formatarData(dataSelecionada)}')),
                      TextButton(
                        onPressed: () async {
                          final escolhida = await showDatePicker(
                            context: context,
                            initialDate: dataSelecionada,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (escolhida != null) setStateDialog(() => dataSelecionada = escolhida);
                        },
                        child: const Text('Selecionar'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    final valorCents = _parseReaisParaCents(valorController.text);
                    if (valorCents == null || valorCents <= 0) {
                      _ok('Informe um valor valido.');
                      return;
                    }

                    final descricao = descricaoController.text.trim();
                    try {
                      if (item == null) {
                        if (isEmployee) {
                          await ref.read(debtsProvider.notifier).add(
                                employeeId,
                                tipoSelecionado,
                                valorCents,
                                descricao,
                                dataSelecionada,
                              );
                        } else {
                          await _actions.createDebt(
                            employeeId: employeeId,
                            title: descricao,
                            type: tipoSelecionado == DebtType.divida ? 'DEBT' : 'ADVANCE',
                            amountCents: valorCents,
                          );
                        }
                      } else {
                        if (isEmployee) {
                          if (!item.allowEmployeeEdit) {
                            _ok('A empresa ainda nao permitiu edicao desta divida.');
                            return;
                          }
                          if (item.editRequestPending) {
                            _ok('Ja existe uma solicitacao pendente para esta divida.');
                            return;
                          }
                          await ref.read(debtsProvider.notifier).requestEdit(
                                debtId: item.id,
                                employeeId: employeeId,
                                tipo: tipoSelecionado,
                                valorCents: valorCents,
                                descricao: descricao,
                                data: dataSelecionada,
                              );
                        } else {
                          await ref.read(debtsProvider.notifier).update(
                                item.id,
                                employeeId,
                                tipoSelecionado,
                                valorCents,
                                descricao,
                                dataSelecionada,
                              );
                        }
                      }
                    } on FinanceActionException catch (e) {
                      _ok(e.message);
                      return;
                    } catch (_) {
                      _ok('Erro ao salvar registro.');
                      return;
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    _ok(
                      isEmployee && item != null
                          ? 'Solicitacao de edicao enviada para aprovacao da empresa.'
                          : 'Dados salvos com sucesso.',
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    valorController.dispose();
    descricaoController.dispose();
  }

  String _textoTipo(DebtType tipo) =>
      tipo == DebtType.divida ? 'Divida' : 'Adiantamento';

  String _textoStatus(DebtStatus status) {
    return switch (status) {
      DebtStatus.aberto => 'Aberto',
      DebtStatus.baixado => 'Baixado',
      DebtStatus.cancelado => 'Cancelado',
    };
  }

  String _formatarMoeda(int cents) {
    final sinal = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final reais = abs ~/ 100;
    final centavos = (abs % 100).toString().padLeft(2, '0');
    return 'R\$ $sinal$reais,$centavos';
  }

  String _centsParaInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
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

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  void _ok(String msg) {
    if (!mounted) return;
    if (!context.mounted) return;
    context.showUserMessage(msg);
  }

  Future<void> _abrirPermissoesEmpresa(BuildContext context, Debt item) async {
    var permitirEditar = item.allowEmployeeEdit;
    var permitirPagar = item.allowEmployeeSettle;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Permissoes da divida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: permitirEditar,
                onChanged: (v) => setDialogState(() => permitirEditar = v),
                title: const Text('Permitir funcionario editar'),
              ),
              SwitchListTile(
                value: permitirPagar,
                onChanged: (v) => setDialogState(() => permitirPagar = v),
                title: const Text('Permitir funcionario pagar'),
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
                  await ref.read(debtsProvider.notifier).setEmployeePermissions(
                        debtId: item.id,
                        allowEmployeeEdit: permitirEditar,
                        allowEmployeeSettle: permitirPagar,
                      );
                } catch (_) {
                  _ok('Erro ao salvar permissoes.');
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _ok('Permissoes atualizadas.');
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

