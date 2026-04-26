import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/product_feedback/presentation/services/product_feedback_service.dart';
import 'package:pontocerto/features/runtime_incidents/presentation/runtime_incidents_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class ProductFeedbackPage extends ConsumerStatefulWidget {
  const ProductFeedbackPage({super.key});

  @override
  ConsumerState<ProductFeedbackPage> createState() => _ProductFeedbackPageState();
}

class _ProductFeedbackPageState extends ConsumerState<ProductFeedbackPage> {
  final _service = ProductFeedbackService();
  final _titleController = TextEditingController();
  final _contextController = TextEditingController();
  final _ideaController = TextEditingController();
  final _userInfoController = TextEditingController();

  String _selectedModule = 'Operacao';
  String _selectedPriority = 'media';
  String _filterStatus = 'todos';
  String _filterModule = 'todos';
  String _filterPriority = 'todos';
  bool _sending = false;

  static const _modules = <String>[
    'Operacao',
    'Financeiro',
    'Fiscal',
    'Contador',
    'Funcionarios',
    'Ponto',
    'Faturamento',
    'Relatorios',
    'Assistente',
    'Documentos',
    'Configuracoes',
    'Outro',
  ];

  static const _priorities = <String, String>{
    'baixa': 'Baixa',
    'media': 'Media',
    'alta': 'Alta',
    'critica': 'Critica',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _contextController.dispose();
    _ideaController.dispose();
    _userInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }

    final stream = FirebaseFirestore.instance
        .collection('product_feedback')
        .where('companyId', isEqualTo: session.companyId)
        .limit(100)
        .snapshots();
    final incidentStream = FirebaseFirestore.instance
        .collection('runtime_incidents')
        .where('companyId', isEqualTo: session.companyId)
        .where('source', isEqualTo: 'product_feedback')
        .limit(120)
        .snapshots();
    final issueStream = FirebaseFirestore.instance
        .collection('system_issues')
        .where('companyId', isEqualTo: session.companyId)
        .limit(120)
        .snapshots();

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Ideias de melhoria',
        subtitle:
            'Espaco para empresa, equipe e contador registrarem dores, ideias e informacoes de uso para orientar as proximas atualizacoes.',
        chips: [
          AppHeaderChip('Disponivel para todos'),
          AppHeaderChip('Base para evolucao do produto'),
        ],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, feedbackSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: incidentStream,
                builder: (context, incidentSnapshot) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: issueStream,
                    builder: (context, issueSnapshot) {
                      final feedbackDocs =
                          feedbackSnapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final incidentDocs =
                          incidentSnapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final issueDocs =
                          issueSnapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final items = _mergeFeedbackItems(
                        feedbackDocs,
                        incidentDocs,
                        issueDocs,
                      );
                      final total = items.length;
                      final novos = items
                          .where((item) => _statusOf(item.feedback) == 'novo')
                          .length;
                      final planejados = items
                          .where((item) => _statusOf(item.feedback) == 'planejado')
                          .length;
                      final entregues = items
                          .where((item) => _statusOf(item.feedback) == 'entregue')
                          .length;
                      final comResumoAssistente = items
                          .where(
                            (item) =>
                                _assistantSummaryFor(item).isNotEmpty ||
                                _recommendedActionFor(item).isNotEmpty,
                          )
                          .length;
                      final consolidadas = items.where((item) => item.issue != null).length;
                      final loading =
                          feedbackSnapshot.connectionState == ConnectionState.waiting &&
                          incidentSnapshot.connectionState == ConnectionState.waiting &&
                          issueSnapshot.connectionState == ConnectionState.waiting;

                      return ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          AppWorkspaceCard(
                            title: 'Panorama',
                            subtitle:
                                'Cada registro salva a ideia, entra na observabilidade e fica acessivel para o assistente resumir e orientar.',
                            trailing: session.role == Role.employee ||
                                    !hasSupremePlatformAccess(session)
                                ? null
                                : OutlinedButton.icon(
                                    onPressed: () => context.go('/runtime-incidents'),
                                    icon: const Icon(Icons.folder_open_outlined),
                                    label: const Text('Abrir observabilidade'),
                                  ),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                AppMetricCard(
                                  label: 'Ideias',
                                  value: '$total',
                                  caption: 'Registros visiveis desta empresa',
                                ),
                                AppMetricCard(
                                  label: 'Novas',
                                  value: '$novos',
                                  caption: 'Ainda sem tratamento',
                                ),
                                AppMetricCard(
                                  label: 'Planejadas',
                                  value: '$planejados',
                                  caption: 'Entraram em fila de evolucao',
                                ),
                                AppMetricCard(
                                  label: 'Entregues',
                                  value: '$entregues',
                                  caption: 'Ja viraram atualizacao',
                                ),
                                AppMetricCard(
                                  label: 'Com resumo IA',
                                  value: '$comResumoAssistente',
                                  caption: 'Ideias ja lidas pela observabilidade',
                                ),
                                AppMetricCard(
                                  label: 'Pasta ativa',
                                  value: '$consolidadas',
                                  caption: 'Problemas ja consolidados para resolver',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppDesktopSplit(
                            sidebarFlex: 11,
                            contentFlex: 13,
                            spacing: 12,
                            sidebar: AppWorkspaceCard(
                              title: 'Registrar ideia',
                              subtitle:
                                  'Descreva o problema real, a melhoria desejada e as informacoes do usuario que ajudam a priorizar.',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(
                                      labelText: 'Titulo curto',
                                      hintText: 'Ex.: Falta fechamento por competencia no contador',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedModule,
                                    decoration: const InputDecoration(labelText: 'Modulo'),
                                    items: [
                                      for (final item in _modules)
                                        DropdownMenuItem(value: item, child: Text(item)),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedModule = value);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedPriority,
                                    decoration: const InputDecoration(
                                      labelText: 'Prioridade percebida',
                                    ),
                                    items: [
                                      for (final entry in _priorities.entries)
                                        DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedPriority = value);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _contextController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'Dor atual',
                                      hintText: 'O que esta travando hoje? Onde isso gera retrabalho, atraso ou perda?',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _ideaController,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      labelText: 'Melhoria desejada',
                                      hintText: 'Como isso deveria funcionar para ficar util no dia a dia?',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _userInfoController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: 'Informacoes do usuario',
                                      hintText:
                                          'Perfil: ${_roleLabel(session.role)} | Ex.: equipe de campo, administrativo interno, contador externo',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.icon(
                                      onPressed: _sending ? null : () => _submit(session),
                                      icon: _sending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.lightbulb_outline),
                                      label: Text(
                                        _sending ? 'Salvando...' : 'Salvar ideia',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            content: AppWorkspaceCard(
                              title: 'Ideias registradas',
                              subtitle:
                                  'Historico real da empresa, com resumo do assistente e trilha ligada na observabilidade.',
                              child: loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _buildFilteredList(session, items),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      );
  }

  Future<void> _submit(Session session) async {
    final title = _titleController.text.trim();
    final contextText = _contextController.text.trim();
    final ideaText = _ideaController.text.trim();
    final userInfo = _userInfoController.text.trim();

    if (title.isEmpty || contextText.isEmpty || ideaText.isEmpty) {
      _show('Preencha titulo, dor atual e melhoria desejada.');
      return;
    }

    setState(() => _sending = true);
    try {
      await _service.submit(
        session: session,
        module: _selectedModule,
        priority: _selectedPriority,
        title: title,
        contextText: contextText,
        ideaText: ideaText,
        userInfo: userInfo,
      );

      _titleController.clear();
      _contextController.clear();
      _ideaController.clear();
      _userInfoController.clear();
      _show('Ideia registrada com sucesso.');
    } catch (error) {
      _show('Falha ao salvar a ideia: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(
    Session session,
    String docId,
    String status, {
    String incidentId = '',
  }) async {
    try {
      await _service.updateStatus(
        session: session,
        feedbackId: docId,
        status: status,
        incidentId: incidentId,
      );
      _show('Status atualizado.');
    } catch (error) {
      _show('Falha ao atualizar status: $error');
    }
  }

  Widget _buildFilteredList(
    Session session,
    List<_FeedbackViewItem> items,
  ) {
    final filteredItems = items.where((item) {
      final data = item.feedback;
      final status = _statusOf(data);
      final module = data['module']?.toString() ?? '';
      final priority = data['priority']?.toString() ?? '';
      if (_filterStatus != 'todos' && status != _filterStatus) return false;
      if (_filterModule != 'todos' && module != _filterModule) return false;
      if (_filterPriority != 'todos' && priority != _filterPriority) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _filterStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  DropdownMenuItem(value: 'novo', child: Text('Novo')),
                  DropdownMenuItem(value: 'planejado', child: Text('Planejado')),
                  DropdownMenuItem(value: 'entregue', child: Text('Entregue')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _filterStatus = value);
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _filterModule,
                decoration: const InputDecoration(labelText: 'Modulo'),
                items: [
                  const DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  for (final item in _modules)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _filterModule = value);
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _filterPriority,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todas')),
                  DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                  DropdownMenuItem(value: 'media', child: Text('Media')),
                  DropdownMenuItem(value: 'alta', child: Text('Alta')),
                  DropdownMenuItem(value: 'critica', child: Text('Critica')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _filterPriority = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredItems.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Nenhuma ideia encontrada com os filtros atuais.'),
          )
        else
          Column(
            children: [
              for (final item in filteredItems) ...[
                _FeedbackTile(
                  data: item.feedback,
                  incidentData: item.incident,
                  currentUserId: session.userId,
                  onMarkPlanned: () => _updateStatus(
                    session,
                    item.feedbackId,
                    'planejado',
                    incidentId:
                        item.feedback['observabilityIncidentId']?.toString() ?? '',
                  ),
                  onMarkDelivered: () => _updateStatus(
                    session,
                    item.feedbackId,
                    'entregue',
                    incidentId:
                        item.feedback['observabilityIncidentId']?.toString() ?? '',
                  ),
                  onAnalyze: () => _analyzeIncident(
                    item.feedback['observabilityIncidentId']?.toString() ?? '',
                  ),
                  onPromoteToIssue: () => _promoteIdeaToIssue(
                    item.feedback['observabilityIncidentId']?.toString() ?? '',
                  ),
                  onOpenObservability: () => context.go('/runtime-incidents'),
                  canManageStatus: session.role != Role.employee,
                  canOpenObservability: hasSupremePlatformAccess(session),
                  hasIssue: item.issue != null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }

  void _show(String message) {
    if (!mounted) return;
    context.showUserMessage(message);
  }

  Future<void> _analyzeIncident(String incidentId) async {
    if (incidentId.trim().isEmpty) {
      _show('Incidente de observabilidade nao encontrado para esta ideia.');
      return;
    }
    try {
      await ref.read(runtimeIncidentsActionsProvider).analyze(incidentId);
      _show('Ideia enviada para analise do assistente.');
    } catch (error) {
      _show('Falha ao analisar a ideia na observabilidade: $error');
    }
  }

  Future<void> _promoteIdeaToIssue(String incidentId) async {
    if (incidentId.trim().isEmpty) {
      _show('Incidente de observabilidade nao encontrado para esta ideia.');
      return;
    }
    try {
      await ref.read(runtimeIncidentsActionsProvider).promoteToIssue(incidentId);
      _show('Ideia consolidada na pasta operacional de observabilidade.');
    } catch (error) {
      _show('Falha ao consolidar a ideia na observabilidade: $error');
    }
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({
    required this.data,
    required this.incidentData,
    required this.currentUserId,
    required this.onMarkPlanned,
    required this.onMarkDelivered,
    required this.onAnalyze,
    required this.onPromoteToIssue,
    required this.onOpenObservability,
    required this.canManageStatus,
    required this.canOpenObservability,
    required this.hasIssue,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic>? incidentData;
  final String currentUserId;
  final VoidCallback onMarkPlanned;
  final VoidCallback onMarkDelivered;
  final VoidCallback onAnalyze;
  final VoidCallback onPromoteToIssue;
  final VoidCallback onOpenObservability;
  final bool canManageStatus;
  final bool canOpenObservability;
  final bool hasIssue;

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(data);
    final isAuthor = data['userId']?.toString() == currentUserId;
    final createdAt = data['createdAt'];
    final createdLabel = createdAt is Timestamp
        ? _formatDateTime(createdAt.toDate())
        : 'agora';
    final assistantSummary =
        _assistantSummaryFromMaps(data, incidentData).trim();
    final recommendedAction =
        _recommendedActionFromMaps(data, incidentData).trim();
    final observabilityStatus =
        incidentData?['status']?.toString().trim().toLowerCase() ?? '';
    final issueStatus = data['issueStatus']?.toString().trim().toLowerCase() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                data['title']?.toString() ?? 'Ideia sem titulo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppBrandColors.ink,
                ),
              ),
              _StatusChip(status: status),
              _MiniChip(label: data['module']?.toString() ?? 'Modulo'),
              _MiniChip(label: _priorityLabel(data['priority']?.toString())),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Registrado por ${data['userName'] ?? 'Usuario'} (${data['userRole'] ?? '-'}) em $createdLabel${isAuthor ? ' • voce' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppBrandColors.softText,
            ),
          ),
          if ((data['userInfo']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Informacoes do usuario: ${data['userInfo']}',
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: AppBrandColors.softText,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _LabelBlock(title: 'Dor atual', text: data['context']?.toString() ?? '-'),
          const SizedBox(height: 10),
          _LabelBlock(title: 'Melhoria desejada', text: data['idea']?.toString() ?? '-'),
          if (assistantSummary.isNotEmpty || recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LabelBlock(
              title: 'Resumo do assistente',
              text: assistantSummary.isNotEmpty ? assistantSummary : 'Resumo pendente.',
            ),
            if (recommendedAction.isNotEmpty) ...[
              const SizedBox(height: 10),
              _LabelBlock(
                title: 'Direcionamento recomendado',
                text: recommendedAction,
              ),
            ],
          ],
          if (observabilityStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Observabilidade: ${_incidentStatusLabel(observabilityStatus)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppBrandColors.softText,
              ),
            ),
          ],
          if (issueStatus.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Pasta operacional: ${_issueStatusLabel(issueStatus)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppBrandColors.softText,
              ),
            ),
          ],
          if (canManageStatus) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: onAnalyze,
                  child: Text(
                    assistantSummary.isEmpty ? 'Analisar no assistente' : 'Reanalisar',
                  ),
                ),
                OutlinedButton(
                  onPressed: hasIssue ? null : onPromoteToIssue,
                  child: Text(
                    hasIssue ? 'Ja esta na pasta operacional' : 'Salvar na pasta operacional',
                  ),
                ),
                if (canOpenObservability)
                  TextButton(
                    onPressed: onOpenObservability,
                    child: const Text('Abrir observabilidade'),
                  ),
                OutlinedButton(
                  onPressed: status == 'planejado' ? null : onMarkPlanned,
                  child: const Text('Marcar como planejado'),
                ),
                FilledButton(
                  onPressed: status == 'entregue' ? null : onMarkDelivered,
                  child: const Text('Marcar como entregue'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LabelBlock extends StatelessWidget {
  const _LabelBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppBrandColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.7,
            fontWeight: FontWeight.w700,
            color: AppBrandColors.softText,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'planejado' => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
      'entregue' => (const Color(0xFFECFDF5), const Color(0xFF047857)),
      _ => (const Color(0xFFFFF7ED), const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status == 'novo'
            ? 'Novo'
            : status == 'planejado'
                ? 'Planejado'
                : 'Entregue',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppBrandColors.softText,
        ),
      ),
    );
  }
}

class _FeedbackViewItem {
  const _FeedbackViewItem({
    required this.feedbackId,
    required this.feedback,
    this.incident,
    this.issue,
  });

  final String feedbackId;
  final Map<String, dynamic> feedback;
  final Map<String, dynamic>? incident;
  final Map<String, dynamic>? issue;
}

List<_FeedbackViewItem> _mergeFeedbackItems(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> feedbackDocs,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> incidentDocs,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> issueDocs,
) {
  final incidentsByFeedbackId = <String, Map<String, dynamic>>{};
  for (final doc in incidentDocs) {
    final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
    final extra = data['extra'];
    final extraMap = extra is Map ? extra.cast<String, dynamic>() : null;
    final feedbackId =
        extraMap?['feedbackId']?.toString().trim() ??
        extraMap?['originId']?.toString().trim() ??
        extraMap?['feedbackDocId']?.toString().trim() ??
        (doc.id.startsWith('feedback_') ? doc.id.substring('feedback_'.length) : '');
    if (feedbackId.isNotEmpty) {
      incidentsByFeedbackId[feedbackId] = data;
    }
  }

  final issuesByIncidentId = <String, Map<String, dynamic>>{};
  for (final doc in issueDocs) {
    final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
    if ((data['source']?.toString().trim() ?? '') != 'product_feedback') {
      continue;
    }
    final latestIncidentId = data['latestIncidentId']?.toString().trim() ?? '';
    if (latestIncidentId.isNotEmpty) {
      issuesByIncidentId[latestIncidentId] = data;
    }
  }

  final items = <_FeedbackViewItem>[];
  final seenIds = <String>{};
  for (final doc in feedbackDocs) {
    final incident = incidentsByFeedbackId[doc.id];
    final issue = incident == null
        ? null
        : issuesByIncidentId[incident['id']?.toString() ?? ''];
    final feedbackData = Map<String, dynamic>.from(doc.data());
    if (issue != null) {
      feedbackData['issueStatus'] = issue['status']?.toString() ?? '';
      feedbackData['issueAssistantSummary'] =
          issue['assistantSummary']?.toString() ?? '';
      feedbackData['issueRecommendedAction'] =
          issue['recommendedAction']?.toString() ?? '';
    }
    items.add(
      _FeedbackViewItem(
        feedbackId: doc.id,
        feedback: feedbackData,
        incident: incident,
        issue: issue,
      ),
    );
    seenIds.add(doc.id);
  }

  for (final entry in incidentsByFeedbackId.entries) {
    if (seenIds.contains(entry.key)) continue;
    final incident = entry.value;
    final extra = incident['extra'];
    final extraMap = extra is Map
        ? extra.cast<String, dynamic>()
        : const <String, dynamic>{};
    items.add(
      _FeedbackViewItem(
        feedbackId: entry.key,
        feedback: <String, dynamic>{
          'title': extraMap['title']?.toString() ?? 'Ideia registrada',
          'module': extraMap['module']?.toString() ?? 'Outro',
          'priority': extraMap['priority']?.toString() ?? 'media',
          'context': extraMap['context']?.toString() ?? '',
          'idea': extraMap['idea']?.toString() ?? '',
          'userInfo': extraMap['userInfo']?.toString() ?? '',
          'userName': incident['reporterName']?.toString() ?? 'Usuario',
          'userRole': incident['reporterRole']?.toString() ?? '',
          'userId': incident['reporterUserId']?.toString() ?? '',
          'status': incident['status']?.toString() == 'resolved'
              ? 'entregue'
              : 'novo',
          'observabilityIncidentId': incident['id']?.toString() ?? '',
          'assistantSummary': incident['assistantSummary']?.toString() ?? '',
          'recommendedAction': incident['recommendedAction']?.toString() ?? '',
          'issueStatus':
              issuesByIncidentId[incident['id']?.toString() ?? '']?['status']
                  ?.toString() ??
              '',
          'issueAssistantSummary':
              issuesByIncidentId[incident['id']?.toString() ?? '']?['assistantSummary']
                  ?.toString() ??
              '',
          'issueRecommendedAction':
              issuesByIncidentId[incident['id']?.toString() ?? '']?['recommendedAction']
                  ?.toString() ??
              '',
          'createdAt': incident['createdAt'],
          'updatedAt': incident['updatedAt'],
        },
        incident: incident,
        issue: issuesByIncidentId[incident['id']?.toString() ?? ''],
      ),
    );
  }

  int timestampFor(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
    return 0;
  }

  items.sort(
    (a, b) => timestampFor(b.feedback).compareTo(timestampFor(a.feedback)),
  );
  return items;
}

String _statusOf(Map<String, dynamic> data) =>
    data['status']?.toString().trim().toLowerCase() ?? 'novo';

String _priorityLabel(String? value) => switch (value) {
      'critica' => 'Critica',
      'alta' => 'Alta',
      'baixa' => 'Baixa',
      _ => 'Media',
    };

String _assistantSummaryFor(_FeedbackViewItem item) =>
    _assistantSummaryFromMaps(item.feedback, item.incident);

String _recommendedActionFor(_FeedbackViewItem item) =>
    _recommendedActionFromMaps(item.feedback, item.incident);

String _assistantSummaryFromMaps(
  Map<String, dynamic> feedback,
  Map<String, dynamic>? incident,
) {
  final incidentSummary = incident?['assistantSummary']?.toString().trim() ?? '';
  if (incidentSummary.isNotEmpty) return incidentSummary;
  final issueSummary = feedback['issueAssistantSummary']?.toString().trim() ?? '';
  if (issueSummary.isNotEmpty) return issueSummary;
  return feedback['assistantSummary']?.toString().trim() ?? '';
}

String _recommendedActionFromMaps(
  Map<String, dynamic> feedback,
  Map<String, dynamic>? incident,
) {
  final incidentAction = incident?['recommendedAction']?.toString().trim() ?? '';
  if (incidentAction.isNotEmpty) return incidentAction;
  final issueAction =
      feedback['issueRecommendedAction']?.toString().trim() ?? '';
  if (issueAction.isNotEmpty) return issueAction;
  return feedback['recommendedAction']?.toString().trim() ?? '';
}

String _roleLabel(Role role) => switch (role) {
      Role.owner => 'Owner',
      Role.manager => 'Manager',
      Role.accountant => 'Contador',
      Role.employee => 'Funcionario',
    };

String _issueStatusLabel(String value) => switch (value) {
      'resolved' => 'Resolvida',
      'monitoring' => 'Monitorando',
      _ => 'Aberta',
    };

String _formatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _incidentStatusLabel(String value) {
  switch (value) {
    case 'resolved':
      return 'Resolvido';
    case 'ignored':
      return 'Ignorado';
    default:
      return 'Em aberto';
  }
}
