// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/media/mobile_upload_optimizer.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/document_drafts/domain/document_request.dart';
import 'package:pontocerto/features/document_drafts/presentation/document_requests_provider.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentDraftsPage extends ConsumerStatefulWidget {
  const DocumentDraftsPage({super.key});

  @override
  ConsumerState<DocumentDraftsPage> createState() => _DocumentDraftsPageState();
}

enum _RequestBoardFilter {
  requested,
  awaiting,
  completed,
  received,
  sent,
  pending,
}

enum _UploadDestinationFilter { company, employees }

class _DocumentDraftsPageState extends ConsumerState<DocumentDraftsPage> {
  _RequestBoardFilter? _selectedFilter;
  String? _expandedRequestId;
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final allEmployees = ref.watch(employeesProvider);
    final operationalEmployees =
        allEmployees
            .where((item) => item.ativo && item.role != EmployeeRole.accountant)
            .toList()
          ..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
    final allRequests = ref.watch(documentRequestsProvider);
    final visibleRequests = _visibleRequestsForRole(allRequests, session);
    final filters = _filtersForRole(session.role);
    final selectedFilter = _selectedFilter ?? filters.first;
    final filtered = visibleRequests
        .where((item) => _matchesFilter(item, selectedFilter, session.role))
        .toList();

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: _titleForRole(session.role),
        subtitle: _subtitleForRole(session.role),
        chips: [
          AppHeaderChip(_chipForRole(session.role)),
          const AppHeaderChip('Pedidos separados'),
        ],
      ),
    );
    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            AppWorkspaceCard(
              title: _panelTitleForRole(session.role),
              subtitle: _panelSubtitleForRole(session.role),
              trailing: switch (session.role) {
                Role.accountant => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _openCreateDialog(employees: operationalEmployees),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Solicitar documento'),
                    ),
                    TextButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _openIndependentUploadDialog(
                              employees: operationalEmployees,
                            ),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Enviar documento'),
                    ),
                  ],
                ),
                Role.owner || Role.manager => TextButton.icon(
                  onPressed: visibleRequests.isEmpty
                      ? null
                      : () =>
                            _openRequestUploadDialog(requests: visibleRequests),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Enviar documento'),
                ),
                Role.employee => null,
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in filters)
                        ChoiceChip(
                          label: Text(_filterLabel(filter, session.role)),
                          selected: selectedFilter == filter,
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = filter;
                              _expandedRequestId = null;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Text(
                      _emptyLabelForRole(session.role),
                      style: const TextStyle(color: AppBrandColors.softText),
                    )
                  else
                    Column(
                      children: [
                        for (final request in filtered) ...[
                          _RequestExpansionCard(
                            request: request,
                            expanded: _expandedRequestId == request.id,
                            role: session.role,
                            uploading: _uploading,
                            onToggle: () {
                              setState(() {
                                _expandedRequestId =
                                    _expandedRequestId == request.id
                                    ? null
                                    : request.id;
                              });
                            },
                            onUpload: () => _uploadDocuments(request),
                            onChangeStatus: session.role == Role.accountant
                                ? (status) => _changeStatus(request, status)
                                : null,
                            onDelete: session.role == Role.accountant
                                ? () => _deleteRequest(request)
                                : null,
                            onForward:
                                session.role == Role.owner ||
                                    session.role == Role.manager
                                ? () => _openForwardDialog(
                                    request: request,
                                    employees: operationalEmployees,
                                  )
                                : null,
                            onOpenAttachment: _openAttachment,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CompanyDocumentRequest> _visibleRequestsForRole(
    List<CompanyDocumentRequest> requests,
    Session session,
  ) {
    return requests;
  }

  Future<void> _openCreateDialog({required List<Employee> employees}) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final documentsController = TextEditingController();
    var targetScope = DocumentRequestTargetScope.company;
    final selectedEmployeeIds = <String>{};

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Solicitar documentos'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyScopeNotice(
                      companyId: session.companyId,
                      employeesCount: employees.length,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titulo do pedido',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Orientacoes do contador',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: documentsController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Documentos solicitados',
                        hintText:
                            'Um item por linha. Ex.:\nCartao CNPJ\nExtrato bancario\nNotas de servico',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Destinatario da solicitacao',
                      style: TextStyle(
                        color: AppBrandColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<DocumentRequestTargetScope>(
                      value: DocumentRequestTargetScope.company,
                      groupValue: targetScope,
                      title: const Text('Direto para a empresa'),
                      subtitle: const Text(
                        'A empresa recebe o pedido e pode encaminhar para um ou mais funcionarios.',
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          targetScope = value;
                          selectedEmployeeIds.clear();
                        });
                      },
                    ),
                    RadioListTile<DocumentRequestTargetScope>(
                      value: DocumentRequestTargetScope.employees,
                      groupValue: targetScope,
                      title: const Text('Direto para funcionarios especificos'),
                      subtitle: const Text(
                        'Somente os funcionarios selecionados receberao o pedido no app.',
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => targetScope = value);
                      },
                    ),
                    if (targetScope ==
                        DocumentRequestTargetScope.employees) ...[
                      const SizedBox(height: 8),
                      if (employees.isEmpty)
                        const Text(
                          'Nenhum funcionario operacional ativo encontrado.',
                          style: TextStyle(color: AppBrandColors.softText),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final employee in employees)
                              FilterChip(
                                label: Text(employee.nomeCompleto),
                                selected: selectedEmployeeIds.contains(
                                  employee.id,
                                ),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedEmployeeIds.add(employee.id);
                                    } else {
                                      selectedEmployeeIds.remove(employee.id);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final requestedDocuments = documentsController.text
                      .split(RegExp(r'[\n,;]+'))
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList();
                  if (requestedDocuments.isEmpty) {
                    _msg('Informe pelo menos um documento.');
                    return;
                  }
                  if (targetScope == DocumentRequestTargetScope.employees &&
                      selectedEmployeeIds.isEmpty) {
                    _msg('Selecione ao menos um funcionario.');
                    return;
                  }

                  final selectedEmployees = employees
                      .where((item) => selectedEmployeeIds.contains(item.id))
                      .toList();
                  final id = FirebaseFirestore.instance
                      .collection('document_requests')
                      .doc()
                      .id;
                  final request = CompanyDocumentRequest(
                    id: id,
                    companyId: session.companyId,
                    title: titleController.text.trim().isEmpty
                        ? 'Solicitacao de documentos'
                        : titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    requestedDocuments: requestedDocuments,
                    status: DocumentRequestStatus.requested,
                    targetScope: targetScope,
                    createdByUserId: session.userId,
                    createdByName: session.nome,
                    requestedEmployeeIds: [
                      for (final item in selectedEmployees) item.id,
                    ],
                    requestedEmployeeNames: [
                      for (final item in selectedEmployees) item.nomeCompleto,
                    ],
                    currentResponsibleEmployeeIds:
                        targetScope == DocumentRequestTargetScope.employees
                        ? [for (final item in selectedEmployees) item.id]
                        : const <String>[],
                    currentResponsibleEmployeeNames:
                        targetScope == DocumentRequestTargetScope.employees
                        ? [
                            for (final item in selectedEmployees)
                              item.nomeCompleto,
                          ]
                        : const <String>[],
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  try {
                    await ref
                        .read(documentRequestsProvider.notifier)
                        .add(request);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      setState(() => _expandedRequestId = request.id);
                    }
                    _msg('Solicitacao criada com sucesso.');
                  } catch (_) {
                    _msg('Nao foi possivel criar a solicitacao.');
                  }
                },
                child: const Text('Salvar solicitacao'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      documentsController.dispose();
    }
  }

  Future<void> _openIndependentUploadDialog({
    required List<Employee> employees,
  }) async {
    final session = ref.read(sessionProvider);
    if (session == null || _uploading) return;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var targetScope = DocumentRequestTargetScope.company;
    final selectedEmployeeIds = <String>{};

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Enviar documento'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyScopeNotice(
                      companyId: session.companyId,
                      employeesCount: employees.length,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titulo do envio',
                        hintText: 'Ex.: Contrato para assinatura',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem para a empresa ou funcionario',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Destino do documento',
                      style: TextStyle(
                        color: AppBrandColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<DocumentRequestTargetScope>(
                      value: DocumentRequestTargetScope.company,
                      groupValue: targetScope,
                      title: const Text('Enviar para a empresa'),
                      subtitle: const Text(
                        'A empresa recebe o documento dentro da empresa selecionada.',
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          targetScope = value;
                          selectedEmployeeIds.clear();
                        });
                      },
                    ),
                    RadioListTile<DocumentRequestTargetScope>(
                      value: DocumentRequestTargetScope.employees,
                      groupValue: targetScope,
                      title: const Text('Enviar para funcionarios especificos'),
                      subtitle: const Text(
                        'Somente funcionarios ativos desta empresa aparecem aqui.',
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => targetScope = value);
                      },
                    ),
                    if (targetScope ==
                        DocumentRequestTargetScope.employees) ...[
                      const SizedBox(height: 8),
                      if (employees.isEmpty)
                        const Text(
                          'Nenhum funcionario operacional ativo encontrado nesta empresa.',
                          style: TextStyle(color: AppBrandColors.softText),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final employee in employees)
                              FilterChip(
                                label: Text(employee.nomeCompleto),
                                selected: selectedEmployeeIds.contains(
                                  employee.id,
                                ),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedEmployeeIds.add(employee.id);
                                    } else {
                                      selectedEmployeeIds.remove(employee.id);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (targetScope == DocumentRequestTargetScope.employees &&
                      selectedEmployeeIds.isEmpty) {
                    _msg('Selecione ao menos um funcionario desta empresa.');
                    return;
                  }
                  final selectedEmployees = employees
                      .where((item) => selectedEmployeeIds.contains(item.id))
                      .toList();
                  Navigator.of(dialogContext).pop();
                  await _createIndependentUploadRequest(
                    title: titleController.text,
                    description: descriptionController.text,
                    targetScope: targetScope,
                    selectedEmployees: selectedEmployees,
                  );
                },
                child: const Text('Escolher arquivos e enviar'),
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

  Future<void> _openForwardDialog({
    required CompanyDocumentRequest request,
    required List<Employee> employees,
  }) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final selectedEmployeeIds = <String>{
      ...request.currentResponsibleEmployeeIds,
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Encaminhar solicitacao'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pedido: ${request.title}',
                    style: const TextStyle(
                      color: AppBrandColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Selecione os funcionarios que vao receber esta solicitacao no app.',
                    style: TextStyle(color: AppBrandColors.softText),
                  ),
                  const SizedBox(height: 12),
                  if (employees.isEmpty)
                    const Text(
                      'Nenhum funcionario operacional ativo encontrado.',
                      style: TextStyle(color: AppBrandColors.softText),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final employee in employees)
                          FilterChip(
                            label: Text(employee.nomeCompleto),
                            selected: selectedEmployeeIds.contains(employee.id),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedEmployeeIds.add(employee.id);
                                } else {
                                  selectedEmployeeIds.remove(employee.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final selectedEmployees = employees
                    .where((item) => selectedEmployeeIds.contains(item.id))
                    .toList();
                try {
                  await ref
                      .read(documentRequestsProvider.notifier)
                      .update(
                        request.copyWith(
                          currentResponsibleEmployeeIds: [
                            for (final item in selectedEmployees) item.id,
                          ],
                          currentResponsibleEmployeeNames: [
                            for (final item in selectedEmployees)
                              item.nomeCompleto,
                          ],
                          forwardedByUserId: session.userId,
                          forwardedByName: session.nome,
                          forwardedAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _msg(
                    selectedEmployees.isEmpty
                        ? 'Solicitacao voltou para a empresa.'
                        : 'Solicitacao encaminhada para funcionario(s).',
                  );
                } catch (_) {
                  _msg('Nao foi possivel encaminhar a solicitacao.');
                }
              },
              child: const Text('Salvar encaminhamento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    CompanyDocumentRequest request,
    DocumentRequestStatus status,
  ) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    try {
      await ref
          .read(documentRequestsProvider.notifier)
          .update(
            request.copyWith(
              status: status,
              updatedAt: DateTime.now(),
              completedAt: status == DocumentRequestStatus.completed
                  ? DateTime.now()
                  : null,
              completedByName: status == DocumentRequestStatus.completed
                  ? session.nome
                  : '',
            ),
          );
      _msg('Status atualizado.');
    } catch (_) {
      _msg('Nao foi possivel atualizar o status.');
    }
  }

  Future<void> _openRequestUploadDialog({
    required List<CompanyDocumentRequest> requests,
  }) async {
    final session = ref.read(sessionProvider);
    if (session == null || requests.isEmpty || _uploading) return;
    final selectable = requests
        .where((item) => item.status != DocumentRequestStatus.completed)
        .toList();
    final options = selectable.isEmpty ? requests : selectable;
    final expanded = options
        .where((item) => item.id == _expandedRequestId)
        .firstOrNull;
    var destinationFilter = _currentDestinationFilterForRequest(
      expanded ?? options.first,
    );
    var filteredOptions = _filterRequestsForUploadDestination(
      options,
      destinationFilter,
    );
    CompanyDocumentRequest? selected =
        filteredOptions
            .where((item) => item.id == _expandedRequestId)
            .firstOrNull ??
        filteredOptions.firstOrNull ??
        options.firstOrNull;
    if (selected == null) {
      _msg('Nenhuma solicitacao disponivel para envio.');
      return;
    }

    destinationFilter = _currentDestinationFilterForRequest(selected);
    filteredOptions = _filterRequestsForUploadDestination(
      options,
      destinationFilter,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enviar documento'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escolha o destino atual do envio e em qual solicitacao os arquivos serao anexados.',
                  style: TextStyle(color: AppBrandColors.softText),
                ),
                const SizedBox(height: 12),
                if (session.role == Role.accountant) ...[
                  const Text(
                    'Destino do envio',
                    style: TextStyle(
                      color: AppBrandColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<_UploadDestinationFilter>(
                    value: _UploadDestinationFilter.company,
                    groupValue: destinationFilter,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enviar para a empresa'),
                    subtitle: const Text(
                      'Mostra pedidos que estao hoje com a empresa.',
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        destinationFilter = value;
                        filteredOptions = _filterRequestsForUploadDestination(
                          options,
                          destinationFilter,
                        );
                        selected = filteredOptions.firstOrNull;
                      });
                    },
                  ),
                  RadioListTile<_UploadDestinationFilter>(
                    value: _UploadDestinationFilter.employees,
                    groupValue: destinationFilter,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enviar para funcionarios especificos'),
                    subtitle: const Text(
                      'Mostra pedidos que estao hoje com um ou mais funcionarios.',
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        destinationFilter = value;
                        filteredOptions = _filterRequestsForUploadDestination(
                          options,
                          destinationFilter,
                        );
                        selected = filteredOptions.firstOrNull;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (filteredOptions.isEmpty)
                  Text(
                    destinationFilter == _UploadDestinationFilter.company
                        ? 'Nenhuma solicitacao esta com a empresa neste momento.'
                        : 'Nenhuma solicitacao esta com funcionarios neste momento.',
                    style: const TextStyle(color: AppBrandColors.softText),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selected?.id,
                    items: [
                      for (final request in filteredOptions)
                        DropdownMenuItem<String>(
                          value: request.id,
                          child: Text(
                            '${request.title} • ${_requestTargetLabel(request).replaceFirst('Destinatario atual: ', '').replaceFirst('Destinatario: ', '')}',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selected = filteredOptions
                            .where((item) => item.id == value)
                            .firstOrNull;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Solicitacao'),
                  ),
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _requestUploadDestinationSummary(selected!),
                    style: const TextStyle(
                      color: AppBrandColors.softText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final target = selected;
                if (target == null) return;
                Navigator.of(dialogContext).pop();
                await _uploadDocuments(target);
              },
              child: const Text('Escolher arquivos'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRequest(CompanyDocumentRequest request) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir solicitacao'),
        content: Text('Deseja excluir "${request.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(documentRequestsProvider.notifier).remove(request.id);
      if (mounted && _expandedRequestId == request.id) {
        setState(() => _expandedRequestId = null);
      }
      _msg('Solicitacao excluida.');
    } catch (_) {
      _msg('Nao foi possivel excluir a solicitacao.');
    }
  }

  Future<void> _createIndependentUploadRequest({
    required String title,
    required String description,
    required DocumentRequestTargetScope targetScope,
    required List<Employee> selectedEmployees,
  }) async {
    final session = ref.read(sessionProvider);
    if (session == null || _uploading) return;
    final id = FirebaseFirestore.instance
        .collection('document_requests')
        .doc()
        .id;
    final request = CompanyDocumentRequest(
      id: id,
      companyId: session.companyId,
      title: title.trim().isEmpty
          ? 'Documento enviado pelo contador'
          : title.trim(),
      description: description.trim(),
      requestedDocuments: const <String>['Documento enviado pelo contador'],
      status: DocumentRequestStatus.awaitingCompany,
      targetScope: targetScope,
      createdByUserId: session.userId,
      createdByName: session.nome,
      requestedEmployeeIds: [for (final item in selectedEmployees) item.id],
      requestedEmployeeNames: [
        for (final item in selectedEmployees) item.nomeCompleto,
      ],
      currentResponsibleEmployeeIds:
          targetScope == DocumentRequestTargetScope.employees
          ? [for (final item in selectedEmployees) item.id]
          : const <String>[],
      currentResponsibleEmployeeNames:
          targetScope == DocumentRequestTargetScope.employees
          ? [for (final item in selectedEmployees) item.nomeCompleto]
          : const <String>[],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(documentRequestsProvider.notifier).add(request);
      if (mounted) {
        setState(() => _expandedRequestId = request.id);
      }
      await _uploadDocuments(
        request,
        successMessage: 'Documento enviado com sucesso.',
      );
    } catch (_) {
      _msg('Nao foi possivel preparar o envio do documento.');
    }
  }

  Future<void> _uploadDocuments(
    CompanyDocumentRequest request, {
    String? successMessage,
  }) async {
    final session = ref.read(sessionProvider);
    if (session == null || _uploading) return;
    if (request.companyId != session.companyId) {
      _msg('Troque para a empresa correta antes de enviar documentos.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final newAttachments = <DocumentRequestAttachment>[];
      for (final file in result.files) {
        final prepared = await MobileUploadOptimizer.preparePlatformFile(
          file: file,
          fallbackContentType: _contentTypeFromFileName(file.name),
        );
        final attachmentId = FirebaseFirestore.instance
            .collection('document_requests')
            .doc()
            .id;
        final safeFileName = _safeStorageName(prepared.fileName);
        final storagePath =
            'companies/${session.companyId}/document_requests/${request.id}/$attachmentId-$safeFileName';
        final storageRef = FirebaseStorage.instance.ref(storagePath);
        await storageRef.putData(
          prepared.bytes,
          SettableMetadata(contentType: prepared.contentType),
        );
        final downloadUrl = await storageRef.getDownloadURL();
        newAttachments.add(
          DocumentRequestAttachment(
            id: attachmentId,
            fileName: prepared.fileName,
            downloadUrl: downloadUrl,
            storagePath: storagePath,
            contentType: prepared.contentType,
            uploadedByUserId: session.userId,
            uploadedByName: session.nome,
            uploadedByRole: session.role.name,
            uploadedAt: DateTime.now(),
          ),
        );
      }

      await ref
          .read(documentRequestsProvider.notifier)
          .update(
            request.copyWith(
              attachments: [...request.attachments, ...newAttachments],
              status: request.status == DocumentRequestStatus.completed
                  ? DocumentRequestStatus.completed
                  : DocumentRequestStatus.awaitingCompany,
              updatedAt: DateTime.now(),
            ),
          );
      _msg(
        successMessage ??
            '${newAttachments.length} arquivo(s) enviado(s) com sucesso.',
      );
    } on MobileUploadOptimizerException catch (error) {
      _msg(error.message);
    } catch (_) {
      _msg('Nao foi possivel enviar os arquivos.');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _openAttachment(DocumentRequestAttachment attachment) async {
    final uri = Uri.tryParse(attachment.downloadUrl);
    if (uri == null) {
      _msg('Arquivo indisponivel.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _msg('Nao foi possivel abrir o arquivo.');
    }
  }

  void _msg(String message) {
    if (!mounted) return;
    if (context.mounted) {
      context.showUserMessage(message);
    }
  }
}

class _CompanyScopeNotice extends StatelessWidget {
  const _CompanyScopeNotice({
    required this.companyId,
    required this.employeesCount,
  });

  final String companyId;
  final int employeesCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        'Empresa ativa: $companyId. Funcionarios listados aqui pertencem somente a esta empresa ($employeesCount ativo(s)). Para outra empresa, troque a empresa na carteira do contador antes de solicitar ou enviar documentos.',
        style: const TextStyle(
          color: AppBrandColors.softText,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

List<_RequestBoardFilter> _filtersForRole(Role role) {
  if (role == Role.accountant) {
    return _accountantFilters;
  }
  if (role == Role.employee) {
    return _employeeFilters;
  }
  return _companyFilters;
}

String _titleForRole(Role role) {
  switch (role) {
    case Role.accountant:
      return 'Solicitacoes de documentos';
    case Role.employee:
      return 'Documentos recebidos';
    case Role.owner:
    case Role.manager:
      return 'Canal de documentos com o escritorio';
  }
}

String _subtitleForRole(Role role) {
  switch (role) {
    case Role.accountant:
      return 'Crie pedidos para a empresa ou para funcionarios especificos e acompanhe os documentos recebidos por solicitacao.';
    case Role.employee:
      return 'Veja somente as solicitacoes encaminhadas para voce e envie os documentos diretamente pelo app.';
    case Role.owner:
    case Role.manager:
      return 'Receba pedidos do contador, envie documentos ou encaminhe a solicitacao para um ou mais funcionarios da empresa.';
  }
}

String _chipForRole(Role role) {
  switch (role) {
    case Role.accountant:
      return 'Fluxo do contador';
    case Role.employee:
      return 'Fluxo do funcionario';
    case Role.owner:
    case Role.manager:
      return 'Fluxo da empresa';
  }
}

String _panelTitleForRole(Role role) {
  switch (role) {
    case Role.accountant:
      return 'Painel de solicitacoes';
    case Role.employee:
      return 'Seus pedidos';
    case Role.owner:
    case Role.manager:
      return 'Painel da empresa';
  }
}

String _panelSubtitleForRole(Role role) {
  switch (role) {
    case Role.accountant:
      return 'Escolha um caminho, abra cada pedido e veja os itens solicitados e os documentos recebidos.';
    case Role.employee:
      return 'Abra cada pedido encaminhado para voce e envie os documentos no lugar certo.';
    case Role.owner:
    case Role.manager:
      return 'Abra cada pedido recebido do contador, envie documentos ou encaminhe para funcionarios da empresa.';
  }
}

String _emptyLabelForRole(Role role) {
  switch (role) {
    case Role.accountant:
      return 'Nenhum pedido encontrado neste caminho.';
    case Role.employee:
      return 'Nenhuma solicitacao foi encaminhada para voce neste caminho.';
    case Role.owner:
    case Role.manager:
      return 'Nenhuma solicitacao encontrada neste caminho.';
  }
}

const _accountantFilters = <_RequestBoardFilter>[
  _RequestBoardFilter.requested,
  _RequestBoardFilter.completed,
  _RequestBoardFilter.awaiting,
];

const _companyFilters = <_RequestBoardFilter>[
  _RequestBoardFilter.received,
  _RequestBoardFilter.sent,
  _RequestBoardFilter.pending,
];

const _employeeFilters = <_RequestBoardFilter>[
  _RequestBoardFilter.received,
  _RequestBoardFilter.sent,
  _RequestBoardFilter.pending,
];

bool _matchesFilter(
  CompanyDocumentRequest request,
  _RequestBoardFilter filter,
  Role role,
) {
  switch (filter) {
    case _RequestBoardFilter.requested:
      return request.status == DocumentRequestStatus.requested;
    case _RequestBoardFilter.completed:
      return request.status == DocumentRequestStatus.completed;
    case _RequestBoardFilter.awaiting:
      return request.status == DocumentRequestStatus.awaitingCompany;
    case _RequestBoardFilter.received:
      return request.status != DocumentRequestStatus.completed;
    case _RequestBoardFilter.sent:
      return request.attachments.isNotEmpty;
    case _RequestBoardFilter.pending:
      return request.status != DocumentRequestStatus.completed &&
          request.attachments.isEmpty;
  }
}

String _filterLabel(_RequestBoardFilter filter, Role role) {
  switch (filter) {
    case _RequestBoardFilter.requested:
      return 'Pedidos solicitados';
    case _RequestBoardFilter.completed:
      return 'Pedidos concluidos';
    case _RequestBoardFilter.awaiting:
      return 'Aguardando';
    case _RequestBoardFilter.received:
      return role == Role.employee
          ? 'Solicitacoes recebidas'
          : 'Solicitacoes recebidas';
    case _RequestBoardFilter.sent:
      return role == Role.employee
          ? 'Solicitacoes enviadas'
          : 'Solicitacoes enviadas';
    case _RequestBoardFilter.pending:
      return role == Role.employee
          ? 'Solicitacoes pendentes'
          : 'Solicitacoes pendentes';
  }
}

String _contentTypeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return 'application/octet-stream';
}

String _safeStorageName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}

Color _statusColor(DocumentRequestStatus status) {
  switch (status) {
    case DocumentRequestStatus.requested:
      return const Color(0xFFB45309);
    case DocumentRequestStatus.awaitingCompany:
      return const Color(0xFF1D4ED8);
    case DocumentRequestStatus.completed:
      return const Color(0xFF15803D);
  }
}

IconData _iconForAttachment(DocumentRequestAttachment attachment) {
  if (attachment.contentType == 'application/pdf') {
    return Icons.picture_as_pdf_outlined;
  }
  return Icons.image_outlined;
}

String _requestTargetLabel(CompanyDocumentRequest request) {
  if (request.targetScope == DocumentRequestTargetScope.company) {
    return request.currentResponsibleEmployeeNames.isEmpty
        ? 'Destinatario: empresa'
        : 'Destinatario atual: ${request.currentResponsibleEmployeeNames.join(', ')}';
  }
  if (request.currentResponsibleEmployeeNames.isNotEmpty) {
    return 'Destinatario: ${request.currentResponsibleEmployeeNames.join(', ')}';
  }
  if (request.requestedEmployeeNames.isNotEmpty) {
    return 'Destinatario: ${request.requestedEmployeeNames.join(', ')}';
  }
  return 'Destinatario: funcionarios';
}

_UploadDestinationFilter _currentDestinationFilterForRequest(
  CompanyDocumentRequest request,
) {
  return request.currentResponsibleEmployeeIds.isEmpty
      ? _UploadDestinationFilter.company
      : _UploadDestinationFilter.employees;
}

List<CompanyDocumentRequest> _filterRequestsForUploadDestination(
  List<CompanyDocumentRequest> requests,
  _UploadDestinationFilter filter,
) {
  return requests.where((request) {
    final current = _currentDestinationFilterForRequest(request);
    return current == filter;
  }).toList();
}

String _requestUploadDestinationSummary(CompanyDocumentRequest request) {
  if (_currentDestinationFilterForRequest(request) ==
      _UploadDestinationFilter.company) {
    return 'O contador enviara arquivos para a empresa nesta solicitacao.';
  }
  final names = request.currentResponsibleEmployeeNames;
  if (names.isEmpty) {
    return 'O contador enviara arquivos para funcionarios vinculados a esta solicitacao.';
  }
  return 'O contador enviara arquivos para: ${names.join(', ')}.';
}

String _uploadedRoleLabel(String role) {
  switch (role.trim().toLowerCase()) {
    case 'accountant':
      return 'contador';
    case 'employee':
      return 'funcionario';
    case 'manager':
      return 'gerente';
    case 'owner':
      return 'empresa';
    default:
      return role.trim().isEmpty ? 'usuario' : role.trim().toLowerCase();
  }
}

class _RequestExpansionCard extends StatelessWidget {
  const _RequestExpansionCard({
    required this.request,
    required this.expanded,
    required this.role,
    required this.uploading,
    required this.onToggle,
    required this.onOpenAttachment,
    this.onUpload,
    this.onChangeStatus,
    this.onDelete,
    this.onForward,
  });

  final CompanyDocumentRequest request;
  final bool expanded;
  final Role role;
  final bool uploading;
  final VoidCallback onToggle;
  final VoidCallback? onUpload;
  final ValueChanged<DocumentRequestStatus>? onChangeStatus;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;
  final Future<void> Function(DocumentRequestAttachment attachment)
  onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final isAccountant = role == Role.accountant;
    final canForward = role == Role.owner || role == Role.manager;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: const TextStyle(
                            color: AppBrandColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniBadge(
                              label: request.status.label,
                              color: _statusColor(request.status),
                            ),
                            _MiniBadge(
                              label:
                                  '${request.requestedDocuments.length} item(ns) pedidos',
                              color: const Color(0xFF475569),
                            ),
                            _MiniBadge(
                              label:
                                  '${request.attachments.length} arquivo(s) anexados',
                              color: const Color(0xFF475569),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _requestTargetLabel(request),
                          style: const TextStyle(
                            color: AppBrandColors.softText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Atualizado em ${_formatDateTime(request.updatedAt)}',
                          style: const TextStyle(
                            color: AppBrandColors.softText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppBrandColors.softText,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request.description.trim().isNotEmpty) ...[
                    const Text(
                      'Observacoes',
                      style: TextStyle(
                        color: AppBrandColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.description.trim(),
                      style: const TextStyle(
                        color: AppBrandColors.softText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'Itens pedidos',
                    style: TextStyle(
                      color: AppBrandColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < request.requestedDocuments.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${i + 1}. ${request.requestedDocuments[i]}',
                        style: const TextStyle(color: AppBrandColors.softText),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniBadge(
                        label: _requestTargetLabel(request),
                        color: const Color(0xFF475569),
                      ),
                      if (request.forwardedByName.isNotEmpty)
                        _MiniBadge(
                          label:
                              'Encaminhado por ${request.forwardedByName} em ${_formatDateTime(request.forwardedAt)}',
                          color: const Color(0xFF475569),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Arquivos do pedido',
                          style: TextStyle(
                            color: AppBrandColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onUpload != null)
                        FilledButton.icon(
                          onPressed:
                              uploading ||
                                  request.status ==
                                      DocumentRequestStatus.completed
                              ? null
                              : onUpload,
                          icon: uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_outlined),
                          label: Text('Enviar documento'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (request.attachments.isEmpty)
                    const Text(
                      'Nenhum arquivo anexado ainda neste pedido.',
                      style: TextStyle(color: AppBrandColors.softText),
                    )
                  else
                    Column(
                      children: [
                        for (final attachment in request.attachments) ...[
                          _AttachmentRow(
                            attachment: attachment,
                            onOpen: () => onOpenAttachment(attachment),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isAccountant)
                        PopupMenuButton<DocumentRequestStatus>(
                          onSelected: onChangeStatus,
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: DocumentRequestStatus.requested,
                              child: Text('Marcar como solicitado'),
                            ),
                            PopupMenuItem(
                              value: DocumentRequestStatus.awaitingCompany,
                              child: Text('Marcar como aguardando'),
                            ),
                            PopupMenuItem(
                              value: DocumentRequestStatus.completed,
                              child: Text('Marcar como concluido'),
                            ),
                          ],
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.swap_horiz_outlined),
                            label: const Text('Alterar status'),
                          ),
                        ),
                      if (canForward)
                        TextButton.icon(
                          onPressed: onForward,
                          icon: const Icon(Icons.forward_to_inbox_outlined),
                          label: const Text('Encaminhar para funcionario'),
                        ),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          'Criado em ${_formatDateTime(request.createdAt)}',
                        ),
                      ),
                      if (isAccountant && onDelete != null)
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.onOpen});

  final DocumentRequestAttachment attachment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Row(
        children: [
          Icon(_iconForAttachment(attachment), color: AppBrandColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: const TextStyle(
                    color: AppBrandColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enviado por ${attachment.uploadedByName} (${_uploadedRoleLabel(attachment.uploadedByRole)}) em ${_formatDateTime(attachment.uploadedAt)}',
                  style: const TextStyle(
                    color: AppBrandColors.softText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onOpen, child: const Text('Abrir')),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
