import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/monitoring/runtime_incident_reporter.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/assistant/domain/assistant_thread.dart';
import 'package:pontocerto/features/assistant/presentation/services/assistant_service.dart';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _service = AssistantService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatItem> _messages = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _threadSub;

  bool _sending = false;
  String? _status;
  String _currentThreadId = '';

  @override
  void dispose() {
    _threadSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    RuntimeIncidentReporter.instance.updateContext(
      screenLabel: 'Assistente Inteligente',
      route: '/assistant',
    );
    final threadId = GoRouterState.of(context).uri.queryParameters['thread'] ?? '';
    if (threadId != _currentThreadId) {
      _bindThread(threadId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }

    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final showHistory =
        GoRouterState.of(context).uri.queryParameters['history'] == '1';
    final showSupremeQueue =
        !showHistory && hasSupremePlatformAccess(session);

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Assistente Inteligente',
        subtitle: showHistory
            ? 'Revise as conversas deste login e toque em uma delas para voltar ao dialogo.'
            : 'Use para tirar duvidas sobre o sistema.',
        chips: showSupremeQueue
            ? [
                Tooltip(
                  message:
                      'Apenas empresa suprema: enfileirar ideias e incidentes abertos para o assistente, sem sair do chat.',
                  child: FilledButton.tonalIcon(
                    onPressed: _sending ? null : () => _openSupremeQueueSheet(session),
                    icon: const Icon(Icons.hub_outlined, size: 20),
                    label: const Text('Fila suprema'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ]
            : const [],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: showHistory
            ? _AssistantHistoryScreen(session: session)
            : Column(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppBrandColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _messages.isEmpty
                            ? const _EmptyAssistantState()
                            : ListView.separated(
                                controller: _scrollController,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: _messages.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _messages[index];
                                  return Align(
                                    alignment: item.isAssistant
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 760),
                                      child: _ChatBubble(item: item),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: keyboardBottom),
                    child: Column(
                      children: [
                        if (_status != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _status!,
                                    style: const TextStyle(
                                      color: AppBrandColors.softText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _buildComposer(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildComposer() {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final input = TextField(
      controller: _controller,
      minLines: 2,
      maxLines: compact ? 5 : 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendMessage(),
      decoration: const InputDecoration(
        hintText: 'Digite sua pergunta para o assistente',
        border: InputBorder.none,
      ),
    );

    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: Size(compact ? double.infinity : 168, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onPressed: _sending ? null : _sendMessage,
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_rounded),
      label: Text(_sending ? 'Enviando...' : 'Enviar'),
    );

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppBrandColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 12),
                    button,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: input),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    await _sendPreparedPrompt(_controller.text.trim(), clearComposer: true);
  }

  Future<void> _sendPreparedPrompt(
    String rawText, {
    bool clearComposer = false,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _status = 'Consultando o assistente...';
      _messages.add(
        _ChatItem(
          text: text,
          author: 'Voce',
          isAssistant: false,
          isPending: false,
        ),
      );
      _messages.add(
        const _ChatItem(
          text: 'Aguardando resposta do assistente...',
          author: 'Assistente Inteligente',
          isAssistant: true,
          isPending: true,
        ),
      );
    });
    if (clearComposer) {
      _controller.clear();
    }
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(
        message: text,
        threadId: _currentThreadId,
      );
      if (!mounted) return;
      final resolvedText = reply.reply.trim().isNotEmpty
          ? reply.reply.trim()
          : reply.rawBody.trim().isNotEmpty
          ? reply.rawBody.trim()
          : 'O assistente nao retornou texto utilizavel.';
      final resolvedThreadId = reply.threadId.trim();

      if (resolvedThreadId.isNotEmpty) {
        _currentThreadId = resolvedThreadId;
        await _loadThreadMessages(
          resolvedThreadId,
          fallbackAssistantReply: resolvedText,
          fallbackUserMessage: text,
        );
        if (!mounted) return;
      }

      setState(() {
        _messages.removeWhere((item) => item.isAssistant && item.isPending);
        if (resolvedThreadId.isEmpty) {
          final emptyAssistantReply = reply.reply.trim().isEmpty;
          final item = _ChatItem(
            text: resolvedText,
            author: 'Assistente Inteligente',
            isAssistant: true,
            isPending: false,
            isError: emptyAssistantReply,
          );
          _messages.add(item);
        }
        _status = reply.model.isNotEmpty
            ? 'Resposta gerada por ${reply.model}.'
            : 'Resposta concluida.';
        if (reply.reply.trim().isEmpty) {
          _status = 'Resposta concluida com alerta. Registro enviado para monitoramento.';
        }
        _sending = false;
      });
      if (reply.reply.trim().isEmpty) {
        unawaited(
          RuntimeIncidentReporter.instance.capture(
            source: 'assistant_empty_reply',
            error: resolvedText,
            severity: 'warning',
            category: 'assistant',
            screenLabel: 'Assistente Inteligente',
            extra: {
              'threadId': resolvedThreadId,
              'prompt': text,
              'model': reply.model,
            },
          ),
        );
      }
      if (resolvedThreadId.isNotEmpty &&
          GoRouterState.of(context).uri.queryParameters['thread'] !=
              resolvedThreadId) {
        context.go('/assistant?thread=$resolvedThreadId');
      }
      _scrollToBottom();
    } catch (error) {
      final rawMessage = _rawErrorMessage(error);
      unawaited(
        RuntimeIncidentReporter.instance.capture(
          source: 'assistant_page',
          error: error,
          severity: 'error',
          category: 'assistant',
          screenLabel: 'Assistente Inteligente',
          extra: {
            'threadId': _currentThreadId,
            'prompt': text,
            'rawMessage': rawMessage,
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((item) => item.isAssistant && item.isPending);
        final item = _ChatItem(
          text: rawMessage,
          author: 'Assistente Inteligente',
          isAssistant: true,
          isPending: false,
          isError: true,
        );
        _messages.add(item);
        _status = 'Falha ao consultar o assistente. Registro enviado para monitoramento.';
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _rawErrorMessage(Object error) {
    final mapped = AppErrorMapper.messageFrom(
      error,
      fallback: 'Nao foi possivel consultar o assistente agora.',
    );
    final raw = error.toString().trim();
    if (raw.isEmpty || raw == 'Exception' || raw == 'Exception:') {
      return mapped;
    }
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  void _bindThread(String threadId) {
    _threadSub?.cancel();
    _currentThreadId = threadId.trim();
    if (_currentThreadId.isEmpty) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _status = null;
        });
      }
      return;
    }
    _threadSub = FirebaseFirestore.instance
        .collection('assistant_threads')
        .doc(_currentThreadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          final nextMessages = _mapThreadMessages(snapshot.docs);
          setState(() {
            _messages
              ..clear()
              ..addAll(nextMessages);
            _status = 'Conversa carregada.';
          });
          _scrollToBottom();
        });
  }

  Future<void> _loadThreadMessages(
    String threadId, {
    required String fallbackAssistantReply,
    required String fallbackUserMessage,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('assistant_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('createdAt')
          .get();
      if (!mounted) return;
      final nextMessages = _mapThreadMessages(snapshot.docs);
      if (nextMessages.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(nextMessages);
      });
    } catch (_) {
      unawaited(
        RuntimeIncidentReporter.instance.capture(
          source: 'assistant_thread_reload',
          error: 'Falha ao recarregar mensagens do thread no cliente.',
          severity: 'warning',
          category: 'assistant',
          screenLabel: 'Assistente Inteligente',
          extra: {
            'threadId': threadId,
            'fallbackUserMessage': fallbackUserMessage,
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((item) => item.isAssistant && item.isPending);
        final hasUserMessage = _messages.any(
          (item) => !item.isAssistant && item.text.trim() == fallbackUserMessage,
        );
        if (!hasUserMessage) {
          _messages.add(
            _ChatItem(
              text: fallbackUserMessage,
              author: 'Voce',
              isAssistant: false,
              isPending: false,
            ),
          );
        }
        _messages.add(
          _ChatItem(
            text: fallbackAssistantReply,
            author: 'Assistente Inteligente',
            isAssistant: true,
            isPending: false,
          ),
        );
      });
    }
  }

  List<_ChatItem> _mapThreadMessages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final authorType = data['authorType']?.toString() ?? 'assistant';
      return _ChatItem(
        text: data['text']?.toString() ?? '',
        author: data['authorName']?.toString() ??
            (authorType == 'assistant' ? 'Assistente Inteligente' : 'Voce'),
        isAssistant: authorType == 'assistant',
        isPending: false,
      );
    }).toList();
  }

  void _openSupremeQueueSheet(Session session) {
    if (!hasSupremePlatformAccess(session) || _sending) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final h = MediaQuery.sizeOf(sheetContext).height;
        return Padding(
          padding: MediaQuery.viewInsetsOf(sheetContext),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.9),
            child: _SupremeAssistantQueueSheet(
              session: session,
              busy: _sending,
              onPickIdea: (data) {
                Navigator.of(sheetContext).pop();
                if (!mounted) {
                  return;
                }
                unawaited(
                  _sendPreparedPrompt(
                    _buildIdeaAnalysisPrompt(data),
                    clearComposer: false,
                  ),
                );
              },
              onPickIncident: (data) {
                Navigator.of(sheetContext).pop();
                if (!mounted) {
                  return;
                }
                unawaited(
                  _sendPreparedPrompt(
                    _buildIncidentAnalysisPrompt(data),
                    clearComposer: false,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

String _buildIdeaAnalysisPrompt(Map<String, dynamic> data) {
  return [
    'Analise esta ideia registrada no sistema e proponha acao objetiva.',
    'Titulo: ${data['title']?.toString() ?? '-'}',
    'Modulo: ${data['module']?.toString() ?? '-'}',
    'Prioridade: ${_feedbackPriorityLabel(data['priority']?.toString())}',
    'Status atual: ${_feedbackStatusLabel(data['status']?.toString())}',
    'Dor atual: ${data['context']?.toString() ?? '-'}',
    'Melhoria desejada: ${data['idea']?.toString() ?? '-'}',
    'Informacoes do usuario: ${data['userInfo']?.toString() ?? '-'}',
    'Responda com: 1) diagnostico, 2) risco operacional, 3) proxima acao recomendada no produto.',
  ].join('\n');
}

String _buildIncidentAnalysisPrompt(Map<String, dynamic> data) {
  final extra = data['extra'];
  return [
    'Analise este item da observabilidade e recomende tratamento.',
    'Mensagem: ${data['message']?.toString() ?? '-'}',
    'Categoria: ${data['category']?.toString() ?? '-'}',
    'Severidade: ${data['severity']?.toString() ?? '-'}',
    'Origem: ${data['source']?.toString() ?? '-'}',
    'Tela: ${data['screenLabel']?.toString() ?? '-'}',
    'Extra: ${extra is Map ? extra.toString() : '-'}',
    'Responda com: 1) causa provavel, 2) impacto, 3) acao recomendada e 4) se parece bug, configuracao ou melhoria.',
  ].join('\n');
}

String _incidentBodyPreview(Map<String, dynamic> data) {
  final extra = data['extra'];
  if (extra is Map && extra.isNotEmpty) {
    return extra.toString();
  }
  return data['screenLabel']?.toString() ?? 'Sem detalhes adicionais.';
}

String _feedbackStatusLabel(String? status) {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'planejado':
      return 'Planejado';
    case 'entregue':
      return 'Entregue';
    default:
      return 'Novo';
  }
}

String _feedbackPriorityLabel(String? priority) {
  switch ((priority ?? '').trim().toLowerCase()) {
    case 'critica':
      return 'Critica';
    case 'alta':
      return 'Alta';
    case 'baixa':
      return 'Baixa';
    default:
      return 'Media';
  }
}

class _SupremeAssistantQueueSheet extends StatelessWidget {
  const _SupremeAssistantQueueSheet({
    required this.session,
    required this.busy,
    required this.onPickIdea,
    required this.onPickIncident,
  });

  final Session session;
  final bool busy;
  final void Function(Map<String, dynamic> data) onPickIdea;
  final void Function(Map<String, dynamic> data) onPickIncident;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fila para o assistente',
                    style: TextStyle(
                      color: AppBrandColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Ideias e incidentes abertos. Toque em analisar para enfileirar pergunta ao assistente (o painel fecha e o envio acontece no chat abaixo).',
              style: TextStyle(
                color: AppBrandColors.softText,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('product_feedback')
                      .where('companyId', isEqualTo: session.companyId)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs =
                        (snapshot.data?.docs ??
                                const <QueryDocumentSnapshot<
                                  Map<String, dynamic>
                                >>[])
                            .toList(
                              growable: true,
                            )..sort((a, b) {
                              final aTime =
                                  (a.data()['updatedAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  (a.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              final bTime =
                                  (b.data()['updatedAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  (b.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              return bTime.compareTo(aTime);
                            });
                    return _AssistantFeedSection(
                      title: 'Ideias recentes',
                      emptyLabel: 'Nenhuma ideia recente para analisar.',
                      children: [
                        for (final doc in docs.take(4))
                          _AssistantFeedTile(
                            title: doc.data()['title']?.toString() ??
                                'Ideia sem titulo',
                            subtitle: [
                              doc.data()['module']?.toString() ?? 'Modulo',
                              _feedbackStatusLabel(
                                doc.data()['status']?.toString(),
                              ),
                              _feedbackPriorityLabel(
                                doc.data()['priority']?.toString(),
                              ),
                            ].join(' | '),
                            body:
                                'Dor: ${doc.data()['context']?.toString() ?? '-'}\nMelhoria: ${doc.data()['idea']?.toString() ?? '-'}',
                            buttonLabel: 'Analisar ideia',
                            enabled: !busy,
                            onPressed: () => onPickIdea(doc.data()),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('runtime_incidents')
                      .where('companyId', isEqualTo: session.companyId)
                      .where('status', isEqualTo: 'open')
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs =
                        (snapshot.data?.docs ??
                                const <QueryDocumentSnapshot<
                                  Map<String, dynamic>
                                >>[])
                            .toList(
                              growable: true,
                            )..sort((a, b) {
                              final aTime =
                                  (a.data()['updatedAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  (a.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              final bTime =
                                  (b.data()['updatedAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  (b.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              return bTime.compareTo(aTime);
                            });
                    return _AssistantFeedSection(
                      title: 'Observabilidade em aberto',
                      emptyLabel: 'Nenhum incidente em aberto para analisar.',
                      children: [
                        for (final doc in docs.take(4))
                          _AssistantFeedTile(
                            title: doc.data()['message']?.toString() ??
                                'Incidente',
                            subtitle: [
                              doc.data()['category']?.toString() ?? 'runtime',
                              doc.data()['severity']?.toString() ?? 'error',
                              doc.data()['source']?.toString() ?? 'app',
                            ].join(' | '),
                            body: _incidentBodyPreview(doc.data()),
                            buttonLabel: 'Analisar incidente',
                            enabled: !busy,
                            onPressed: () => onPickIncident(doc.data()),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantFeedSection extends StatelessWidget {
  const _AssistantFeedSection({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppBrandColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(color: AppBrandColors.softText),
          )
        else
          Column(children: children),
      ],
    );
  }
}

class _AssistantFeedTile extends StatelessWidget {
  const _AssistantFeedTile({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String body;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppBrandColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppBrandColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: enabled ? onPressed : null,
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantHistoryScreen extends StatelessWidget {
  const _AssistantHistoryScreen({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('assistant_threads')
            .where('createdByUid', isEqualTo: session.userId)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nao foi possivel carregar o historico agora.',
                style: TextStyle(color: AppBrandColors.softText),
              ),
            );
          }

          final threads =
              snapshot.data?.docs
                  .map(AssistantThread.fromSnapshot)
                  .where(
                    (item) =>
                        !item.archived &&
                        item.createdByUid == session.userId &&
                        item.companyId == session.companyId,
                  )
                  .toList(growable: true) ??
              <AssistantThread>[];
          threads.sort((a, b) {
            final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Historico de conversa',
                style: TextStyle(
                  color: AppBrandColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Somente as conversas deste login aparecem aqui. Toque em uma conversa para voltar ao dialogo com o assistente.',
                style: TextStyle(
                  color: AppBrandColors.softText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              if (threads.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nenhuma conversa deste login foi encontrada ainda.',
                    style: TextStyle(color: AppBrandColors.softText),
                  ),
                )
              else
                for (final thread in threads)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.go('/assistant?thread=${thread.id}'),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppBrandColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                thread.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppBrandColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (thread.lastMessagePreview.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  thread.lastMessagePreview,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                thread.updatedAt == null
                                    ? 'Sem data'
                                    : 'Atualizada em ${_formatThreadDate(thread.updatedAt!)}',
                                style: const TextStyle(
                                  color: AppBrandColors.softText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  String _formatThreadDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}

class _ChatItem {
  const _ChatItem({
    required this.text,
    required this.author,
    required this.isAssistant,
    required this.isPending,
    this.isError = false,
  });

  final String text;
  final String author;
  final bool isAssistant;
  final bool isPending;
  final bool isError;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.item});

  final _ChatItem item;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = item.isAssistant
        ? (item.isError ? const Color(0xFFFEF2F2) : Colors.white)
        : const Color(0xFF032A72);
    final textColor = item.isAssistant
        ? (item.isError ? const Color(0xFF991B1B) : AppBrandColors.ink)
        : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.isAssistant
              ? (item.isError ? const Color(0xFFFECACA) : AppBrandColors.border)
              : const Color(0xFF032A72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.author,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              item.text,
              style: TextStyle(height: 1.45, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAssistantState extends StatelessWidget {
  const _EmptyAssistantState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 42,
            color: Color(0xFF0F766E),
          ),
          SizedBox(height: 14),
          Text(
            'Pronto para a primeira pergunta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppBrandColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pergunte sobre uma funcionalidade do sistema para comecar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppBrandColors.softText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
