import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/features/clients/presentation/clients_provider.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/fiscal/domain/invoice_customer.dart';
import 'package:pontocerto/features/service_orders/domain/service_order.dart';
import 'package:pontocerto/features/service_orders/presentation/service_orders_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class ServiceOrdersPage extends ConsumerStatefulWidget {
  const ServiceOrdersPage({super.key});

  @override
  ConsumerState<ServiceOrdersPage> createState() => _ServiceOrdersPageState();
}

class _ServiceOrdersPageState extends ConsumerState<ServiceOrdersPage> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final orders = ref.watch(serviceOrdersProvider);
    final employees = ref.watch(employeesProvider).where((e) => e.ativo).toList()
      ..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
    final tasks = ref.watch(tasksProvider);
    final clients = ref.watch(clientsProvider);
    final openCount = orders.where((o) => o.status == ServiceOrderStatus.open).length;
    final inProgressCount = orders
        .where((o) => o.status == ServiceOrderStatus.inProgress)
        .length;
    final completedCount = orders
        .where((o) => o.status == ServiceOrderStatus.completed)
        .length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Ordens de servico',
        subtitle:
            'Camada operacional em volta das tarefas para organizar atendimento, responsavel, visita em campo e fechamento do servico.',
        chips: const [
          AppHeaderChip('ERP de servicos'),
          AppHeaderChip('Ligada a cliente e tarefa'),
        ],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
            children: [
              AppWorkspaceCard(
                title: 'Resumo operacional',
                subtitle:
                    'Visao rapida das ordens abertas, em andamento e finalizadas.',
                trailing: session.role == Role.employee
                    ? null
                    : TextButton.icon(
                        onPressed: () =>
                            _openCreateDialog(session, employees, tasks, clients),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Nova OS'),
                      ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppMetricCard(
                      label: 'Abertas',
                      value: openCount.toString(),
                      caption: 'Aguardando inicio',
                    ),
                    AppMetricCard(
                      label: 'Em andamento',
                      value: inProgressCount.toString(),
                      caption: 'Execucao de campo',
                    ),
                    AppMetricCard(
                      label: 'Finalizadas',
                      value: completedCount.toString(),
                      caption: 'Concluidas',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Fila de atendimento',
                subtitle:
                    'Ordens ligadas a cliente, tarefa e responsavel para organizar atendimento, visita em campo e fechamento.',
                child: orders.isEmpty
                    ? const Text(
                        'Nenhuma ordem de servico criada ainda.',
                        style: TextStyle(color: AppBrandColors.softText),
                      )
                    : Column(
                        children: [
                          for (final order in orders) ...[
                            _OrderTile(
                              order: order,
                              canManage: session.role != Role.employee,
                              onStatusChanged: (status) =>
                                  _updateStatus(order, status),
                              onEditNotes: () =>
                                  _openNotesDialog(order),
                              onDelete: session.role == Role.employee
                                  ? null
                                  : () => _confirmDelete(order),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
    );
  }

  Future<void> _openCreateDialog(
    Session session,
    List<Employee> employees,
    List<TarefaItem> tasks,
    List<InvoiceCustomer> clients,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String clientId = '';
    String clientName = '';
    String taskId = '';
    String assignedEmployeeId = '';
    String assignedEmployeeName = '';
    DateTime? scheduledDate;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nova ordem de servico'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: clientId.isEmpty ? null : clientId,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: [
                      for (final client in clients)
                        DropdownMenuItem<String>(
                          value: client.id.toString(),
                          child: Text(
                            client.legalName.isNotEmpty
                                ? client.legalName
                                : client.tradeName,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      final selected = clients
                          .where((c) => c.id == value)
                          .firstOrNull;
                      setDialogState(() {
                        clientId = selected?.id.toString() ?? '';
                        clientName = selected == null
                            ? ''
                            : (selected.legalName.isNotEmpty
                                  ? selected.legalName
                                  : selected.tradeName);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: taskId.isEmpty ? null : taskId,
                    decoration: const InputDecoration(labelText: 'Tarefa ligada'),
                    items: [
                      for (final task in tasks)
                        DropdownMenuItem<String>(
                          value: task.id,
                          child: Text(task.nome),
                        ),
                    ],
                    onChanged: (value) {
                      final selected = tasks.where((t) => t.id == value).firstOrNull;
                      setDialogState(() {
                        taskId = selected?.id ?? '';
                        if (titleController.text.trim().isEmpty &&
                            selected != null) {
                          titleController.text = selected.nome;
                        }
                        if (descriptionController.text.trim().isEmpty &&
                            selected != null) {
                          descriptionController.text = selected.descricao;
                        }
                        if (clientId.isEmpty && selected != null) {
                          clientId = selected.clienteId;
                          clientName = selected.clienteNome;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue:
                        assignedEmployeeId.isEmpty ? null : assignedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Responsavel de campo',
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem<String>(
                          value: employee.id,
                          child: Text(employee.nomeCompleto),
                        ),
                    ],
                    onChanged: (value) {
                      final selected = employees.where((e) => e.id == value).firstOrNull;
                      setDialogState(() {
                        assignedEmployeeId = selected?.id ?? '';
                        assignedEmployeeName = selected?.nomeCompleto ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data prevista'),
                    subtitle: Text(
                      scheduledDate == null
                          ? 'Nao definida'
                          : _formatDate(scheduledDate),
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                          initialDate: scheduledDate ?? DateTime.now(),
                        );
                        if (picked == null) return;
                        setDialogState(() => scheduledDate = picked);
                      },
                      icon: const Icon(Icons.event_outlined),
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
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  final order = ServiceOrder(
                    id: 'os_${DateTime.now().microsecondsSinceEpoch}',
                    companyId: session.companyId,
                    title: title,
                    description: descriptionController.text.trim(),
                    clientId: clientId,
                    clientName: clientName,
                    taskId: taskId,
                    assignedEmployeeId: assignedEmployeeId,
                    assignedEmployeeName: assignedEmployeeName,
                    scheduledDate: scheduledDate,
                  );
                  await ref.read(serviceOrdersProvider.notifier).add(order);
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
    }
  }

  Future<void> _openNotesDialog(ServiceOrder order) async {
    final controller = TextEditingController(text: order.fieldNotes);
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registro de execucao'),
          content: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Observacoes de campo',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(serviceOrdersProvider.notifier).update(
                      order.copyWith(fieldNotes: controller.text.trim()),
                    );
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _updateStatus(
    ServiceOrder order,
    ServiceOrderStatus status,
  ) async {
    await ref.read(serviceOrdersProvider.notifier).update(
          order.copyWith(status: status),
        );
  }

  Future<void> _confirmDelete(ServiceOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ordem de servico'),
        content: Text(
          'Deseja excluir a OS "${order.title}"? Essa acao remove o registro operacional desta visita.',
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
    await ref.read(serviceOrdersProvider.notifier).remove(order);
    if (!mounted) return;
    if (context.mounted) { context.showUserMessage('Ordem de servico excluida.'); }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Nao definida';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.canManage,
    required this.onStatusChanged,
    required this.onEditNotes,
    required this.onDelete,
  });

  final ServiceOrder order;
  final bool canManage;
  final ValueChanged<ServiceOrderStatus> onStatusChanged;
  final VoidCallback onEditNotes;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppBrandColors.ink,
                  ),
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          if (order.description.trim().isNotEmpty)
            Text(
              order.description,
              style: const TextStyle(
                color: AppBrandColors.softText,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (order.clientName.isNotEmpty)
                AppHeaderChip('Cliente ${order.clientName}'),
              if (order.assignedEmployeeName.isNotEmpty)
                AppHeaderChip('Responsavel ${order.assignedEmployeeName}'),
              if (order.taskId.isNotEmpty) AppHeaderChip('Tarefa ${order.taskId}'),
              AppHeaderChip(
                order.scheduledDate == null
                    ? 'Sem agenda'
                    : 'Prevista ${_formatDate(order.scheduledDate!)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (canManage)
                DropdownButton<ServiceOrderStatus>(
                  value: order.status,
                  items: const [
                    DropdownMenuItem(
                      value: ServiceOrderStatus.open,
                      child: Text('Aberta'),
                    ),
                    DropdownMenuItem(
                      value: ServiceOrderStatus.inProgress,
                      child: Text('Em andamento'),
                    ),
                    DropdownMenuItem(
                      value: ServiceOrderStatus.completed,
                      child: Text('Finalizada'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onStatusChanged(value);
                  },
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: onEditNotes,
                icon: const Icon(Icons.edit_note_outlined),
                label: Text(
                  order.fieldNotes.trim().isEmpty ? 'Registrar campo' : 'Editar registro',
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ],
            ],
          ),
          if (order.fieldNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              order.fieldNotes,
              style: const TextStyle(
                color: AppBrandColors.softText,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ServiceOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ServiceOrderStatus.open => 'Aberta',
      ServiceOrderStatus.inProgress => 'Em andamento',
      ServiceOrderStatus.completed => 'Finalizada',
    };
    final color = switch (status) {
      ServiceOrderStatus.open => const Color(0xFFFFF1DE),
      ServiceOrderStatus.inProgress => const Color(0xFFEAF4FF),
      ServiceOrderStatus.completed => const Color(0xFFE0F6E9),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppBrandColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
