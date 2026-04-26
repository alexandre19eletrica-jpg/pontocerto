import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/pdf/standard_document.dart';
import 'package:pontocerto/core/pdf/pdf_output.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:url_launcher/url_launcher.dart';

enum ProposalStatus { proposta, contrato }

class ServiceProposal {
  ServiceProposal({
    required this.id,
    required this.companyId,
    required this.createdById,
    required this.createdByName,
    required this.clientName,
    this.clientCompany = '',
    this.clientCnpj = '',
    this.clientEmail = '',
    this.clientWhatsapp = '',
    this.clientAddress = '',
    this.notes = '',
    required this.taskIds,
    required this.taskTitles,
    required this.totalCents,
    this.chargeBdi = false,
    this.attachClauseSummary = false,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String createdById;
  final String createdByName;
  final String clientName;
  final String clientCompany;
  final String clientCnpj;
  final String clientEmail;
  final String clientWhatsapp;
  final String clientAddress;
  final String notes;
  final List<String> taskIds;
  final List<String> taskTitles;
  final int totalCents;
  final bool chargeBdi;
  final bool attachClauseSummary;
  final ProposalStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  int get bdiCents => chargeBdi ? ((totalCents * 0.2).round()) : 0;
  int get totalWithBdiCents => totalCents + bdiCents;

  factory ServiceProposal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final statusName = map['status']?.toString();
    final status =
        ProposalStatus.values.where((e) => e.name == statusName).isNotEmpty
        ? ProposalStatus.values.firstWhere((e) => e.name == statusName)
        : ProposalStatus.proposta;
    final createdAtRaw = map['createdAt'];
    final updatedAtRaw = map['updatedAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();
    final updatedAt = updatedAtRaw is Timestamp ? updatedAtRaw.toDate() : null;

    return ServiceProposal(
      id: doc.id,
      companyId: map['companyId']?.toString() ?? '',
      createdById: map['createdById']?.toString() ?? '',
      createdByName: map['createdByName']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      clientCompany: map['clientCompany']?.toString() ?? '',
      clientCnpj: map['clientCnpj']?.toString() ?? '',
      clientEmail: map['clientEmail']?.toString() ?? '',
      clientWhatsapp: map['clientWhatsapp']?.toString() ?? '',
      clientAddress: map['clientAddress']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      taskIds: _toStringList(map['taskIds']),
      taskTitles: _toStringList(map['taskTitles']),
      totalCents: (map['totalCents'] as num?)?.toInt() ?? 0,
      chargeBdi: map['chargeBdi'] == true,
      attachClauseSummary: map['attachClauseSummary'] == true,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'createdById': createdById,
      'createdByName': createdByName,
      'clientName': clientName,
      'clientCompany': clientCompany,
      'clientCnpj': clientCnpj,
      'clientEmail': clientEmail,
      'clientWhatsapp': clientWhatsapp,
      'clientAddress': clientAddress,
      'notes': notes,
      'taskIds': taskIds,
      'taskTitles': taskTitles,
      'totalCents': totalCents,
      'chargeBdi': chargeBdi,
      'attachClauseSummary': attachClauseSummary,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class ServiceProposalsPage extends ConsumerStatefulWidget {
  const ServiceProposalsPage({super.key, required this.startInContracts});

  final bool startInContracts;

  @override
  ConsumerState<ServiceProposalsPage> createState() => _ServiceProposalsPageState();
}

class _ServiceProposalsPageState extends ConsumerState<ServiceProposalsPage> {
  late ProposalStatus _statusFiltro;
  String? _companyIdEfetivo;
  bool _syncCompanyIdIniciado = false;

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
  void initState() {
    super.initState();
    _statusFiltro = widget.startInContracts
        ? ProposalStatus.contrato
        : ProposalStatus.proposta;
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }
    if (sessao.role == Role.employee) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(
        body: Center(child: Text('Modulo disponivel apenas para empresa.')),
      );
    }
    final accountantReadOnly =
        sessao.role == Role.accountant &&
        _statusFiltro == ProposalStatus.contrato;

    final tarefas = ref.watch(tasksProvider);
    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Propostas e contratos',
        subtitle:
            'Comercial e formalizacao no mesmo ambiente, com conversao direta de tarefas em proposta ou contrato.',
        chips: [
          AppHeaderChip(
            _statusFiltro == ProposalStatus.proposta ? 'Foco em propostas' : 'Foco em contratos',
          ),
        ],
      ),
      beforeLogout: _statusFiltro == ProposalStatus.proposta && !accountantReadOnly
          ? [
              IconButton(
                onPressed: () => _abrirDialogoNovaProposta(context, sessao, tarefas),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Nova proposta',
              ),
            ]
          : const [],
    );
    final companyId = (_companyIdEfetivo ?? sessao.companyId).trim();
    if (!_syncCompanyIdIniciado) {
      _syncCompanyIdIniciado = true;
      _syncCompanyId(sessao);
    }
    final stream = FirebaseFirestore.instance
        .collection('service_proposals')
        .where('companyId', isEqualTo: companyId)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .snapshots(),
      builder: (context, settingsSnapshot) {
        final companySettings = settingsSnapshot.data?.data() ?? <String, dynamic>{};
        final accountantContractsRead =
            (companySettings['accountantPermissions'] as Map?)
                    ?.cast<String, dynamic>()['allowContractsRead'] as bool? ??
                true;
        if (sessao.role == Role.accountant && !accountantContractsRead) {
          ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
          return const Center(
            child: Text(
              'O contador desta empresa esta sem liberacao para consultar contratos.',
            ),
          );
        }

        return AppGradientBackground(
          child: AppPageLayout(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: sessao.role == Role.accountant
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(label: Text('Leitura de contratos')),
                        )
                      : SegmentedButton<ProposalStatus>(
                          segments: const [
                            ButtonSegment(
                              value: ProposalStatus.proposta,
                              label: Text('Propostas'),
                            ),
                            ButtonSegment(
                              value: ProposalStatus.contrato,
                              label: Text('Contratos'),
                            ),
                          ],
                          selected: <ProposalStatus>{_statusFiltro},
                          onSelectionChanged: (set) {
                            setState(() => _statusFiltro = set.first);
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            _statusFiltro == ProposalStatus.proposta
                                ? 'Nao ha proposta cadastrada.'
                                : 'Nao ha contrato cadastrado.',
                          ),
                        );
                      }

                      final lista = (snapshot.data?.docs ?? const [])
                          .map(ServiceProposal.fromDoc)
                          .where((p) => p.status == _statusFiltro)
                          .toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                      if (lista.isEmpty) {
                        return Center(
                          child: Text(
                            _statusFiltro == ProposalStatus.proposta
                                ? 'Nenhuma proposta cadastrada.'
                                : 'Nenhum contrato cadastrado.',
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: lista.length,
                        itemBuilder: (context, index) {
                          final item = lista[index];
                          return _surface(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.clientName,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.clientCompany.isEmpty ? '-' : item.clientCompany} | ${_formatarMoeda(item.totalCents)}'
                                    '${item.status == ProposalStatus.contrato ? ' (+BDI: ${item.chargeBdi ? 'Sim' : 'Nao'})' : ''}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Tarefas: ${item.taskTitles.join(', ')}'),
                                  if (item.clientEmail.isNotEmpty || item.clientWhatsapp.isNotEmpty)
                                    Text(
                                      'Contato: ${item.clientEmail.isEmpty ? '-' : item.clientEmail}'
                                      ' | ${item.clientWhatsapp.isEmpty ? '-' : item.clientWhatsapp}',
                                    ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _abrirPdf(item, tarefas),
                                        icon: const Icon(Icons.picture_as_pdf_outlined),
                                        label: const Text('Abrir PDF'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _compartilharPdf(item, tarefas),
                                        icon: const Icon(Icons.share_outlined),
                                        label: const Text('Compartilhar PDF'),
                                      ),
                                      if (!accountantReadOnly)
                                        OutlinedButton.icon(
                                          onPressed: () => _editarProposta(context, item, tarefas),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Editar'),
                                        ),
                                      if (!accountantReadOnly)
                                        OutlinedButton.icon(
                                          onPressed: () => _apagarProposta(context, item),
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Apagar'),
                                        ),
                                      if (item.clientWhatsapp.isNotEmpty)
                                        OutlinedButton.icon(
                                          onPressed: () => _abrirWhatsapp(item),
                                          icon: const Icon(Icons.chat_bubble_outline),
                                          label: const Text('WhatsApp'),
                                        ),
                                      if (item.clientEmail.isNotEmpty)
                                        OutlinedButton.icon(
                                          onPressed: () => _abrirEmail(item),
                                          icon: const Icon(Icons.email_outlined),
                                          label: const Text('Email'),
                                        ),
                                      if (!accountantReadOnly && item.status == ProposalStatus.proposta)
                                        ElevatedButton.icon(
                                          onPressed: () => _transformarEmContrato(
                                            context,
                                            item,
                                          ),
                                          icon: const Icon(Icons.assignment_turned_in_outlined),
                                          label: const Text('Transformar em contrato'),
                                        ),
                                      if (!accountantReadOnly && item.status == ProposalStatus.contrato)
                                        OutlinedButton.icon(
                                          onPressed: () => _editarBdiContrato(
                                            context,
                                            item,
                                          ),
                                          icon: const Icon(Icons.percent),
                                          label: const Text('BDI'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirDialogoNovaProposta(
    BuildContext context,
    Session sessao,
    List<TarefaItem> tarefas,
  ) async {
    final companyId = (_companyIdEfetivo ?? sessao.companyId).trim();
    final nomeCtrl = TextEditingController();
    final empresaCtrl = TextEditingController();
    final cnpjCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final whatsappCtrl = TextEditingController();
    final enderecoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    final selecionadas = <String>{};
    var anexarResumoClausulas = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) {
          final total = _somarTarefasSelecionadas(tarefas, selecionadas);
          return AlertDialog(
            title: const Text('Nova proposta de servico'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do cliente *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: empresaCtrl,
                      decoration: const InputDecoration(labelText: 'Empresa'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cnpjCtrl,
                      decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: whatsappCtrl,
                      decoration: const InputDecoration(labelText: 'WhatsApp'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: enderecoCtrl,
                      decoration: const InputDecoration(labelText: 'Endereco'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Observacoes'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selecionar tarefas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (tarefas.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Nenhuma tarefa cadastrada.'),
                      ),
                    ...tarefas.map(
                      (t) => CheckboxListTile(
                        dense: true,
                        value: selecionadas.contains(t.id),
                        title: Text(t.nome),
                        subtitle: Text(
                          '${t.autorNome} - ${_formatarMoeda(_valorTarefaCents(t))}',
                        ),
                        onChanged: (v) {
                          setDialog(() {
                            if (v == true) {
                              selecionadas.add(t.id);
                            } else {
                              selecionadas.remove(t.id);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Total selecionado: ${_formatarMoeda(total)}'),
                    ),
                    CheckboxListTile(
                      value: anexarResumoClausulas,
                      title: const Text('Anexar resumo das clausulas na proposta'),
                      onChanged: (v) =>
                          setDialog(() => anexarResumoClausulas = v ?? false),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  nomeCtrl.clear();
                  empresaCtrl.clear();
                  cnpjCtrl.clear();
                  emailCtrl.clear();
                  whatsappCtrl.clear();
                  enderecoCtrl.clear();
                  obsCtrl.clear();
                  setDialog(() {
                    selecionadas.clear();
                    anexarResumoClausulas = false;
                  });
                },
                child: const Text('Limpar tudo'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nomeCliente = _normalizarTextoSimples(nomeCtrl.text);
                  if (nomeCliente.isEmpty) {
                    _msg(context, 'Informe o nome do cliente.');
                    return;
                  }
                  if (selecionadas.isEmpty) {
                    _msg(context, 'Selecione ao menos uma tarefa.');
                    return;
                  }
                  final tarefasSelecionadas = tarefas
                      .where((t) => selecionadas.contains(t.id))
                      .toList();
                  final id = DateTime.now().microsecondsSinceEpoch.toString();
                  final proposta = ServiceProposal(
                    id: id,
                    companyId: companyId,
                    createdById: sessao.userId,
                    createdByName: sessao.nome,
                    clientName: _normalizarTextoSimples(nomeCliente, upper: true),
                    clientCompany: _normalizarTextoSimples(empresaCtrl.text, upper: true),
                    clientCnpj: _normalizarTextoSimples(cnpjCtrl.text, upper: true),
                    clientEmail: _normalizarEmail(emailCtrl.text),
                    clientWhatsapp: _normalizarTelefoneBR(whatsappCtrl.text),
                    clientAddress: _normalizarTextoSimples(enderecoCtrl.text, upper: true),
                    notes: _normalizarTextoSimples(obsCtrl.text, upper: true),
                    taskIds: [for (final t in tarefasSelecionadas) t.id],
                    taskTitles: [for (final t in tarefasSelecionadas) t.nome],
                    totalCents: _somarTarefasSelecionadas(tarefas, selecionadas),
                    chargeBdi: false,
                    attachClauseSummary: anexarResumoClausulas,
                    status: ProposalStatus.proposta,
                    createdAt: DateTime.now(),
                  );
                  try {
                    await FirebaseFirestore.instance
                        .collection('service_proposals')
                        .doc(id)
                        .set({
                          ...proposta.toMap(),
                          'companyId': companyId,
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    if (!context.mounted) return;
                    _msg(context, 'Proposta salva com sucesso.');
                  } catch (e) {
                    if (!context.mounted) return;
                    _msg(
                      context,
                      AppErrorMapper.messageFrom(
                        e,
                        fallback: 'Nao foi possivel salvar agora. Tente novamente.',
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    nomeCtrl.dispose();
    empresaCtrl.dispose();
    cnpjCtrl.dispose();
    emailCtrl.dispose();
    whatsappCtrl.dispose();
    enderecoCtrl.dispose();
    obsCtrl.dispose();
  }


  Future<void> _transformarEmContrato(
    BuildContext context,
    ServiceProposal proposta,
  ) async {
    var cobrarBdi = proposta.chargeBdi;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Transformar proposta em contrato'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: cobrarBdi,
                title: const Text('Cobrar BDI (+20%)'),
                onChanged: (v) => setDialog(() => cobrarBdi = v ?? false),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total contrato: ${_formatarMoeda(_totalComBdi(proposta.totalCents, cobrarBdi))}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('service_proposals')
                    .doc(proposta.id)
                    .set({
                      'status': ProposalStatus.contrato.name,
                      'chargeBdi': cobrarBdi,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (!context.mounted) return;
                _msg(context, 'Contrato atualizado em tempo real.');
              } catch (_) {
                if (!context.mounted) return;
                _msg(context, 'Nao foi possivel salvar agora. Tente novamente.');
              }
            },
            child: const Text('Confirmar'),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarBdiContrato(
    BuildContext context,
    ServiceProposal contrato,
  ) async {
    var cobrarBdi = contrato.chargeBdi;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('BDI do contrato'),
          content: CheckboxListTile(
            value: cobrarBdi,
            title: const Text('Cobrar BDI (+20%)'),
            subtitle: Text(
              'Total: ${_formatarMoeda(_totalComBdi(contrato.totalCents, cobrarBdi))}',
            ),
            onChanged: (v) => setDialog(() => cobrarBdi = v ?? false),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('service_proposals')
                    .doc(contrato.id)
                    .set({
                      'chargeBdi': cobrarBdi,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (!context.mounted) return;
                _msg(context, 'Contrato atualizado em tempo real.');
              } catch (_) {
                if (!context.mounted) return;
                _msg(context, 'Nao foi possivel salvar agora. Tente novamente.');
              }
            },
            child: const Text('Salvar'),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _compartilharPdf(
    ServiceProposal proposta,
    List<TarefaItem> tarefas,
  ) async {
    try {
      final bytes = await _montarPdfPropostaOuContrato(proposta, tarefas);
      final prefix = proposta.status == ProposalStatus.proposta
          ? 'proposta'
          : 'contrato';
      await sharePdfBytes(
        bytes: bytes,
        filename: '$prefix-${proposta.id}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      _msg(context, 'Nao foi possivel compartilhar PDF.');
    }
  }

  Future<void> _abrirPdf(
    ServiceProposal proposta,
    List<TarefaItem> tarefas,
  ) async {
    try {
      final bytes = await _montarPdfPropostaOuContrato(proposta, tarefas);
      await openPdfBytes(
        bytes: bytes,
        filename: '${proposta.status.name}-${proposta.id}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      _msg(context, 'Nao foi possivel abrir PDF.');
    }
  }

  Future<void> _apagarProposta(
    BuildContext context,
    ServiceProposal proposta,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar registro'),
        content: Text(
          'Deseja apagar ${proposta.status == ProposalStatus.proposta ? 'a proposta' : 'o contrato'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('service_proposals')
          .doc(proposta.id)
          .delete();
      if (!context.mounted) return;
      _msg(context, 'Registro apagado com sucesso.');
    } catch (e) {
      if (!context.mounted) return;
      _msg(
        context,
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel apagar agora.',
        ),
      );
    }
  }

  Future<void> _editarProposta(
    BuildContext context,
    ServiceProposal proposta,
    List<TarefaItem> tarefas,
  ) async {
    final nomeCtrl = TextEditingController(text: proposta.clientName);
    final empresaCtrl = TextEditingController(text: proposta.clientCompany);
    final cnpjCtrl = TextEditingController(text: proposta.clientCnpj);
    final emailCtrl = TextEditingController(text: proposta.clientEmail);
    final whatsappCtrl = TextEditingController(text: proposta.clientWhatsapp);
    final enderecoCtrl = TextEditingController(text: proposta.clientAddress);
    final obsCtrl = TextEditingController(text: proposta.notes);
    final selecionadas = <String>{...proposta.taskIds};
    var anexarResumoClausulas = proposta.attachClauseSummary;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) {
          final total = _somarTarefasSelecionadas(tarefas, selecionadas);
          return AlertDialog(
            title: const Text('Editar proposta/contrato'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome do cliente *'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: empresaCtrl,
                      decoration: const InputDecoration(labelText: 'Empresa'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cnpjCtrl,
                      decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: whatsappCtrl,
                      decoration: const InputDecoration(labelText: 'WhatsApp'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: enderecoCtrl,
                      decoration: const InputDecoration(labelText: 'Endereco'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Observacoes'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selecionar tarefas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...tarefas.map(
                      (t) => CheckboxListTile(
                        dense: true,
                        value: selecionadas.contains(t.id),
                        title: Text(t.nome),
                        subtitle: Text('${t.autorNome} - ${_formatarMoeda(_valorTarefaCents(t))}'),
                        onChanged: (v) {
                          setDialog(() {
                            if (v == true) {
                              selecionadas.add(t.id);
                            } else {
                              selecionadas.remove(t.id);
                            }
                          });
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Total selecionado: ${_formatarMoeda(total)}'),
                    ),
                    CheckboxListTile(
                      value: anexarResumoClausulas,
                      title: const Text('Anexar resumo das clausulas na proposta'),
                      onChanged: (v) =>
                          setDialog(() => anexarResumoClausulas = v ?? false),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  nomeCtrl.clear();
                  empresaCtrl.clear();
                  cnpjCtrl.clear();
                  emailCtrl.clear();
                  whatsappCtrl.clear();
                  enderecoCtrl.clear();
                  obsCtrl.clear();
                  setDialog(() {
                    selecionadas.clear();
                    anexarResumoClausulas = false;
                  });
                },
                child: const Text('Limpar tudo'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nomeCliente = _normalizarTextoSimples(nomeCtrl.text);
                  if (nomeCliente.isEmpty) {
                    _msg(context, 'Informe o nome do cliente.');
                    return;
                  }
                  if (selecionadas.isEmpty) {
                    _msg(context, 'Selecione ao menos uma tarefa.');
                    return;
                  }
                  final tarefasSelecionadas = tarefas
                      .where((t) => selecionadas.contains(t.id))
                      .toList();
                  try {
                    await FirebaseFirestore.instance
                        .collection('service_proposals')
                        .doc(proposta.id)
                        .set({
                          'clientName': _normalizarTextoSimples(nomeCliente, upper: true),
                          'clientCompany': _normalizarTextoSimples(empresaCtrl.text, upper: true),
                          'clientCnpj': _normalizarTextoSimples(cnpjCtrl.text, upper: true),
                          'clientEmail': _normalizarEmail(emailCtrl.text),
                          'clientWhatsapp': _normalizarTelefoneBR(whatsappCtrl.text),
                          'clientAddress': _normalizarTextoSimples(enderecoCtrl.text, upper: true),
                          'notes': _normalizarTextoSimples(obsCtrl.text, upper: true),
                          'taskIds': [for (final t in tarefasSelecionadas) t.id],
                          'taskTitles': [for (final t in tarefasSelecionadas) t.nome],
                          'totalCents': _somarTarefasSelecionadas(tarefas, selecionadas),
                          'attachClauseSummary': anexarResumoClausulas,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    if (!context.mounted) return;
                    _msg(context, 'Registro atualizado com sucesso.');
                  } catch (e) {
                    if (!context.mounted) return;
                    _msg(
                      context,
                      AppErrorMapper.messageFrom(
                        e,
                        fallback: 'Nao foi possivel atualizar agora.',
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    nomeCtrl.dispose();
    empresaCtrl.dispose();
    cnpjCtrl.dispose();
    emailCtrl.dispose();
    whatsappCtrl.dispose();
    enderecoCtrl.dispose();
    obsCtrl.dispose();
  }

  Future<Uint8List> _montarPdfPropostaOuContrato(
    ServiceProposal proposta,
    List<TarefaItem> tarefas,
  ) async {
    final dadosEmpresa = await _dadosEmpresaPdf();
    final clausulasEmpresa = await _carregarClausulasEmpresa();
    final tarefasSelecionadas = tarefas
        .where((t) => proposta.taskIds.contains(t.id))
        .toList();
    final totalBase = proposta.totalCents;
    final totalFinal = _totalComBdi(totalBase, proposta.chargeBdi);
    final titulo = proposta.status == ProposalStatus.proposta
        ? 'Proposta de Servicos'
        : 'Contrato de Prestacao de Servicos';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: StandardPdfDocument.pageTheme(),
        build: (_) => [
          StandardPdfDocument.header(
            title: titulo,
            subtitle:
                proposta.status == ProposalStatus.proposta
                    ? 'Documento comercial padronizado para apresentacao e aprovacao do cliente.'
                    : 'Documento padronizado para formalizacao comercial com base nas informacoes da empresa.',
            company: StandardPdfCompanyInfo(
              name: dadosEmpresa.nome,
              document: dadosEmpresa.cnpj == '-' ? '' : dadosEmpresa.cnpj,
              address: dadosEmpresa.endereco == '-' ? '' : dadosEmpresa.endereco,
            ),
            metadata: [
              StandardPdfField('Cliente', proposta.clientName),
              StandardPdfField(
                'Empresa do cliente',
                proposta.clientCompany.isEmpty ? '-' : proposta.clientCompany,
              ),
              StandardPdfField(
                'CPF/CNPJ do cliente',
                proposta.clientCnpj.isEmpty ? '-' : proposta.clientCnpj,
              ),
              StandardPdfField('Emitido por', proposta.createdByName),
              StandardPdfField(
                'Data de emissao',
                '${proposta.createdAt.day.toString().padLeft(2, '0')}/${proposta.createdAt.month.toString().padLeft(2, '0')}/${proposta.createdAt.year}',
              ),
              StandardPdfField('Valor base', _formatarMoeda(totalBase)),
              if (proposta.status == ProposalStatus.contrato)
                StandardPdfField(
                  'Total do contrato',
                  _formatarMoeda(totalFinal),
                ),
            ],
          ),
          StandardPdfDocument.section(
            title: 'Partes e contato',
            children: [
              StandardPdfDocument.infoGrid([
                StandardPdfField('Nome do cliente', proposta.clientName),
                StandardPdfField(
                  'Empresa do cliente',
                  proposta.clientCompany.isEmpty ? '-' : proposta.clientCompany,
                ),
                StandardPdfField(
                  'Email',
                  proposta.clientEmail.isEmpty ? '-' : proposta.clientEmail,
                ),
                StandardPdfField(
                  'WhatsApp',
                  proposta.clientWhatsapp.isEmpty ? '-' : proposta.clientWhatsapp,
                ),
                StandardPdfField(
                  'Endereco',
                  proposta.clientAddress.isEmpty ? '-' : proposta.clientAddress,
                ),
                StandardPdfField('Responsavel da empresa', proposta.createdByName),
              ]),
            ],
          ),
          StandardPdfDocument.section(
            title: 'Escopo dos servicos',
            children: StandardPdfDocument.bulletList([
              if (tarefasSelecionadas.isEmpty)
                'Nenhum servico vinculado.'
              else
                for (final tarefa in tarefasSelecionadas)
                  '${tarefa.nome} | ${_formatarMoeda(_valorTarefaCents(tarefa))}'
                      '${tarefa.descricao.trim().isEmpty ? '' : ' | ${tarefa.descricao.trim()}'}'
                      '${tarefa.itens.isEmpty ? '' : ' | Itens: ${tarefa.itens.map((i) => i.nome).join(', ')}'}',
            ]),
          ),
          StandardPdfDocument.section(
            title: 'Condicoes comerciais',
            children: [
              StandardPdfDocument.infoGrid([
                StandardPdfField('Valor base', _formatarMoeda(totalBase)),
                StandardPdfField(
                  'Aplicacao de BDI',
                  proposta.status == ProposalStatus.contrato
                      ? (proposta.chargeBdi ? 'Sim, 20%' : 'Nao')
                      : 'Nao se aplica',
                ),
                StandardPdfField(
                  'Valor final',
                  _formatarMoeda(totalFinal),
                ),
              ]),
            ],
          ),
          StandardPdfDocument.section(
            title: proposta.status == ProposalStatus.proposta
                ? 'Condicoes e observacoes'
                : 'Clausulas contratuais',
            children: StandardPdfDocument.bulletList(
              proposta.status == ProposalStatus.proposta
                  ? (proposta.attachClauseSummary
                      ? (clausulasEmpresa.resumo.isNotEmpty
                          ? clausulasEmpresa.resumo
                          : _clausulasResumo())
                      : <String>[
                          'Escopo sujeito a validacao final antes do aceite.',
                          'Alteracoes de escopo, prazo ou material podem alterar o valor final.',
                          'A aprovacao formal da proposta libera a execucao operacional.',
                        ])
                  : (clausulasEmpresa.completas.isNotEmpty
                      ? clausulasEmpresa.completas
                      : _clausulasCompletas()),
            ),
          ),
          if (proposta.notes.trim().isNotEmpty)
            StandardPdfDocument.section(
              title: 'Observacoes complementares',
              children: [
                StandardPdfDocument.paragraph(proposta.notes.trim()),
              ],
            ),
          StandardPdfDocument.signatureBlock([
            StandardPdfSigner(
              label: 'Representante da contratada',
              name: dadosEmpresa.nome == '-' ? 'Empresa contratada' : dadosEmpresa.nome,
              details: [
                if (dadosEmpresa.cnpj != '-') 'CPF/CNPJ: ${dadosEmpresa.cnpj}',
              ],
            ),
            StandardPdfSigner(
              label: proposta.status == ProposalStatus.proposta
                  ? 'Cliente para aprovacao'
                  : 'Contratante',
              name: proposta.clientName,
              details: [
                if (proposta.clientCnpj.isNotEmpty)
                  'CPF/CNPJ: ${proposta.clientCnpj}',
              ],
            ),
          ]),
        ],
      ),
    );
    return pdf.save();
  }


  Future<({List<String> resumo, List<String> completas})> _carregarClausulasEmpresa() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return (resumo: const <String>[], completas: const <String>[]);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .get();
      final map = doc.data() ?? <String, dynamic>{};
      final resumoRaw = map['clausesSummaryText']?.toString() ?? '';
      final completasRaw = map['clausesFullText']?.toString() ?? '';
      return (
        resumo: resumoRaw.trim().isEmpty ? const <String>[] : _quebrarClausulas(resumoRaw),
        completas: completasRaw.trim().isEmpty ? const <String>[] : _quebrarClausulas(completasRaw),
      );
    } catch (_) {
      return (resumo: const <String>[], completas: const <String>[]);
    }
  }

  List<String> _quebrarClausulas(String texto) {
    return texto
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _clausulasResumo() {
    return const [
      'Prestacao de mao de obra conforme escopo aprovado.',
      'Alteracoes de escopo podem gerar revisao de prazo e valor.',
      'Pagamentos devem seguir as datas acordadas.',
      'Materiais, EPIs e estrutura operacional sao da contratante.',
      'Garantia cobre falhas de execucao da contratada.',
    ];
  }

  List<String> _clausulasCompletas() {
    return const [
      '1. Objeto e escopo dos servicos.',
      '2. Horarios e flexibilidade operacional.',
      '3. Regime de execucao autonomo.',
      '4. Prazo, paralisacoes e revisao de valores.',
      '5. Pagamento, prazos e adimplencia.',
      '6. Encargos, despesas, EPIs e responsabilidades.',
      '7. Treinamentos e capacitacoes.',
      '8. Ferramentas e equipamentos.',
      '9. Obrigacoes e limitacao de responsabilidade da contratada.',
      '10. Obrigacoes da contratante.',
      '11. Inexistencia de vinculo trabalhista.',
      '12. Etica, boa-fe e limitacao de responsabilidade.',
      '13. Rescisao.',
      '14. Condicoes para inicio.',
      '15. Foro.',
    ];
  }
  Future<({String nome, String cnpj, String endereco})> _dadosEmpresaPdf() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) {
      return (nome: '-', cnpj: '-', endereco: '-');
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sessao.userId)
          .get();
      final map = doc.data();
      final companyData = (map?['companyData'] as Map?)?.cast<String, dynamic>();
      final nome = companyData?['nomeFantasia']?.toString().trim();
      final cnpj = companyData?['cnpj']?.toString().trim();
      final enderecoPadrao = companyData?['endereco']?.toString().trim();
      final rua = companyData?['rua']?.toString().trim() ?? '';
      final quadra = companyData?['quadra']?.toString().trim() ?? '';
      final lote = companyData?['lote']?.toString().trim() ?? '';
      final cidade = companyData?['cidade']?.toString().trim() ?? '';
      final estado = companyData?['estado']?.toString().trim() ?? '';
      final enderecoCompleto = <String>[
        if (rua.isNotEmpty) 'RUA $rua',
        if (quadra.isNotEmpty) 'QUADRA $quadra',
        if (lote.isNotEmpty) 'LOTE $lote',
        if (cidade.isNotEmpty) cidade,
        if (estado.isNotEmpty) estado,
      ].join(', ');
      final endereco = enderecoCompleto.isNotEmpty ? enderecoCompleto : (enderecoPadrao ?? '');
      return (
        nome: (nome == null || nome.isEmpty) ? '-' : nome,
        cnpj: (cnpj == null || cnpj.isEmpty) ? '-' : cnpj,
        endereco: endereco.isEmpty ? '-' : endereco,
      );
    } catch (_) {
      return (nome: '-', cnpj: '-', endereco: '-');
    }
  }

  Future<String> _resolverCompanyId(Session sessao) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final companyId = doc.data()?['companyId']?.toString().trim();
      if (companyId != null && companyId.isNotEmpty) return companyId;
    } catch (_) {
      // fallback sessao.
    }
    return sessao.companyId;
  }

  Future<void> _syncCompanyId(Session sessao) async {
    final resolved = (await _resolverCompanyId(sessao)).trim();
    if (!mounted || resolved.isEmpty || resolved == _companyIdEfetivo) return;
    setState(() => _companyIdEfetivo = resolved);
  }

  int _valorTarefaCents(TarefaItem tarefa) {
    if (tarefa.valorTotalCents != null) return tarefa.valorTotalCents!;
    return tarefa.itens.fold<int>(0, (s, i) => s + (i.valorCents ?? 0));
  }

  Future<void> _abrirWhatsapp(ServiceProposal proposta) async {
    final numero = proposta.clientWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.isEmpty) return;
    final mensagem = Uri.encodeComponent(
      'Segue ${proposta.status == ProposalStatus.proposta ? 'a proposta' : 'o contrato'} em PDF para avaliacao.',
    );
    final uri = Uri.parse('https://wa.me/$numero?text=$mensagem');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirEmail(ServiceProposal proposta) async {
    final assunto = Uri.encodeComponent(
      proposta.status == ProposalStatus.proposta
          ? 'Proposta de servicos'
          : 'Contrato de servicos',
    );
    final corpo = Uri.encodeComponent(
      'Segue em anexo o PDF para avaliacao.',
    );
    final uri = Uri.parse('mailto:${proposta.clientEmail}?subject=$assunto&body=$corpo');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  int _somarTarefasSelecionadas(List<TarefaItem> tarefas, Set<String> ids) {
    var total = 0;
    for (final t in tarefas) {
      if (ids.contains(t.id)) total += _valorTarefaCents(t);
    }
    return total;
  }

  int _totalComBdi(int totalBase, bool cobrarBdi) {
    if (!cobrarBdi) return totalBase;
    return totalBase + (totalBase * 0.2).round();
  }

  String _normalizarTextoSimples(String texto, {bool upper = false}) {
    var t = texto
        .replaceAll(RegExp(r'[\u0000-\u001F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    t = t.replaceFirst(RegExp(r'^[^A-Za-z0-9\u00C0-\u00FF]+'), '');
    t = t.replaceFirst(RegExp(r'[^A-Za-z0-9\u00C0-\u00FF]+$'), '');
    return upper ? t.toUpperCase() : t;
  }

  String _normalizarEmail(String texto) {
    return _normalizarTextoSimples(texto).toLowerCase();
  }

  String _normalizarTelefoneBR(String texto) {
    final digits = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return digits;
    final ddd = digits.substring(0, 2);
    final numeroBase = digits.length >= 11 ? digits.substring(2, 11) : digits.substring(2, 10);
    if (numeroBase.length == 9) {
      return '($ddd) ${numeroBase.substring(0, 5)}-${numeroBase.substring(5)}';
    }
    return '($ddd) ${numeroBase.substring(0, 4)}-${numeroBase.substring(4)}';
  }

  String _formatarMoeda(int cents) {
    final negativo = cents < 0;
    final absoluto = cents.abs();
    final reais = absoluto ~/ 100;
    final centavos = (absoluto % 100).toString().padLeft(2, '0');
    final reaisTexto = reais.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '${negativo ? '-' : ''}R\$ $reaisTexto,$centavos';
  }

  void _msg(BuildContext context, String texto) {
    if (!context.mounted) return;
    context.showUserMessage(texto);
  }
}

