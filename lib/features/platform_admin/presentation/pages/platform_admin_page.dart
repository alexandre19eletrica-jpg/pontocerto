import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/constants/public_campaign_routes.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/replace_trailing_paste_text_input_formatter.dart';
import 'package:pontocerto/core/utils/trial_invite_bulk_parser.dart';
import 'package:pontocerto/features/finance/presentation/utils/money.dart';
import 'package:pontocerto/features/governance_engineering/presentation/pages/engineering_agent_page.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_demo_config_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_sales_config_service.dart';
import 'package:pontocerto/features/platform_admin/presentation/platform_admin_section.dart';
import 'package:pontocerto/features/platform_admin/presentation/widgets/governance/governance_bulk_email_panel.dart';
import 'package:pontocerto/features/platform_admin/presentation/widgets/governance/governance_hub.dart';
import 'package:pontocerto/features/platform_admin/presentation/services/platform_admin_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/ui/shell_selection_guard.dart';

class PlatformAdminPage extends ConsumerStatefulWidget {
  const PlatformAdminPage({
    super.key,
    required this.section,
    this.governancePanel,
  });

  final PlatformAdminSection section;
  final String? governancePanel;

  @override
  ConsumerState<PlatformAdminPage> createState() => _PlatformAdminPageState();
}

class _PlatformAdminPageState extends ConsumerState<PlatformAdminPage> {
  static const String salesPageWebUrl = 'https://pontocerto-e1dab.web.app/';
  final _service = PlatformAdminService();
  final _publicSalesConfigService = PublicSalesConfigService();
  final _publicDemoConfigService = PublicDemoConfigService();
  final _trialCompanyEmail = TextEditingController();
  final _trialCompanyName = TextEditingController();
  final _trialCompanyCnpj = TextEditingController();
  final _trialCompanyOpenedAt = TextEditingController();
  final _trialAccountantEmail = TextEditingController();
  final _trialAccountantName = TextEditingController();
  bool _issuingTrial = false;
  IssuedTrialInvite? _lastTrialInvite;
  String? _selectedTrialCompanyId;
  bool _extendingTrial = false;
  late Future<List<TrialInviteSummary>> _trialInvitesFuture;
  final Set<String> _selectedInviteIds = <String>{};
  bool _inviteSelectionMode = false;
  bool _deletingInvites = false;
  bool _purgingDeletedInvites = false;
  List<BulkInviteRow> _bulkReadyRows = [];
  List<BulkInviteRow> _bulkPendingRows = [];
  final List<DateTime> _bulkRecentInviteSends = [];
  DateTime? _bulkNextWaveUnlockedAt;
  Timer? _bulkCountdownTimer;
  List<String> _bulkSkipped = [];
  String? _bulkHint;
  String? _bulkFileName;
  bool _bulkSending = false;
  late Future<List<PlatformCompanySummary>> _future;
  late Future<PublicSalesConfig> _publicSalesConfigFuture;
  late Future<PublicDemoConfig> _publicDemoConfigFuture;
  late Future<PlatformSalesPipelineSnapshot> _salesPipelineFuture;
  late Future<PlatformMarketingDashboard> _marketingDashboardFuture;
  late Future<List<PlatformAccountingOfficeSummary>> _accountingOfficesFuture;
  Future<List<StandaloneLightweightCompanyRow>>? _standaloneLightFuture;
  Future<List<PublicDemoAccessLedgerRow>>? _demoLedgerFuture;
  Future<List<StandaloneLightweightOfficeRow>>? _lightweightOfficesFuture;
  Future<GovernanceRealRegistrationsResult>? _realRegistrationsFuture;
  Future<PlatformFiscalCompanyStatus>? _fiscalStatusFuture;
  String? _selectedCompanyId;
  String? _selectedAdminOfficeId;
  bool _officeActionBusy = false;
  final _accountingOfficeSearchEmail = TextEditingController();
  final _supremeGovCompanyId = TextEditingController();
  final _supremeGovOfficeId = TextEditingController();
  bool _supremeGovBusy = false;
  final Set<String> _governanceActionBusyCompanies = <String>{};

  Future<List<PlatformAccountingOfficeSummary>>
  _listAccountingOfficesWithSearch() {
    final q = _accountingOfficeSearchEmail.text.trim();
    return _service.listAccountingOffices(searchEmail: q.isEmpty ? null : q);
  }

  void _primeGovernanceFutures() {
    if (widget.section == PlatformAdminSection.governanca) {
      _standaloneLightFuture = _service.listStandaloneLightweightCompanies();
      _demoLedgerFuture = _service.listPublicDemoAccessLedger(limit: 200);
      _lightweightOfficesFuture = _service.listLightweightTestOffices();
      _realRegistrationsFuture = _service.listGovernanceRealRegistrations();
    } else {
      _standaloneLightFuture = null;
      _demoLedgerFuture = null;
      _lightweightOfficesFuture = null;
      _realRegistrationsFuture = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _primeGovernanceFutures();
    if (widget.section == PlatformAdminSection.governanca ||
        widget.section == PlatformAdminSection.engineeringAgent) {
      _future = Future.value(const <PlatformCompanySummary>[]);
    } else {
      _future = _load();
    }
    _publicSalesConfigFuture = _publicSalesConfigService.fetch();
    _publicDemoConfigFuture = _publicDemoConfigService.fetch();
    _salesPipelineFuture = _service.listSalesPipeline();
    _marketingDashboardFuture = _service.getMarketingDashboard();
    _trialInvitesFuture = _service.listTrialInvites(limit: 80);
    _accountingOfficesFuture = _listAccountingOfficesWithSearch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final companyQ = GoRouterState.of(
      context,
    ).uri.queryParameters['company']?.trim();
    if (companyQ == null || companyQ.isEmpty) {
      return;
    }
    if (widget.section != PlatformAdminSection.financeiro &&
        widget.section != PlatformAdminSection.integracoes) {
      return;
    }
    if (companyQ == _selectedCompanyId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedCompanyId = companyQ;
        _fiscalStatusFuture = widget.section == PlatformAdminSection.integracoes
            ? _service.getCompanyFiscalStatus(companyId: companyQ)
            : null;
      });
    });
  }

  @override
  void didUpdateWidget(covariant PlatformAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _primeGovernanceFutures();
      if (widget.section == PlatformAdminSection.governanca ||
          widget.section == PlatformAdminSection.engineeringAgent) {
        _future = Future.value(const <PlatformCompanySummary>[]);
      } else if (oldWidget.section == PlatformAdminSection.governanca ||
          oldWidget.section == PlatformAdminSection.engineeringAgent) {
        _future = _load();
      }
    }
    if (oldWidget.section != widget.section) {
      if (widget.section == PlatformAdminSection.integracoes &&
          _selectedCompanyId != null &&
          _selectedCompanyId!.isNotEmpty) {
        setState(() {
          _fiscalStatusFuture = _service.getCompanyFiscalStatus(
            companyId: _selectedCompanyId!,
          );
        });
      } else if (widget.section == PlatformAdminSection.financeiro) {
        setState(() {
          _fiscalStatusFuture = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _bulkCountdownTimer?.cancel();
    _trialCompanyEmail.dispose();
    _trialCompanyName.dispose();
    _trialCompanyCnpj.dispose();
    _trialCompanyOpenedAt.dispose();
    _trialAccountantEmail.dispose();
    _trialAccountantName.dispose();
    _accountingOfficeSearchEmail.dispose();
    _supremeGovCompanyId.dispose();
    _supremeGovOfficeId.dispose();
    super.dispose();
  }

  Future<void> _issueTrialInvite() async {
    if (_issuingTrial) return;
    final companyEmail = _trialCompanyEmail.text.trim().toLowerCase();
    final accountantEmail = _trialAccountantEmail.text.trim().toLowerCase();
    if (accountantEmail.isEmpty || !accountantEmail.contains('@')) {
      if (context.mounted) {
        context.showUserMessage('Informe o email do contador.');
      }
      return;
    }

    setState(() => _issuingTrial = true);
    try {
      final invite = await _service.issueTrialInvite90Days(
        companyEmail: companyEmail.isEmpty ? null : companyEmail,
        accountantEmail: accountantEmail,
        companyName: _trialCompanyName.text.trim(),
        accountantName: _trialAccountantName.text.trim(),
        companyCnpj: _trialCompanyCnpj.text.trim().isEmpty
            ? null
            : _trialCompanyCnpj.text.trim(),
        companyOpenedAt: _trialCompanyOpenedAt.text.trim().isEmpty
            ? null
            : _trialCompanyOpenedAt.text.trim(),
      );
      if (!mounted) return;
      setState(() => _lastTrialInvite = invite);
      await Clipboard.setData(ClipboardData(text: invite.inviteUrl));
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage('Convite emitido e link copiado.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      if (mounted) setState(() => _issuingTrial = false);
    }
  }

  void _pruneHourlyBulkSends() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _bulkRecentInviteSends.removeWhere((item) => item.isBefore(cutoff));
  }

  int _bulkHourlyRoom() {
    _pruneHourlyBulkSends();
    final left =
        kTitanBulkMaxInvitesPerRollingHour - _bulkRecentInviteSends.length;
    return left < 0 ? 0 : left;
  }

  void _startBulkCountdownTimerIfNeeded() {
    _bulkCountdownTimer?.cancel();
    final needTimer =
        _bulkPendingRows.isNotEmpty || _bulkNextWaveUnlockedAt != null;
    if (!needTimer) return;
    _bulkCountdownTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _pruneHourlyBulkSends();
      final stillNeeded =
          _bulkPendingRows.isNotEmpty ||
          (_bulkNextWaveUnlockedAt != null &&
              DateTime.now().isBefore(_bulkNextWaveUnlockedAt!));
      if (!stillNeeded) {
        _bulkCountdownTimer?.cancel();
        _bulkCountdownTimer = null;
        return;
      }
      setState(() {});
    });
  }

  String? _bulkCooldownLabel() {
    final unlockAt = _bulkNextWaveUnlockedAt;
    if (unlockAt == null) return null;
    final delta = unlockAt.difference(DateTime.now());
    if (delta.isNegative) return null;
    final minutes = delta.inMinutes;
    final seconds = delta.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Future<void> _pickBulkTrialList() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'csv',
        'txt',
        'tsv',
        'lst',
        'xlsx',
        'xls',
        'pdf',
      ],
      withData: true,
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty) return;
    final file = pick.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError('Nao foi possivel ler o arquivo selecionado.');
      }
      return;
    }

    final parsed = parseTrialInviteBulkFile(bytes: bytes, fileName: file.name);
    final rows = List<BulkInviteRow>.from(parsed.rows);
    final ready = rows.length <= kTitanBulkWaveMaxInvites
        ? List<BulkInviteRow>.from(rows)
        : rows.sublist(0, kTitanBulkWaveMaxInvites);
    final pending = rows.length <= kTitanBulkWaveMaxInvites
        ? <BulkInviteRow>[]
        : rows.sublist(kTitanBulkWaveMaxInvites);
    final skipped = List<String>.from(parsed.skipped);
    if (pending.isNotEmpty) {
      skipped.add(
        '${pending.length} convite(s) ficaram em Pendente; a leva imediata respeita o limite de $kTitanBulkWaveMaxInvites por rodada.',
      );
    }

    if (!mounted) return;
    setState(() {
      _bulkFileName = file.name;
      _bulkReadyRows = ready;
      _bulkPendingRows = pending;
      _bulkSkipped = skipped;
      _bulkHint = parsed.hint;
      _bulkNextWaveUnlockedAt = null;
      _bulkSending = false;
    });
    _startBulkCountdownTimerIfNeeded();
    if (context.mounted) {
      context.showUserMessage(
        rows.isEmpty
            ? 'Nenhuma linha valida encontrada no arquivo.'
            : 'Leva pronta: ${ready.length}. Pendente: ${pending.length}.',
      );
    }
  }

  void _clearBulkList() {
    _bulkCountdownTimer?.cancel();
    _bulkCountdownTimer = null;
    setState(() {
      _bulkReadyRows = [];
      _bulkPendingRows = [];
      _bulkSkipped = [];
      _bulkHint = null;
      _bulkFileName = null;
      _bulkNextWaveUnlockedAt = null;
      _bulkRecentInviteSends.clear();
      _bulkSending = false;
    });
  }

  void _removeBulkReadyRow(int index) {
    if (index < 0 || index >= _bulkReadyRows.length) return;
    setState(() {
      _bulkReadyRows = List<BulkInviteRow>.from(_bulkReadyRows)
        ..removeAt(index);
    });
  }

  void _promotePendingWave() {
    if (_bulkSending) return;
    final unlockAt = _bulkNextWaveUnlockedAt;
    final now = DateTime.now();
    if (unlockAt != null && now.isBefore(unlockAt)) {
      final left = unlockAt.difference(now);
      if (context.mounted) {
        context.showUserMessage(
          'Aguarde ${left.inMinutes}m antes de liberar a proxima leva.',
        );
      }
      return;
    }
    _pruneHourlyBulkSends();
    final room = _bulkHourlyRoom();
    if (room < 1) {
      if (context.mounted) {
        context.showUserError(
          'Limite horario de convites atingido. Aguarde a janela de 1 hora.',
        );
      }
      return;
    }
    if (_bulkPendingRows.isEmpty) return;

    final size = [
      kTitanBulkWaveMaxInvites,
      room,
      _bulkPendingRows.length,
    ].reduce((a, b) => a < b ? a : b);
    setState(() {
      _bulkReadyRows = [
        ..._bulkReadyRows,
        ..._bulkPendingRows.sublist(0, size),
      ];
      _bulkPendingRows = _bulkPendingRows.sublist(size);
      _bulkNextWaveUnlockedAt = null;
    });
    _startBulkCountdownTimerIfNeeded();
    if (context.mounted) {
      context.showUserMessage('$size convite(s) movidos para a leva pronta.');
    }
  }

  Future<void> _sendBulkTrialInvites() async {
    if (_bulkSending || _bulkReadyRows.isEmpty) return;
    _pruneHourlyBulkSends();
    final room = _bulkHourlyRoom();
    if (room < 1) {
      if (context.mounted) {
        context.showUserError(
          'Limite horario de convites atingido para esta leva.',
        );
      }
      return;
    }

    final batch = List<BulkInviteRow>.from(_bulkReadyRows);
    final size = batch.length < room ? batch.length : room;
    final toSend = batch.sublist(0, size);
    final remainder = batch.sublist(size);

    setState(() {
      _bulkSending = true;
      _bulkReadyRows = remainder;
    });

    var sent = 0;
    final failures = <String>[];
    final failedRows = <BulkInviteRow>[];

    for (var i = 0; i < toSend.length; i++) {
      final row = toSend[i];
      try {
        await _service.issueTrialInvite90Days(
          companyEmail: row.companyEmail,
          accountantEmail: row.accountantEmail,
          companyName: row.companyName,
          accountantName: row.accountantName,
          companyCnpj: row.companyCnpj,
          companyOpenedAt: row.companyOpenedAt,
        );
        sent++;
        _bulkRecentInviteSends.add(DateTime.now());
      } catch (error) {
        failures.add(
          '${row.companyEmail} -> ${row.accountantEmail}: ${AppErrorMapper.messageFrom(error)}',
        );
        failedRows.add(row);
      }
      if (i < toSend.length - 1) {
        await Future<void>.delayed(
          const Duration(seconds: kTitanBulkMinSecondsBetweenInvites),
        );
      }
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() {
      _bulkSending = false;
      _bulkReadyRows = [...failedRows, ..._bulkReadyRows];
      if (sent > 0 && _bulkPendingRows.isNotEmpty) {
        _bulkNextWaveUnlockedAt = DateTime.now().add(
          const Duration(minutes: kTitanBulkCooldownMinutesAfterWave),
        );
      } else if (sent > 0 &&
          _bulkPendingRows.isEmpty &&
          _bulkReadyRows.isEmpty &&
          failedRows.isEmpty) {
        _bulkFileName = null;
        _bulkSkipped = [];
        _bulkHint = null;
        _bulkNextWaveUnlockedAt = null;
        _bulkCountdownTimer?.cancel();
        _bulkCountdownTimer = null;
      }
    });
    _startBulkCountdownTimerIfNeeded();
    _reload();

    final message = StringBuffer('Enviados nesta leva: $sent');
    if (failures.isNotEmpty) {
      message.write(' | Falhas: ${failures.length}');
    }
    if (_bulkPendingRows.isNotEmpty && sent > 0) {
      message.write(
        ' | Proxima leva liberada em cerca de $kTitanBulkCooldownMinutesAfterWave min.',
      );
    }
    if (context.mounted) {
      context.showUserMessage(message.toString());
    }

    if (failures.isNotEmpty && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Falhas no envio em massa'),
          content: SingleChildScrollView(child: Text(failures.join('\n'))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  Future<List<PlatformCompanySummary>> _load() async {
    final items = await _service.listCompanies();
    items.sort((a, b) => a.companyName.compareTo(b.companyName));
    if (items.isNotEmpty && !_containsCompany(items, _selectedCompanyId)) {
      _selectedCompanyId = items.first.companyId;
    }
    final companyId = _selectedCompanyId;
    if (companyId != null && companyId.isNotEmpty) {
      _fiscalStatusFuture = _service.getCompanyFiscalStatus(
        companyId: companyId,
      );
    }
    return items;
  }

  int _daysUntil(String iso) {
    if (iso.trim().isEmpty) return 0;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return 0;
    final delta = parsed.difference(DateTime.now());
    return delta.inDays;
  }

  String _billingStatusLabel(String raw) => platformBillingStatusLabel(raw);
  String _accessLabel(bool allowLogin) => platformAccessLabel(allowLogin);

  Future<void> _extendTrial({
    required String companyId,
    required int extraDays,
  }) async {
    if (_extendingTrial) return;
    setState(() => _extendingTrial = true);
    try {
      await _service.extendCompanyTrial(
        companyId: companyId,
        extraDays: extraDays,
      );
      if (!mounted) return;
      _reload();
      if (!mounted) return;
      if (context.mounted) {
        context.showUserSuccess('Trial estendido em +$extraDays dias.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      if (mounted) setState(() => _extendingTrial = false);
    }
  }

  Future<void> _deleteTrialInvites(List<String> ids) async {
    if (_deletingInvites) return;
    final normalized = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return;
    setState(() => _deletingInvites = true);
    try {
      await _service.deleteTrialInvites(inviteIds: normalized);
      if (!mounted) return;
      _selectedInviteIds.removeWhere((id) => normalized.contains(id));
      _trialInvitesFuture = _service.listTrialInvites(limit: 80);
      if (context.mounted) {
        context.showUserMessage('Convites excluidos: ${normalized.length}.');
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      if (mounted) setState(() => _deletingInvites = false);
    }
  }

  Future<void> _purgeDeletedTrialInvites(List<String> ids) async {
    if (_purgingDeletedInvites) return;
    final normalized = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return;
    setState(() => _purgingDeletedInvites = true);
    try {
      await _service.purgeDeletedTrialInvites(inviteIds: normalized);
      if (!mounted) return;
      _selectedInviteIds.removeWhere((id) => normalized.contains(id));
      _trialInvitesFuture = _service.listTrialInvites(limit: 80);
      if (context.mounted) {
        context.showUserMessage(
          'Excluidos removidos definitivamente: ${normalized.length}.',
        );
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      if (mounted) setState(() => _purgingDeletedInvites = false);
    }
  }

  void _selectCompanyInAdminPanel(String companyId) {
    if (companyId.trim().isEmpty) return;
    final uri = Uri(
      path: kPlatformAdminFinanceiroPath,
      queryParameters: <String, String>{'company': companyId},
    );
    context.go(uri.toString());
  }

  Future<void> _reconcileAdminOfficeInvite(
    PlatformAccountingOfficeSummary office,
  ) async {
    if (_officeActionBusy) return;
    setState(() => _officeActionBusy = true);
    try {
      final r = await _service.reconcileAccountingOfficeTrialInvite(
        officeId: office.officeId,
      );
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage(
          r.updated > 0
              ? 'Convites vinculados ao escritorio: ${r.updated}.'
              : (r.message.isNotEmpty
                    ? r.message
                    : 'Nada a reconciliar para este email.'),
        );
      }
      setState(() {
        _accountingOfficesFuture = _listAccountingOfficesWithSearch();
        _trialInvitesFuture = _service.listTrialInvites(limit: 80);
      });
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      if (mounted) setState(() => _officeActionBusy = false);
    }
  }

  Future<void> _promptAndSetAdminOfficeAccess({
    required PlatformAccountingOfficeSummary office,
    required bool allowAccess,
  }) async {
    if (_officeActionBusy) return;
    if (!allowAccess) {
      final reasonCtrl = TextEditingController();
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Suspender acesso do escritorio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informe o motivo administrativo (obrigatorio).'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Suspender'),
                ),
              ],
            );
          },
        );
        if (ok != true || !mounted) return;
        if (reasonCtrl.text.trim().isEmpty) {
          if (mounted) {
            if (context.mounted) {
              context.showUserMessage('Motivo e obrigatorio.');
            }
          }
          return;
        }
        setState(() => _officeActionBusy = true);
        await _service.setAccountingOfficeAccess(
          officeId: office.officeId,
          allowAccess: false,
          reason: reasonCtrl.text.trim(),
        );
        if (!mounted) return;
        if (context.mounted) {
          context.showUserMessage(
            'Acesso do contador suspenso (login bloqueado).',
          );
        }
        setState(
          () => _accountingOfficesFuture = _listAccountingOfficesWithSearch(),
        );
      } catch (error) {
        if (!mounted) return;
        if (context.mounted) {
          context.showUserError(AppErrorMapper.messageFrom(error));
        }
      } finally {
        reasonCtrl.dispose();
        if (mounted) setState(() => _officeActionBusy = false);
      }
      return;
    }

    setState(() => _officeActionBusy = true);
    try {
      await _service.setAccountingOfficeAccess(
        officeId: office.officeId,
        allowAccess: true,
      );
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage(
          'Acesso reativado para contadores do escritorio.',
        );
      }
      setState(
        () => _accountingOfficesFuture = _listAccountingOfficesWithSearch(),
      );
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      if (mounted) setState(() => _officeActionBusy = false);
    }
  }

  void _reloadGovernance() {
    setState(() {
      if (widget.section != PlatformAdminSection.governanca) {
        return;
      }
      _standaloneLightFuture =
          _service.listStandaloneLightweightCompanies();
      _demoLedgerFuture = _service.listPublicDemoAccessLedger(limit: 200);
      _lightweightOfficesFuture = _service.listLightweightTestOffices();
      _realRegistrationsFuture = _service.listGovernanceRealRegistrations();
      _marketingDashboardFuture = _service.getMarketingDashboard();
    });
  }

  Future<void> _runSupremeGov(Future<void> Function() action) async {
    if (_supremeGovBusy) return;
    setState(() => _supremeGovBusy = true);
    try {
      await action();
      _reloadGovernance();
    } catch (e) {
      if (mounted) {
        context.showUserError(AppErrorMapper.messageFrom(e));
      }
    } finally {
      if (mounted) setState(() => _supremeGovBusy = false);
    }
  }

  Future<void> _confirmSupremeDeleteCompany() async {
    final id = _supremeGovCompanyId.text.trim();
    if (id.isEmpty) {
      context.showUserMessage('Informe o companyId.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir empresa?'),
        content: Text(
          'Remove company_settings, utilizadores da empresa e vinculos contador no Firestore, '
          'e apaga os utilizadores no Firebase Auth. Irreversivel.\n\n$id',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runSupremeGov(() async {
      await _service.supremeDeleteCompany(companyId: id);
      if (mounted) context.showUserMessage('Empresa removida.');
    });
  }

  Future<void> _confirmSupremeDeleteOffice() async {
    final id = _supremeGovOfficeId.text.trim();
    if (id.isEmpty) {
      context.showUserMessage('Informe o officeId.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir escritorio?'),
        content: Text(
          'Exige carteira vazia no servidor. Remove o escritorio e contadores '
          'ligados (Auth + Firestore). Irreversivel.\n\n$id',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runSupremeGov(() async {
      await _service.supremeDeleteOffice(officeId: id);
      if (mounted) context.showUserMessage('Escritorio removido.');
    });
  }

  Widget _buildSupremeGovernanceCommandsCard() {
    return AppWorkspaceCard(
      title: 'Comandos supremos',
      subtitle:
          'Somente dono da empresa suprema. Ativar/desativar login (company_settings), '
          'suspender/liberar escritorio, ou exclusao administrativa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_supremeGovBusy)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          const Text(
            'Empresa',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _supremeGovCompanyId,
            decoration: const InputDecoration(
              labelText: 'companyId',
              hintText: 'comp_...',
            ),
          ),
          const SizedBox(height: 10),
          shellTapFriendly(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _supremeGovBusy
                      ? null
                      : () => _runSupremeGov(() async {
                            final cid = _supremeGovCompanyId.text.trim();
                            if (cid.isEmpty) {
                              context.showUserMessage('Informe o companyId.');
                              return;
                            }
                            await _service.supremeSetCompanyAllowLogin(
                              companyId: cid,
                              allowLogin: true,
                            );
                            if (mounted) {
                              context.showUserMessage(
                                'Login da empresa ativado.',
                              );
                            }
                          }),
                  child: const Text('Ativar login'),
                ),
                FilledButton.tonal(
                  onPressed: _supremeGovBusy
                      ? null
                      : () => _runSupremeGov(() async {
                            final cid = _supremeGovCompanyId.text.trim();
                            if (cid.isEmpty) {
                              context.showUserMessage('Informe o companyId.');
                              return;
                            }
                            await _service.supremeSetCompanyAllowLogin(
                              companyId: cid,
                              allowLogin: false,
                            );
                            if (mounted) {
                              context.showUserMessage(
                                'Login da empresa desativado.',
                              );
                            }
                          }),
                  child: const Text('Desativar login'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  onPressed:
                      _supremeGovBusy ? null : _confirmSupremeDeleteCompany,
                  child: const Text('Excluir empresa'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Escritorio',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _supremeGovOfficeId,
            decoration: const InputDecoration(
              labelText: 'officeId',
            ),
          ),
          const SizedBox(height: 10),
          shellTapFriendly(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _supremeGovBusy
                      ? null
                      : () => _runSupremeGov(() async {
                            final oid = _supremeGovOfficeId.text.trim();
                            if (oid.isEmpty) {
                              context.showUserMessage('Informe o officeId.');
                              return;
                            }
                            await _service.setAccountingOfficeAccess(
                              officeId: oid,
                              allowAccess: true,
                            );
                            if (mounted) {
                              context.showUserMessage(
                                'Acesso do escritorio liberado.',
                              );
                            }
                          }),
                  child: const Text('Liberar escritorio'),
                ),
                FilledButton.tonal(
                  onPressed: _supremeGovBusy
                      ? null
                      : () => _runSupremeGov(() async {
                            final oid = _supremeGovOfficeId.text.trim();
                            if (oid.isEmpty) {
                              context.showUserMessage('Informe o officeId.');
                              return;
                            }
                            await _service.setAccountingOfficeAccess(
                              officeId: oid,
                              allowAccess: false,
                              reason:
                                  'Suspenso pela empresa suprema (governanca).',
                            );
                            if (mounted) {
                              context.showUserMessage(
                                'Escritorio suspenso.',
                              );
                            }
                          }),
                  child: const Text('Suspender escritorio'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  onPressed:
                      _supremeGovBusy ? null : _confirmSupremeDeleteOffice,
                  child: const Text('Excluir escritorio'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteLightweightTestCompany(
    StandaloneLightweightCompanyRow r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Apagar empresa de teste?'),
          content: Text(
            'Remove utilizador no Auth, documentos em users (owners de teste), '
            'vinculos accountant_links pendentes/inativos e company_settings - '
            'apenas se continuar em modo cadastro leve e sem vinculo ativo com contador.\n\n'
            '${r.companyName}\n'
            '${r.companyId}\n'
            '${r.ownerEmail}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar definitivamente'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteLightweightTestCompany(companyId: r.companyId);
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage('Empresa de teste removida.');
      }
      _reloadGovernance();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(e));
      }
    }
  }

  Future<void> _confirmDeleteLightweightTestOffice(
    StandaloneLightweightOfficeRow r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Apagar escritorio de teste?'),
          content: Text(
            'Remove utilizador contador no Auth, users e accounting_offices - '
            'apenas escritorio ainda em cadastro leve e sem empresas na carteira.\n\n'
            '${r.officeName}\n'
            '${r.officeId}\n'
            '${r.email}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar definitivamente'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteLightweightTestOffice(officeId: r.officeId);
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage('Escritorio de teste removido.');
      }
      _reloadGovernance();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(e));
      }
    }
  }

  Widget _folderCard({
    required String title,
    required String subtitle,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [child],
        ),
      ),
    );
  }

  bool _containsCompany(List<PlatformCompanySummary> items, String? companyId) {
    if (companyId == null || companyId.isEmpty) return false;
    return items.any((item) => item.companyId == companyId);
  }

  AppWorkspaceHeader _headerForSection() {
    switch (widget.section) {
      case PlatformAdminSection.engineeringAgent:
        return const AppWorkspaceHeader(
          title: 'Agente de Engenharia',
          subtitle: '',
          chips: [],
        );
      case PlatformAdminSection.governanca:
        return const AppWorkspaceHeader(
          title: 'Governanca SaaS · acessos e cobranca cliente',
          subtitle:
              'Fluxo ordenado: onboarding publico (empresa e escritorio de teste), clientes SaaS com accoes sobre Asaas e suspensao com snapshot reversivel, e por ultimo somente contagens anonimizadas de demos.',
          chips: [
            AppHeaderChip('Plataforma'),
            AppHeaderChip('Demo'),
          ],
        );
      case PlatformAdminSection.escritorios:
        return const AppWorkspaceHeader(
          title: 'Escritorios e carteira',
          subtitle:
              'Acompanhe escritorios, carteira do contador e vinculos com empresas. Mesmo estilo e fluxo de antes, organizado nesta aba.',
          chips: [AppHeaderChip('Plataforma'), AppHeaderChip('Contabilidade')],
        );
      case PlatformAdminSection.convidar:
        return const AppWorkspaceHeader(
          title: 'Vendas e convites',
          subtitle:
              'Pagina de vendas, convites trial, envio em massa e acompanhamento. Fluxo completo validado.',
          chips: [AppHeaderChip('Convite'), AppHeaderChip('Trials')],
        );
      case PlatformAdminSection.financeiro:
        return const AppWorkspaceHeader(
          title: 'Financeiro da plataforma',
          subtitle:
              'Cobrancas Asaas, planos e gestao comercial de clientes do SaaS (escritorios e empresas). Nao confunda com o Financeiro /finance da sua propria obra.',
          chips: [
            AppHeaderChip('Clientes do SaaS'),
            AppHeaderChip('Plataforma'),
          ],
        );
      case PlatformAdminSection.integracoes:
        return const AppWorkspaceHeader(
          title: 'Integracoes fiscais',
          subtitle:
              'Focus e operacao fiscal: sincronize, valide e edite a configuracao por empresa, como ja funciona em producao.',
          chips: [AppHeaderChip('Focus'), AppHeaderChip('Fiscal')],
        );
    }
  }

  Future<void> _withGovernanceCadastroRealBusy(
    GraduatedPublicCompanyRow row,
    Future<void> Function() job,
    String successMessage,
  ) async {
    final id = row.companyId;
    if (id.isEmpty || _governanceActionBusyCompanies.contains(id)) {
      return;
    }
    setState(() => _governanceActionBusyCompanies.add(id));
    try {
      await job();
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage(successMessage);
      }
      _reloadGovernance();
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(e));
      }
    } finally {
      if (mounted) {
        setState(() => _governanceActionBusyCompanies.remove(id));
      }
    }
  }

  Widget _gvFlowCaption(String lines) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      lines,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F766E),
        height: 1.35,
      ),
    ),
  );

  Widget _buildGovernanceCadastroRealCompanyTile(GraduatedPublicCompanyRow c) {
    final busy = _governanceActionBusyCompanies.contains(c.companyId);
    final billingProviderLc = c.billingProvider.trim().toLowerCase();
    final hasAsaasSub =
        billingProviderLc == 'asaas' && c.asaasSubscriptionId.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF8FAFC),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.companyName.isEmpty ? c.companyId : c.companyName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 6),
              SelectableText(
                '${c.ownerEmail}\n'
                '${c.companyId}\n'
                'Origem leve: ${c.directSignupSource}\n'
                '${c.accountantPendingStatus.isEmpty ? "" : "Onboarding contador: ${c.accountantPendingStatus}\n"}'
                'Owner cadastro sem pendencia leve: ${c.ownerLightweightResolved ? "sim" : "nao"}\n'
                'Lifecycle declarado (Firestore commercial): '
                '${c.lifecycleStatus.isEmpty ? "-" : c.lifecycleStatus}\n'
                'Billing status declarado (Firestore): '
                '${c.billingStatus.isEmpty ? "-" : c.billingStatus}\n'
                'Integracao billing: ${c.billingProvider.isEmpty ? "-" : c.billingProvider}'
                '${c.asaasSubscriptionId.isEmpty ? "" : "\nAssinatura Asaas subscriptionId:\n${c.asaasSubscriptionId}"}\n'
                'commercial.allowLogin directo gravado:\n${c.allowLogin ? "sim" : "nao"}'
                '${c.updatedAtIso.isEmpty ? "" : "\ncompany_settings actualizado ISO:\n${c.updatedAtIso}"}'
                '${c.governanceAdministrativeFreezeActive ? "\n[SUSPEND] Flag governanca com snapshot disponivel para retomar." : ""}',
                style: const TextStyle(height: 1.38, fontSize: 13),
              ),
              const SizedBox(height: 10),
              shellTapFriendly(
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF92400E)),
                    onPressed: busy
                        ? null
                        : () => context.go(
                            '$kPlatformAdminFinanceiroPath?company=${Uri.encodeComponent(c.companyId)}',
                          ),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Financeiro cliente'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            final target = !c.governanceAdministrativeFreezeActive;
                            final title =
                                target ? 'Suspender empresa pela plataforma?' : 'Retomar acesso da empresa?';
                            final explanation = target
                                ? 'Suspende usando a governanca; guardamos ciclo/allowLogin anteriores e restauramos ao clicar Retomar.\n${c.companyName}'
                                : 'Restaura valores guardados antes desta ferramenta de suspender.\n${c.companyName}';
                            unawaited(
                              showDialog<void>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: Text(title),
                                    content: SingleChildScrollView(
                                      child: Text(explanation),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop();
                                          _withGovernanceCadastroRealBusy(
                                            c,
                                            () => _service.governanceCompanySetSuspended(
                                                  companyId: c.companyId,
                                                  suspend: target,
                                                ),
                                            target ? 'Suspensao pela governanca aplicada.' : 'Cliente reabilitado usando snapshot guardado.',

                                          );
                                        },
                                        child: Text(target ? 'Suspender agora' : 'Retomar agora'),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                    icon: Icon(
                      c.governanceAdministrativeFreezeActive ? Icons.restore : Icons.pause_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      c.governanceAdministrativeFreezeActive ? 'Retomar acesso' : 'Suspender empresa',
                    ),
                  ),
                  if (hasAsaasSub) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB45309)),
                      onPressed: busy
                          ? null
                          : () {
                              unawaited(
                                showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Cancelar boletos/as parcelas em aberto no Asaas?'),
                                      content: SingleChildScrollView(
                                        child: Text(
                                          'Chama DELETE cobranca no Asaas apenas para parcelas marcadas pendente/overdue até o gateway aceitar.\nCliente: ${c.companyName}',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: const Text('Fechar'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                            _withGovernanceCadastroRealBusy(
                                              c,
                                              () async {
                                                await _service
                                                    .governanceCompanyCancelPendingAsaasPayments(
                                                      companyId: c.companyId,
                                                    );
                                              },
                                              'Pedido de cancelamento de boletos pendentes processado pelo servidor.',
                                            );
                                          },
                                          child: const Text('Cancelar pendentes no Asaas'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Cancelar boletos/em aberto (Asaas)'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                      ),
                      onPressed: busy
                          ? null
                          : () {
                              unawaited(
                                showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text(
                                        'ENCERRAR assinatura recorrente Asaas?',
                                      ),
                                      content: SingleChildScrollView(
                                        child: Text(
                                          'Envia DELETE /subscriptions no mesmo fluxo oficial do cliente. Encerra ciclo futuro no Asaas e marca billing como cancelado no Firestore assim que o servidor concluir o pedido HTTP.\nEmpresa ${c.companyName}',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: const Text('Abortar'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFB91C1C),
                                          ),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                            _withGovernanceCadastroRealBusy(
                                              c,
                                              () async {
                                                await _service
                                                    .governanceCompanyCancelAsaasBilling(
                                                      companyId: c.companyId,
                                                    );
                                              },
                                              'Assinatura Asaas encerrada e controlo cliente actualizado.',
                                            );
                                          },
                                          child:
                                              const Text('Encerrar assinatura AGORA'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                      icon: const Icon(Icons.unsubscribe_rounded, size: 18),
                      label:
                          const Text('Desactivar cobrança / cancelar ciclo'),
                    ),
                  ],
                ],
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLeadOriginLine(StandaloneLightweightCompanyRow r) {
    final parts = <String>[];
    if (r.leadOriginEstado.isNotEmpty) {
      parts.add('UF ${r.leadOriginEstado}');
    }
    if (r.leadOriginCidade.isNotEmpty) {
      parts.add(r.leadOriginCidade);
    }
    if (r.leadOriginCep.isNotEmpty) {
      parts.add('CEP ${r.leadOriginCep}');
    }
    if (parts.isEmpty) {
      return '';
    }
    return '\nOrigem (link): ${parts.join(' · ')}';
  }

  Widget _governanceBackToHub() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.go(kPlatformAdminGovernancaPath),
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Menu de governanca'),
      ),
    );
  }

  Widget _buildGovernanceFunilWorkspace() {
    return FutureBuilder<PlatformMarketingDashboard>(
      future: _marketingDashboardFuture,
      builder: (context, snapshot) {
        final dashboard =
            snapshot.data ??
            const PlatformMarketingDashboard(
              days: 30,
              metrics: PlatformMarketingMetrics(
                visitors: 0,
                sessions: 0,
                salesViews: 0,
                preregViews: 0,
                planSelects: 0,
                preregSubmits: 0,
                companyLightPreregistrationViews: 0,
                companyLightPreregistrationSubmits: 0,
                hotVisitors: 0,
                recurringVisitors: 0,
                demoVisitors: 0,
                demoCompanyUnique: 0,
                demoAccountantUnique: 0,
                demoOpenCount: 0,
                preregConversionRate: 0,
                planSelectRate: 0,
              ),
              topSources: <PlatformMarketingCount>[],
              topCampaigns: <PlatformMarketingCount>[],
              topPlans: <PlatformMarketingCount>[],
              recentLeads: <PlatformMarketingLead>[],
            );
        final m = dashboard.metrics;
        return AppWorkspaceCard(
          title: 'Funil: visualizacoes e contactos',
          subtitle:
              'Últimos ${dashboard.days} dias (coleção marketing). Use Atualizar no topo para recarregar.',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              AppMetricCard(
                label: 'Visualizacoes landing /vendas',
                value: m.salesViews.toString(),
                caption: 'Rotas comerciais publicas',
              ),
              AppMetricCard(
                label: 'Visualizacoes (rotas genericas)',
                value: m.preregViews.toString(),
                caption: 'Historico agregado',
              ),
              AppMetricCard(
                label: 'Visualizações pré-cadastro empresa',
                value: m.companyLightPreregistrationViews.toString(),
                caption: kPublicPreCadastroEmpresaPath,
              ),
              AppMetricCard(
                label: 'Contactos agregados (redirect)',
                value: m.preregSubmits.toString(),
                caption: 'Historico inclui /contratar e fluxos antigos',
              ),
              AppMetricCard(
                label: 'Leads empresa leve',
                value: m.companyLightPreregistrationSubmits.toString(),
                caption: 'Pré-cadastro concluído',
              ),
              AppMetricCard(
                label: 'Demo empresa (únicos)',
                value: m.demoCompanyUnique.toString(),
                caption: 'Dispositivos demo',
              ),
              AppMetricCard(
                label: 'Demo contador (únicos)',
                value: m.demoAccountantUnique.toString(),
                caption: 'Dispositivos demo',
              ),
              AppMetricCard(
                label: 'Aberturas demo',
                value: m.demoOpenCount.toString(),
                caption: 'Total agregado',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _governanceCampaignLinksCard() {
    const base = kPublicWebAppOrigin;
    final links = <(String label, String url)>[
      ('Demo — perfil empresa', '$base/demo-empresa'),
      ('Demo — perfil contador', '$base/demo-contador'),
      (
        'Pre-cadastro empresa (UF, cidade e CEP no query para pre-preencher)',
        '$base$kPublicPreCadastroEmpresaPath?uf=SP&cidade=SaoPaulo&cep=01310100',
      ),
      ('Pre-cadastro escritorio contabil', '$base$kPublicPreCadastroEscritorioPath'),
      (
        'Atalho /contratar (redirect para pre-cadastro empresa; conserve UTM)',
        '$base/contratar?utm_source=campanha&utm_medium=pago',
      ),
    ];
    return AppWorkspaceCard(
      title: 'Links para divulgação',
      subtitle:
          'Copie e adapte UTM e localização. Valores de UF/cidade/CEP vindos do link ficam no pré-cadastro.',
      child: Column(
        children: [
          for (final item in links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.$1),
              subtitle: SelectableText(item.$2),
              isThreeLine: false,
              trailing: shellTapFriendly(
                IconButton(
                  tooltip: 'Copiar',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: item.$2));
                    if (mounted) {
                      context.showUserMessage('Link copiado.');
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _governanceTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Painel preparado como operacao SaaS. Actualizar recarrega listas e métricas no servidor. '
            'Apagar empresa de teste so quando o servidor confirma modo leve e sem vinculo contador activo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        shellTapFriendly(
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reloadGovernance,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _governancePassoACard(
    Future<List<StandaloneLightweightCompanyRow>> standalone,
  ) {
    return _folderCard(
      title: 'Passo A — Empresa onboarding publico sem escritorio',
      subtitle:
          'Owners ainda com lightweightProfilePending. Apagar só remove registos servidor quando company_settings directSignup marca cadastro leve e nao há vinculo contador.',
      initiallyExpanded: true,
      child: FutureBuilder<List<StandaloneLightweightCompanyRow>>(
        future: standalone,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Text(AppErrorMapper.messageFrom(snap.error!));
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Text(
              'Nenhuma empresa nesta fila no momento.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppBrandColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.companyName.isEmpty ? r.companyId : r.companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppBrandColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${r.ownerEmail}\n${r.companyId}'
                            '${_formatLeadOriginLine(r)}'
                            '${r.accountantPendingStatus.isEmpty ? "" : "\ncontador pendente: ${r.accountantPendingStatus}"}'
                            '${!r.standaloneDeletionAllowed && r.standaloneDeletionBlockedReason.isNotEmpty ? "\n[BLOQUEIO] ${r.standaloneDeletionBlockedReason}" : ""}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  height: 1.35,
                                  color: AppBrandColors.softText,
                                ),
                          ),
                          const SizedBox(height: 14),
                          shellTapFriendly(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _selectCompanyInAdminPanel(r.companyId),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('Financeiro'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                    alignment: Alignment.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB91C1C),
                                    side: const BorderSide(
                                      color: Color(0xFFFECACA),
                                    ),
                                    minimumSize: const Size.fromHeight(46),
                                    alignment: Alignment.center,
                                  ),
                                  onPressed: r.standaloneDeletionAllowed
                                      ? () => _confirmDeleteLightweightTestCompany(r)
                                      : null,
                                  icon: const Icon(Icons.delete_forever_rounded),
                                  label: const Text('Apagar'),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _governancePassoBCard(
    Future<List<StandaloneLightweightOfficeRow>> offices,
  ) {
    return _folderCard(
      title: 'Passo B — Escritorio apenas em entrada leve',
      subtitle:
          'Pre-cadastro publico incompleto; sem carteira no indice nem empresas reais ligadas segundo regra servidor apagar escritorio sandbox.',
      initiallyExpanded: true,
      child: FutureBuilder<List<StandaloneLightweightOfficeRow>>(
        future: offices,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Text(AppErrorMapper.messageFrom(snap.error!));
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Text(
              'Nenhum escritorio nesta fila (ou ja concluiram cadastro real).',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppBrandColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.officeName.isEmpty ? r.officeId : r.officeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppBrandColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${r.email}\n'
                            '${r.officeId}\n'
                            'carteira(index): ${r.linkedCompaniesInIndex} empresas | campo office: '
                            '${r.linkedCompaniesCount}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  height: 1.35,
                                  color: AppBrandColors.softText,
                                ),
                          ),
                          const SizedBox(height: 14),
                          shellTapFriendly(
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                                minimumSize: const Size.fromHeight(46),
                                alignment: Alignment.center,
                              ),
                              onPressed: () =>
                                  _confirmDeleteLightweightTestOffice(r),
                              icon: const Icon(Icons.delete_forever_rounded),
                              label: const Text('Apagar escritorio'),
                            ),
                          ),
                        ],
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

  Widget _governancePassoCCard(
    Future<GovernanceRealRegistrationsResult> realRegs,
  ) {
    return _folderCard(
      title: 'Passo C — Cadastro SaaS pos-onboarding leve',
      subtitle:
          'Empresas/escritorios que ja concluem perfil suficiente. Por empresa efectiva aparece suspensao reversivel snapshot, botoes para cancelar boletos pendente no Asaas e encerramento de assinatura (usa subscription registada quando provider e Asaas).',
      initiallyExpanded: true,
      child: FutureBuilder<GovernanceRealRegistrationsResult>(
        future: realRegs,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Text(AppErrorMapper.messageFrom(snap.error!));
          }
          final data = snap.data ??
              const GovernanceRealRegistrationsResult(
                companies: <GraduatedPublicCompanyRow>[],
                offices: <GraduatedPublicOfficeRow>[],
              );
          if (data.companies.isEmpty && data.offices.isEmpty) {
            return const Text(
              'Ainda sem registros: quando uma empresa ou escritorio de teste completar cadastro real, '
              'a entrada surge nesta lista automaticamente.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.companies.isNotEmpty) ...[
                const Text(
                  'Empresas — comandos cliente',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final c in data.companies)
                  _buildGovernanceCadastroRealCompanyTile(c),
                const SizedBox(height: 14),
              ],
              if (data.offices.isNotEmpty) ...[
                const Text(
                  'Escritorios',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final r in data.offices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.officeName.isEmpty ? r.officeId : r.officeName,
                    ),
                    subtitle: Text(
                      '${r.email}\nCNPJ cadastrado: ${r.cnpj.isEmpty ? "—" : r.cnpj}\n'
                      '${r.officeId} · status ${r.platformStatus}\n'
                      'Carteira (indice Firestore): ${r.linkedCompaniesInIndex} empresa(s)',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _governanceDemoCard(
    Future<List<PublicDemoAccessLedgerRow>> demos,
  ) {
    return _folderCard(
      title: 'Livro de demos publicos (somente contagens)',
      subtitle:
          'Cada entrada agrega sessoes com a mesma chave tecnica interna para nao multiplicar o numero de acessos — sem mostrar rede, navegador ou dispositivo.',
      initiallyExpanded: true,
      child: FutureBuilder<List<PublicDemoAccessLedgerRow>>(
        future: demos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return Text(AppErrorMapper.messageFrom(snap.error!));
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Text(
              'Sem registos agregados de demo nesta vista.',
            );
          }
          return Column(
            children: [
              for (final r in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${r.rolesCompany ? "Demo empresa" : ""}'
                    '${r.rolesCompany && r.rolesAccountant ? " · " : ""}'
                    '${r.rolesAccountant ? "Demo contador" : ""}'
                    '${!r.rolesCompany && !r.rolesAccountant ? "(sem papel registrado)" : ""}'
                    ' · ${r.accessCount}x',
                  ),
                  subtitle: Text(
                    'Primeiro acesso: ${r.firstSeenAtIso}\n'
                    'Ultimo acesso: ${r.lastSeenAtIso}',
                  ),
                  isThreeLine: true,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGovernanceSection() {
    final standalone = _standaloneLightFuture;
    final demos = _demoLedgerFuture;
    final offices = _lightweightOfficesFuture;
    final realRegs = _realRegistrationsFuture;
    if (standalone == null ||
        demos == null ||
        offices == null ||
        realRegs == null) {
      return const Center(
        child: Text('Estado de governanca indisponivel.'),
      );
    }

    final panel = (widget.governancePanel ?? '').trim().toLowerCase();
    final hubMode = panel.isEmpty || panel == 'hub';

    final session = ref.watch(sessionProvider);

    Widget shell(List<Widget> children) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: children,
      );
    }

    final head = <Widget>[
      if (!hubMode) ...[
        _governanceBackToHub(),
        const SizedBox(height: 8),
      ],
      _governanceTopBar(),
      const SizedBox(height: 8),
      if (session != null && hasSupremePlatformAccess(session)) ...[
        _buildSupremeGovernanceCommandsCard(),
        const SizedBox(height: 12),
      ],
    ];

    if (hubMode) {
      return shell([
        ...head,
        OutlinedButton.icon(
          onPressed: () => context.go(kPlatformAdminEscritoriosPath),
          icon: const Icon(Icons.account_balance_outlined),
          label: const Text('Ir para Escritorios e carteira'),
        ),
        const SizedBox(height: 12),
        _gvFlowCaption(
          'Cada cartão abre um painel dedicado. Para carteira real e vinculos contador, use Escritorios e carteira.',
        ),
        const SizedBox(height: 12),
        const GovernanceHub(),
      ]);
    }

    if (panel == 'funil') {
      return shell([
        ...head,
        const SizedBox(height: 4),
        _buildGovernanceFunilWorkspace(),
      ]);
    }

    if (panel == 'precadastro_empresas') {
      return shell([
        ...head,
        OutlinedButton.icon(
          onPressed: () => context.go(kPlatformAdminEscritoriosPath),
          icon: const Icon(Icons.account_balance_outlined),
          label: const Text('Ir para Escritorios e carteira'),
        ),
        const SizedBox(height: 12),
        _gvFlowCaption(
          'Empresas em entrada publica sem escritorio vinculado (modo leve).',
        ),
        const SizedBox(height: 8),
        _governancePassoACard(standalone),
      ]);
    }

    if (panel == 'precadastro_escritorios') {
      return shell([
        ...head,
        const SizedBox(height: 4),
        _gvFlowCaption(
          'Escritorios apenas com pre-cadastro publico / sandbox.',
        ),
        const SizedBox(height: 8),
        _governancePassoBCard(offices),
      ]);
    }

    if (panel == 'cadastro_completo') {
      return shell([
        ...head,
        const SizedBox(height: 4),
        _gvFlowCaption('Pos onboarding real: empresas com comandos e escritorios com carteira.'),
        const SizedBox(height: 8),
        _governancePassoCCard(realRegs),
      ]);
    }

    if (panel == 'demo') {
      return shell([
        ...head,
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => context.go(kPlatformAdminEscritoriosPath),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Escritorios e carteira (numeros completos)'),
        ),
        const SizedBox(height: 12),
        _gvFlowCaption(
          'Demos agregam por chave interna; IP e browser apenas deduplicam — use a outra rota para carteira real de escritorio.',
        ),
        const SizedBox(height: 8),
        _governanceDemoCard(demos),
      ]);
    }

    if (panel == 'links') {
      return shell([
        ...head,
        const SizedBox(height: 4),
        _governanceCampaignLinksCard(),
      ]);
    }

    if (panel == 'email_massa') {
      return shell([
        ...head,
        const SizedBox(height: 4),
        _gvFlowCaption(
          'Destinatários agregados das mesmas fontes da governança; envio usa SMTP ou SendGrid já configurados.',
        ),
        const SizedBox(height: 12),
        GovernanceBulkEmailPanel(service: _service),
      ]);
    }

    return shell([
      ...head,
      const Text('Painel desconhecido. Voltando ao menu recomendado.'),
      const SizedBox(height: 8),
      GovernanceHub(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (!canAccessPlatformAdminRoute(session)) {
      ref.read(shellPageChromeProvider.notifier).state =
          const ShellPageChrome();
      return const Scaffold(
        body: Center(
          child: Text(
            'Acesso negado. Exija OWNER e empresa suprema ou e-mail em PLATFORM_ADMIN_EMAILS (build).',
          ),
        ),
      );
    }

    if (widget.section == PlatformAdminSection.engineeringAgent) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
        title: 'Agente de Engenharia',
      );
      if (!hasSupremePlatformAccess(session)) {
        return AppGradientBackground(
          child: AppPageLayout(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'Acesso negado ao Agente de Engenharia: apenas dono da empresa suprema da plataforma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppBrandColors.ink,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return AppGradientBackground(
        child: AppPageLayout(
          scrollable: false,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: const EngineeringAgentPage(),
        ),
      );
    }

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: _headerForSection(),
    );

    if (widget.section == PlatformAdminSection.governanca) {
      return AppGradientBackground(
        child: AppPageLayout(
          child: _buildGovernanceSection(),
        ),
      );
    }

    return AppGradientBackground(
      child: AppPageLayout(
        child: FutureBuilder<List<PlatformCompanySummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppWorkspaceCard(
                title: 'Painel indisponivel',
                subtitle: AppErrorMapper.messageFrom(snapshot.error!),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              );
            }

            final items = snapshot.data ?? const <PlatformCompanySummary>[];
            final s = widget.section;
            final trialItems = s == PlatformAdminSection.convidar
                ? (items
                      .where(
                        (e) =>
                            e.lifecycleStatus.trim().toLowerCase() == 'trial',
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          b.billingGraceUntil.compareTo(a.billingGraceUntil),
                    ))
                : <PlatformCompanySummary>[];
            if (s == PlatformAdminSection.convidar) {
              if (_selectedTrialCompanyId == null ||
                  !trialItems.any(
                    (e) => e.companyId == _selectedTrialCompanyId,
                  )) {
                _selectedTrialCompanyId = trialItems.isNotEmpty
                    ? trialItems.first.companyId
                    : null;
              }
            }
            final selectedTrial = s == PlatformAdminSection.convidar
                ? (_selectedTrialCompanyId == null
                      ? null
                      : trialItems
                            .where(
                              (e) => e.companyId == _selectedTrialCompanyId,
                            )
                            .firstOrNull)
                : null;
            final selected = items
                .where((item) => item.companyId == _selectedCompanyId)
                .firstOrNull;

            return ListView(
              children: [
                if (s == PlatformAdminSection.escritorios) ...[
                  AppWorkspaceCard(
                    title: 'Resumo da plataforma',
                    subtitle: 'Leitura consolidada das empresas cadastradas.',
                    trailing: FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar'),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        AppMetricCard(
                          label: 'Empresas',
                          value: items.length.toString(),
                          caption: 'Owners identificados',
                        ),
                        AppMetricCard(
                          label: 'Liberadas',
                          value: items
                              .where((e) => e.allowLogin)
                              .length
                              .toString(),
                          caption: 'Liberadas apos pagamento',
                        ),
                        AppMetricCard(
                          label: 'Regularizacao',
                          value: items
                              .where((e) => !e.allowLogin)
                              .length
                              .toString(),
                          caption: 'Aguardando regularizacao',
                        ),
                        AppMetricCard(
                          label: 'Pendentes',
                          value: items
                              .where(
                                (e) =>
                                    (e.activationRequired &&
                                        e.activationStatus != 'released') ||
                                    e.approvalStatus != 'approved' &&
                                        e.approvalStatus != 'auto_approved',
                              )
                              .length
                              .toString(),
                          caption: 'Aguardando liberacao',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<PlatformAccountingOfficeSummary>>(
                    future: _accountingOfficesFuture,
                    builder: (context, officeSnap) {
                      if (officeSnap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      if (officeSnap.hasError) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _folderCard(
                              title: 'Escritorios cadastrados',
                              subtitle:
                                  'Falha ao carregar. As functions precisam estar publicadas (platformListAccountingOffices).',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppErrorMapper.messageFrom(
                                      officeSnap.error!,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(
                                      () => _accountingOfficesFuture =
                                          _listAccountingOfficesWithSearch(),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                      final officeItems =
                          officeSnap.data ??
                          const <PlatformAccountingOfficeSummary>[];
                      if (_selectedAdminOfficeId == null ||
                          !officeItems.any(
                            (e) => e.officeId == _selectedAdminOfficeId,
                          )) {
                        _selectedAdminOfficeId = officeItems.isNotEmpty
                            ? officeItems.first.officeId
                            : null;
                      }
                      final selectedOffice = officeItems
                          .where((e) => e.officeId == _selectedAdminOfficeId)
                          .firstOrNull;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _folderCard(
                            title: 'Escritorios cadastrados',
                            subtitle:
                                'Cada escritorio concentra as empresas vinculadas na carteira do contador. Acompanhe status, reconcilie convite trial antigo, suspenda acesso e abra empresas abaixo no painel geral.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    AppMetricCard(
                                      label: 'Escritorios',
                                      value: officeItems.length.toString(),
                                      caption: 'Firestore accounting_offices',
                                    ),
                                    if (selectedOffice != null)
                                      AppMetricCard(
                                        label: 'Carteira',
                                        value: selectedOffice.companies.length
                                            .toString(),
                                        caption: 'Empresas (company_settings)',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _accountingOfficeSearchEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar por email do escritorio',
                                    hintText:
                                        'Inclui o cadastro mesmo fora dos 200 mais recentes',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => setState(() {
                                        _accountingOfficesFuture =
                                            _listAccountingOfficesWithSearch();
                                      }),
                                      icon: const Icon(
                                        Icons.search_rounded,
                                        size: 20,
                                      ),
                                      label: const Text('Aplicar busca'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        _accountingOfficeSearchEmail.clear();
                                        setState(() {
                                          _accountingOfficesFuture =
                                              _listAccountingOfficesWithSearch();
                                        });
                                      },
                                      child: const Text('Limpar busca'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (officeItems.isEmpty)
                                  const Text(
                                    'Nenhum escritorio retornado. Apos deploy, use Atualizar no resumo; use a busca por email se o CNPJ ja existia e o registro nao entrou no top 200 por data.',
                                  )
                                else ...[
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedAdminOfficeId,
                                    decoration: const InputDecoration(
                                      labelText: 'Selecionar escritorio',
                                      filled: true,
                                    ),
                                    items: [
                                      for (final o in officeItems)
                                        DropdownMenuItem(
                                          value: o.officeId,
                                          child: Text(
                                            o.officeName.isNotEmpty
                                                ? o.officeName
                                                : o.officeId,
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      setState(
                                        () => _selectedAdminOfficeId = v,
                                      );
                                    },
                                  ),
                                  if (selectedOffice != null) ...[
                                    const SizedBox(height: 12),
                                    _DetailLine(
                                      'Email / ID',
                                      '${selectedOffice.email} | ${selectedOffice.officeId}',
                                    ),
                                    _DetailLine(
                                      'Responsavel',
                                      selectedOffice.responsibleName,
                                    ),
                                    _DetailLine(
                                      'Contato',
                                      '${selectedOffice.phone} | ${selectedOffice.city} ${selectedOffice.state}',
                                    ),
                                    _DetailLine(
                                      'Status',
                                      'plataforma: ${selectedOffice.platformStatus} | ativo: ${selectedOffice.active} | suspenso: ${selectedOffice.accessSuspended} | cobranca esc.: ${selectedOffice.officeBillingStatus}',
                                    ),
                                    _DetailLine(
                                      'Origem',
                                      selectedOffice.source,
                                    ),
                                    _DetailLine(
                                      'Criado / atualizado',
                                      '${selectedOffice.createdAt} / ${selectedOffice.updatedAt}',
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: _officeActionBusy
                                              ? null
                                              : () =>
                                                    _reconcileAdminOfficeInvite(
                                                      selectedOffice,
                                                    ),
                                          icon: const Icon(Icons.link),
                                          label: const Text(
                                            'Reconciliar convite trial',
                                          ),
                                        ),
                                        if (selectedOffice.accessSuspended)
                                          FilledButton.icon(
                                            onPressed: _officeActionBusy
                                                ? null
                                                : () =>
                                                      _promptAndSetAdminOfficeAccess(
                                                        office: selectedOffice,
                                                        allowAccess: true,
                                                      ),
                                            icon: const Icon(Icons.lock_open),
                                            label: const Text(
                                              'Reativar acesso contador',
                                            ),
                                          )
                                        else
                                          OutlinedButton.icon(
                                            onPressed: _officeActionBusy
                                                ? null
                                                : () =>
                                                      _promptAndSetAdminOfficeAccess(
                                                        office: selectedOffice,
                                                        allowAccess: false,
                                                      ),
                                            icon: const Icon(Icons.block),
                                            label: const Text(
                                              'Suspender acesso contador',
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Empresas vinculadas a este escritorio',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (selectedOffice.companies.isEmpty)
                                      const Text(
                                        'Nenhuma empresa vinculada. O contador vincula ao cadastrar clientes (login do contador).',
                                      )
                                    else
                                      for (final c in selectedOffice.companies)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${c.companyName} (${c.companyId}) — ${_billingStatusLabel(c.billingStatus)} | ${_accessLabel(c.allowLogin)} | ciclo: ${c.lifecycleStatus}',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _selectCompanyInAdminPanel(
                                                      c.companyId,
                                                    ),
                                                child: const Text(
                                                  'Abrir no painel',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                ],
                if (s == PlatformAdminSection.convidar) ...[
                  AppWorkspaceCard(
                    title: 'Pagina de vendas',
                    subtitle:
                        'Modulo para abrir e copiar o endereco web da pagina comercial publica do sistema.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: SelectableText(
                            salesPageWebUrl,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppBrandColors.ink,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: salesPageWebUrl),
                            );
                            if (!context.mounted) return;
                            context.showUserSuccess(
                              'Link da pagina de vendas copiado.',
                            );
                          },
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copiar endereco web'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Convite de teste 30 dias (escritorio contabil)',
                    subtitle:
                        'Convite com texto institucional do fundador. Nome da empresa, CNPJ e data de abertura sao opcionais e aparecem no bloco de transparencia do e-mail quando preenchidos.',
                    trailing: FilledButton.icon(
                      onPressed: _issuingTrial ? null : _issueTrialInvite,
                      icon: _issuingTrial
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        _issuingTrial ? 'Enviando...' : 'Enviar convite',
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _trialCompanyEmail,
                          decoration: const InputDecoration(
                            labelText: 'Email da empresa (opcional)',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _trialCompanyName,
                          decoration: const InputDecoration(
                            labelText: 'Nome da empresa (opcional)',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _trialCompanyCnpj,
                          decoration: const InputDecoration(
                            labelText: 'CNPJ da empresa (opcional, 14 digitos)',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _trialCompanyOpenedAt,
                          decoration: const InputDecoration(
                            labelText:
                                'Data de abertura (opcional, ex. 26/02/2022)',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _trialAccountantEmail,
                          decoration: const InputDecoration(
                            labelText: 'Email do escritorio *',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _trialAccountantName,
                          decoration: const InputDecoration(
                            labelText:
                                'Nome do escritorio ou responsavel (opcional)',
                            filled: true,
                          ),
                        ),
                        if (_lastTrialInvite != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Ultimo convite',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _lastTrialInvite!.inviteUrlCompany.isNotEmpty
                                ? _lastTrialInvite!.inviteUrlCompany
                                : _lastTrialInvite!.inviteUrl,
                          ),
                          if (_lastTrialInvite!
                              .inviteUrlAccountant
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Link do contador',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              _lastTrialInvite!.inviteUrlAccountant,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text('Expira em: ${_lastTrialInvite!.expiresAtIso}'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Envio em massa de convites',
                    subtitle:
                        'Importa arquivo com empresa + contador, separa a leva imediata da fila pendente e aplica intervalo conservador entre disparos.',
                    trailing: shellTapFriendly(
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _bulkSending ? null : _pickBulkTrialList,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Importar arquivo'),
                          ),
                        OutlinedButton.icon(
                          onPressed:
                              (_bulkSending ||
                                  _bulkReadyRows.isEmpty &&
                                      _bulkPendingRows.isEmpty)
                              ? null
                              : _clearBulkList,
                          icon: const Icon(Icons.clear_all_rounded),
                          label: const Text('Limpar'),
                        ),
                        FilledButton.icon(
                          onPressed: (_bulkSending || _bulkReadyRows.isEmpty)
                              ? null
                              : _sendBulkTrialInvites,
                          icon: _bulkSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _bulkSending ? 'Enviando...' : 'Disparar leva',
                          ),
                        ),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            AppMetricCard(
                              label: 'Prontos',
                              value: _bulkReadyRows.length.toString(),
                              caption: 'Leva imediata',
                            ),
                            AppMetricCard(
                              label: 'Pendentes',
                              value: _bulkPendingRows.length.toString(),
                              caption: 'Aguardando promocao manual',
                            ),
                            AppMetricCard(
                              label: 'Janela 1h',
                              value: _bulkHourlyRoom().toString(),
                              caption: 'Convites restantes na hora atual',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _bulkFileName == null
                              ? 'Nenhum arquivo carregado.'
                              : 'Arquivo atual: $_bulkFileName',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (_bulkHint != null &&
                            _bulkHint!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_bulkHint!),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'Formato recomendado: contador@dominio.com;Nome Contador ou empresa@dominio.com;Nome Empresa;contador@dominio.com;Nome Contador',
                        ),
                        if (_bulkCooldownLabel() != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Proxima promocao de pendentes liberada em ${_bulkCooldownLabel()}.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  (_bulkSending || _bulkPendingRows.isEmpty)
                                  ? null
                                  : _promotePendingWave,
                              icon: const Icon(Icons.move_up_outlined),
                              label: const Text('Promover pendentes'),
                            ),
                          ],
                        ),
                        if (_bulkReadyRows.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Leva pronta',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          for (var i = 0; i < _bulkReadyRows.length; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppBrandColors.border,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_bulkReadyRows[i].companyEmail} -> ${_bulkReadyRows[i].accountantEmail}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if ((_bulkReadyRows[i].companyName ??
                                                '')
                                            .isNotEmpty)
                                          Text(
                                            'Empresa: ${_bulkReadyRows[i].companyName}',
                                          ),
                                        if ((_bulkReadyRows[i].accountantName ??
                                                '')
                                            .isNotEmpty)
                                          Text(
                                            'Contador: ${_bulkReadyRows[i].accountantName}',
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _bulkSending
                                        ? null
                                        : () => _removeBulkReadyRow(i),
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: 'Remover da leva',
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (_bulkPendingRows.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Pendentes (${_bulkPendingRows.length})',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          for (final row in _bulkPendingRows.take(8))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${row.companyEmail} -> ${row.accountantEmail}',
                              ),
                            ),
                          if (_bulkPendingRows.length > 8)
                            Text(
                              '... e mais ${_bulkPendingRows.length - 8} convite(s) na fila.',
                            ),
                        ],
                        if (_bulkSkipped.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Linhas ignoradas / avisos',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          for (final item in _bulkSkipped.take(12))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(item),
                            ),
                          if (_bulkSkipped.length > 12)
                            Text(
                              '... e mais ${_bulkSkipped.length - 12} aviso(s).',
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _folderCard(
                    title: 'Acompanhamento de trials (30 dias)',
                    subtitle:
                        'Lista empresas em teste, dias restantes e permite estender o prazo por empresa quando necessario.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            AppMetricCard(
                              label: 'Trials ativos',
                              value: trialItems
                                  .where((e) => e.allowLogin)
                                  .length
                                  .toString(),
                              caption: 'Empresas em teste com acesso liberado',
                            ),
                            AppMetricCard(
                              label: 'Trials totais',
                              value: trialItems.length.toString(),
                              caption: 'Empresas cadastradas em teste',
                            ),
                            AppMetricCard(
                              label: 'Expirando (<=7d)',
                              value: trialItems
                                  .where(
                                    (e) => _daysUntil(e.billingGraceUntil) <= 7,
                                  )
                                  .length
                                  .toString(),
                              caption: 'Teste terminando em ate 7 dias',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (trialItems.isEmpty)
                          const Text('Nenhuma empresa em trial no momento.')
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTrialCompanyId,
                            decoration: const InputDecoration(
                              labelText: 'Selecionar empresa em trial',
                              filled: true,
                            ),
                            items: [
                              for (final t in trialItems)
                                DropdownMenuItem(
                                  value: t.companyId,
                                  child: Text(
                                    '${t.companyName} (${t.companyId})',
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedTrialCompanyId = value);
                            },
                          ),
                        if (selectedTrial != null) ...[
                          const SizedBox(height: 12),
                          _DetailLine(
                            'Owner',
                            '${selectedTrial.ownerName} | ${selectedTrial.ownerEmail}',
                          ),
                          _DetailLine(
                            'Status',
                            '${_billingStatusLabel(selectedTrial.billingStatus)} | ${_accessLabel(selectedTrial.allowLogin)}',
                          ),
                          _DetailLine(
                            'Fim do teste',
                            selectedTrial.billingGraceUntil.isNotEmpty
                                ? '${selectedTrial.billingGraceUntil} (faltam ${_daysUntil(selectedTrial.billingGraceUntil)} dias)'
                                : 'nao definido',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: _extendingTrial
                                    ? null
                                    : () => _extendTrial(
                                        companyId: selectedTrial.companyId,
                                        extraDays: 7,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('+7 dias'),
                              ),
                              FilledButton.icon(
                                onPressed: _extendingTrial
                                    ? null
                                    : () => _extendTrial(
                                        companyId: selectedTrial.companyId,
                                        extraDays: 15,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('+15 dias'),
                              ),
                              FilledButton.icon(
                                onPressed: _extendingTrial
                                    ? null
                                    : () => _extendTrial(
                                        companyId: selectedTrial.companyId,
                                        extraDays: 30,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('+30 dias'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<TrialInviteSummary>>(
                    future: _trialInvitesFuture,
                    builder: (context, inviteSnapshot) {
                      final invites =
                          inviteSnapshot.data ?? const <TrialInviteSummary>[];
                      final activeInvites = invites
                          .where((e) => e.status.trim() != 'deleted')
                          .toList();
                      final deletedInvites = invites
                          .where((e) => e.status.trim() == 'deleted')
                          .toList();
                      final issued = activeInvites
                          .where((e) => e.status.trim() == 'issued')
                          .length;
                      final used = activeInvites
                          .where((e) => e.status.trim() == 'used')
                          .length;
                      final expired = activeInvites
                          .where((e) => e.status.trim() == 'expired')
                          .length;
                      return _folderCard(
                        title: 'Convites enviados (trial)',
                        subtitle:
                            'Auditoria operacional dos convites. Exclua itens antigos para manter a governanca organizada.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (inviteSnapshot.connectionState !=
                                ConnectionState.done)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(),
                              ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                AppMetricCard(
                                  label: 'Emitidos',
                                  value: issued.toString(),
                                  caption: 'Aguardando cadastro',
                                ),
                                AppMetricCard(
                                  label: 'Usados',
                                  value: used.toString(),
                                  caption: 'Viraram empresa trial',
                                ),
                                AppMetricCard(
                                  label: 'Expirados',
                                  value: expired.toString(),
                                  caption: 'Token expirou',
                                ),
                                AppMetricCard(
                                  label: 'Excluidos',
                                  value: deletedInvites.length.toString(),
                                  caption: 'Removidos da lista ativa',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _deletingInvites ? null : _reload,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Atualizar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _deletingInvites
                                      ? null
                                      : () {
                                          setState(() {
                                            _inviteSelectionMode =
                                                !_inviteSelectionMode;
                                            if (!_inviteSelectionMode) {
                                              _selectedInviteIds.clear();
                                            }
                                          });
                                        },
                                  icon: Icon(
                                    _inviteSelectionMode
                                        ? Icons.close_rounded
                                        : Icons.checklist_rounded,
                                  ),
                                  label: Text(
                                    _inviteSelectionMode
                                        ? 'Sair da selecao'
                                        : 'Selecionar varios',
                                  ),
                                ),
                                if (_inviteSelectionMode)
                                  FilledButton.icon(
                                    onPressed:
                                        _deletingInvites ||
                                            _selectedInviteIds.isEmpty
                                        ? null
                                        : () => _deleteTrialInvites(
                                            _selectedInviteIds.toList(),
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(
                                      'Excluir selecionados (${_selectedInviteIds.length})',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (inviteSnapshot.hasError)
                              Text(
                                AppErrorMapper.messageFrom(
                                  inviteSnapshot.error!,
                                ),
                              )
                            else if (activeInvites.isEmpty &&
                                deletedInvites.isEmpty)
                              const Text('Nenhum convite encontrado.')
                            else
                              Column(
                                children: [
                                  for (final invite in activeInvites.take(40))
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppBrandColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (_inviteSelectionMode)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: Checkbox(
                                                    value: _selectedInviteIds
                                                        .contains(invite.id),
                                                    onChanged: _deletingInvites
                                                        ? null
                                                        : (value) {
                                                            setState(() {
                                                              if (value ==
                                                                  true) {
                                                                _selectedInviteIds
                                                                    .add(
                                                                      invite.id,
                                                                    );
                                                              } else {
                                                                _selectedInviteIds
                                                                    .remove(
                                                                      invite.id,
                                                                    );
                                                              }
                                                            });
                                                          },
                                                  ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  '${invite.companyEmail}  →  ${invite.accountantEmail}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: AppBrandColors.ink,
                                                  ),
                                                ),
                                              ),
                                              AppHeaderChip(
                                                invite.status.isNotEmpty
                                                    ? invite.status
                                                    : 'status?',
                                              ),
                                              IconButton(
                                                tooltip: 'Excluir convite',
                                                onPressed: _deletingInvites
                                                    ? null
                                                    : () => _deleteTrialInvites(
                                                        [invite.id],
                                                      ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (invite.usedCompanyId.isNotEmpty)
                                            Text(
                                              'Empresa criada: ${invite.usedCompanyId}',
                                            ),
                                          if (invite.usedOfficeId.isNotEmpty)
                                            Text(
                                              'Escritorio cadastrado: ${invite.usedOfficeId}',
                                            ),
                                          Text(
                                            'Emitido: ${invite.issuedAtIso.isNotEmpty ? invite.issuedAtIso : '-'}',
                                          ),
                                          Text(
                                            'Expira: ${invite.expiresAtIso.isNotEmpty ? invite.expiresAtIso : '-'}',
                                          ),
                                          if (invite.usedAtIso.isNotEmpty)
                                            Text(
                                              'Usado em: ${invite.usedAtIso}',
                                            ),
                                          if (invite.issuedByName.isNotEmpty ||
                                              invite.issuedByUid.isNotEmpty)
                                            Text(
                                              'Por: ${invite.issuedByName.isNotEmpty ? invite.issuedByName : invite.issuedByUid}',
                                            ),
                                          if (invite.notes.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text('Obs: ${invite.notes}'),
                                          ],
                                        ],
                                      ),
                                    ),
                                  if (deletedInvites.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Divider(),
                                    const SizedBox(height: 10),
                                    ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                        'Excluidos (${deletedInvites.length})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Itens removidos da lista ativa.',
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              FilledButton.icon(
                                                onPressed:
                                                    _purgingDeletedInvites
                                                    ? null
                                                    : () =>
                                                          _purgeDeletedTrialInvites(
                                                            deletedInvites
                                                                .take(100)
                                                                .map(
                                                                  (e) => e.id,
                                                                )
                                                                .toList(),
                                                          ),
                                                icon: const Icon(
                                                  Icons.delete_forever_rounded,
                                                ),
                                                label: const Text(
                                                  'Limpar excluidos (ate 100)',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        for (final invite
                                            in deletedInvites.take(40))
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: AppBrandColors.border,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${invite.companyEmail}  →  ${invite.accountantEmail}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: AppBrandColors
                                                              .ink,
                                                        ),
                                                      ),
                                                    ),
                                                    const AppHeaderChip(
                                                      'deleted',
                                                    ),
                                                    shellTapFriendly(
                                                      IconButton(
                                                        tooltip:
                                                            'Excluir definitivamente',
                                                        onPressed:
                                                            _purgingDeletedInvites
                                                            ? null
                                                            : () =>
                                                                  _purgeDeletedTrialInvites(
                                                                    [
                                                                      invite.id,
                                                                    ],
                                                                  ),
                                                        icon: const Icon(
                                                          Icons
                                                              .delete_forever_rounded,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Excluido em: ${invite.deletedAtIso.isNotEmpty ? invite.deletedAtIso : '-'}',
                                                ),
                                                if (invite
                                                    .deletedByName
                                                    .isNotEmpty)
                                                  Text(
                                                    'Por: ${invite.deletedByName}',
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<PublicSalesConfig>(
                    future: _publicSalesConfigFuture,
                    builder: (context, snapshot) {
                      final config =
                          snapshot.data ?? PublicSalesConfig.defaults();
                      return AppWorkspaceCard(
                        title: 'Checkout publico da landing',
                        subtitle:
                            'Define nomes, valores e links publicos dos planos exibidos na pagina de vendas.',
                        trailing: shellTapFriendly(
                          OutlinedButton.icon(
                            onPressed: () => _editPublicSalesConfig(config),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Editar landing'),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailLine(
                              config.planSolo.title,
                              '${config.planSolo.priceLabel} | ${config.planSolo.checkoutUrl.isNotEmpty ? config.planSolo.checkoutUrl : 'link pendente'}',
                            ),
                            _DetailLine(
                              config.planEquipe.title,
                              '${config.planEquipe.priceLabel} | ${config.planEquipe.checkoutUrl.isNotEmpty ? config.planEquipe.checkoutUrl : 'link pendente'}',
                            ),
                            _DetailLine(
                              config.additionalAccess.title,
                              '${config.additionalAccess.priceLabel} | ${config.additionalAccess.checkoutUrl.isNotEmpty ? config.additionalAccess.checkoutUrl : 'link pendente'}',
                            ),
                            const SizedBox(height: 6),
                            _DetailLine(
                              'Meta Pixel (head do site web)',
                              config.metaPixelHeadSnippet.isNotEmpty
                                  ? 'Configurado'
                                  : 'Nao configurado',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<PublicDemoConfig>(
                    future: _publicDemoConfigFuture,
                    builder: (context, snapshot) {
                      final config =
                          snapshot.data ?? PublicDemoConfig.defaults();
                      return AppWorkspaceCard(
                        title: 'Demo publico',
                        subtitle:
                            'Define o ambiente demo publico. Por padrao, o sistema usa um workspace ficticio do Ponto Certo, sem expor dados reais.',
                        trailing: shellTapFriendly(
                          OutlinedButton.icon(
                            onPressed: () => _editPublicDemoConfig(config),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Configurar demo'),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailLine(
                              'Status',
                              config.enabled ? 'Ativo' : 'Desligado',
                            ),
                            _DetailLine(
                              'Demo empresa',
                              '${config.ownerDisplayName} | companyId: ${config.ownerCompanyId.isNotEmpty ? config.ownerCompanyId : 'public_demo_workspace'}',
                            ),
                            _DetailLine(
                              'Demo contador',
                              '${config.accountantDisplayName} | companyId: ${config.accountantCompanyId.isNotEmpty ? config.accountantCompanyId : 'public_demo_workspace'}',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (s == PlatformAdminSection.financeiro) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<PlatformSalesPipelineSnapshot>(
                    future: _salesPipelineFuture,
                    builder: (context, snapshot) {
                      final pipeline =
                          snapshot.data ??
                          const PlatformSalesPipelineSnapshot(
                            leads: <PlatformSalesLeadSummary>[],
                            onboardings: <PlatformSalesOnboardingSummary>[],
                            employeeTesterLeads:
                                <PlatformEmployeeTesterLeadSummary>[],
                            productIdeas: <PlatformProductIdeaSummary>[],
                            governanceIssues:
                                <PlatformGovernanceIssueSummary>[],
                          );
                      return AppWorkspaceCard(
                        title: 'Pipeline comercial',
                        subtitle:
                            'Acompanhe pre-cadastros, implantacoes guiadas e gere a cobranca de implantacao quando a implantacao for feita pela plataforma.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                AppMetricCard(
                                  label: 'Pre-cadastros',
                                  value: pipeline.leads.length.toString(),
                                  caption: 'Leads recentes',
                                ),
                                AppMetricCard(
                                  label: 'Implantacoes',
                                  value: pipeline.onboardings.length.toString(),
                                  caption: 'Cadastros em andamento',
                                ),
                                AppMetricCard(
                                  label: 'Cobranca pendente',
                                  value: pipeline.onboardings
                                      .where(
                                        (e) =>
                                            e.implementationMode !=
                                                'accountant' &&
                                            e.status == 'submitted' &&
                                            e
                                                .implementationChargePaymentId
                                                .isEmpty,
                                      )
                                      .length
                                      .toString(),
                                  caption: 'Implantacoes para cobrar',
                                ),
                                AppMetricCard(
                                  label: 'Testadores',
                                  value: pipeline.employeeTesterLeads.length
                                      .toString(),
                                  caption: 'Fila Play Store',
                                ),
                                AppMetricCard(
                                  label: 'Alertas governanca',
                                  value: pipeline.governanceIssues.length
                                      .toString(),
                                  caption: 'Cadastros/Asaas para revisar',
                                ),
                              ],
                            ),
                            if (pipeline.governanceIssues.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Alertas de governanca',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppBrandColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final issue
                                  in pipeline.governanceIssues.take(8))
                                _GovernanceIssueCard(issue: issue),
                            ],
                            const SizedBox(height: 16),
                            const Text(
                              'Pre-cadastros recentes',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (pipeline.leads.isEmpty)
                              const Text('Nenhum pre-cadastro recente.')
                            else
                              for (final item in pipeline.leads.take(8))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _DetailLine(
                                    '${item.customerName.isNotEmpty ? item.customerName : item.customerEmail} | ${item.planTitle}',
                                    '${item.status} | ${item.implementationMode == 'accountant' ? 'contador' : 'plataforma'}${item.accountantEmail.isNotEmpty ? ' | contador: ${item.accountantEmail}' : ''}',
                                  ),
                                ),
                            const SizedBox(height: 12),
                            const Text(
                              'Implantacoes recentes',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (pipeline.onboardings.isEmpty)
                              const Text('Nenhuma implantacao recente.')
                            else
                              for (final item in pipeline.onboardings.take(
                                8,
                              )) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppBrandColors.border,
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.legalName.isNotEmpty ? item.legalName : item.customerName} | ${item.planTitle}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppBrandColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${item.status} | ${item.implementationMode == 'accountant' ? 'contador' : 'plataforma'}',
                                      ),
                                      Text(
                                        platformSalesLifecycleLabel(item),
                                        style: const TextStyle(
                                          color: AppBrandColors.softText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (item.status ==
                                          'operational_company_created') ...[
                                        if (item.companyName.isNotEmpty ||
                                            item.companyId.isNotEmpty)
                                          Text(
                                            'Empresa criada: ${item.companyName.isNotEmpty ? item.companyName : item.companyId}',
                                          ),
                                        if (item.accountantEmail.isNotEmpty)
                                          Text(
                                            'Contador: ${item.accountantName.isNotEmpty ? item.accountantName : item.accountantEmail} | ${item.accountantEmail}',
                                          ),
                                        if (item.archivedCompanyPath.isNotEmpty)
                                          Text(
                                            'Pasta da empresa: ${item.archivedCompanyPath}',
                                          ),
                                      ] else ...[
                                        Text('Uploads: ${item.uploadedCount}'),
                                        if (item.city.isNotEmpty ||
                                            item.state.isNotEmpty)
                                          Text(
                                            'Cidade: ${item.city}/${item.state}',
                                          ),
                                      ],
                                      if (item
                                          .implementationChargePaymentId
                                          .isNotEmpty)
                                        Text(
                                          'Cobranca implantacao: ${item.implementationChargeStatus.isNotEmpty ? item.implementationChargeStatus : item.implementationChargePaymentId}',
                                        ),
                                      if (item
                                          .implementationChargeAutomationError
                                          .isNotEmpty)
                                        Text(
                                          'Alerta cobranca: ${item.implementationChargeAutomationError}',
                                          style: const TextStyle(
                                            color: Color(0xFFB71C1C),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (item.status == 'submitted')
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  _finalizeSalesOnboarding(
                                                    item,
                                                  ),
                                              icon: const Icon(
                                                Icons.domain_add_outlined,
                                              ),
                                              label: const Text(
                                                'Concluir implantacao e criar empresa',
                                              ),
                                            ),
                                          if (item.implementationMode !=
                                                  'accountant' &&
                                              item.status !=
                                                  'operational_company_created' &&
                                              item
                                                  .implementationChargePaymentId
                                                  .isEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _generateImplementationCharge(
                                                    item,
                                                  ),
                                              icon: const Icon(
                                                Icons.receipt_long_outlined,
                                              ),
                                              label: const Text(
                                                'Gerar cobranca manual',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            const SizedBox(height: 12),
                            const Text(
                              'Testadores Play Store',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (pipeline.employeeTesterLeads.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _copyTesterEmails(
                                        pipeline.employeeTesterLeads,
                                      ),
                                      icon: const Icon(Icons.copy_all_outlined),
                                      label: const Text(
                                        'Copiar todos os emails',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (pipeline.employeeTesterLeads.isNotEmpty)
                              const SizedBox(height: 8),
                            if (pipeline.employeeTesterLeads.isEmpty)
                              const Text('Nenhum testador recente.')
                            else
                              for (final item
                                  in pipeline.employeeTesterLeads.take(12))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _testerStageColor(
                                        item,
                                      ).withValues(alpha: 0.35),
                                    ),
                                    color: _testerStageColor(
                                      item,
                                    ).withValues(alpha: 0.08),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.fullName.isNotEmpty
                                                      ? item.fullName
                                                      : item.email,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: AppBrandColors.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                SelectableText(
                                                  item.email,
                                                  style: const TextStyle(
                                                    color: AppBrandColors.ink,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _testerStageColor(item),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _testerStageLabel(item),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        children: [
                                          if (item.phone.isNotEmpty)
                                            Text('Telefone: ${item.phone}'),
                                          if (item.city.isNotEmpty ||
                                              item.state.isNotEmpty)
                                            Text(
                                              'Cidade: ${item.city}${item.state.isNotEmpty ? '/${item.state}' : ''}',
                                            ),
                                          if (item.occupation.isNotEmpty)
                                            Text('Perfil: ${item.occupation}'),
                                          Text(
                                            'Origem: ${_formatMarketingKey(item.sourceBucket.isNotEmpty ? item.sourceBucket : item.utmSource)}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        children: [
                                          Text(
                                            'Entrada: ${_formatIsoDate(item.createdAt)}',
                                          ),
                                          if (item
                                              .playStoreTesterIncludedAt
                                              .isNotEmpty)
                                            Text(
                                              'Play Store marcada: ${_formatIsoDate(item.playStoreTesterIncludedAt)}',
                                            ),
                                          if (item
                                              .playStoreReleasedAt
                                              .isNotEmpty)
                                            Text(
                                              'Acesso teste: ${_formatIsoDate(item.playStoreReleasedAt)}',
                                            ),
                                          if (item
                                              .realAccessReleasedAt
                                              .isNotEmpty)
                                            Text(
                                              'Ambiente real: ${_formatIsoDate(item.realAccessReleasedAt)}',
                                            ),
                                        ],
                                      ),
                                      if (item.testerUid.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text('UID: ${item.testerUid}'),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (item
                                              .playStoreTesterIncludedAt
                                              .isEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _markTesterPlayStoreIncluded(
                                                    item,
                                                  ),
                                              icon: const Icon(
                                                Icons
                                                    .playlist_add_check_circle_outlined,
                                              ),
                                              label: const Text(
                                                'Marcar na Play Store',
                                              ),
                                            ),
                                          if (item.testerUid.isEmpty)
                                            FilledButton.icon(
                                              onPressed:
                                                  item
                                                      .playStoreTesterIncludedAt
                                                      .isEmpty
                                                  ? null
                                                  : () => _releaseTesterAccess(
                                                      item,
                                                    ),
                                              icon: const Icon(
                                                Icons.mark_email_read_outlined,
                                              ),
                                              label: const Text(
                                                'Enviar acesso do teste',
                                              ),
                                            ),
                                          if (item.testerUid.isNotEmpty &&
                                              item.realAccessReleasedAt.isEmpty)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _releaseTesterRealAccess(
                                                    item,
                                                  ),
                                              icon: const Icon(
                                                Icons.open_in_new_outlined,
                                              ),
                                              label: const Text(
                                                'Liberar ambiente real',
                                              ),
                                            ),
                                          if (item.testerUid.isNotEmpty)
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _showTesterUsageSummary(item),
                                              icon: const Icon(
                                                Icons.insights_outlined,
                                              ),
                                              label: const Text(
                                                'Resumo de uso',
                                              ),
                                            ),
                                          TextButton.icon(
                                            onPressed: () =>
                                                _copyTesterEmail(item.email),
                                            icon: const Icon(
                                              Icons.copy_outlined,
                                            ),
                                            label: const Text('Copiar email'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 16),
                            const Text(
                              'Ideias do produto',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (pipeline.productIdeas.isEmpty)
                              const Text(
                                'Nenhuma ideia recente registrada pelos usuarios.',
                              )
                            else ...[
                              AppHorizontalCardGrid(
                                minItemWidth: 180,
                                maxColumns: 4,
                                children: [
                                  AppMetricCard(
                                    label: 'Ideias',
                                    value: pipeline.productIdeas.length
                                        .toString(),
                                    caption: 'Painel supremo',
                                  ),
                                  AppMetricCard(
                                    label: 'Testadores',
                                    value: pipeline.productIdeas
                                        .where((item) => _isTesterIdea(item))
                                        .length
                                        .toString(),
                                    caption: 'Play Store e homologacao',
                                  ),
                                  AppMetricCard(
                                    label: 'Empresas',
                                    value: pipeline.productIdeas
                                        .where(
                                          (item) =>
                                              _ideaAudience(item) == 'Empresa',
                                        )
                                        .length
                                        .toString(),
                                    caption: 'Owners e gestores',
                                  ),
                                  AppMetricCard(
                                    label: 'Equipe',
                                    value: pipeline.productIdeas
                                        .where(
                                          (item) =>
                                              _ideaAudience(item) ==
                                              'Funcionario',
                                        )
                                        .length
                                        .toString(),
                                    caption: 'Fluxo operacional',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AppHorizontalCardGrid(
                                minItemWidth: 300,
                                maxColumns: 2,
                                children: [
                                  for (final item in pipeline.productIdeas.take(
                                    24,
                                  ))
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppBrandColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title.isNotEmpty
                                                          ? item.title
                                                          : 'Ideia registrada',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            AppBrandColors.ink,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${item.companyName.isNotEmpty ? item.companyName : item.companyId} | ${item.module.isNotEmpty ? item.module : 'Outro'}',
                                                      style: const TextStyle(
                                                        color: AppBrandColors
                                                            .softText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _ideaStatusColor(
                                                    item.status,
                                                  ).withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  _ideaStatusLabel(item.status),
                                                  style: TextStyle(
                                                    color: _ideaStatusColor(
                                                      item.status,
                                                    ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              AppHeaderChip(
                                                _ideaAudience(item),
                                              ),
                                              AppHeaderChip(
                                                'Prioridade ${_ideaPriorityLabel(item.priority)}',
                                              ),
                                              if (item.issueStatus.isNotEmpty)
                                                AppHeaderChip(
                                                  'Pasta ${_ideaIssueStatusLabel(item.issueStatus)}',
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Usuario: ${item.userName.isNotEmpty ? item.userName : '-'}${item.userEmail.isNotEmpty ? ' | ${item.userEmail}' : ''}',
                                          ),
                                          if (item.context.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Dor atual: ${item.context}',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (item.idea.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Melhoria: ${item.idea}',
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (item
                                              .assistantSummary
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              'Resumo assistente: ${item.assistantSummary}',
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppBrandColors.softText,
                                              ),
                                            ),
                                          ],
                                          if (item
                                              .recommendedAction
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Direcionamento: ${item.recommendedAction}',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppBrandColors.ink,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 8,
                                            children: [
                                              Text(
                                                'Atualizada: ${_formatIsoDate(item.updatedAt)}',
                                              ),
                                              if (item.incidentId.isNotEmpty)
                                                Text('Observabilidade ligada'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (s == PlatformAdminSection.convidar) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<PlatformMarketingDashboard>(
                    future: _marketingDashboardFuture,
                    builder: (context, snapshot) {
                      final dashboard =
                          snapshot.data ??
                          const PlatformMarketingDashboard(
                            days: 30,
                            metrics: PlatformMarketingMetrics(
                              visitors: 0,
                              sessions: 0,
                              salesViews: 0,
                              preregViews: 0,
                              planSelects: 0,
                              preregSubmits: 0,
                              companyLightPreregistrationViews: 0,
                              companyLightPreregistrationSubmits: 0,
                              hotVisitors: 0,
                              recurringVisitors: 0,
                              demoVisitors: 0,
                              demoCompanyUnique: 0,
                              demoAccountantUnique: 0,
                              demoOpenCount: 0,
                              preregConversionRate: 0,
                              planSelectRate: 0,
                            ),
                            topSources: <PlatformMarketingCount>[],
                            topCampaigns: <PlatformMarketingCount>[],
                            topPlans: <PlatformMarketingCount>[],
                            recentLeads: <PlatformMarketingLead>[],
                          );
                      return AppWorkspaceCard(
                        title: 'Inteligencia comercial',
                        subtitle:
                            'Convites e entradas publicas: demos, pre-cadastros empresa e contador e contactos vindos das rotas da pagina publica. Para remarketing e perfil no Instagram, a proxima etapa e ligar Meta/Google.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                AppMetricCard(
                                  label: 'Visitantes',
                                  value: dashboard.metrics.visitors.toString(),
                                  caption: 'Ultimos ${dashboard.days} dias',
                                ),
                                AppMetricCard(
                                  label: 'Sessoes',
                                  value: dashboard.metrics.sessions.toString(),
                                  caption: 'Navegacoes registradas',
                                ),
                                AppMetricCard(
                                  label: 'Leads enviados',
                                  value: dashboard.metrics.preregSubmits
                                      .toString(),
                                  caption: _formatRatio(
                                    dashboard.metrics.preregConversionRate,
                                  ),
                                ),
                                AppMetricCard(
                                  label: 'Visitantes quentes',
                                  value: dashboard.metrics.hotVisitors
                                      .toString(),
                                  caption: 'Score alto de compra',
                                ),
                                AppMetricCard(
                                  label: 'Recorrentes',
                                  value: dashboard.metrics.recurringVisitors
                                      .toString(),
                                  caption: 'Voltaram pelo menos 2 vezes',
                                ),
                                AppMetricCard(
                                  label: 'Demo unicos',
                                  value: dashboard.metrics.demoVisitors
                                      .toString(),
                                  caption: 'Dispositivos unicos no demo',
                                ),
                                AppMetricCard(
                                  label: 'Demo empresa',
                                  value: dashboard.metrics.demoCompanyUnique
                                      .toString(),
                                  caption: 'Entradas unicas no perfil empresa',
                                ),
                                AppMetricCard(
                                  label: 'Demo contador',
                                  value: dashboard.metrics.demoAccountantUnique
                                      .toString(),
                                  caption:
                                      'Entradas unicas no perfil contador',
                                ),
                                AppMetricCard(
                                  label: 'Aberturas demo',
                                  value: dashboard.metrics.demoOpenCount
                                      .toString(),
                                  caption:
                                      'Acessos totais registrados no demo',
                                ),
                                AppMetricCard(
                                  label: 'Visualizacoes pre-cadastro empresa',
                                  value: dashboard
                                      .metrics
                                      .companyLightPreregistrationViews
                                      .toString(),
                                  caption: kPublicPreCadastroEmpresaPath,
                                ),
                                AppMetricCard(
                                  label: 'Leads empresa leve',
                                  value: dashboard
                                      .metrics
                                      .companyLightPreregistrationSubmits
                                      .toString(),
                                  caption: 'Conta criada',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (dashboard.topSources.isNotEmpty) ...[
                              const Text(
                                'Origens que mais trouxeram visita',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppBrandColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final item in dashboard.topSources)
                                _DetailLine(
                                  _formatMarketingKey(item.key),
                                  '${item.count} evento(s)',
                                ),
                              const SizedBox(height: 12),
                            ],
                            if (dashboard.topCampaigns.isNotEmpty) ...[
                              const Text(
                                'Campanhas com mais movimento',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppBrandColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final item in dashboard.topCampaigns)
                                _DetailLine(
                                  _formatMarketingKey(item.key),
                                  '${item.count} evento(s)',
                                ),
                              const SizedBox(height: 12),
                            ],
                            const Text(
                              'Leads recentes com origem',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (dashboard.recentLeads.isEmpty)
                              const Text(
                                'Nenhum lead recente com rastreio ainda.',
                              )
                            else
                              for (final item in dashboard.recentLeads)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _DetailLine(
                                    '${item.customerName.isNotEmpty ? item.customerName : item.customerEmail} | ${item.planCode}',
                                    '${item.status} | origem: ${_formatMarketingKey(item.sourceBucket.isNotEmpty ? item.sourceBucket : item.utmSource)}${item.utmCampaign.isNotEmpty ? ' | campanha: ${item.utmCampaign}' : ''}',
                                  ),
                                ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (s == PlatformAdminSection.financeiro ||
                    s == PlatformAdminSection.integracoes) ...[
                  const SizedBox(height: 12),
                  AppDesktopSplit(
                    sidebarFlex: 12,
                    contentFlex: 15,
                    spacing: 12,
                    sidebar: AppWorkspaceCard(
                      title: 'Empresas cadastradas',
                      subtitle: s == PlatformAdminSection.integracoes
                          ? 'Selecione uma empresa para operacao fiscal e integracao Focus (configurar / editar).'
                          : 'Cobranca, plano e Asaas: gestao comercial da empresa cliente da plataforma (nao e o /finance interno).',
                      child: items.isEmpty
                          ? const Text('Nenhuma empresa encontrada.')
                          : Column(
                              children: [
                                for (final item in items) ...[
                                  _CompanyListTile(
                                    item: item,
                                    selected:
                                        item.companyId == selected?.companyId,
                                    onTap: () => setState(() {
                                      _selectedCompanyId = item.companyId;
                                      if (s ==
                                          PlatformAdminSection.integracoes) {
                                        _fiscalStatusFuture = _service
                                            .getCompanyFiscalStatus(
                                              companyId: item.companyId,
                                            );
                                      } else {
                                        _fiscalStatusFuture = null;
                                      }
                                    }),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                    ),
                    content: selected == null
                        ? const AppWorkspaceCard(
                            title: 'Empresa nao selecionada',
                            child: Text('Selecione uma empresa na lista.'),
                          )
                        : s == PlatformAdminSection.financeiro
                        ? _CompanyDetailCard(
                            item: selected,
                            onEdit: () => _editCompany(selected),
                            onIssueCode: () => _issueActivationCode(selected),
                            onProvisionAsaas: () => _provisionAsaas(selected),
                            onBlock: () => _quickUpdate(
                              item: selected,
                              allowLogin: false,
                              lifecycleStatus: 'blocked',
                              note:
                                  'Bloqueio operacional aplicado pela plataforma.',
                            ),
                            onRelease: () => _quickUpdate(
                              item: selected,
                              allowLogin: true,
                              lifecycleStatus: 'active',
                              note:
                                  'Liberacao aplicada novamente pela plataforma.',
                            ),
                          )
                        : FutureBuilder<PlatformFiscalCompanyStatus>(
                            future: _fiscalStatusFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const AppWorkspaceCard(
                                  title: 'Operacao fiscal',
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return AppWorkspaceCard(
                                  title: 'Operacao fiscal',
                                  subtitle: AppErrorMapper.messageFrom(
                                    snapshot.error!,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton.icon(
                                      onPressed: () => _reloadFiscalStatus(
                                        selected.companyId,
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Tentar novamente'),
                                    ),
                                  ),
                                );
                              }
                              final fiscal = snapshot.data;
                              if (fiscal == null) {
                                return const AppWorkspaceCard(
                                  title: 'Operacao fiscal',
                                  child: Text('Status fiscal indisponivel.'),
                                );
                              }
                              return _CompanyFiscalStatusCard(
                                item: selected,
                                fiscal: fiscal,
                                onRefresh: () =>
                                    _reloadFiscalStatus(selected.companyId),
                                onSyncFocus: () =>
                                    _syncFiscalCompanyFocus(selected),
                                onEditSetup: () =>
                                    _editFiscalSetup(selected, fiscal),
                                onManagePendings: () =>
                                    _manageFiscalPendings(selected, fiscal),
                                onRequestCompany: () =>
                                    _requestFiscalItemsByEmail(
                                      selected,
                                      fiscal,
                                    ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
      _publicSalesConfigFuture = _publicSalesConfigService.fetch();
      _publicDemoConfigFuture = _publicDemoConfigService.fetch();
      _salesPipelineFuture = _service.listSalesPipeline();
      _marketingDashboardFuture = _service.getMarketingDashboard();
      _trialInvitesFuture = _service.listTrialInvites(limit: 80);
      _accountingOfficesFuture = _listAccountingOfficesWithSearch();
      if (widget.section == PlatformAdminSection.integracoes &&
          _selectedCompanyId != null &&
          _selectedCompanyId!.isNotEmpty) {
        _fiscalStatusFuture = _service.getCompanyFiscalStatus(
          companyId: _selectedCompanyId!,
        );
      }
    });
  }

  void _reloadFiscalStatus(String companyId) {
    setState(() {
      _fiscalStatusFuture = _service.getCompanyFiscalStatus(
        companyId: companyId,
      );
    });
  }

  Future<void> _generateImplementationCharge(
    PlatformSalesOnboardingSummary item,
  ) async {
    try {
      final charge = await _service.generateImplementationCharge(
        requestId: item.id,
        implementationFeeCents: item.implementationFeeCents,
      );
      if (!mounted) return;
      _reload();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cobranca de implantacao gerada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment: ${charge.paymentId}'),
              Text('Valor: ${formatCents(charge.valueCents)}'),
              Text('Vencimento: ${charge.dueDate}'),
              if (charge.invoiceUrl.trim().isNotEmpty)
                SelectableText(charge.invoiceUrl),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _finalizeSalesOnboarding(
    PlatformSalesOnboardingSummary item,
  ) async {
    try {
      final finalized = await _service.finalizeSalesOnboarding(
        requestId: item.id,
      );
      if (!mounted) return;
      _reload();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Empresa operacional criada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Empresa: ${finalized.companyName}'),
              if (finalized.implementationCharge != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Boleto da implantacao gerado: ${formatCents(finalized.implementationCharge!.valueCents)}',
                ),
                Text('Vencimento: ${finalized.implementationCharge!.dueDate}'),
                if (finalized.implementationCharge!.invoiceUrl
                    .trim()
                    .isNotEmpty)
                  SelectableText(finalized.implementationCharge!.invoiceUrl),
              ],
              if (finalized.implementationChargeError.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Empresa criada, mas o boleto automatico falhou: ${finalized.implementationChargeError}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _quickUpdate({
    required PlatformCompanySummary item,
    required bool allowLogin,
    required String lifecycleStatus,
    required String note,
  }) async {
    try {
      await _service.updateCommercialSettings(
        companyId: item.companyId,
        plan: item.plan,
        businessTier: item.businessTier,
        lifecycleStatus: lifecycleStatus,
        billingStatus: item.billingStatus,
        approvalStatus: item.approvalStatus,
        allowLogin: allowLogin,
        requiresApproval: item.approvalStatus == 'pending',
        seatsIncluded: item.seatsIncluded,
        contractedAppUsers: item.contractedAppUsers,
        baseSystemPriceCents: item.baseSystemPriceCents,
        extraAppUserPriceCents: item.extraAppUserPriceCents,
        monthlyPriceCents: item.monthlyPriceCents,
        platformNote: note,
      );
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserMessage('Status comercial atualizado.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _editCompany(PlatformCompanySummary item) async {
    var plan = item.plan;
    var lifecycleStatus = item.lifecycleStatus;
    var billingStatus = item.billingStatus;
    var approvalStatus = item.approvalStatus;
    var allowLogin = item.allowLogin;
    var requiresApproval =
        item.approvalStatus != 'approved' &&
        item.approvalStatus != 'auto_approved';
    var billingProvider = item.billingProvider;
    var billingGatewayStatus = item.billingGatewayStatus;
    var billingAccessManagedByGateway = item.billingAccessManagedByGateway;
    var seatsIncluded = item.seatsIncluded;
    var contractedAppUsers = item.contractedAppUsers;
    final billingCustomerIdController = TextEditingController(
      text: item.billingCustomerId,
    );
    final billingSubscriptionIdController = TextEditingController(
      text: item.billingSubscriptionId,
    );
    final billingPaymentLinkUrlController = TextEditingController(
      text: item.billingPaymentLinkUrl,
    );
    final billingExternalReferenceController = TextEditingController(
      text: item.billingExternalReference.isNotEmpty
          ? item.billingExternalReference
          : item.companyId,
    );
    final billingGraceDaysController = TextEditingController(
      text: item.billingGraceDays.toString(),
    );
    final baseSystemPriceController = TextEditingController(
      text: item.baseSystemPriceCents.toString(),
    );
    final extraAppUserPriceController = TextEditingController(
      text: item.extraAppUserPriceCents.toString(),
    );
    final monthlyPriceController = TextEditingController(
      text: item.monthlyPriceCents.toString(),
    );
    final noteController = TextEditingController(text: item.platformNote);

    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final baseValue =
                int.tryParse(baseSystemPriceController.text.trim()) ?? 0;
            final extraValue =
                int.tryParse(extraAppUserPriceController.text.trim()) ?? 0;
            final additionalUsers = (contractedAppUsers - seatsIncluded).clamp(
              0,
              100000,
            );
            final calculatedTotal = baseValue + additionalUsers * extraValue;
            return AlertDialog(
              title: Text(
                item.companyName.isNotEmpty ? item.companyName : item.companyId,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: plan,
                      decoration: const InputDecoration(labelText: 'Plano'),
                      items: const [
                        DropdownMenuItem(value: 'solo', child: Text('Solo')),
                        DropdownMenuItem(
                          value: 'equipe',
                          child: Text('Equipe'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => plan = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        plan == 'solo'
                            ? 'Classificacao atual: MEI / Solo'
                            : 'Classificacao atual: Empresa / Equipe',
                        style: const TextStyle(
                          color: AppBrandColors.softText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: lifecycleStatus,
                      decoration: const InputDecoration(labelText: 'Ciclo'),
                      items: const [
                        DropdownMenuItem(value: 'trial', child: Text('Teste')),
                        DropdownMenuItem(value: 'active', child: Text('Ativa')),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspensa'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inativa'),
                        ),
                        DropdownMenuItem(
                          value: 'blocked',
                          child: Text('Bloqueada'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => lifecycleStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: approvalStatus,
                      decoration: const InputDecoration(labelText: 'Aprovacao'),
                      items: const [
                        DropdownMenuItem(
                          value: 'auto_approved',
                          child: Text('Auto aprovada'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Aprovada'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pendente'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejeitada'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => approvalStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: billingStatus,
                      decoration: const InputDecoration(
                        labelText: 'Faturamento',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'trialing',
                          child: Text('Em teste'),
                        ),
                        DropdownMenuItem(
                          value: 'paid',
                          child: Text('Pagamento confirmado'),
                        ),
                        DropdownMenuItem(value: 'due', child: Text('A vencer')),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text('Em atraso'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => billingStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: allowLogin,
                      onChanged: (value) =>
                          setDialogState(() => allowLogin = value),
                      title: const Text('Liberar login'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      value: requiresApproval,
                      onChanged: (value) =>
                          setDialogState(() => requiresApproval = value),
                      title: const Text('Exigir aprovacao'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: billingProvider,
                      decoration: const InputDecoration(
                        labelText: 'Meio de cobranca',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'manual',
                          child: Text('Manual'),
                        ),
                        DropdownMenuItem(value: 'asaas', child: Text('Asaas')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => billingProvider = value);
                        }
                      },
                    ),
                    SwitchListTile(
                      value: billingAccessManagedByGateway,
                      onChanged: (value) => setDialogState(
                        () => billingAccessManagedByGateway = value,
                      ),
                      title: const Text('Vincular acesso ao meio de cobranca'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: billingGatewayStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status da cobranca',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending_setup',
                          child: Text('Aguardando setup'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Pagamento confirmado'),
                        ),
                        DropdownMenuItem(
                          value: 'trialing',
                          child: Text('Teste'),
                        ),
                        DropdownMenuItem(
                          value: 'pending_payment',
                          child: Text('Boleto gerado'),
                        ),
                        DropdownMenuItem(
                          value: 'paid',
                          child: Text('Pagamento confirmado'),
                        ),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text('Em atraso'),
                        ),
                        DropdownMenuItem(
                          value: 'delinquent',
                          child: Text('Inadimplente'),
                        ),
                        DropdownMenuItem(
                          value: 'canceled',
                          child: Text('Cancelado'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => billingGatewayStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: billingCustomerIdController,
                      decoration: const InputDecoration(
                        labelText: 'Asaas customerId',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: billingSubscriptionIdController,
                      decoration: const InputDecoration(
                        labelText: 'Asaas subscriptionId',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: billingPaymentLinkUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Link de pagamento',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: billingExternalReferenceController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia externa',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: billingGraceDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carencia em dias',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: seatsIncluded,
                      decoration: const InputDecoration(
                        labelText: 'Acessos incluidos no plano',
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 acesso')),
                        DropdownMenuItem(value: 3, child: Text('3 acessos')),
                        DropdownMenuItem(value: 5, child: Text('5 acessos')),
                        DropdownMenuItem(value: 10, child: Text('10 acessos')),
                        DropdownMenuItem(value: 20, child: Text('20 acessos')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => seatsIncluded = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: contractedAppUsers,
                      decoration: const InputDecoration(
                        labelText: 'Acessos contratados',
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 acesso')),
                        DropdownMenuItem(value: 3, child: Text('3 acessos')),
                        DropdownMenuItem(value: 5, child: Text('5 acessos')),
                        DropdownMenuItem(value: 10, child: Text('10 acessos')),
                        DropdownMenuItem(value: 20, child: Text('20 acessos')),
                        DropdownMenuItem(value: 30, child: Text('30 acessos')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => contractedAppUsers = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseSystemPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor base do sistema em centavos',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: extraAppUserPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor por acesso extra em centavos',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: monthlyPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor mensal final em centavos',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Calculo sugerido: ${formatCents(calculatedTotal)}',
                        style: const TextStyle(
                          color: AppBrandColors.softText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observacao da plataforma',
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
                    await _service.updateCommercialSettings(
                      companyId: item.companyId,
                      plan: plan,
                      businessTier: plan == 'solo' ? 'mei' : 'empresa',
                      lifecycleStatus: lifecycleStatus,
                      billingStatus: billingStatus,
                      approvalStatus: approvalStatus,
                      allowLogin: allowLogin,
                      requiresApproval: requiresApproval,
                      billingProvider: billingProvider,
                      billingAccessManagedByGateway:
                          billingAccessManagedByGateway,
                      billingCustomerId: billingCustomerIdController.text
                          .trim(),
                      billingSubscriptionId: billingSubscriptionIdController
                          .text
                          .trim(),
                      billingPaymentLinkUrl: billingPaymentLinkUrlController
                          .text
                          .trim(),
                      billingExternalReference:
                          billingExternalReferenceController.text.trim(),
                      billingGatewayStatus: billingGatewayStatus,
                      billingGraceDays:
                          int.tryParse(
                            billingGraceDaysController.text.trim(),
                          ) ??
                          3,
                      seatsIncluded: seatsIncluded,
                      contractedAppUsers: contractedAppUsers,
                      baseSystemPriceCents:
                          int.tryParse(baseSystemPriceController.text.trim()) ??
                          0,
                      extraAppUserPriceCents:
                          int.tryParse(
                            extraAppUserPriceController.text.trim(),
                          ) ??
                          0,
                      monthlyPriceCents:
                          int.tryParse(monthlyPriceController.text.trim()) ?? 0,
                      platformNote: noteController.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserMessage('Configuracao comercial atualizada.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      baseSystemPriceController.dispose();
      billingCustomerIdController.dispose();
      billingSubscriptionIdController.dispose();
      billingPaymentLinkUrlController.dispose();
      billingExternalReferenceController.dispose();
      billingGraceDaysController.dispose();
      extraAppUserPriceController.dispose();
      monthlyPriceController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _issueActivationCode(PlatformCompanySummary item) async {
    try {
      final issued = await _service.issueActivationCode(
        companyId: item.companyId,
      );
      if (!mounted) return;
      _reload();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Codigo de liberacao emitido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Guarde este codigo agora. Ele so aparece completo nesta emissao.',
              ),
              const SizedBox(height: 12),
              SelectableText(
                issued.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppBrandColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text('Validade: ${_formatIsoDate(issued.expiresAtIso)}'),
              Text('Final: ${issued.codeLast4}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _provisionAsaas(PlatformCompanySummary item) async {
    var billingType = 'BOLETO';
    var cycle = 'MONTHLY';
    var nextDueDate = DateTime.now().add(const Duration(days: 1));
    final graceDaysController = TextEditingController(
      text: item.billingGraceDays.toString(),
    );
    final descriptionController = TextEditingController(
      text:
          'Plano ${item.plan} | ${item.companyName.isNotEmpty ? item.companyName : item.companyId}',
    );
    final externalReferenceController = TextEditingController(
      text: item.billingExternalReference.isNotEmpty
          ? item.billingExternalReference
          : item.companyId,
    );

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Provisionar Asaas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: billingType,
                    decoration: const InputDecoration(
                      labelText: 'Forma de cobranca',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BOLETO', child: Text('Boleto')),
                      DropdownMenuItem(value: 'PIX', child: Text('Pix')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => billingType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cycle,
                    decoration: const InputDecoration(labelText: 'Ciclo'),
                    items: const [
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Mensal')),
                      DropdownMenuItem(
                        value: 'QUARTERLY',
                        child: Text('Trimestral'),
                      ),
                      DropdownMenuItem(value: 'YEARLY', child: Text('Anual')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => cycle = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Primeiro vencimento'),
                    subtitle: Text(_formatDate(nextDueDate)),
                    trailing: IconButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          initialDate: nextDueDate,
                        );
                        if (picked != null) {
                          setDialogState(() => nextDueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: graceDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carencia em dias',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: externalReferenceController,
                    decoration: const InputDecoration(
                      labelText: 'External reference',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descricao'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Provisionar'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;

      final provisioned = await _service.provisionAsaasBilling(
        companyId: item.companyId,
        billingType: billingType,
        cycle: cycle,
        nextDueDate: _formatDate(nextDueDate),
        graceDays: int.tryParse(graceDaysController.text.trim()) ?? 3,
        description: descriptionController.text.trim(),
        externalReference: externalReferenceController.text.trim(),
      );
      if (!mounted) return;
      _reload();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Asaas provisionado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${provisioned.customerId}'),
              Text('Subscription: ${provisioned.subscriptionId}'),
              Text('Vencimento: ${provisioned.nextDueDate}'),
              if (provisioned.paymentLinkUrl.trim().isNotEmpty)
                SelectableText(
                  'Boleto / checkout: ${provisioned.paymentLinkUrl}',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      graceDaysController.dispose();
      descriptionController.dispose();
      externalReferenceController.dispose();
    }
  }

  Future<void> _editPublicSalesConfig(PublicSalesConfig config) async {
    final soloTitle = TextEditingController(text: config.planSolo.title);
    final soloPrice = TextEditingController(text: config.planSolo.priceLabel);
    final soloImplantation = TextEditingController(
      text: config.planSolo.implantationLabel,
    );
    final soloCheckout = TextEditingController(
      text: config.planSolo.checkoutUrl,
    );
    final equipeTitle = TextEditingController(text: config.planEquipe.title);
    final equipePrice = TextEditingController(
      text: config.planEquipe.priceLabel,
    );
    final equipeImplantation = TextEditingController(
      text: config.planEquipe.implantationLabel,
    );
    final equipeCheckout = TextEditingController(
      text: config.planEquipe.checkoutUrl,
    );
    final additionalTitle = TextEditingController(
      text: config.additionalAccess.title,
    );
    final additionalPrice = TextEditingController(
      text: config.additionalAccess.priceLabel,
    );
    final additionalImplantation = TextEditingController(
      text: config.additionalAccess.implantationLabel,
    );
    final additionalCheckout = TextEditingController(
      text: config.additionalAccess.checkoutUrl,
    );
    final metaPixelHead = TextEditingController(
      text: config.metaPixelHeadSnippet,
    );

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Editar landing publica'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _salesConfigField('Solo titulo', soloTitle),
                  _salesConfigField('Solo preco', soloPrice),
                  _salesConfigField('Solo implantacao', soloImplantation),
                  _salesConfigField('Solo checkout', soloCheckout),
                  const SizedBox(height: 12),
                  _salesConfigField('Equipe titulo', equipeTitle),
                  _salesConfigField('Equipe preco', equipePrice),
                  _salesConfigField('Equipe implantacao', equipeImplantation),
                  _salesConfigField('Equipe checkout', equipeCheckout),
                  const SizedBox(height: 12),
                  _salesConfigField('Adicional titulo', additionalTitle),
                  _salesConfigField('Adicional preco', additionalPrice),
                  _salesConfigField(
                    'Adicional implantacao',
                    additionalImplantation,
                  ),
                  _salesConfigField('Adicional checkout', additionalCheckout),
                  const SizedBox(height: 16),
                  const Text(
                    'Codigo de base do Meta Pixel (HTML no head do site web)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Apos salvar, e obrigatorio publicar: (1) Cloud Functions, (2) o site web (flutter build web + deploy do Hosting). Enquanto nao fizer o deploy, o pixel nao aparece no site publico, mesmo com esta mensagem de sucesso.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No guia do Meta, copie o trecho de instalacao; ele deve ficar no head da pagina, como se fosse colado no index.html, entre abertura e fechamento do head. Se ja existir outro codigo nesse bloco, coloque o pixel abaixo dele e acima de fechar o head. Aqui, ao salvar, o app web aplica isso de forma equivalente (na primeira carga, em todas as rotas do mesmo site). Ao colar um codigo novo por cima do que ja esta no campo, o conteudo anterior e substituido (nao soma duas vezes).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: metaPixelHead,
                    maxLength: 65535,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    inputFormatters: const [
                      ReplaceTrailingBlockPasteTextInputFormatter(),
                    ],
                    style: const TextStyle(
                      fontFamily: 'ui-monospace, monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cole o codigo (script e noscript do Events Manager)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final trechoMetaPixel = metaPixelHead.text;
      final saved = await _publicSalesConfigService.update(
        PublicSalesConfig(
          enabled: true,
          planSolo: PublicSalesPlan(
            title: soloTitle.text.trim(),
            priceLabel: soloPrice.text.trim(),
            implantationLabel: soloImplantation.text.trim(),
            checkoutUrl: soloCheckout.text.trim(),
          ),
          planEquipe: PublicSalesPlan(
            title: equipeTitle.text.trim(),
            priceLabel: equipePrice.text.trim(),
            implantationLabel: equipeImplantation.text.trim(),
            checkoutUrl: equipeCheckout.text.trim(),
          ),
          additionalAccess: PublicSalesPlan(
            title: additionalTitle.text.trim(),
            priceLabel: additionalPrice.text.trim(),
            implantationLabel: additionalImplantation.text.trim(),
            checkoutUrl: additionalCheckout.text.trim(),
          ),
          metaPixelHeadSnippet: trechoMetaPixel,
          updatedAtIso: '',
        ),
      );

      if (!mounted) return;
      if (trechoMetaPixel.trim().isNotEmpty &&
          saved.metaPixelHeadSnippet.trim().isEmpty) {
        if (context.mounted) {
          context.showUserError(
            'O codigo do pixel voltou vazio do servidor. Publique as Cloud Functions (firebase deploy --only functions) e salve de novo. No Firestore, confira platform_public / sales_page, campo metaPixelHeadSnippet.',
          );
        }
        _reload();
        return;
      }
      _reload();
      if (context.mounted) {
        context.showUserMessage('Landing publica atualizada.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      soloTitle.dispose();
      soloPrice.dispose();
      soloImplantation.dispose();
      soloCheckout.dispose();
      equipeTitle.dispose();
      equipePrice.dispose();
      equipeImplantation.dispose();
      equipeCheckout.dispose();
      additionalTitle.dispose();
      additionalPrice.dispose();
      additionalImplantation.dispose();
      additionalCheckout.dispose();
      metaPixelHead.dispose();
    }
  }

  Future<void> _editPublicDemoConfig(PublicDemoConfig config) async {
    final ownerCompanyId = TextEditingController(text: config.ownerCompanyId);
    final ownerDisplayName = TextEditingController(
      text: config.ownerDisplayName,
    );
    final accountantCompanyId = TextEditingController(
      text: config.accountantCompanyId,
    );
    final accountantDisplayName = TextEditingController(
      text: config.accountantDisplayName,
    );
    bool enabled = config.enabled;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Configurar demo publico'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      value: enabled,
                      onChanged: (value) =>
                          setStateDialog(() => enabled = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Demo publico ativo'),
                      subtitle: const Text(
                        'Quando desligado, os botoes continuam visiveis, mas o acesso nao abre sessao demo.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _salesConfigField('Empresa demo - companyId', ownerCompanyId),
                    _salesConfigField('Empresa demo - nome exibido', ownerDisplayName),
                    const SizedBox(height: 12),
                    _salesConfigField(
                      'Contador demo - companyId',
                      accountantCompanyId,
                    ),
                    _salesConfigField(
                      'Contador demo - nome exibido',
                      accountantDisplayName,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Se os companyId ficarem vazios, o backend usa automaticamente o workspace ficticio do Ponto Certo. So preencha esses campos se quiser apontar o demo para outro ambiente controlado. O acesso demo continua somente leitura.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;

      await _publicDemoConfigService.update(
        PublicDemoConfig(
          enabled: enabled,
          ownerUid: config.ownerUid,
          ownerCompanyId: ownerCompanyId.text.trim(),
          ownerDisplayName: ownerDisplayName.text.trim(),
          accountantUid: config.accountantUid,
          accountantCompanyId: accountantCompanyId.text.trim(),
          accountantDisplayName: accountantDisplayName.text.trim(),
        ),
      );

      if (!mounted) return;
      _reload();
      context.showUserSuccess('Configuracao do demo publico salva.');
    } catch (error) {
      if (!mounted) return;
      context.showUserError(AppErrorMapper.messageFrom(error));
    } finally {
      ownerCompanyId.dispose();
      ownerDisplayName.dispose();
      accountantCompanyId.dispose();
      accountantDisplayName.dispose();
    }
  }

  Widget _salesConfigField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _editFiscalSetup(
    PlatformCompanySummary item,
    PlatformFiscalCompanyStatus fiscal,
  ) async {
    final registrationController = TextEditingController();
    final cityController = TextEditingController(text: fiscal.city);
    final stateController = TextEditingController(text: fiscal.state);
    final municipalProviderController = TextEditingController(
      text: fiscal.fiscalProvider,
    );
    final environmentController = TextEditingController(
      text: fiscal.fiscalEnvironment,
    );
    final focusApiController = TextEditingController(text: fiscal.focusNfseApi);
    final municipalCodeController = TextEditingController(
      text: fiscal.municipalCode,
    );
    final certificateRefController = TextEditingController(
      text: fiscal.certificateRef,
    );
    final homologationController = TextEditingController(
      text: fiscal.lastHomologationNote,
    );
    final certificatePasswordController = TextEditingController();
    bool companyBaseReviewed = fiscal.pendingItems
        .where((item) => item.code == 'check_company_base')
        .isEmpty;
    bool certificateValidated = fiscal.pendingItems
        .where((item) => item.code == 'check_certificate')
        .isEmpty;
    bool matrixValidated = fiscal.pendingItems
        .where((item) => item.code == 'check_matrix')
        .isEmpty;
    bool providerConnectionValidated = fiscal.pendingItems
        .where((item) => item.code == 'check_provider_connection')
        .isEmpty;
    bool pilotInvoiceValidated = fiscal.pendingItems
        .where((item) => item.code == 'check_pilot_invoice')
        .isEmpty;
    bool productionAuthorized = fiscal.pendingItems
        .where((item) => item.code == 'check_production_authorization')
        .isEmpty;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Editar operacao fiscal'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cadastro base',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: registrationController,
                      decoration: const InputDecoration(
                        labelText: 'Inscricao municipal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stateController,
                      decoration: const InputDecoration(labelText: 'UF'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Integracao',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: municipalProviderController,
                      decoration: const InputDecoration(
                        labelText: 'Provedor fiscal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: environmentController,
                      decoration: const InputDecoration(
                        labelText: 'Ambiente fiscal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: focusApiController,
                      decoration: const InputDecoration(
                        labelText: 'Modalidade Focus',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: municipalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Codigo municipal/base',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: certificateRefController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia do certificado',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Token API Focus global: configurado na infraestrutura da plataforma '
                      '(nao exibido aqui). No cadastro da empresa cliente, deixe vazio para usar esse token padrao.',
                      style: TextStyle(height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: certificatePasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Senha do certificado',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: homologationController,
                      decoration: const InputDecoration(
                        labelText: 'Observacao de homologacao',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Checklist operacional',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    CheckboxListTile(
                      value: companyBaseReviewed,
                      onChanged: (value) => setModalState(() {
                        companyBaseReviewed = value ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cadastro base revisado'),
                    ),
                    CheckboxListTile(
                      value: certificateValidated,
                      onChanged: (value) => setModalState(() {
                        certificateValidated = value ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Certificado validado'),
                    ),
                    CheckboxListTile(
                      value: matrixValidated,
                      onChanged: (value) => setModalState(() {
                        matrixValidated = value ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Matriz fiscal validada'),
                    ),
                    CheckboxListTile(
                      value: providerConnectionValidated,
                      onChanged: (value) => setModalState(() {
                        providerConnectionValidated = value ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Conexao com provedor validada'),
                    ),
                    CheckboxListTile(
                      value: pilotInvoiceValidated,
                      onChanged: (value) => setModalState(() {
                        pilotInvoiceValidated = value ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Emissao piloto validada'),
                    ),
                    CheckboxListTile(
                      value: productionAuthorized,
                      onChanged: (value) => setModalState(() {
                        productionAuthorized = value ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Producao autorizada'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await _service.updateCompanyFiscalStatus(
        companyId: item.companyId,
        companyDataPatch: {
          'inscricaoMunicipal': registrationController.text.trim(),
          'cidade': cityController.text.trim(),
          'estado': stateController.text.trim(),
        },
        integrationPatch: {
          'provider': municipalProviderController.text.trim(),
          'environment': environmentController.text.trim(),
          'focusNfseApi': focusApiController.text.trim(),
          'municipalCode': municipalCodeController.text.trim(),
          'certificateRef': certificateRefController.text.trim(),
          'lastHomologationNote': homologationController.text.trim(),
        },
        checklistPatch: {
          'companyBaseReviewed': companyBaseReviewed,
          'certificateValidated': certificateValidated,
          'matrixValidated': matrixValidated,
          'providerConnectionValidated': providerConnectionValidated,
          'pilotInvoiceValidated': pilotInvoiceValidated,
          'productionAuthorized': productionAuthorized,
        },
        securePatch: {
          'certificatePassword': certificatePasswordController.text.trim(),
        },
      );
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserMessage('Operacao fiscal atualizada.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      registrationController.dispose();
      cityController.dispose();
      stateController.dispose();
      municipalProviderController.dispose();
      environmentController.dispose();
      focusApiController.dispose();
      municipalCodeController.dispose();
      certificateRefController.dispose();
      homologationController.dispose();
      certificatePasswordController.dispose();
    }
  }

  Future<void> _manageFiscalPendings(
    PlatformCompanySummary item,
    PlatformFiscalCompanyStatus fiscal,
  ) async {
    final pending = fiscal.pendingItems
        .map(
          (entry) => {
            'code': entry.code,
            'title': entry.title,
            'owner': entry.owner,
            'status': entry.status,
            'note': entry.note,
            'documentRequired': entry.documentRequired,
          },
        )
        .toList();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Gerenciar pendencias fiscais'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in pending) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppBrandColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry['title']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  entry['owner']?.toString().isNotEmpty == true
                                  ? entry['owner']!.toString()
                                  : 'company',
                              decoration: const InputDecoration(
                                labelText: 'Responsavel pela correcao',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'company',
                                  child: Text('Empresa'),
                                ),
                                DropdownMenuItem(
                                  value: 'platform',
                                  child: Text('Plataforma'),
                                ),
                                DropdownMenuItem(
                                  value: 'accountant',
                                  child: Text('Contador'),
                                ),
                              ],
                              onChanged: (value) => setModalState(() {
                                entry['owner'] = value ?? 'company';
                              }),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  entry['status']?.toString().isNotEmpty == true
                                  ? entry['status']!.toString()
                                  : 'pending',
                              decoration: const InputDecoration(
                                labelText: 'Status operacional',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pendente'),
                                ),
                                DropdownMenuItem(
                                  value: 'in_progress',
                                  child: Text('Em andamento'),
                                ),
                                DropdownMenuItem(
                                  value: 'awaiting_company',
                                  child: Text('Aguardando empresa'),
                                ),
                                DropdownMenuItem(
                                  value: 'resolved',
                                  child: Text('Resolvido'),
                                ),
                              ],
                              onChanged: (value) => setModalState(() {
                                entry['status'] = value ?? 'pending';
                              }),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: entry['note']?.toString() ?? '',
                              decoration: InputDecoration(
                                labelText: entry['documentRequired'] == true
                                    ? 'Observacao interna / documento solicitado'
                                    : 'Observacao interna',
                              ),
                              minLines: 1,
                              maxLines: 3,
                              onChanged: (value) => entry['note'] = value,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salvar pendencias'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await _service.updateCompanyFiscalStatus(
        companyId: item.companyId,
        pendingItems: pending
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(),
      );
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserMessage('Pendencias fiscais atualizadas.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _requestFiscalItemsByEmail(
    PlatformCompanySummary item,
    PlatformFiscalCompanyStatus fiscal,
  ) async {
    final messageController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Solicitar pendencias por e-mail'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O e-mail sera enviado automaticamente para ${fiscal.ownerEmail}.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Observacao adicional',
                    helperText:
                        'Opcional. Use para contextualizar o que a empresa precisa enviar.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enviar agora'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _service.updateCompanyFiscalStatus(
        companyId: item.companyId,
        sendPendingEmail: true,
        customMessage: messageController.text.trim(),
      );
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserSuccess(
          'Pendencias fiscais enviadas por e-mail para a empresa.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    } finally {
      messageController.dispose();
    }
  }

  Future<void> _syncFiscalCompanyFocus(PlatformCompanySummary item) async {
    try {
      await _service.syncCompanyFocus(companyId: item.companyId);
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserSuccess(
          'Empresa sincronizada com a Focus pela suprema.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _markTesterPlayStoreIncluded(
    PlatformEmployeeTesterLeadSummary item,
  ) async {
    try {
      await _service.markEmployeeTesterPlayStoreIncluded(leadId: item.id);
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserSuccess('Lead marcado como incluido na Play Store.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _releaseTesterAccess(
    PlatformEmployeeTesterLeadSummary item,
  ) async {
    try {
      await _service.releaseEmployeeTesterAccess(leadId: item.id);
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserMessage('Acesso do teste enviado ao testador.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _releaseTesterRealAccess(
    PlatformEmployeeTesterLeadSummary item,
  ) async {
    try {
      await _service.releaseEmployeeTesterRealAccess(leadId: item.id);
      if (!mounted) return;
      _reload();
      if (context.mounted) {
        context.showUserSuccess('Ambiente real liberado para o testador.');
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _showTesterUsageSummary(
    PlatformEmployeeTesterLeadSummary item,
  ) async {
    try {
      final summary = await _service.getEmployeeTesterUsageSummary(
        leadId: item.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            summary.fullName.isNotEmpty ? summary.fullName : summary.email,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(summary.email),
                  const SizedBox(height: 8),
                  Text('Status: ${summary.status}'),
                  Text(
                    'UID: ${summary.testerUid.isNotEmpty ? summary.testerUid : '-'}',
                  ),
                  Text(
                    'Ultimo login: ${_formatIsoDate(summary.authLastSignInAt)}',
                  ),
                  Text(
                    'Ultima atividade: ${_formatIsoDate(summary.lastActivityAt)}',
                  ),
                  Text(
                    'Consentimento do aparelho: ${summary.hasDeviceConsent ? 'sim' : 'nao'}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppMetricCard(
                        label: 'Tarefas',
                        value: summary.tasksCount.toString(),
                        caption: 'Rotina',
                      ),
                      AppMetricCard(
                        label: 'OS',
                        value: summary.serviceOrdersCount.toString(),
                        caption: 'Ordens de servico',
                      ),
                      AppMetricCard(
                        label: 'Ponto',
                        value: summary.punchesCount.toString(),
                        caption: 'Registros',
                      ),
                      AppMetricCard(
                        label: 'Justificativas',
                        value: summary.justificationsCount.toString(),
                        caption: 'Fluxo do funcionario',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(AppErrorMapper.messageFrom(error));
      }
    }
  }

  Future<void> _copyTesterEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: cleanEmail));
    if (!mounted) return;
    if (context.mounted) {
      context.showUserSuccess('Email copiado.');
    }
  }

  Future<void> _copyTesterEmails(
    List<PlatformEmployeeTesterLeadSummary> items,
  ) async {
    final emails = items
        .map((item) => item.email.trim())
        .where((email) => email.isNotEmpty)
        .toSet()
        .join('; ');
    if (emails.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: emails));
    if (!mounted) return;
    if (context.mounted) {
      context.showUserMessage('${items.length} emails copiados.');
    }
  }

  Color _testerStageColor(PlatformEmployeeTesterLeadSummary item) {
    if (item.realAccessReleasedAt.isNotEmpty) return const Color(0xFF047857);
    if (item.testerUid.isNotEmpty) return const Color(0xFF1D4ED8);
    if (item.playStoreTesterIncludedAt.isNotEmpty) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFFD97706);
  }

  String _testerStageLabel(PlatformEmployeeTesterLeadSummary item) {
    if (item.realAccessReleasedAt.isNotEmpty) return 'Ambiente real liberado';
    if (item.testerUid.isNotEmpty) return 'Teste liberado';
    if (item.playStoreTesterIncludedAt.isNotEmpty) {
      return 'Pronto para enviar acesso';
    }
    return 'Pendente de Play Store';
  }

  bool _isTesterIdea(PlatformProductIdeaSummary item) =>
      item.companyId == 'public_employee_testers';

  String _ideaAudience(PlatformProductIdeaSummary item) {
    if (_isTesterIdea(item)) return 'Testador';
    final role = item.userRole.trim().toLowerCase();
    if (role == 'owner' || role == 'manager') return 'Empresa';
    if (role == 'accountant' || role == 'contador') return 'Contador';
    return 'Funcionario';
  }

  String _ideaPriorityLabel(String value) {
    switch (value.trim().toLowerCase()) {
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

  String _ideaStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'planejado':
        return 'Planejada';
      case 'entregue':
        return 'Entregue';
      default:
        return 'Nova';
    }
  }

  Color _ideaStatusColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'planejado':
        return const Color(0xFFD97706);
      case 'entregue':
        return const Color(0xFF047857);
      default:
        return const Color(0xFF1D4ED8);
    }
  }

  String _ideaIssueStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'resolved':
        return 'Resolvida';
      case 'monitoring':
        return 'Monitorando';
      default:
        return 'Aberta';
    }
  }

  String _formatIsoDate(String value) {
    if (value.trim().isEmpty) return '-';
    return value.split('T').first;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatRatio(double value) {
    return '${(value * 100).toStringAsFixed(1)}% das sessoes';
  }

  String _formatMarketingKey(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return '-';
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

class _CompanyListTile extends StatelessWidget {
  const _CompanyListTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PlatformCompanySummary item;
  final bool selected;
  final VoidCallback onTap;

  bool get _hasPendingAccountantLink =>
      item.accountantOnboardingStatus == 'pending_accountant_link';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppBrandColors.primaryDeep
                : AppBrandColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.companyName.isNotEmpty ? item.companyName : item.companyId,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppBrandColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.lifecycleStatus == 'active'
                  ? 'Empresa operacional ativa'
                  : 'Empresa: ${platformLifecycleLabel(item.lifecycleStatus)}',
              style: const TextStyle(color: AppBrandColors.softText),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppHeaderChip('Plano ${item.plan}'),
                AppHeaderChip(
                  item.plan == 'solo' ? 'MEI / Solo' : 'Empresa / Equipe',
                ),
                AppHeaderChip(item.allowLogin ? 'Ativa' : 'Bloqueada'),
                if (item.activationRequired)
                  AppHeaderChip('Ativacao ${item.activationStatus}'),
                AppHeaderChip('Cobranca ${item.billingProvider}'),
                if (item.fiscalOverallStatus.isNotEmpty)
                  AppHeaderChip(
                    'Fiscal ${item.fiscalOverallStatus} (${item.fiscalPendingCount})',
                  ),
                if (_hasPendingAccountantLink)
                  const AppHeaderChip('Contador pendente'),
                AppHeaderChip('${item.contractedAppUsers} acessos'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyDetailCard extends StatelessWidget {
  const _CompanyDetailCard({
    required this.item,
    required this.onEdit,
    required this.onIssueCode,
    required this.onProvisionAsaas,
    required this.onBlock,
    required this.onRelease,
  });

  final PlatformCompanySummary item;
  final VoidCallback onEdit;
  final VoidCallback onIssueCode;
  final VoidCallback onProvisionAsaas;
  final VoidCallback onBlock;
  final VoidCallback onRelease;

  bool get _hasPendingAccountantLink =>
      item.accountantOnboardingStatus == 'pending_accountant_link';

  @override
  Widget build(BuildContext context) {
    final extraUsers = (item.contractedAppUsers - item.seatsIncluded).clamp(
      0,
      100000,
    );
    return AppWorkspaceCard(
      title: item.companyName.isNotEmpty ? item.companyName : item.companyId,
      subtitle:
          'Tela de gestao comercial desta empresa, com bloqueio, liberacao, plano e composicao de valor.',
      trailing: shellTapFriendly(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Editar'),
          ),
          OutlinedButton.icon(
            onPressed: onIssueCode,
            icon: const Icon(Icons.key_outlined),
            label: const Text('Emitir codigo'),
          ),
          OutlinedButton.icon(
            onPressed: onProvisionAsaas,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Provisionar Asaas'),
          ),
          if (item.allowLogin)
            OutlinedButton.icon(
              onPressed: onBlock,
              icon: const Icon(Icons.block_outlined),
              label: const Text('Bloquear'),
            ),
          if (!item.allowLogin)
            FilledButton.icon(
              onPressed: onRelease,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Liberar'),
            ),
        ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppHeaderChip('Plano ${item.plan}'),
              AppHeaderChip(
                item.plan == 'solo' ? 'MEI / Solo' : 'Empresa / Equipe',
              ),
              AppHeaderChip(
                'Ciclo ${platformLifecycleLabel(item.lifecycleStatus)}',
              ),
              AppHeaderChip('Aprovacao ${item.approvalStatus}'),
              if (item.activationRequired)
                AppHeaderChip('Ativacao ${item.activationStatus}'),
              AppHeaderChip(
                'Financeiro ${platformBillingStatusLabel(item.billingStatus)}',
              ),
              AppHeaderChip('Cobranca ${item.billingProvider}'),
              if (item.fiscalOverallStatus.isNotEmpty)
                AppHeaderChip(
                  'Fiscal ${item.fiscalOverallStatus} (${item.fiscalPendingCount})',
                ),
              if (_hasPendingAccountantLink)
                const AppHeaderChip('Contador pendente'),
              if (item.billingAccessManagedByGateway)
                AppHeaderChip('Acesso por pagamento'),
              AppHeaderChip(platformAccessLabel(item.allowLogin)),
            ],
          ),
          const SizedBox(height: 16),
          AppHorizontalCardGrid(
            minItemWidth: 220,
            maxColumns: 4,
            children: [
              AppMetricCard(
                label: 'Valor base',
                value: formatCents(item.baseSystemPriceCents),
                caption: 'Uso principal do sistema',
              ),
              AppMetricCard(
                label: 'Por acesso extra',
                value: formatCents(item.extraAppUserPriceCents),
                caption: 'Cada acesso adicional',
              ),
              AppMetricCard(
                label: 'Acessos contratados',
                value: item.contractedAppUsers.toString(),
                caption: '${item.seatsIncluded} incluidos no plano',
              ),
              AppMetricCard(
                label: 'Mensal calculado',
                value: formatCents(item.calculatedMonthlyPriceCents),
                caption: '$extraUsers acesso(s) extra(s)',
              ),
            ],
          ),
          if (_hasPendingAccountantLink) ...[
            const SizedBox(height: 12),
            const Text(
              'Contador aguardando vinculo',
              style: TextStyle(
                color: AppBrandColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _DetailLine(
              'Status',
              'Convite enviado e aguardando conclusao do vinculo do contador.',
            ),
            _DetailLine(
              'Contato',
              item.accountantOnboardingName.isNotEmpty
                  ? '${item.accountantOnboardingName} | ${item.accountantOnboardingEmail}'
                  : item.accountantOnboardingEmail,
            ),
          ],
          if (item.platformNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Observacao da plataforma',
              style: TextStyle(
                color: AppBrandColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.platformNote,
              style: const TextStyle(color: AppBrandColors.softText),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanyFiscalStatusCard extends StatelessWidget {
  const _CompanyFiscalStatusCard({
    required this.item,
    required this.fiscal,
    required this.onRefresh,
    required this.onSyncFocus,
    required this.onEditSetup,
    required this.onManagePendings,
    required this.onRequestCompany,
  });

  final PlatformCompanySummary item;
  final PlatformFiscalCompanyStatus fiscal;
  final VoidCallback onRefresh;
  final VoidCallback onSyncFocus;
  final VoidCallback onEditSetup;
  final VoidCallback onManagePendings;
  final VoidCallback onRequestCompany;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceCard(
      title: 'Operacao fiscal da empresa',
      subtitle:
          'Conferencia fiscal por empresa, com pendencias, dono da correcao e solicitacao automatica para a empresa quando faltar documento ou dado.',
      trailing: shellTapFriendly(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recarregar'),
            ),
          OutlinedButton.icon(
            onPressed: onSyncFocus,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Sincronizar Focus'),
          ),
          OutlinedButton.icon(
            onPressed: onEditSetup,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Editar setup'),
          ),
          OutlinedButton.icon(
            onPressed: onManagePendings,
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Gerenciar pendencias'),
          ),
          FilledButton.icon(
            onPressed: onRequestCompany,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Solicitar empresa'),
          ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppHeaderChip('Status ${_statusLabel(fiscal.overallStatus)}'),
              AppHeaderChip('Focus ${fiscal.focusProvisioningStatus}'),
              AppHeaderChip('${fiscal.pendingCount} pendencia(s)'),
              AppHeaderChip('${fiscal.documentPendingCount} doc(s)'),
              AppHeaderChip(
                'Checklist ${fiscal.checklistCompleted}/${fiscal.checklistTotal}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppHorizontalCardGrid(
            minItemWidth: 220,
            maxColumns: 4,
            children: [
              AppMetricCard(
                label: 'Pendencias',
                value: fiscal.pendingCount.toString(),
                caption: '${fiscal.criticalPendingCount} critica(s)',
              ),
              AppMetricCard(
                label: 'Documento',
                value: fiscal.documentPendingCount.toString(),
                caption: 'Solicitacoes para a empresa',
              ),
              AppMetricCard(
                label: 'Focus',
                value: fiscal.focusCompanyId.isEmpty ? '-' : 'OK',
                caption: fiscal.focusCompanyId.isEmpty
                    ? fiscal.focusProvisioningStatus
                    : fiscal.focusCompanyId,
              ),
              AppMetricCard(
                label: 'Certificado',
                value: fiscal.certificateFileName.isEmpty
                    ? 'Pendente'
                    : 'Enviado',
                caption: fiscal.certificateValidUntil.isEmpty
                    ? 'Validade pendente'
                    : fiscal.certificateValidUntil,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppHorizontalCardGrid(
            minItemWidth: 260,
            maxColumns: 2,
            children: [
              _DetailLine('Empresa', fiscal.companyName),
              _DetailLine(
                'Responsavel',
                '${fiscal.ownerName} | ${fiscal.ownerEmail}',
              ),
              _DetailLine(
                'Setup fiscal',
                '${fiscal.fiscalProvider.isEmpty ? 'provedor pendente' : fiscal.fiscalProvider} | ambiente ${fiscal.fiscalEnvironment.isEmpty ? 'pendente' : fiscal.fiscalEnvironment}',
              ),
              _DetailLine(
                'Codigo base',
                fiscal.municipalCode.isEmpty ? '-' : fiscal.municipalCode,
              ),
              _DetailLine(
                'Certificado',
                fiscal.certificateFileName.isEmpty
                    ? 'nao enviado'
                    : fiscal.certificateFileName,
              ),
              if (fiscal.lastPendingEmailAt.isNotEmpty)
                _DetailLine(
                  'Ultimo e-mail',
                  '${fiscal.lastPendingEmailAt.split('T').first} para ${fiscal.lastPendingEmailTo.isEmpty ? fiscal.ownerEmail : fiscal.lastPendingEmailTo}',
                ),
              if (fiscal.focusProvisioningError.isNotEmpty)
                _DetailLine('Erro da Focus', fiscal.focusProvisioningError),
            ],
          ),
          if (fiscal.pendingItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Pendencias atuais',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppBrandColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            AppHorizontalCardGrid(
              minItemWidth: 300,
              maxColumns: 2,
              children: [
                for (final pending in fiscal.pendingItems)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppBrandColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pending.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pending.description,
                          style: const TextStyle(
                            color: AppBrandColors.softText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppHeaderChip(
                              'Resp. ${_ownerLabel(pending.owner)}',
                            ),
                            AppHeaderChip(
                              'Status ${_pendingStatusLabel(pending.status)}',
                            ),
                            AppHeaderChip(
                              pending.documentRequired
                                  ? 'Documento'
                                  : pending.category,
                            ),
                            AppHeaderChip(_severityLabel(pending.severity)),
                          ],
                        ),
                        if (pending.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Observacao: ${pending.note}',
                            style: const TextStyle(
                              color: AppBrandColors.softText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Sem pendencias fiscais no momento.'),
            ),
        ],
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'READY':
        return 'Pronta';
      case 'BLOCKED':
        return 'Bloqueada';
      case 'ERROR':
        return 'Com erro';
      default:
        return 'Pendente';
    }
  }

  String _ownerLabel(String value) {
    switch (value) {
      case 'platform':
        return 'Plataforma';
      case 'accountant':
        return 'Contador';
      default:
        return 'Empresa';
    }
  }

  String _pendingStatusLabel(String value) {
    switch (value) {
      case 'in_progress':
        return 'Em andamento';
      case 'awaiting_company':
        return 'Aguardando empresa';
      case 'resolved':
        return 'Resolvido';
      default:
        return 'Pendente';
    }
  }

  String _severityLabel(String value) {
    switch (value) {
      case 'critical':
        return 'Critica';
      case 'medium':
        return 'Media';
      default:
        return 'Alta';
    }
  }
}

String platformLifecycleLabel(String raw) {
  final value = raw.trim().toLowerCase();
  return switch (value) {
    'trial' => 'Teste',
    'active' => 'Ativa',
    'blocked' => 'Bloqueada',
    'inactive' => 'Inativa',
    'suspended' => 'Suspensa',
    'awaiting_payment' => 'Boleto gerado',
    _ => value.isEmpty ? 'Nao definido' : raw,
  };
}

String platformBillingStatusLabel(String raw) {
  final value = raw.trim().toLowerCase();
  return switch (value) {
    'trialing' => 'Teste',
    'active' => 'Pagamento confirmado',
    'paid' => 'Pagamento confirmado',
    'confirmed' => 'Pagamento confirmado',
    'received' => 'Pagamento confirmado',
    'pending_payment' => 'Boleto gerado',
    'awaiting_payment' => 'Boleto gerado',
    'trial_expired' => 'Aguardando boleto',
    _ => value.isEmpty ? 'Nao definido' : raw,
  };
}

String platformAccessLabel(bool allowLogin) =>
    allowLogin ? 'Liberado apos pagamento' : 'Aguardando regularizacao';

String platformSalesLifecycleLabel(PlatformSalesOnboardingSummary item) {
  final leadStep = 'lead recebido';
  final chargeStep = item.implementationMode == 'accountant'
      ? 'implantacao pelo contador'
      : item.implementationChargePaymentId.isEmpty
      ? 'cobranca pendente'
      : 'cobranca ${item.implementationChargeStatus.isEmpty ? 'gerada' : item.implementationChargeStatus}';
  final onboardingStep = item.status == 'submitted'
      ? 'onboarding enviado'
      : item.status.isEmpty
      ? 'onboarding sem status'
      : item.status;
  final companyStep = item.companyId.isEmpty
      ? 'empresa ainda nao criada'
      : 'empresa criada';
  final accountantStep = item.accountantEmail.isEmpty
      ? 'aguarda contador vincular escritorio'
      : 'contador/escritorio informado';
  final billingStep = item.companyId.isEmpty
      ? 'cobranca recorrente aguardando empresa'
      : 'validar cobranca ativa no cadastro da empresa';
  return 'Rastreio: $leadStep -> $chargeStep -> $onboardingStep -> $companyStep -> $accountantStep -> $billingStep';
}

class _GovernanceIssueCard extends StatelessWidget {
  const _GovernanceIssueCard({required this.issue});

  final PlatformGovernanceIssueSummary issue;

  @override
  Widget build(BuildContext context) {
    final isError = issue.severity.toLowerCase() == 'error';
    final color = isError ? const Color(0xFFB71C1C) : const Color(0xFFE65100);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  issue.description,
                  style: const TextStyle(
                    color: AppBrandColors.softText,
                    height: 1.35,
                  ),
                ),
                if (issue.entityId.isNotEmpty ||
                    issue.updatedAt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (issue.entityId.isNotEmpty) 'ID: ${issue.entityId}',
                      if (issue.updatedAt.isNotEmpty)
                        'Atualizado: ${issue.updatedAt}',
                    ].join(' | '),
                    style: const TextStyle(
                      color: AppBrandColors.softText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppBrandColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
