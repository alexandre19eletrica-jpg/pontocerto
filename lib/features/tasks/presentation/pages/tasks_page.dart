import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/media/firebase_media_upload.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/pdf/pdf_output.dart';
import 'package:pontocerto/core/pdf/standard_document.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/utils/bytes_download.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/features/clients/presentation/clients_provider.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/fiscal/domain/invoice_customer.dart';
import 'package:pontocerto/features/fiscal/presentation/services/fiscal_registry_lookup_service.dart';
import 'package:pontocerto/features/service_catalog/presentation/service_catalog_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:url_launcher/url_launcher.dart';

part 'tasks_page_support.dart';
part 'task_details_page.dart';
part 'task_details_sections.dart';
part 'task_details_operations.dart';
part 'task_details_media_pdf.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final _registryLookup = FiscalRegistryLookupService();
  String? _selectedResponsibleFilterId;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final isEmployee = sessao.role == Role.employee;
    final isAccountant = sessao.role == Role.accountant;
    final canManageTasks = sessao.role == Role.owner || sessao.role == Role.manager;
    final isEmpresa = !isEmployee;
    final employees = ref.watch(employeesProvider).where((e) => e.ativo).toList()
      ..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
    final todas = ref.watch(tasksProvider);
    final tarefasBase = isEmployee
        ? todas.where((t) => t.autorId == currentUid).toList()
        : todas;
    if (isEmpresa &&
        _selectedResponsibleFilterId != null &&
        !employees.any((e) => e.id == _selectedResponsibleFilterId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedResponsibleFilterId = null);
      });
    }
    final tarefas = isEmpresa && _selectedResponsibleFilterId != null
        ? tarefasBase
              .where((t) => t.autorId == _selectedResponsibleFilterId)
              .toList()
        : tarefasBase;
    final tarefasVisiveis = isAccountant
        ? tarefas.where((t) => t.status == StatusTarefa.finalizado).toList()
        : tarefas;
    final concluidas = tarefasVisiveis
        .where((t) => t.status == StatusTarefa.finalizado)
        .length;
    final pendentes = tarefasVisiveis.length - concluidas;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Tarefas e execucao',
        subtitle:
            isAccountant
                ? 'Consulta das tarefas finalizadas da empresa ativa da carteira para conferencia operacional antes da emissao fiscal.'
                : 'Fluxo de campo com tarefas, cliente, materiais, anexos e acompanhamento do status operacional.',
        chips: [
          const AppHeaderChip('Execucao conectada'),
          const AppHeaderChip('PDF e anexos'),
          AppHeaderChip('Total ${tarefasVisiveis.length}'),
        ],
      ),
    );
    return AppGradientBackground(
        child: AppPageLayout(
          child: ListView(
            children: [
              AppWorkspaceCard(
                title: 'Resumo de tarefas',
                subtitle:
                    isAccountant
                        ? 'Consulta do que ja foi finalizado na empresa ativa, sem alterar a operacao da equipe.'
                        : 'Visao rapida da carga operacional, com abertura para criacao de novas tarefas sem repetir contexto.',
                trailing: canManageTasks
                    ? TextButton.icon(
                        onPressed: () => _abrirDialogoCriar(sessao, currentUid),
                        icon: const Icon(Icons.add),
                        label: const Text('Criar'),
                      )
                    : null,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppMetricCard(
                      label: 'Total',
                      value: tarefasVisiveis.length.toString(),
                      caption: 'Tarefas no recorte atual',
                    ),
                    AppMetricCard(
                      label: 'Pendentes',
                      value: pendentes.toString(),
                      caption: 'Aguardando execucao ou fechamento',
                    ),
                    AppMetricCard(
                      label: 'Finalizadas',
                      value: concluidas.toString(),
                      caption: 'Concluidas no fluxo operacional',
                    ),
                  ],
                ),
              ),
              if (isEmployee) ...[
                const SizedBox(height: 16),
                _buildEmployeeAlertCard(tarefasVisiveis),
              ],
              if (isEmpresa) ...[
                const SizedBox(height: 16),
                _buildCompanyAssignmentCard(
                  employees: employees,
                  tarefasBase: tarefasBase,
                  tarefasFiltradas: tarefasVisiveis,
                  readOnlyAccountant: isAccountant,
                ),
              ],
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Lista operacional',
                subtitle:
                    isAccountant
                        ? 'Somente tarefas finalizadas da empresa ativa, para consulta do contador.'
                        : isEmpresa
                        ? 'Tarefas por responsavel, com cliente, status e data de execucao.'
                        : 'Tarefas em andamento, aprovadas, finalizadas ou em orcamento, com cliente e data de execucao.',
                child: Column(
                  children: [
                    if (tarefasVisiveis.isEmpty)
                      _buildEmptyTaskTile(
                        isAccountant
                            ? 'Nenhum servico finalizado encontrado para a empresa ativa.'
                            : isEmpresa && _selectedResponsibleFilterId != null
                            ? 'Nenhuma tarefa encontrada para o responsavel selecionado.'
                            : 'Nenhuma tarefa cadastrada.',
                      ),
                    ...tarefasVisiveis.map((tarefa) {
                      return _buildTaskListTile(
                        context,
                        sessao: sessao,
                        tarefa: tarefa,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildEmployeeAlertCard(List<TarefaItem> tarefas) {
    final novasOuPendentes = tarefas
        .where((t) => t.status != StatusTarefa.finalizado)
        .toList()
      ..sort(
        (a, b) => (a.dataExecucao ?? DateTime(2100)).compareTo(
          b.dataExecucao ?? DateTime(2100),
        ),
      );
    final proxima = novasOuPendentes.firstOrNull;
    return AppWorkspaceCard(
      title: 'Demandas para voce',
      subtitle:
          'Alerta rapido das tarefas que ainda precisam de acao no seu fluxo operacional.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          AppMetricCard(
            label: 'Aguardando acao',
            value: novasOuPendentes.length.toString(),
            caption: 'Tarefas ainda nao finalizadas',
          ),
          AppMetricCard(
            label: 'Proxima execucao',
            value: _formatarData(proxima?.dataExecucao),
            caption: proxima?.nome ?? 'Sem tarefa pendente',
          ),
          AppMetricCard(
            label: 'Em andamento',
            value: tarefas
                .where((t) => t.status == StatusTarefa.emAndamento)
                .length
                .toString(),
            caption: 'Ja iniciadas e ainda abertas',
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyAssignmentCard({
    required List<Employee> employees,
    required List<TarefaItem> tarefasBase,
    required List<TarefaItem> tarefasFiltradas,
    required bool readOnlyAccountant,
  }) {
    final pendentesGerais = tarefasBase
        .where((t) => t.status != StatusTarefa.finalizado)
        .length;
    final selectedEmployee = _findResponsibleById(
      employees,
      _selectedResponsibleFilterId,
    );
    final topEmployee = _employeeWithMostOpenTasks(employees, tarefasBase);
    return AppWorkspaceCard(
      title: 'Distribuicao por responsavel',
      subtitle:
          readOnlyAccountant
              ? 'Filtre os servicos finalizados por responsavel dentro da empresa ativa da carteira.'
              : 'Acompanhe a carga por funcionario e filtre a fila operacional antes de cobrar execucao.',
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _selectedResponsibleFilterId,
            decoration: const InputDecoration(
              labelText: 'Filtrar por responsavel',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos os responsaveis'),
              ),
              for (final employee in employees)
                DropdownMenuItem<String?>(
                  value: employee.id,
                  child: Text(employee.nomeCompleto),
                ),
            ],
            onChanged: (value) {
              setState(() => _selectedResponsibleFilterId = value);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              AppMetricCard(
                label: 'Pendentes',
                value: pendentesGerais.toString(),
                caption: 'Carga aberta da empresa',
              ),
              AppMetricCard(
                label: 'Responsavel filtrado',
                value: selectedEmployee?.nomeCompleto ?? 'Todos',
                caption: '${tarefasFiltradas.length} tarefa(s) no recorte',
              ),
              AppMetricCard(
                label: 'Maior carga',
                value: topEmployee?.nomeCompleto ?? '-',
                caption: topEmployee == null
                    ? 'Sem tarefas pendentes'
                    : '${_openTaskCount(topEmployee.id, tarefasBase)} pendente(s)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Employee? _employeeWithMostOpenTasks(
    List<Employee> employees,
    List<TarefaItem> tarefas,
  ) {
    Employee? top;
    var maiorCarga = 0;
    for (final employee in employees) {
      final carga = _openTaskCount(employee.id, tarefas);
      if (carga > maiorCarga) {
        maiorCarga = carga;
        top = employee;
      }
    }
    return top;
  }

  int _openTaskCount(String employeeId, List<TarefaItem> tarefas) {
    return tarefas
        .where(
          (t) =>
              t.autorId == employeeId && t.status != StatusTarefa.finalizado,
        )
        .length;
  }

  String _rotuloStatus(StatusTarefa status) {
    return _taskStatusLabel(status);
  }

  Color _statusColor(StatusTarefa status) {
    return switch (status) {
      StatusTarefa.orcamento => const Color(0xFFFFF1DE),
      StatusTarefa.aprovado => const Color(0xFFE5F3FF),
      StatusTarefa.iniciado => const Color(0xFFEAF5E8),
      StatusTarefa.emAndamento => const Color(0xFFEFF0FF),
      StatusTarefa.finalizado => const Color(0xFFE0F6E9),
    };
  }

  Widget _buildEmptyTaskTile(String message) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(message),
    );
  }

  Widget _buildTaskListTile(
    BuildContext context, {
    required Session sessao,
    required TarefaItem tarefa,
  }) {
    final cliente = tarefa.clienteNome.isEmpty ? '-' : tarefa.clienteNome;
    final clienteDocumento = tarefa.clienteDocumentoFormatado;
    final subtitulo = sessao.role == Role.employee
        ? '$cliente${clienteDocumento.isEmpty ? '' : ' - $clienteDocumento'} - ${_formatarData(tarefa.dataExecucao)}'
        : '${tarefa.autorNome} - $cliente${clienteDocumento.isEmpty ? '' : ' - $clienteDocumento'} - ${_formatarData(tarefa.dataExecucao)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        title: Text(tarefa.nome),
        subtitle: Text('${_rotuloStatus(tarefa.status)}\n$subtitulo'),
        isThreeLine: true,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor(tarefa.status),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: Color(0xFF10243A),
            size: 22,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailsPage(taskId: tarefa.id),
          ),
        ),
      ),
    );
  }

  List<Employee> _activeEmployees() {
    return ref.read(employeesProvider).where((e) => e.ativo).toList()
      ..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
  }

  Future<void> _abrirDialogoCriar(Session sessao, String currentUid) async {
    if (sessao.role == Role.accountant) {
      _msg('Contador possui consulta operacional somente leitura nesta rota.');
      return;
    }
    final nomeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final clienteCtrl = TextEditingController();
    final clienteDocumentoCtrl = TextEditingController();
    String? selectedClientId;
    final isEmpresa = sessao.role != Role.employee;
    final employees = _activeEmployees();
    String? selectedEmployeeId = isEmpresa && employees.isNotEmpty
        ? employees.first.id
        : null;
    bool lookupBusy = false;
    DateTime? dataExecucao;
    TarefaItem? nova;
    final clients = ref.read(clientsProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Criar tarefa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                const SizedBox(height: 8),
                if (isEmpresa) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _findResponsibleById(
                          employees,
                          selectedEmployeeId,
                        ) !=
                        null
                        ? selectedEmployeeId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Direcionar para funcionario',
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(employee.nomeCompleto),
                        ),
                    ],
                    onChanged: (value) {
                      setDialog(() => selectedEmployeeId = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      employees.isEmpty
                          ? 'Nenhum funcionario ativo disponivel para receber a tarefa.'
                          : 'A tarefa sera criada ja vinculada ao funcionario responsavel.',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (clients.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Cliente salvo',
                    ),
                    items: clients
                        .map(
                          (client) => DropdownMenuItem(
                            value: client.id,
                            child: Text(
                              client.legalName.isNotEmpty
                                  ? client.legalName
                                  : client.tradeName,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final selected = clients.where((c) => c.id == value).firstOrNull;
                      if (selected == null) return;
                      _applySharedCustomer(
                        customer: selected,
                        clienteCtrl: clienteCtrl,
                        clienteDocumentoCtrl: clienteDocumentoCtrl,
                      );
                      setDialog(() => selectedClientId = value);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: clienteCtrl,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: clienteDocumentoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CpfCnpjInputFormatter()],
                        maxLength: 18,
                        onChanged: (_) => setDialog(() {
                          selectedClientId = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'CPF ou CNPJ do cliente',
                          hintText: 'Digite o documento ou selecione um cliente salvo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: lookupBusy
                          ? null
                          : () async {
                              final digits = _somenteDigitosTexto(
                                clienteDocumentoCtrl.text,
                              );
                              if (digits.length != 14) {
                                _msg('Informe um CNPJ valido com 14 digitos.');
                                return;
                              }
                              setDialog(() => lookupBusy = true);
                              try {
                                final result = await _registryLookup.lookupCnpj(digits);
                                clienteCtrl.text =
                                    result['legalName']?.toString().trim().isNotEmpty == true
                                    ? result['legalName'].toString()
                                    : result['tradeName']?.toString() ?? '';
                                final clientId = _sharedCustomerId(
                                  clienteDocumentoCtrl.text,
                                );
                                selectedClientId = await _saveSharedCustomer(
                                  sessao: sessao,
                                  clientId: clientId,
                                  clientName: clienteCtrl.text.trim(),
                                  clientDocument: clienteDocumentoCtrl.text.trim(),
                                  email: result['email']?.toString() ?? '',
                                  phone: result['phone']?.toString() ?? '',
                                  municipalRegistration:
                                      sanitizeMunicipalRegistrationFromCnpjLookup(
                                    result,
                                    '',
                                  ),
                                  stateRegistration:
                                      result['stateRegistration']?.toString() ?? '',
                                  zipCode: result['zipCode']?.toString() ?? '',
                                  street: result['street']?.toString() ?? '',
                                  number: result['number']?.toString() ?? '',
                                  complement: result['complement']?.toString() ?? '',
                                  neighborhood:
                                      result['neighborhood']?.toString() ?? '',
                                  city: result['city']?.toString() ?? '',
                                  state: result['state']?.toString() ?? '',
                                );
                                if (mounted) {
                                  _msg('Cliente carregado e salvo na base.');
                                }
                              } catch (_) {
                                _msg('Nao foi possivel buscar o CNPJ agora.');
                              } finally {
                                if (mounted) {
                                  setDialog(() => lookupBusy = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar CNPJ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_documentoEhCnpjTexto(clienteDocumentoCtrl.text))
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ao buscar o CNPJ, o cliente entra automaticamente na base compartilhada.',
                    ),
                  ),
                if (_documentoEhCpfTexto(clienteDocumentoCtrl.text))
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CPF permanece com preenchimento manual por privacidade e LGPD.',
                    ),
                  ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da execucao'),
                  subtitle: Text(_formatarData(dataExecucao)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final escolhida = await showDatePicker(
                      context: dialogCtx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: dataExecucao ?? DateTime.now(),
                    );
                    if (escolhida != null) {
                      setDialog(() => dataExecucao = escolhida);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nomeCtrl.text.trim().isEmpty) {
                  return _msg('Informe o nome da tarefa.');
                }
                if (clienteCtrl.text.trim().isEmpty) {
                  return _msg('Informe o cliente da tarefa.');
                }
                if (dataExecucao == null) {
                  return _msg('Informe a data da execucao.');
                }
                final responsible = isEmpresa
                    ? _findResponsibleById(employees, selectedEmployeeId)
                    : null;
                if (isEmpresa && responsible == null) {
                  return _msg(
                    employees.isEmpty
                        ? 'Cadastre um funcionario ativo antes de direcionar tarefas.'
                        : 'Selecione o funcionario responsavel pela tarefa.',
                  );
                }
                nova = TarefaItem(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  autorId: responsible?.id ?? currentUid,
                  autorNome: responsible?.nomeCompleto ?? sessao.nome,
                  nome: nomeCtrl.text.trim(),
                  descricao: descCtrl.text.trim(),
                  clienteId:
                      selectedClientId ??
                      (_somenteDigitosTexto(clienteDocumentoCtrl.text).isEmpty
                          ? ''
                          : _sharedCustomerId(clienteDocumentoCtrl.text)),
                  clienteNome: clienteCtrl.text.trim(),
                  clienteDocumento: clienteDocumentoCtrl.text.trim(),
                  dataExecucao: _normalizarData(dataExecucao!),
                  itens: const <ItemServico>[],
                );
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    nomeCtrl.dispose();
    descCtrl.dispose();
    clienteCtrl.dispose();
    clienteDocumentoCtrl.dispose();
    if (nova == null || !mounted) return;

    try {
      if (nova!.clienteNome.trim().isNotEmpty &&
          nova!.clienteDocumento.trim().isNotEmpty) {
        final clientId = nova!.clienteId.isEmpty
            ? _sharedCustomerId(nova!.clienteDocumento)
            : nova!.clienteId;
        await _saveSharedCustomer(
          sessao: sessao,
          clientId: clientId,
          clientName: nova!.clienteNome.trim(),
          clientDocument: nova!.clienteDocumento.trim(),
        );
        nova = nova!.copyWith(clienteId: clientId);
      }
      await ref.read(tasksProvider.notifier).add(nova!);
      _msg('Tarefa salva com sucesso.');
    } catch (_) {
      _msg('Erro ao salvar tarefa.');
    }
  }

  DateTime _normalizarData(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatarData(DateTime? data) {
    return _taskFormatDate(data);
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }
}

