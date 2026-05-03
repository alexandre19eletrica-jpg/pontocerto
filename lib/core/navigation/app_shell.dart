import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/features/platform_admin/presentation/platform_admin_section.dart';
import 'package:pontocerto/core/navigation/shell_menu_scroll.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';

class AppShellScaffold extends StatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.title,
    required this.session,
    required this.body,
    this.actions,
    this.header,
  });

  final String title;
  final Session session;
  final Widget body;
  final List<Widget>? actions;
  final Widget? header;

  static const _items = <_ShellItem>[
    _ShellItem('Painel', '/home', Icons.dashboard_customize_outlined),
    _ShellItem(
      'Assistente',
      '/assistant',
      Icons.auto_awesome_outlined,
      group: _ShellGroup.assistant,
    ),
    _ShellItem('Ideias', '/improvements', Icons.lightbulb_outline_rounded),
    _ShellItem(
      'Empresas do contador',
      '/accountant-companies',
      Icons.domain_outlined,
    ),
    _ShellItem(
      'Perfil fiscal',
      '/accountant-fiscal-profile',
      Icons.verified_user_outlined,
    ),
    _ShellItem(
      'Declaracoes',
      '/accountant-declarations',
      Icons.account_balance_outlined,
    ),
    _ShellItem(
      'Cadastrar empresa',
      '/accountant-register-company',
      Icons.add_business_outlined,
    ),
    _ShellItem(
      'Seja nosso parceiro',
      '/accountant-partner',
      Icons.handshake_outlined,
    ),
    _ShellItem('Financeiro', '/finance', Icons.account_balance_wallet_outlined),
    _ShellItem('Fiscal', '/fiscal', Icons.receipt_long_outlined),
    _ShellItem('Trabalhista', '/workforce', Icons.groups_2_outlined),
    _ShellItem('Funcionarios', '/employees', Icons.badge_outlined),
    _ShellItem('Ponto', '/punch', Icons.punch_clock_outlined),
    _ShellItem('Justificativas', '/justifications', Icons.rule_folder_outlined),
    _ShellItem('Tarefas', '/tasks', Icons.assignment_turned_in_outlined),
    _ShellItem(
      'Ordens de servico',
      '/service-orders',
      Icons.build_circle_outlined,
    ),
    _ShellItem('Faturamento', '/billing', Icons.autorenew_outlined),
    _ShellItem('Clientes', '/clients', Icons.apartment_outlined),
    _ShellItem('Relatorios', '/reports', Icons.insert_chart_outlined),
    _ShellItem('Pagamentos', '/payments', Icons.payments_outlined),
    _ShellItem('Dividas', '/debts', Icons.request_quote_outlined),
    _ShellItem('Propostas', '/proposals', Icons.description_outlined),
    _ShellItem('Contratos', '/contracts', Icons.handshake_outlined),
    _ShellItem('Clausulas', '/contract-clauses', Icons.gavel_outlined),
    _ShellItem('Documentos', '/documents', Icons.description_outlined),
    _ShellItem('Catalogo', '/service-catalog', Icons.view_list_outlined),
    _ShellItem(
      'Plataforma',
      kPlatformAdminEscritoriosPath,
      Icons.hub_outlined,
      group: _ShellGroup.platformAdmin,
    ),
    _ShellItem('Observabilidade', '/runtime-incidents', Icons.sensors_outlined),
    _ShellItem('Materiais', '/materials', Icons.inventory_2_outlined),
    _ShellItem('Empresa', '/company', Icons.business_outlined),
    _ShellItem('Configuracoes', '/settings', Icons.settings_outlined),
    _ShellItem('Auditoria', '/audit', Icons.fact_check_outlined),
  ];

  /// Título padrão da app bar (menu lateral) a partir de [GoRouterState.matchedLocation].
  static String titleForPath(String matchedLocation) {
    if (matchedLocation.startsWith('/platform-admin')) {
      return 'Plataforma';
    }
    for (final item in _items) {
      if (matchedLocation == item.route) {
        return item.label;
      }
    }
    String? bestLabel;
    var bestLen = 0;
    for (final item in _items) {
      final r = item.route;
      if (matchedLocation.startsWith(r) &&
          (matchedLocation.length == r.length || matchedLocation[r.length] == '/')) {
        if (r.length >= bestLen) {
          bestLen = r.length;
          bestLabel = item.label;
        }
      }
    }
    return bestLabel ?? 'Ponto Certo';
  }

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  int _refreshEpoch = 0;
  late final FocusNode _bodyFocusNode;
  late final ScrollController _bodyScrollController;
  final GlobalKey _bodyContentKey = GlobalKey(debugLabel: 'shell_body_content');

  @override
  void initState() {
    super.initState();
    _bodyFocusNode = FocusNode(debugLabel: 'shell_body_focus');
    _bodyScrollController = ScrollController();
  }

  @override
  void dispose() {
    _bodyFocusNode.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePullToRefresh() async {
    if (!mounted) return;
    setState(() => _refreshEpoch++);
    GoRouter.of(context).refresh();
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }

  Future<void> _openRealAccessRoute() async {
    final targetRoute = widget.session.isDemoCompany
        ? '/cadastro-empresa'
        : '/cadastro-escritorio-contabil';
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    context.go(targetRoute);
  }

  ScrollPosition? _resolveBodyScrollPosition() {
    if (_bodyScrollController.hasClients) {
      return _bodyScrollController.position;
    }

    final context = _bodyContentKey.currentContext;
    if (context is! Element) {
      return null;
    }
    return _findScrollableDescendant(context)?.position;
  }

  ScrollableState? _findScrollableDescendant(Element element) {
    ScrollableState? result;

    void visit(Element current) {
      if (result != null) {
        return;
      }
      if (current is StatefulElement && current.state is ScrollableState) {
        result = current.state as ScrollableState;
        return;
      }
      current.visitChildren(visit);
    }

    element.visitChildren(visit);
    return result;
  }

  KeyEventResult _handleBodyKeyScroll(KeyEvent event) {
    final position = _resolveBodyScrollPosition();
    if (event is! KeyDownEvent || position == null) {
      return KeyEventResult.ignored;
    }

    const lineStep = 72.0;
    final viewportStep = position.viewportDimension * 0.85;

    double? targetOffset;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      targetOffset = (position.pixels + lineStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      targetOffset = (position.pixels - lineStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      targetOffset = (position.pixels + viewportStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      targetOffset = (position.pixels - viewportStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      targetOffset = position.minScrollExtent;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      targetOffset = position.maxScrollExtent;
    }

    if (targetOffset == null) {
      return KeyEventResult.ignored;
    }

    position.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = AppViewportInfo.of(context);
    final useRail = !viewport.usesDrawerNavigation;

    return Scaffold(
      drawer: useRail
          ? null
          : Drawer(
              backgroundColor: AppBrandColors.sidebar,
              surfaceTintColor: AppBrandColors.sidebar,
              child: SafeArea(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppBrandColors.sidebar,
                  ),
                  child: _ShellMenu(
                    session: widget.session,
                    currentRoute: GoRouterState.of(context).matchedLocation,
                    onTap: (route) {
                      Navigator.of(context).pop();
                      context.go(route);
                    },
                  ),
                ),
              ),
            ),
      appBar: useRail
          ? null
          : AppBar(
              automaticallyImplyLeading: true,
              toolbarHeight: 64,
              elevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              iconTheme: const IconThemeData(color: AppBrandColors.ink),
              title: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppBrandColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [...(widget.actions ?? const [])],
            ),
      body: Row(
        children: [
          if (useRail)
            SizedBox(
              width: 296,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppBrandColors.sidebar,
                  border: Border(
                    right: BorderSide(color: AppBrandColors.sidebarStrong),
                  ),
                ),
                child: SafeArea(
                  child: _ShellMenu(
                    session: widget.session,
                    currentRoute: GoRouterState.of(context).matchedLocation,
                    onTap: (route) => context.go(route),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  if (useRail && widget.header == null)
                    Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: AppBrandColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: AppBrandColors.ink,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                                Text(
                                  widget.session.nome,
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...?widget.actions,
                        ],
                      ),
                    ),
                  if (widget.header != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        useRail ? 20 : 14,
                        20,
                        0,
                      ),
                      child: useRail
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final actions = widget.actions ?? const <Widget>[];
                                final hasActions = actions.isNotEmpty;
                                final actionBar = !hasActions
                                    ? null
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: AppBrandColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [...actions],
                                        ),
                                      );
                                final narrow = constraints.maxWidth < 920;
                                if (narrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      widget.header!,
                                      if (actionBar != null) ...[
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: actionBar,
                                        ),
                                      ],
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: widget.header!),
                                    if (actionBar != null) ...[
                                      const SizedBox(width: 12),
                                      actionBar,
                                    ],
                                  ],
                                );
                              },
                            )
                          : widget.header,
                    ),
                  if (widget.session.isDemo)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD54F)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.isDemoCompany
                                ? 'Modo demo da empresa: leitura somente. Os dados exibidos representam a experiencia real do sistema, mas nenhuma alteracao e gravada.'
                                : 'Modo demo do contador: leitura somente. Os dados exibidos representam a experiencia real do sistema, mas nenhuma alteracao e gravada.',
                            style: const TextStyle(
                              color: AppBrandColors.ink,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openRealAccessRoute,
                            icon: const Icon(Icons.lock_open_outlined),
                            label: Text(
                              widget.session.isDemoCompany
                                  ? 'Ir para acesso real da empresa'
                                  : 'Ir para acesso real do contador',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppBrandColors.ink,
                              side: const BorderSide(color: Color(0xFFFFC107)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => _bodyFocusNode.requestFocus(),
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final position = _resolveBodyScrollPosition();
                          if (position == null) {
                            return;
                          }
                          final target =
                              (position.pixels + event.scrollDelta.dy).clamp(
                                position.minScrollExtent,
                                position.maxScrollExtent,
                              );
                          if ((target - position.pixels).abs() > 0.1) {
                            _bodyScrollController.jumpTo(target);
                          }
                        }
                      },
                      child: Focus(
                        autofocus: true,
                        focusNode: _bodyFocusNode,
                        onKeyEvent: (_, event) => _handleBodyKeyScroll(event),
                        child: PrimaryScrollController(
                          controller: _bodyScrollController,
                          automaticallyInheritForPlatforms: const {
                            TargetPlatform.android,
                            TargetPlatform.iOS,
                            TargetPlatform.macOS,
                            TargetPlatform.windows,
                            TargetPlatform.linux,
                            TargetPlatform.fuchsia,
                          },
                          child: RefreshIndicator.adaptive(
                            color: AppBrandColors.accent,
                            backgroundColor: Colors.white,
                            edgeOffset: useRail ? 8 : 0,
                            onRefresh: _handlePullToRefresh,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: KeyedSubtree(
                                key: _bodyContentKey,
                                child: KeyedSubtree(
                                  key: ValueKey(_refreshEpoch),
                                  child: SelectionArea(child: widget.body),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellMenu extends StatefulWidget {
  const _ShellMenu({
    required this.session,
    required this.currentRoute,
    required this.onTap,
  });

  final Session session;
  final String currentRoute;
  final ValueChanged<String> onTap;

  @override
  State<_ShellMenu> createState() => _ShellMenuState();
}

class _ShellMenuState extends State<_ShellMenu> {
  late final FocusNode _focusNode;
  /// Um controlador por instância: o global reutilizava [ScrollPosition]
  /// de [ListView] descartado e conflitava com restauração/offset.
  late final ScrollController _menuScroll;
  bool _assistantExpanded = false;
  bool _platformAdminExpanded = false;

  int _menuScrollRestoreTries = 0;
  /// Enquanto `false`, nao grava [appShellMenuLastScrollOffset] (o layout
  /// inicial em 0 apagava a posicao salva ao trocar de rota).
  bool _menuScrollSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _menuScroll = ScrollController(
      initialScrollOffset: appShellMenuLastScrollOffset,
    );
    _focusNode = FocusNode(debugLabel: 'shell_menu_focus');
    _assistantExpanded = widget.currentRoute == '/assistant';
    _platformAdminExpanded =
        widget.currentRoute.startsWith('/platform-admin');
    _menuScrollRestoreTries = 0;
    _menuScrollSaveEnabled = false;
    _scheduleMenuScrollRestore();
  }

  void _enableMenuScrollSaveAfterRestore() {
    if (!mounted) {
      return;
    }
    _menuScrollSaveEnabled = true;
  }

  void _captureMenuOffset() {
    appShellMenuCaptureOffsetFrom(_menuScroll);
  }

  /// Chama [_captureMenuOffset] e navega. Deve ser o unico
  /// caminho de navegacao a partir do menu, para a posicao nao cair
  /// para 0 ao fechar o drawer / destruir o [ListView] antes do [go].
  void _navigateTo(String route) {
    _captureMenuOffset();
    widget.onTap(route);
  }

  void _scheduleMenuScrollRestore() {
    const maxTries = 20;

    void tick() {
      if (!mounted) {
        return;
      }
      if (!_menuScroll.hasClients) {
        if (_menuScrollRestoreTries < maxTries) {
          _menuScrollRestoreTries++;
          WidgetsBinding.instance.addPostFrameCallback((_) => tick());
        } else {
          _enableMenuScrollSaveAfterRestore();
        }
        return;
      }
      final p = _menuScroll.position;
      if (p.maxScrollExtent <= 0 && appShellMenuLastScrollOffset > 0) {
        if (_menuScrollRestoreTries < maxTries) {
          _menuScrollRestoreTries++;
          WidgetsBinding.instance.addPostFrameCallback((_) => tick());
        } else {
          _enableMenuScrollSaveAfterRestore();
        }
        return;
      }
      final target = appShellMenuLastScrollOffset
          .clamp(p.minScrollExtent, p.maxScrollExtent);
      if ((p.pixels - target).abs() > 1) {
        _menuScroll.jumpTo(target);
      }
      if (_menuScroll.hasClients) {
        appShellMenuLastScrollOffset = _menuScroll.offset;
      }
      // Depois de aplicar a posicao, o proximo frame ja reflete o scroll
      // real; so entao permitimos que notificacoes voltem a persistir.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _enableMenuScrollSaveAfterRestore();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  @override
  void dispose() {
    _captureMenuOffset();
    _menuScroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyScroll(KeyEvent event) {
    if (event is! KeyDownEvent || !_menuScroll.hasClients) {
      return KeyEventResult.ignored;
    }

    final position = _menuScroll.position;
    const lineStep = 72.0;
    final viewportStep = position.viewportDimension * 0.85;

    double? targetOffset;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      targetOffset = (position.pixels + lineStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      targetOffset = (position.pixels - lineStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      targetOffset = (position.pixels + viewportStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      targetOffset = (position.pixels - viewportStep).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      targetOffset = position.minScrollExtent;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      targetOffset = position.maxScrollExtent;
    }

    if (targetOffset == null) {
      return KeyEventResult.ignored;
    }

    _menuScroll.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final items = AppShellScaffold._items
        .where(
          (item) =>
              canAccessRoute(widget.session.role, item.route) &&
              _canSeePrivilegedItem(widget.session, item.route),
        )
        .toList();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _focusNode.requestFocus(),
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: (_, event) => _handleKeyScroll(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF1E3A8A),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ponto Certo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Painel administrativo',
                          style: TextStyle(color: AppBrandColors.sidebarMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppBrandColors.sidebarStrong,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2B5C89)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.session.role == Role.employee
                          ? 'Acesso de funcionario'
                          : widget.session.companyId,
                      style: const TextStyle(
                        color: AppBrandColors.sidebarMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification n) {
                  if (_menuScrollSaveEnabled && n.metrics.axis == Axis.vertical) {
                    appShellMenuLastScrollOffset = n.metrics.pixels;
                  }
                  return false;
                },
                child: Scrollbar(
                  controller: _menuScroll,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  radius: const Radius.circular(999),
                  child: ListView(
                    primary: false,
                    controller: _menuScroll,
                    padding: const EdgeInsets.fromLTRB(12, 0, 10, 20),
                    children: [
                    for (final item in items)
                      if (item.group == _ShellGroup.assistant)
                        _AssistantShellGroup(
                          item: item,
                          session: widget.session,
                          selected: widget.currentRoute == item.route,
                          expanded:
                              _assistantExpanded ||
                              widget.currentRoute == '/assistant',
                          onTap: () {
                            _captureMenuOffset();
                            setState(() => _assistantExpanded = true);
                            widget.onTap(item.route);
                          },
                          onHistoryTap: () => _navigateTo(
                            '/assistant?history=1',
                          ),
                          onToggleExpanded: () {
                            setState(
                              () => _assistantExpanded = !_assistantExpanded,
                            );
                          },
                        )
                      else if (item.group == _ShellGroup.platformAdmin)
                        _PlatformAdminShellGroup(
                          item: item,
                          currentRoute: widget.currentRoute,
                          selected:
                              widget.currentRoute.startsWith('/platform-admin'),
                          expanded: _platformAdminExpanded ||
                              widget.currentRoute
                                  .startsWith('/platform-admin'),
                          onTap: () {
                            _captureMenuOffset();
                            setState(() => _platformAdminExpanded = true);
                            widget.onTap(kPlatformAdminEscritoriosPath);
                          },
                          onToggleExpanded: () {
                            setState(
                              () => _platformAdminExpanded =
                                  !_platformAdminExpanded,
                            );
                          },
                          onSubRoute: _navigateTo,
                        )
                      else
                        _ShellTile(
                          item: item,
                          selected: widget.currentRoute == item.route,
                          onTap: () => _navigateTo(item.route),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSeePrivilegedItem(Session session, String route) {
    if (route == kPlatformAdminEscritoriosPath) {
      return canAccessPlatformAdminRoute(session);
    }
    if (route == '/runtime-incidents') {
      return hasSupremePlatformAccess(session);
    }
    return true;
  }
}

class _ShellTile extends StatelessWidget {
  const _ShellTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ShellItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppBrandColors.sidebarStrong : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? Colors.white : AppBrandColors.sidebarMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppBrandColors.sidebarSoft,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantShellGroup extends StatelessWidget {
  const _AssistantShellGroup({
    required this.item,
    required this.session,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.onHistoryTap,
    required this.onToggleExpanded,
  });

  final _ShellItem item;
  final Session session;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? AppBrandColors.sidebarStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: selected
                          ? Colors.white
                          : AppBrandColors.sidebarMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppBrandColors.sidebarSoft,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: selected
                            ? Colors.white
                            : AppBrandColors.sidebarMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4, bottom: 8),
            child: _AssistantHistoryEntry(
              selected:
                  GoRouterState.of(context).uri.queryParameters['history'] ==
                  '1',
              onTap: onHistoryTap,
            ),
          ),
      ],
    );
  }
}

class _PlatformAdminShellGroup extends StatelessWidget {
  const _PlatformAdminShellGroup({
    required this.item,
    required this.currentRoute,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.onToggleExpanded,
    required this.onSubRoute,
  });

  final _ShellItem item;
  final String currentRoute;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSubRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? AppBrandColors.sidebarStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: selected
                          ? Colors.white
                          : AppBrandColors.sidebarMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppBrandColors.sidebarSoft,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: selected
                            ? Colors.white
                            : AppBrandColors.sidebarMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded) ...[
          _PlatformAdminSubEntry(
            label: 'Escritorios',
            selected: currentRoute == kPlatformAdminEscritoriosPath,
            onTap: () => onSubRoute(kPlatformAdminEscritoriosPath),
          ),
          _PlatformAdminSubEntry(
            label: 'Convidar',
            selected: currentRoute == kPlatformAdminConvidarPath,
            onTap: () => onSubRoute(kPlatformAdminConvidarPath),
          ),
          _PlatformAdminSubEntry(
            label: 'Financeiro (plataforma)',
            selected: currentRoute == kPlatformAdminFinanceiroPath,
            onTap: () => onSubRoute(kPlatformAdminFinanceiroPath),
          ),
          _PlatformAdminSubEntry(
            label: 'Integracoes',
            selected: currentRoute == kPlatformAdminIntegracoesPath,
            onTap: () => onSubRoute(kPlatformAdminIntegracoesPath),
          ),
        ],
      ],
    );
  }
}

class _PlatformAdminSubEntry extends StatelessWidget {
  const _PlatformAdminSubEntry({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4, bottom: 8),
      child: Material(
        color: selected
            ? AppBrandColors.sidebarStrong
            : const Color(0xFF12324E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantHistoryEntry extends StatelessWidget {
  const _AssistantHistoryEntry({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppBrandColors.sidebarStrong
            : const Color(0xFF12324E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Historico de conversa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceHeader extends StatelessWidget {
  const AppWorkspaceHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.chips = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compactHeader = width < 640;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compactHeader ? 16 : 22,
        compactHeader ? 16 : 20,
        compactHeader ? 16 : 22,
        compactHeader ? 16 : 20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppBrandColors.ink,
              fontSize: compactHeader ? 20 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: AppBrandColors.softText,
              height: 1.45,
              fontSize: compactHeader ? 13 : 14,
            ),
            maxLines: compactHeader ? 4 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: chips),
          ],
        ],
      ),
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(220.0, 320.0).toDouble()
                : 260.0;
        return Container(
          width: targetWidth,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFEFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD6E1EA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  color: AppBrandColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 6),
                Text(
                  caption!,
                  style: const TextStyle(color: AppBrandColors.softText),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _ShellGroup { none, assistant, platformAdmin }

class _ShellItem {
  const _ShellItem(
    this.label,
    this.route,
    this.icon, {
    this.group = _ShellGroup.none,
  });

  final String label;
  final String route;
  final IconData icon;
  final _ShellGroup group;
}
