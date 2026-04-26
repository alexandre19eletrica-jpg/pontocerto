import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/work_entries/domain/work_entry.dart';
import 'package:pontocerto/features/work_entries/presentation/work_entries_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class WorkEntriesPage extends ConsumerStatefulWidget {
  const WorkEntriesPage({super.key});

  @override
  ConsumerState<WorkEntriesPage> createState() => _WorkEntriesPageState();
}

class _WorkEntriesPageState extends ConsumerState<WorkEntriesPage> {
  String? _employeeSelecionadoId;

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

    final somenteLeitura = sessao.role == Role.employee;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final entries = ref.watch(workEntriesProvider);

    if (somenteLeitura) {
      final employeeId = currentUid;
      final listaFiltrada = entries
          .where((item) => item.employeeId == employeeId)
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data));

      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
        header: AppWorkspaceHeader(
          title: 'Apontamentos',
          subtitle:
              'Leitura individual das horas registradas com acompanhamento de aprovacao.',
        ),
      );

      return AppGradientBackground(
        child: AppPageLayout(
          child: listaFiltrada.isEmpty
              ? const Center(child: Text('Nenhum apontamento para este funcionario.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: listaFiltrada.length,
                  itemBuilder: (context, index) {
                    final item = listaFiltrada[index];
                    final status = item.status == WorkEntryStatus.aprovado ? 'Aprovado' : 'Pendente';

                    return _surface(
                      child: ListTile(
                        title: Text('${_formatarData(item.data)} - ${item.horas}h'),
                        subtitle: Text('Status: $status'),
                      ),
                    );
                  },
                ),
        ),
      );
    }

    final employees = ref.watch(employeesProvider).where((e) => e.ativo).toList();
    if (employees.isEmpty) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
        header: AppWorkspaceHeader(
          title: 'Apontamentos',
          subtitle:
              'Controle operacional de horas por colaborador com aprovacao rapida.',
        ),
      );
      return const Center(child: Text('Cadastre funcionarios para lancar apontamentos.'));
    }

    _employeeSelecionadoId ??= employees.first.id;
    if (!employees.any((e) => e.id == _employeeSelecionadoId)) {
      _employeeSelecionadoId = employees.first.id;
    }

    final listaFiltrada = entries
        .where((item) => item.employeeId == _employeeSelecionadoId)
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Apontamentos',
        subtitle:
            'Controle operacional de horas por colaborador com aprovacao e edicao da empresa.',
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: _employeeSelecionadoId,
                  decoration: const InputDecoration(labelText: 'Funcionario'),
                  items: [
                    for (final employee in employees)
                      DropdownMenuItem(value: employee.id, child: Text(employee.nome)),
                  ],
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() => _employeeSelecionadoId = valor);
                    }
                  },
                ),
              ),
              Expanded(
                child: listaFiltrada.isEmpty
                    ? const Center(child: Text('Nenhum apontamento para este funcionario.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: listaFiltrada.length,
                        itemBuilder: (context, index) {
                          final item = listaFiltrada[index];
                          final status = item.status == WorkEntryStatus.aprovado
                              ? 'Aprovado'
                              : 'Pendente';

                          return _surface(
                            child: ListTile(
                              title: Text('${_formatarData(item.data)} - ${item.horas}h'),
                              subtitle: Text('Status: $status'),
                              onTap: somenteLeitura
                                  ? null
                                  : () => _abrirDialogo(
                                        context,
                                        employeeId: item.employeeId,
                                        item: item,
                                      ),
                              onLongPress: somenteLeitura
                                  ? null
                                  : () async {
                                      try {
                                        await ref.read(workEntriesProvider.notifier).remove(item.id);
                                        _ok('Apontamento removido com sucesso.');
                                      } catch (_) {
                                        _ok('Erro ao remover apontamento.');
                                      }
                                    },
                              trailing: somenteLeitura || item.status == WorkEntryStatus.aprovado
                                  ? null
                                  : TextButton(
                                      onPressed: () async {
                                        try {
                                          await ref.read(workEntriesProvider.notifier).approve(item.id);
                                          _ok('Apontamento aprovado com sucesso.');
                                        } catch (_) {
                                          _ok('Erro ao aprovar apontamento.');
                                        }
                                      },
                                      child: const Text('Aprovar'),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
              if (!somenteLeitura) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _abrirDialogo(
                      context,
                      employeeId: _employeeSelecionadoId!,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo apontamento'),
                  ),
                ),
              ],
            ],
        ),
      ),
    );
  }

  Future<void> _abrirDialogo(
    BuildContext context, {
    required String employeeId,
    WorkEntry? item,
  }) async {
    final horasController = TextEditingController(text: item?.horas.toString() ?? '');
    DateTime dataSelecionada = item?.data ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(item == null ? 'Novo apontamento' : 'Editar apontamento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final horas = int.tryParse(horasController.text.trim());
                    if (horas == null || horas <= 0) {
                      _ok('Informe horas validas.');
                      return;
                    }

                    if (item == null) {
                      try {
                        await ref.read(workEntriesProvider.notifier).add(employeeId, dataSelecionada, horas);
                      } catch (_) {
                        _ok('Erro ao salvar apontamento.');
                        return;
                      }
                    } else {
                      try {
                        await ref.read(workEntriesProvider.notifier).update(item.id, employeeId, dataSelecionada, horas);
                      } catch (_) {
                        _ok('Erro ao salvar apontamento.');
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
            );
          },
        );
      },
    );

    horasController.dispose();
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
}

