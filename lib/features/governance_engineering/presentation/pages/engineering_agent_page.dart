import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/features/governance_engineering/data/engineering_agent_service.dart';
import 'package:pontocerto/features/governance_engineering/domain/engineering_agent_message.dart';
import 'package:pontocerto/features/governance_engineering/presentation/providers/engineering_agent_provider.dart';

/// Agente de Engenharia — chat em tela cheia (OpenAI só no backend; sessões por projeto).
class EngineeringAgentPage extends ConsumerStatefulWidget {
  const EngineeringAgentPage({super.key});

  @override
  ConsumerState<EngineeringAgentPage> createState() => _EngineeringAgentPageState();
}

class _EngineeringAgentPageState extends ConsumerState<EngineeringAgentPage> {
  final _inputCtrl = TextEditingController();
  final _scrollChat = ScrollController();
  final _createNameCtrl = TextEditingController();
  final _createRootCtrl = TextEditingController();
  final _createManifestCtrl = TextEditingController();
  final _continuityCtrl = TextEditingController();

  String? _sessionId;
  List<EngineeringAgentChatMessage> _messages = [];
  EngineeringAgentStructuredSlots _slots = EngineeringAgentStructuredSlots.empty;
  EngineeringAgentSessionDetail? _sessionDetail;
  bool _busy = false;
  List<EngineeringAgentSessionSummary> _sessions = [];
  EngineeringAgentProjectsLoadResult? _projectsLoad;
  String _selectedProjectId = kEngineeringAgentPontocertoProjectId;
  String _createType = 'externo';

  static String _formatSessionTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  List<EngineeringAgentProjectSummary> get _allProjects {
    final load = _projectsLoad;
    if (load == null) return [];
    return [load.builtin, ...load.projects];
  }

  EngineeringAgentProjectSummary? get _currentProject {
    for (final p in _allProjects) {
      if (p.id == _selectedProjectId) return p;
    }
    return _projectsLoad?.builtin;
  }

  String get _modeBadge {
    final p = _currentProject;
    if (p == null) return 'Modo';
    if (p.type == 'pontocerto') return 'PontoCerto';
    if (p.type == 'novo') return 'Novo';
    return 'Externo';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollChat.dispose();
    _createNameCtrl.dispose();
    _createRootCtrl.dispose();
    _createManifestCtrl.dispose();
    _continuityCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final svc = ref.read(engineeringAgentServiceProvider);
    try {
      final r = await svc.listProjects();
      if (!mounted) return;
      setState(() {
        _projectsLoad = r;
        _selectedProjectId = r.selectedProjectId.isEmpty
            ? kEngineeringAgentPontocertoProjectId
            : r.selectedProjectId;
      });
      await _reloadSessions();
    } catch (e) {
      if (mounted) context.showUserMessage('Erro ao carregar projetos: $e');
    }
  }

  Future<void> _reloadSessions() async {
    final svc = ref.read(engineeringAgentServiceProvider);
    try {
      final list = await svc.listSessions(projectId: _selectedProjectId);
      if (mounted) setState(() => _sessions = list);
    } catch (_) {
      if (mounted) context.showUserMessage('Nao foi possivel carregar sessoes.');
    }
  }

  Future<void> _onProjectChanged(String? pid) async {
    if (pid == null || pid == _selectedProjectId) return;
    final svc = ref.read(engineeringAgentServiceProvider);
    setState(() => _busy = true);
    try {
      await svc.selectProject(pid);
      if (!mounted) return;
      setState(() {
        _selectedProjectId = pid;
        _sessionId = null;
        _messages = [];
        _sessionDetail = null;
        _slots = EngineeringAgentStructuredSlots.empty;
        _busy = false;
      });
      await _reloadSessions();
      if (mounted) context.showUserMessage('Projeto selecionado.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showUserMessage('Erro: $e');
      }
    }
  }

  Future<void> _loadSession(String id) async {
    final svc = ref.read(engineeringAgentServiceProvider);
    setState(() => _busy = true);
    try {
      final r = await svc.getSession(id);
      if (!mounted) return;
      setState(() {
        _sessionId = id;
        _messages = r.messages;
        _sessionDetail = r.session;
        _slots = EngineeringAgentStructuredSlots(
          plan: r.session.lastPlan,
          files: r.session.lastFiles,
          docs: r.session.lastDocs,
          risks: r.session.lastRisks,
          impact: r.session.lastImpact,
          patchPreview: r.session.lastPatchPreview,
          command: r.session.lastCommand,
          reply: '',
        );
        _busy = false;
      });
      _scrollBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showUserMessage('Erro ao abrir sessao: $e');
      }
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    final svc = ref.read(engineeringAgentServiceProvider);
    setState(() => _busy = true);
    _inputCtrl.clear();
    try {
      final out = await svc.sendMessage(
        text: text,
        projectId: _selectedProjectId,
        sessionId: _sessionId,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = out.sessionId;
        _slots = out.structured;
        _busy = false;
      });
      await _loadSession(out.sessionId);
      await _reloadSessions();
      if (!mounted) return;
      context.showUserMessage('Resposta recebida.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showUserMessage('Erro: $e');
      }
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollChat.hasClients) return;
      _scrollChat.jumpTo(_scrollChat.position.maxScrollExtent);
    });
  }

  Future<void> _approvePatch() async {
    if (_sessionId == null) {
      context.showUserMessage('Abra ou crie uma sessao primeiro.');
      return;
    }
    final svc = ref.read(engineeringAgentServiceProvider);
    setState(() => _busy = true);
    try {
      await svc.approvePatch(
        sessionId: _sessionId!,
        approved: true,
        note: 'Aprovado na UI plataforma',
      );
      if (mounted) {
        setState(() => _busy = false);
        context.showUserMessage('Patch registado como aprovado.');
      }
      await _loadSession(_sessionId!);
      await _reloadSessions();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showUserMessage('Erro: $e');
      }
    }
  }

  Future<void> _copyCommand() async {
    final cmd = _slots.command.trim();
    if (cmd.isEmpty || cmd == '-') {
      context.showUserMessage('Sem comando na ultima resposta.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: cmd));
    if (mounted) context.showUserMessage('Comando copiado.');
  }

  Future<void> _generateCommand() async {
    if (_sessionId == null) {
      context.showUserMessage('Abra ou envie uma mensagem primeiro.');
      return;
    }
    final svc = ref.read(engineeringAgentServiceProvider);
    setState(() => _busy = true);
    try {
      final cmd = await svc.generateCommand(sessionId: _sessionId!, mergeToSession: true);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _slots = EngineeringAgentStructuredSlots(
          plan: _slots.plan,
          files: _slots.files,
          docs: _slots.docs,
          risks: _slots.risks,
          impact: _slots.impact,
          patchPreview: _slots.patchPreview,
          command: cmd,
          reply: _slots.reply,
        );
      });
      await _loadSession(_sessionId!);
      if (mounted) context.showUserMessage('Comando gerado e gravado na sessao.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showUserMessage('Erro: $e');
      }
    }
  }

  void _showSlotSheet(BuildContext context, String title, String raw) {
    final body = raw.trim().isEmpty ? '—' : raw.trim();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(ctx).bottom + 12,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: body));
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!context.mounted) return;
                            context.showUserMessage('Copiado.');
                          },
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        body,
                        style: const TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _docsDialog() {
    final body = _slots.docs.trim().isEmpty ? '—' : _slots.docs.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Documentacao (slot <<<DOC>>>)'),
        content: SizedBox(
          width: 520,
          height: 280,
          child: SingleChildScrollView(child: SelectableText(body)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) context.showUserMessage('Documentacao copiada.');
            },
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  void _filesDialog() {
    final raw = _slots.files.trim().isEmpty ? '' : _slots.files.trim();
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '-')
        .toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivos alterados'),
        content: SizedBox(
          width: 440,
          height: 320,
          child: lines.isEmpty
              ? const Text('Nenhum caminho listado.')
              : ListView(
                  children: lines
                      .map(
                        (path) => ListTile(
                          dense: true,
                          title: SelectableText(path),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: path));
                              if (mounted) context.showUserMessage('Copiado: $path');
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _continuityDialog() {
    _continuityCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar continuidade'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Texto guardado no servidor (auditoria). Para docs/CONTINUIDADE_ATUAL.md copie e cole no repositorio.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _continuityCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Resumo da sessao, ficheiros, decisoes...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final note = _continuityCtrl.text.trim();
              if (_sessionId == null || note.isEmpty) return;
              final svc = ref.read(engineeringAgentServiceProvider);
              try {
                await svc.registerContinuity(sessionId: _sessionId!, note: note);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) context.showUserMessage('Continuidade registada no servidor.');
              } catch (e) {
                if (mounted) context.showUserMessage('Erro: $e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _createProjectDialog() {
    _createNameCtrl.clear();
    _createRootCtrl.clear();
    _createManifestCtrl.clear();
    _createType = 'externo';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Cadastrar projeto autorizado'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Declare apenas projetos que autoriza. O servidor nao acede ao disco; '
                    'colar README/package.json/pubspec ajuda a detetar stack.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _createNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _createType,
                        items: const [
                          DropdownMenuItem(value: 'externo', child: Text('Projeto externo')),
                          DropdownMenuItem(value: 'novo', child: Text('Projeto novo (explicito)')),
                        ],
                        onChanged: (v) => setLocal(() => _createType = v ?? 'externo'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _createRootCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Root autorizado (ex.: C:\\src\\meu-repo)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _createManifestCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Manifesto / README (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final name = _createNameCtrl.text.trim();
                final root = _createRootCtrl.text.trim();
                if (name.isEmpty || root.isEmpty) return;
                final svc = ref.read(engineeringAgentServiceProvider);
                try {
                  final pid = await svc.createProject(
                    name: name,
                    type: _createType,
                    rootPath: root,
                    manifestSnippet: _createManifestCtrl.text.trim(),
                  );
                  await _bootstrap();
                  if (pid.isNotEmpty) await svc.selectProject(pid);
                  if (!mounted) return;
                  setState(() => _selectedProjectId = pid.isNotEmpty ? pid : _selectedProjectId);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _reloadSessions();
                  if (mounted) context.showUserMessage('Projeto criado.');
                } catch (e) {
                  if (mounted) context.showUserMessage('Erro: $e');
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _newConversation() {
    setState(() {
      _sessionId = null;
      _messages = [];
      _sessionDetail = null;
      _slots = EngineeringAgentStructuredSlots.empty;
    });
  }

  void _openSessionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sessoes',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Nova conversa',
                        icon: const Icon(Icons.add_comment_outlined),
                        onPressed: () {
                          _newConversation();
                          Navigator.pop(ctx);
                        },
                      ),
                      IconButton(
                        tooltip: 'Recarregar',
                        icon: const Icon(Icons.refresh_outlined),
                        onPressed: () {
                          _reloadSessions();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _sessions
                        .map(
                          (s) => _sessionTile(
                            s,
                            beforeSelect: () => Navigator.pop(ctx),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onOverflowMenu(String id) {
    switch (id) {
      case 'nova_sessao':
        _newConversation();
        break;
      case 'reload_sessoes':
        _reloadSessions();
        break;
      case 'plano':
        _showSlotSheet(context, 'Plano', _slots.plan);
        break;
      case 'arquivos':
        _filesDialog();
        break;
      case 'docs':
        _docsDialog();
        break;
      case 'riscos':
        _showSlotSheet(context, 'Riscos evitados', _slots.risks);
        break;
      case 'impacto':
        _showSlotSheet(context, 'Impacto', _slots.impact);
        break;
      case 'patch':
        _showSlotSheet(context, 'Patch (preview)', _slots.patchPreview);
        break;
      case 'comando':
        _showSlotSheet(context, 'Comando PowerShell', _slots.command);
        break;
      case 'aprovar':
        _approvePatch();
        break;
      case 'gerar_cmd':
        _generateCommand();
        break;
      case 'copiar_cmd':
        _copyCommand();
        break;
      case 'continuidade':
        _continuityDialog();
        break;
    }
  }

  Widget _sessionTile(EngineeringAgentSessionSummary s, {VoidCallback? beforeSelect}) {
    final selected = s.id == _sessionId;
    return ListTile(
      selected: selected,
      title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _formatSessionTime(s.updatedAtIso),
        style: const TextStyle(fontSize: 11),
      ),
      trailing: s.patchApproved ? const Icon(Icons.check_circle_outline, size: 18) : null,
      onTap: () {
        beforeSelect?.call();
        _loadSession(s.id);
      },
    );
  }

  Widget _compactToolbar(BuildContext context, {required bool narrow}) {
    final items = _allProjects;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppBrandColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            if (narrow)
              IconButton(
                tooltip: 'Sessoes',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.history),
                onPressed: () => _openSessionsSheet(context),
              ),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Projeto',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: items.any((p) => p.id == _selectedProjectId) ? _selectedProjectId : null,
                    items: items
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _busy ? null : _onProjectChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: _modeBadge,
              child: Chip(
                label: Text(_modeBadge, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                avatar: Icon(
                  _currentProject?.type == 'pontocerto'
                      ? Icons.business_outlined
                      : Icons.folder_copy_outlined,
                  size: 16,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Novo projeto',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _busy ? null : _createProjectDialog,
            ),
            PopupMenuButton<String>(
              tooltip: 'Entrega e acoes',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert),
              onSelected: _onOverflowMenu,
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'nova_sessao', child: Text('Nova conversa')),
                const PopupMenuItem(value: 'reload_sessoes', child: Text('Recarregar sessoes')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'plano', child: Text('Plano')),
                const PopupMenuItem(value: 'arquivos', child: Text('Arquivos afetados')),
                const PopupMenuItem(value: 'docs', child: Text('Documentacao')),
                const PopupMenuItem(value: 'riscos', child: Text('Riscos')),
                const PopupMenuItem(value: 'impacto', child: Text('Impacto')),
                const PopupMenuItem(value: 'patch', child: Text('Patch (preview)')),
                const PopupMenuItem(value: 'comando', child: Text('Comando PowerShell')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'aprovar', child: Text('Aprovar patch')),
                const PopupMenuItem(value: 'gerar_cmd', child: Text('Gerar comando')),
                const PopupMenuItem(value: 'copiar_cmd', child: Text('Copiar comando')),
                const PopupMenuItem(value: 'continuidade', child: Text('Registrar continuidade')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionsRail() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppBrandColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sessoes',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Nova conversa',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                  onPressed: _newConversation,
                ),
                IconButton(
                  tooltip: 'Recarregar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_outlined, size: 20),
                  onPressed: _reloadSessions,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(children: _sessions.map(_sessionTile).toList()),
          ),
        ],
      ),
    );
  }

  Widget _chatArea(double assistantBubbleMaxWidth) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppBrandColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _sessionDetail?.title ?? 'Nova sessao',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_sessionDetail?.patchApproved == true)
                  Icon(Icons.verified_outlined, size: 18, color: Colors.green.shade700),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, chatConstraints) {
                final maxW = assistantBubbleMaxWidth > 0 && assistantBubbleMaxWidth.isFinite
                    ? assistantBubbleMaxWidth
                    : (chatConstraints.maxWidth - 24).clamp(320.0, 920.0);
                return ListView.builder(
                  controller: _scrollChat,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final user = m.role == 'user';
                    return Align(
                      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: user ? 520 : maxW,
                        ),
                        decoration: BoxDecoration(
                          color: user ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppBrandColors.border),
                        ),
                        child: SelectableText(
                          m.text,
                          style: const TextStyle(fontSize: 14, height: 1.45),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Escreva a mensagem em portugues...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  ),
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 1040;
    final assistantMax =
        (MediaQuery.sizeOf(context).width - (narrow ? 48 : 296)).clamp(400.0, 960.0);

    if (_projectsLoad == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _compactToolbar(context, narrow: narrow),
        const SizedBox(height: 8),
        Expanded(
          child: narrow
              ? _chatArea(assistantMax)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 220, child: _sessionsRail()),
                    const SizedBox(width: 10),
                    Expanded(child: _chatArea(assistantMax)),
                  ],
                ),
        ),
      ],
    );
  }
}
