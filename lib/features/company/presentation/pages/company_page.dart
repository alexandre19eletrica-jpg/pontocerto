import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/company/company_access_state.dart';
import 'package:pontocerto/core/company/company_experience.dart';
import 'package:pontocerto/core/company/company_settings_provider.dart';
import 'package:pontocerto/core/company/empresa_cache.dart';
import 'package:pontocerto/core/firebase/employee_access_service.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/features/assistant/presentation/services/assistant_admin_service.dart';
import 'package:pontocerto/features/company/presentation/services/company_billing_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/urls/receita_official_urls.dart';
import 'package:url_launcher/url_launcher.dart';

class CompanyPage extends ConsumerStatefulWidget {
  const CompanyPage({super.key});

  @override
  ConsumerState<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends ConsumerState<CompanyPage> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  bool _salvando = false;
  bool _limpandoDados = false;
  final _assistantAdminService = AssistantAdminService();
  final _companyBillingService = CompanyBillingService();
  AssistantCompanyConfigStatus? _assistantConfigStatus;
  bool _assistantConfigLoading = false;
  bool _billingBusy = false;

  String _companyLifecycleLabel(String raw) {
    final value = raw.trim().toLowerCase();
    final label = switch (value) {
      'trial' => 'Teste',
      'active' => 'Ativa',
      'blocked' => 'Bloqueada',
      'inactive' => 'Inativa',
      'suspended' => 'Suspensa',
      'awaiting_payment' => 'Boleto gerado',
      _ => value.isEmpty ? 'Nao definido' : raw,
    };
    return 'Ciclo $label';
  }

  String _companyBillingStatusLabel(String raw) {
    final value = raw.trim().toLowerCase();
    final label = switch (value) {
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
    return 'Financeiro $label';
  }

  String _billingActionHint({
    required String lifecycleStatus,
    required String billingStatus,
    required bool allowLogin,
  }) {
    final lifecycle = lifecycleStatus.trim().toLowerCase();
    final billing = billingStatus.trim().toLowerCase();
    if (billing == 'trial_expired') {
      return 'Teste encerrado. Para continuar, gere agora o boleto pre-pago com vencimento em 5 dias.';
    }
    if (!allowLogin &&
        (billing == 'pending_payment' || lifecycle == 'awaiting_payment')) {
      return 'Boleto pre-pago pendente. O acesso volta a ser liberado assim que o pagamento for confirmado.';
    }
    if (allowLogin &&
        ['paid', 'confirmed', 'received', 'active'].contains(billing)) {
      return 'Acesso liberado apos pagamento confirmado.';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) {
      if (mounted) {
        setState(() => _carregando = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sessao.userId)
          .get();
      final map = doc.data();
      if (mounted) {
        setState(() {
          _dados = (map?['companyData'] as Map?)?.cast<String, dynamic>();
          _carregando = false;
        });
      }
      await _loadAssistantConfigStatus();
    } catch (_) {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _loadAssistantConfigStatus() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null || sessao.role != Role.owner) return;
    if (mounted) {
      setState(() => _assistantConfigLoading = true);
    }
    try {
      final status = await _assistantAdminService.getCompanyConfigStatus();
      if (!mounted) return;
      setState(() => _assistantConfigStatus = status);
    } catch (_) {
      if (!mounted) return;
      setState(() => _assistantConfigStatus = null);
    } finally {
      if (mounted) {
        setState(() => _assistantConfigLoading = false);
      }
    }
  }

  Future<void> _contractAdditionalAccess(
    Map<String, dynamic> commercial,
  ) async {
    if (_billingBusy) return;
    final seatsIncluded = (commercial['seatsIncluded'] as num?)?.toInt() ?? 0;
    final contractedCurrent =
        (commercial['contractedAppUsers'] as num?)?.toInt() ?? seatsIncluded;
    final controller = TextEditingController(
      text: contractedCurrent.toString(),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contratar acesso adicional'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total de acessos contratados',
              helperText: 'Base incluida: $seatsIncluded acessos',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final contracted = int.tryParse(controller.text.trim());
      if (contracted == null || contracted < seatsIncluded) {
        throw Exception('Informe um total valido de acessos.');
      }
      setState(() => _billingBusy = true);
      final result = await _companyBillingService.updateAdditionalAppAccess(
        contractedAppUsers: contracted,
      );
      if (!mounted) return;
      if (context.mounted) {
        context.showUserSuccess(
          'Acessos atualizados para ${result.contractedAppUsers}. Novo total ${_formatCurrency(result.monthlyPriceCents)}.',
        );
      }
      ref.invalidate(companySettingsProvider);
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() => _billingBusy = false);
      }
    }
  }

  Future<void> _cancelBillingPlan() async {
    if (_billingBusy) return;
    final reasonController = TextEditingController(
      text: 'Cancelamento solicitado pela empresa.',
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar plano'),
          content: TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motivo interno',
              helperText:
                  'O sistema vai cancelar a recorrencia e manter o acesso ate o fim do ciclo vigente.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancelar plano'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _billingBusy = true);
      final result = await _companyBillingService.cancelSubscription(
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      if (context.mounted) {
        context.showUserMessage(
          'Plano cancelado. Acesso mantido ate ${result.accessUntil.split('T').first}.',
        );
      }
      ref.invalidate(companySettingsProvider);
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      reasonController.dispose();
      if (mounted) {
        setState(() => _billingBusy = false);
      }
    }
  }

  Future<void> _startPrepaidPlanFromTrial() async {
    if (_billingBusy) return;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aderir ao plano'),
          content: const Text(
            'Ao confirmar, o sistema vai gerar agora o boleto pre-pago com vencimento em 5 dias para continuidade do acesso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Gerar boleto'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _billingBusy = true);
      final result = await _companyBillingService.startPrepaidPlanFromTrial();
      if (!mounted) return;
      if (context.mounted) {
        context.showUserSuccess(
          result.reusedExistingCharge
              ? 'Boleto pendente recuperado. Vencimento em ${result.dueDate.split('T').first}.'
              : 'Boleto gerado com vencimento em ${result.dueDate.split('T').first}.',
        );
      }
      ref.invalidate(companySettingsProvider);
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      if (mounted) {
        setState(() => _billingBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }
    final dados = _dados ?? <String, dynamic>{};
    final companySettings =
        ref.watch(companySettingsProvider).valueOrNull ?? <String, dynamic>{};

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Empresa',
        subtitle:
            'Cadastro do emitente, perfil da operacao e configuracoes centrais da empresa.',
        chips: [
          AppHeaderChip(dados['cnpj']?.toString() ?? 'CNPJ pendente'),
          AppHeaderChip(dados['cidade']?.toString() ?? 'Cidade nao informada'),
          AppHeaderChip(sessao.companyId),
        ],
      ),
      beforeLogout: [
        IconButton(
          onPressed: _carregando || _salvando ? null : _abrirEdicao,
          icon: const Icon(Icons.edit, color: AppBrandColors.ink),
          tooltip: 'Editar',
        ),
        IconButton(
          onPressed: _carregando || _salvando || _limpandoDados
              ? null
              : _abrirLimpezaDados,
          icon: const Icon(
            Icons.delete_sweep_outlined,
            color: AppBrandColors.ink,
          ),
          tooltip: 'Limpar pontos/justificativas',
        ),
      ],
    );

    return _carregando
        ? const Center(child: CircularProgressIndicator())
        : AppGradientBackground(
            child: AppPageLayout(
              child: ListView(
                  children: [
                    AppWorkspaceCard(
                      title: 'Atalhos',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go('/service-catalog'),
                            icon: const Icon(Icons.dataset_outlined),
                            label: const Text('Banco de servicos'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/materials'),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Banco de materiais'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/proposals'),
                            icon: const Icon(Icons.request_quote_rounded),
                            label: const Text('Proposta de servicos'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/contracts'),
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('Contratos'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/contract-clauses'),
                            icon: const Icon(Icons.gavel_outlined),
                            label: const Text('Clausulas contratuais'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final profile = _operationalProfileFromSettings(
                          companySettings,
                        );
                        final canManageProfile = sessao.role == Role.owner;
                        return AppWorkspaceCard(
                          title: 'Perfil operacional',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('MEI / Solo'),
                                    selected:
                                        profile ==
                                        _CompanyOperationalProfile.mei,
                                    onSelected: canManageProfile
                                        ? (_) => _applyOperationalProfile(
                                            sessao,
                                            _CompanyOperationalProfile.mei,
                                          )
                                        : null,
                                  ),
                                  ChoiceChip(
                                    label: const Text('Empresa / Equipe'),
                                    selected:
                                        profile ==
                                        _CompanyOperationalProfile.empresa,
                                    onSelected: canManageProfile
                                        ? (_) => _applyOperationalProfile(
                                            sessao,
                                            _CompanyOperationalProfile.empresa,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  onPressed: canManageProfile
                                      ? () => _openOperationalSetupAssistant(
                                          sessao,
                                          profile,
                                        )
                                      : null,
                                  icon: const Icon(
                                    Icons.auto_fix_high_outlined,
                                  ),
                                  label: const Text(
                                    'Assistente de ativacao inicial',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _sectionTitle('Checklist de implantacao'),
                              const SizedBox(height: 4),
                              ..._buildOperationalChecklist(profile),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final companyExperience =
                            CompanyExperience.fromSettings(companySettings);
                        if (!companyExperience.isMei) {
                          return const SizedBox.shrink();
                        }
                        final meiDasRaw = companySettings['meiDas'];
                        final meiDas = meiDasRaw is Map
                            ? meiDasRaw.cast<String, dynamic>()
                            : <String, dynamic>{};
                        return AppWorkspaceCard(
                          title: 'DAS do MEI',
                          subtitle:
                              'Controle interno simples do DAS. A emissao, a baixa da guia e o pagamento seguem pelos canais oficiais da Receita.',
                          trailing: sessao.role == Role.owner
                              ? OutlinedButton.icon(
                                  onPressed: () =>
                                      _openMeiDasDialog(sessao, meiDas),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Atualizar DAS'),
                                )
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppHeaderChip(
                                    'Status ${_meiDasStatusLabel(meiDas['status']?.toString() ?? 'pendente')}',
                                  ),
                                  AppHeaderChip(
                                    'Valor ${_formatCurrency((meiDas['estimatedValueCents'] as num?)?.toInt() ?? 0)}',
                                  ),
                                  AppHeaderChip(
                                    'Vencimento ${meiDas['dueDate']?.toString().trim().isNotEmpty == true ? meiDas['dueDate'] : 'nao informado'}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _openMeiDasOfficialPortal,
                                    icon: const Icon(
                                      Icons.open_in_new_outlined,
                                    ),
                                    label: const Text('Emitir DAS oficial'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _openReceitaFederalPaymentsPortal,
                                    icon: const Icon(Icons.download_outlined),
                                    label: const Text('Consultar comprovantes'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final accessState = CompanyAccessState.fromSettings(
                          companySettings,
                          companyId: sessao.companyId,
                        );
                        final commercialRaw =
                            companySettings['commercialSettings'];
                        final commercial = commercialRaw is Map
                            ? commercialRaw.cast<String, dynamic>()
                            : <String, dynamic>{};
                        final lifecycleStatus =
                            commercial['lifecycleStatus']?.toString() ??
                            'trial';
                        final approvalStatus =
                            commercial['approvalStatus']?.toString() ??
                            'auto_approved';
                        final plan = commercial['plan']?.toString() ?? 'solo';
                        final billingStatus =
                            commercial['billingStatus']?.toString() ??
                            'trialing';
                        final billingRaw = commercial['billingIntegration'];
                        final billing = billingRaw is Map
                            ? billingRaw.cast<String, dynamic>()
                            : <String, dynamic>{};
                        final effectiveBillingStatus =
                            billing['status']?.toString().trim().isNotEmpty ==
                                true
                            ? billing['status']?.toString() ?? 'trialing'
                            : billingStatus;
                        final seatsIncluded =
                            (commercial['seatsIncluded'] as num?)?.toInt() ?? 3;
                        final contractedAppUsers =
                            (commercial['contractedAppUsers'] as num?)
                                ?.toInt() ??
                            seatsIncluded;
                        final monthlyPriceCents =
                            (commercial['monthlyPriceCents'] as num?)
                                ?.toInt() ??
                            0;
                        final canManageRecurringBilling =
                            sessao.role == Role.owner &&
                            (billing['provider']?.toString().toLowerCase() ??
                                    '') ==
                                'asaas' &&
                            (billing['subscriptionId']?.toString() ?? '')
                                .trim()
                                .isNotEmpty;
                        final canStartPrepaidFromTrial =
                            sessao.role == Role.owner &&
                            billingStatus.trim().toLowerCase() ==
                                'trial_expired';
                        final billingHint = _billingActionHint(
                          lifecycleStatus: lifecycleStatus,
                          billingStatus: effectiveBillingStatus,
                          allowLogin: accessState.allowLogin,
                        );
                        return AppWorkspaceCard(
                          title: 'Status comercial da empresa',
                          subtitle:
                              'Leitura do plano, do trial e da cobranca pre-paga desta empresa.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppHeaderChip(
                                    plan == 'solo'
                                        ? 'Plano MEI / Solo'
                                        : 'Plano Empresa / Equipe',
                                  ),
                                  AppHeaderChip(
                                    _companyLifecycleLabel(lifecycleStatus),
                                  ),
                                  AppHeaderChip('Aprovacao $approvalStatus'),
                                  AppHeaderChip(
                                    _companyBillingStatusLabel(
                                      effectiveBillingStatus,
                                    ),
                                  ),
                                  AppHeaderChip(
                                    'Cobranca ${billing['provider']?.toString() ?? 'manual'}',
                                  ),
                                  if (billing['accessManagedByGateway'] == true)
                                    const AppHeaderChip(
                                      'Acesso ligado ao pagamento',
                                    ),
                                  AppHeaderChip('$seatsIncluded acessos base'),
                                  AppHeaderChip(
                                    '$contractedAppUsers acessos contratados',
                                  ),
                                  AppHeaderChip(
                                    _formatCurrency(monthlyPriceCents),
                                  ),
                                  AppHeaderChip(
                                    accessState.allowLogin
                                        ? 'Liberado apos pagamento'
                                        : 'Aguardando regularizacao',
                                  ),
                                ],
                              ),
                              if (accessState.message.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  accessState.message,
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (billingHint.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  billingHint,
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if ((billing['subscriptionId']?.toString() ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SelectableText(
                                  'Assinatura: ${billing['subscriptionId']}',
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                  ),
                                ),
                              ],
                              if ((billing['paymentLinkUrl']?.toString() ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SelectableText(
                                  'Boleto / checkout: ${billing['paymentLinkUrl']}',
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                  ),
                                ),
                              ],
                              if (canStartPrepaidFromTrial ||
                                  canManageRecurringBilling) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (canStartPrepaidFromTrial)
                                      ElevatedButton.icon(
                                        onPressed: _billingBusy
                                            ? null
                                            : _startPrepaidPlanFromTrial,
                                        icon: const Icon(
                                          Icons.receipt_long_outlined,
                                        ),
                                        label: const Text(
                                          'Gerar boleto para continuar',
                                        ),
                                      ),
                                    if (canManageRecurringBilling)
                                      ElevatedButton.icon(
                                        onPressed: _billingBusy
                                            ? null
                                            : () => _contractAdditionalAccess(
                                                commercial,
                                              ),
                                        icon: const Icon(
                                          Icons.shop_two_outlined,
                                        ),
                                        label: const Text(
                                          'Contratar acesso app Play Store para funcionario',
                                        ),
                                      ),
                                    if (canManageRecurringBilling)
                                      OutlinedButton.icon(
                                        onPressed: _billingBusy
                                            ? null
                                            : _cancelBillingPlan,
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Cancelar plano'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  canStartPrepaidFromTrial
                                      ? 'A continuidade do servico acontece em modelo pre-pago. O boleto inicial vence em 5 dias e o acesso volta apos a confirmacao.'
                                      : 'A assinatura do plano renova automaticamente a cada mes no Asaas ate cancelamento. Quando precisar ampliar a equipe, contrate mais acessos do app para funcionarios.',
                                  style: const TextStyle(
                                    color: AppBrandColors.softText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final permissions = _AccountantPermissions.fromSettings(
                          companySettings,
                        );
                        final canManage = sessao.role == Role.owner;
                        return AppWorkspaceCard(
                          title: 'Governanca do contador',
                          subtitle:
                              'Controle como os contadores vinculados operam no fiscal, financeiro e contratos sem misturar com a equipe operacional.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppHeaderChip('Emissao fiscal liberada'),
                                  AppHeaderChip(
                                    permissions.allowFinanceRead
                                        ? 'Financeiro visivel'
                                        : 'Financeiro oculto',
                                  ),
                                  AppHeaderChip(
                                    permissions.allowContractsRead
                                        ? 'Contratos em leitura'
                                        : 'Contratos bloqueados',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                value: true,
                                onChanged: null,
                                title: const Text('Contador emite NFS-e'),
                                subtitle: const Text(
                                  'Contadores vinculados operam a emissao e a gestao fiscal da empresa. Esta permissao agora fica sempre liberada.',
                                ),
                              ),
                              SwitchListTile(
                                value: permissions.allowFinanceRead,
                                onChanged: canManage
                                    ? (value) => _saveAccountantPermissions(
                                        sessao,
                                        permissions.copyWith(
                                          allowFinanceRead: value,
                                        ),
                                      )
                                    : null,
                                title: const Text('Contador acessa financeiro'),
                                subtitle: const Text(
                                  'Mantem o painel financeiro disponivel para consulta e conferencia da empresa.',
                                ),
                              ),
                              SwitchListTile(
                                value: permissions.allowContractsRead,
                                onChanged: canManage
                                    ? (value) => _saveAccountantPermissions(
                                        sessao,
                                        permissions.copyWith(
                                          allowContractsRead: value,
                                        ),
                                      )
                                    : null,
                                title: const Text('Contador le contratos'),
                                subtitle: const Text(
                                  'Libera leitura dos contratos comerciais sem permitir edicao.',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final settings = _AssistantSettings.fromSettings(
                          companySettings,
                        );
                        final usageRaw = companySettings['assistantUsage'];
                        final usage = usageRaw is Map
                            ? usageRaw.cast<String, dynamic>()
                            : <String, dynamic>{};
                        final canManage = sessao.role == Role.owner;
                        final requestCount =
                            (usage['requestCount'] as num?)?.toInt() ?? 0;
                        final tokenCount =
                            (usage['totalTokens'] as num?)?.toInt() ?? 0;
                        final periodKey =
                            usage['periodKey']?.toString() ?? 'periodo atual';
                        return AppWorkspaceCard(
                          title: 'Governanca do assistente',
                          subtitle:
                              'Modelo SaaS centralizado: a plataforma controla acesso, franquia mensal e disponibilidade do assistente por empresa.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppHeaderChip(
                                    settings.enabled
                                        ? 'Assistente ativo'
                                        : 'Assistente desativado',
                                  ),
                                  AppHeaderChip('Plano ${settings.plan}'),
                                  AppHeaderChip(
                                    settings.monthlyRequestLimit > 0
                                        ? '$requestCount/${settings.monthlyRequestLimit} atendimentos no mes'
                                        : '$requestCount atendimentos sem teto',
                                  ),
                                  AppHeaderChip(
                                    '$tokenCount tokens acumulados',
                                  ),
                                  AppHeaderChip('Periodo $periodKey'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                value: settings.enabled,
                                onChanged: canManage
                                    ? (value) => _saveAssistantSettings(
                                        sessao,
                                        settings.copyWith(enabled: value),
                                      )
                                    : null,
                                title: const Text(
                                  'Assistente liberado para esta empresa',
                                ),
                                subtitle: const Text(
                                  'Desliga ou religa o modulo inteiro sem afetar o restante do sistema.',
                                ),
                              ),
                              SwitchListTile(
                                value: settings.allowAccountantAccess,
                                onChanged: canManage
                                    ? (value) => _saveAssistantSettings(
                                        sessao,
                                        settings.copyWith(
                                          allowAccountantAccess: value,
                                        ),
                                      )
                                    : null,
                                title: const Text('Contador usa o assistente'),
                                subtitle: const Text(
                                  'Mantem o contador dentro do mesmo canal de orientacao e preparo de textos.',
                                ),
                              ),
                              SwitchListTile(
                                value: settings.allowEmployeeAccess,
                                onChanged: canManage
                                    ? (value) => _saveAssistantSettings(
                                        sessao,
                                        settings.copyWith(
                                          allowEmployeeAccess: value,
                                        ),
                                      )
                                    : null,
                                title: const Text(
                                  'Funcionarios usam o assistente',
                                ),
                                subtitle: const Text(
                                  'Libera ajuda operacional para o time de campo sem abrir configuracoes sensiveis.',
                                ),
                              ),
                              SwitchListTile(
                                value: settings.blockWhenLimitReached,
                                onChanged: canManage
                                    ? (value) => _saveAssistantSettings(
                                        sessao,
                                        settings.copyWith(
                                          blockWhenLimitReached: value,
                                        ),
                                      )
                                    : null,
                                title: const Text(
                                  'Bloquear ao atingir a franquia',
                                ),
                                subtitle: const Text(
                                  'Quando ligado, o backend bloqueia novas consultas ao chegar no teto mensal.',
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: settings.monthlyRequestLimit,
                                decoration: const InputDecoration(
                                  labelText: 'Franquia mensal de atendimentos',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 50,
                                    child: Text('50 por mes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 200,
                                    child: Text('200 por mes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 500,
                                    child: Text('500 por mes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 1000,
                                    child: Text('1000 por mes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text('Sem limite'),
                                  ),
                                ],
                                onChanged: canManage
                                    ? (value) {
                                        if (value == null) return;
                                        _saveAssistantSettings(
                                          sessao,
                                          settings.copyWith(
                                            monthlyRequestLimit: value,
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: settings.plan,
                                decoration: const InputDecoration(
                                  labelText: 'Plano interno do assistente',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'solo',
                                    child: Text('MEI / Solo'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'equipe',
                                    child: Text('Empresa / Equipe'),
                                  ),
                                ],
                                onChanged: canManage
                                    ? (value) {
                                        if (value == null) return;
                                        _saveAssistantSettings(
                                          sessao,
                                          settings.copyWith(plan: value),
                                        );
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildAssistantCredentialInfoCard(
                                showTechnical: canManage,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    AppWorkspaceCard(
                      title: 'Dados cadastrais',
                      child: Column(
                        children: [
                          _campo(
                            'Nome fantasia',
                            dados['nomeFantasia']?.toString(),
                          ),
                          _campo(
                            'Razao social',
                            dados['razaoSocial']?.toString(),
                          ),
                          _campo('CNPJ', dados['cnpj']?.toString()),
                          _campo(
                            'Ramo principal',
                            _businessCategoryLabel(
                              dados['businessCategory']?.toString(),
                            ),
                          ),
                          _campo(
                            'Inscricao estadual',
                            dados['inscricaoEstadualDispensada'] == true
                                ? 'Dispensada para prestacao de servicos'
                                : dados['inscricaoEstadual']?.toString(),
                          ),
                          _campo(
                            'Inscricao municipal',
                            dados['inscricaoMunicipal']?.toString(),
                          ),
                          _campo('Telefone', dados['telefone']?.toString()),
                          _campo('Email', dados['email']?.toString()),
                          _campo('CEP', dados['cep']?.toString()),
                          _campo('Endereco', dados['endereco']?.toString()),
                          _campo('Rua', dados['rua']?.toString()),
                          _campo('Numero', dados['numero']?.toString()),
                          _campo(
                            'Complemento',
                            dados['complemento']?.toString(),
                          ),
                          _campo('Bairro', dados['bairro']?.toString()),
                          _campo('Quadra', dados['quadra']?.toString()),
                          _campo('Lote', dados['lote']?.toString()),
                          _campo('Cidade', dados['cidade']?.toString()),
                          _campo('Estado', dados['estado']?.toString()),
                          _campo('ID da empresa', sessao.companyId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Future<void> _openMeiDasDialog(
    Session sessao,
    Map<String, dynamic> current,
  ) async {
    final valueController = TextEditingController(
      text: _currencyInput(
        (current['estimatedValueCents'] as num?)?.toInt() ?? 0,
      ),
    );
    final dueDateController = TextEditingController(
      text: current['dueDate']?.toString() ?? '',
    );
    var status = current['status']?.toString() ?? 'pendente';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Atualizar DAS do MEI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'pendente',
                      child: Text('Pendente'),
                    ),
                    DropdownMenuItem(value: 'pago', child: Text('Pago')),
                    DropdownMenuItem(
                      value: 'atrasado',
                      child: Text('Atrasado'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => status = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor estimado',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dueDateController,
                  decoration: const InputDecoration(
                    labelText: 'Vencimento',
                    hintText: 'Ex: 20/04/2026',
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
                await FirebaseFirestore.instance
                    .collection('company_settings')
                    .doc(sessao.companyId)
                    .set({
                      'companyId': sessao.companyId,
                      'meiDas': {
                        'status': status,
                        'estimatedValueCents':
                            _parseCurrencyToCents(valueController.text) ?? 0,
                        'dueDate': dueDateController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      },
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('DAS do MEI atualizado.');
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    valueController.dispose();
    dueDateController.dispose();
  }

  Future<void> _openMeiDasOfficialPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.pgmeiEmissaoDas);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openReceitaFederalPaymentsPortal() async {
    final uri = Uri.parse(ReceitaOfficialUrls.ecacLogin);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _campo(String label, String? valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E4FF)),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFE5F0FF), Color(0xFFFFFFFF)],
            ),
          ),
          child: const Icon(
            Icons.apartment_rounded,
            color: AppBrandColors.primaryDeep,
          ),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          (valor == null || valor.isEmpty) ? '-' : valor,
          style: const TextStyle(color: AppBrandColors.softText),
        ),
      ),
    );
  }

  String _businessCategoryLabel(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'service' => 'Prestacao de servicos',
      'commerce' => 'Comercio',
      'industry' => 'Industria',
      'mixed' => 'Misto',
      _ => '-',
    };
  }

  Widget _sectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppBrandColors.ink,
        ),
      ),
    );
  }

  Future<void> _abrirEdicao() async {
    final sessao = ref.read(sessionProvider);
    final dados = Map<String, dynamic>.from(_dados ?? {});
    if (sessao == null) return;

    final nomeFantasiaController = TextEditingController(
      text: dados['nomeFantasia']?.toString() ?? '',
    );
    final telefoneController = TextEditingController(
      text: dados['telefone']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: dados['email']?.toString() ?? '',
    );
    final enderecoController = TextEditingController(
      text: dados['endereco']?.toString() ?? '',
    );
    final cepController = TextEditingController(
      text: dados['cep']?.toString() ?? '',
    );
    final ruaController = TextEditingController(
      text: dados['rua']?.toString() ?? '',
    );
    final numeroController = TextEditingController(
      text: dados['numero']?.toString() ?? '',
    );
    final complementoController = TextEditingController(
      text: dados['complemento']?.toString() ?? '',
    );
    final bairroController = TextEditingController(
      text: dados['bairro']?.toString() ?? '',
    );
    final quadraController = TextEditingController(
      text: dados['quadra']?.toString() ?? '',
    );
    final loteController = TextEditingController(
      text: dados['lote']?.toString() ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, _) => AlertDialog(
          title: const Text('Editar dados da empresa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aqui a empresa pode editar apenas dados seguros de contato e endereco operacional. Dados fiscais, CNPJ, inscricoes, CNAE e emitente ficam restritos a empresa suprema ou ao contador vinculado.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppBrandColors.softText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomeFantasiaController,
                  decoration: const InputDecoration(labelText: 'Nome fantasia'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [TelefoneInputFormatter()],
                  maxLength: 15,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: enderecoController,
                  decoration: const InputDecoration(labelText: 'Endereco'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cepController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'CEP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'O CNPJ ja deve preencher endereco e dados fiscais do emitente. Use o CEP apenas para ajuste manual, se necessario.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppBrandColors.softText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ruaController,
                  decoration: const InputDecoration(labelText: 'Rua'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: numeroController,
                        decoration: const InputDecoration(labelText: 'Numero'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: complementoController,
                        decoration: const InputDecoration(
                          labelText: 'Complemento',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bairroController,
                  decoration: const InputDecoration(labelText: 'Bairro'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quadraController,
                  decoration: const InputDecoration(labelText: 'Quadra'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: loteController,
                  decoration: const InputDecoration(labelText: 'Lote'),
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
                final nomeFantasia = nomeFantasiaController.text.trim();
                if (nomeFantasia.isEmpty) {
                  _msg('Informe o nome fantasia.');
                  return;
                }

                final novosDados = <String, dynamic>{
                  ...dados,
                  'nomeFantasia': _normalizarTexto(nomeFantasia, upper: true),
                  'telefone': _normalizarTelefoneBR(telefoneController.text),
                  'email': _normalizarEmail(emailController.text),
                  'cep': _normalizarTexto(cepController.text, upper: true),
                  'endereco': _normalizarTexto(
                    enderecoController.text,
                    upper: true,
                  ),
                  'rua': _normalizarTexto(ruaController.text, upper: true),
                  'numero': _normalizarTexto(
                    numeroController.text,
                    upper: true,
                  ),
                  'complemento': _normalizarTexto(
                    complementoController.text,
                    upper: true,
                  ),
                  'bairro': _normalizarTexto(
                    bairroController.text,
                    upper: true,
                  ),
                  'quadra': _normalizarTexto(
                    quadraController.text,
                    upper: true,
                  ),
                  'lote': _normalizarTexto(loteController.text, upper: true),
                };

                Navigator.of(context).pop();
                await _salvarEdicao(sessao.userId, novosDados);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    nomeFantasiaController.dispose();
    telefoneController.dispose();
    emailController.dispose();
    cepController.dispose();
    enderecoController.dispose();
    ruaController.dispose();
    numeroController.dispose();
    complementoController.dispose();
    bairroController.dispose();
    quadraController.dispose();
    loteController.dispose();
  }

  Future<void> _salvarEdicao(
    String userId,
    Map<String, dynamic> novosDados,
  ) async {
    setState(() => _salvando = true);
    try {
      final sessao = ref.read(sessionProvider);
      if (sessao == null) {
        _msg('Sessao nao encontrada.');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'companyId': sessao.companyId,
        'companyData': novosDados,
        'companyName': novosDados['nomeFantasia'],
      });
      try {
        final service = EmployeeAccessService(ref);
        await service.sincronizarPerfilEmpresa(
          companyName: novosDados['nomeFantasia']?.toString() ?? '',
          companyData: novosDados,
        );
      } catch (_) {
        await _sincronizarPerfilLocalFallback(
          companyId: sessao.companyId,
          companyName: novosDados['nomeFantasia']?.toString() ?? '',
          companyData: novosDados,
        );
      }

      final nome = novosDados['nomeFantasia']?.toString();
      if (nome != null && nome.isNotEmpty) {
        ref.read(nomeEmpresaCacheProvider.notifier).state = nome;
        await salvarNomeEmpresaCache(nome);
      }

      setState(() => _dados = novosDados);
      _msg('Dados da empresa salvos com sucesso.');
    } catch (_) {
      _msg('Nao foi possivel salvar os dados da empresa.');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _abrirLimpezaDados() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    if (sessao.role != Role.owner) {
      _msg('Somente o dono pode limpar registros da empresa.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpeza de dados'),
        content: const Text(
          'Escolha o que deseja apagar.\n'
          'Essa acao remove registros de forma permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _confirmarEApagar(
                titulo: 'Apagar pontos',
                descricao:
                    'Isto vai apagar todos os registros de ponto (punches e worked_days) da empresa.',
                acao: _apagarPontosEmpresa,
              );
            },
            child: const Text('Apagar pontos'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _confirmarEApagar(
                titulo: 'Apagar justificativas',
                descricao:
                    'Isto vai apagar todas as justificativas da empresa.',
                acao: _apagarJustificativasEmpresa,
              );
            },
            child: const Text('Apagar justificativas'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEApagar({
    required String titulo,
    required String descricao,
    required Future<int> Function() acao,
  }) async {
    final confirmacaoController = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(descricao),
            const SizedBox(height: 12),
            const Text('Digite APAGAR para confirmar'),
            const SizedBox(height: 8),
            TextField(
              controller: confirmacaoController,
              decoration: const InputDecoration(labelText: 'Confirmacao'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(confirmacaoController.text.trim().toUpperCase() == 'APAGAR'),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    confirmacaoController.dispose();
    if (confirmou != true) return;

    setState(() => _limpandoDados = true);
    try {
      final total = await acao();
      _msg('Limpeza concluida. $total registro(s) removido(s).');
    } catch (_) {
      _msg('Nao foi possivel concluir a limpeza.');
    } finally {
      if (mounted) {
        setState(() => _limpandoDados = false);
      }
    }
  }

  Future<int> _apagarPontosEmpresa() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return 0;
    var total = 0;
    total += await _apagarColecaoPorEmpresa(
      collection: 'punches',
      companyId: sessao.companyId,
    );
    total += await _apagarColecaoPorEmpresa(
      collection: 'worked_days',
      companyId: sessao.companyId,
    );
    return total;
  }

  Future<int> _apagarJustificativasEmpresa() async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return 0;
    return _apagarColecaoPorEmpresa(
      collection: 'justifications',
      companyId: sessao.companyId,
    );
  }

  Future<int> _apagarColecaoPorEmpresa({
    required String collection,
    required String companyId,
  }) async {
    const batchSize = 350;
    var total = 0;

    while (true) {
      final query = await FirebaseFirestore.instance
          .collection(collection)
          .where('companyId', isEqualTo: companyId)
          .limit(batchSize)
          .get();

      if (query.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      total += query.docs.length;
    }

    return total;
  }

  Future<void> _sincronizarPerfilLocalFallback({
    required String companyId,
    required String companyName,
    required Map<String, dynamic> companyData,
  }) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    var batch = FirebaseFirestore.instance.batch();
    var count = 0;

    for (final doc in query.docs) {
      batch.set(doc.reference, {
        'companyName': companyName,
        'companyData': companyData,
        'companyProfileUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      count++;

      if (count == 400) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> _saveAccountantPermissions(
    Session sessao,
    _AccountantPermissions permissions,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'accountantPermissions': permissions.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'accountant_permissions_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {'accountantPermissions': permissions.toMap()},
      );
      _msg('Permissoes do contador atualizadas.');
    } catch (_) {
      _msg('Nao foi possivel salvar as permissoes do contador.');
    }
  }

  Future<void> _saveAssistantSettings(
    Session sessao,
    _AssistantSettings settings,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'assistantSettings': settings.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'assistant_settings_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {'assistantSettings': settings.toMap()},
      );
      _msg('Governanca do assistente atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a governanca do assistente.');
    }
  }

  Widget _buildAssistantCredentialInfoCard({required bool showTechnical}) {
    final status = _assistantConfigStatus;
    final hasCompany = status?.hasCompanyApiKey == true;
    final hasPlatform = status?.hasPlatformApiKey == true;

    final sourceChip = switch (status?.source) {
      'company' => 'Credencial desta empresa: chave propria (legado)',
      'platform' => 'Credencial: plataforma (suprema)',
      _ => hasPlatform
          ? 'Credencial: plataforma (suprema)'
          : 'Credencial: verificar na plataforma',
    };

    final bodyText = !showTechnical
        ? 'O assistente usa a mesma credencial OpenAI da plataforma (empresa suprema). Sua empresa nao precisa cadastrar token: basta usar o assistente. Limites de uso por empresa ficam na franquia mensal acima.'
        : hasCompany
            ? 'Esta empresa ainda possui chave OpenAI propria cadastrada (legado). O modelo do produto e credencial unica da suprema para todos; alinhe com o suporte se quiser remover o cadastro legado.'
            : hasPlatform
                ? 'O assistente esta ligado a credencial unica da plataforma (mesma da empresa suprema). Nao ha cadastro de token por empresa nesta tela: a empresa use o assistente e ajuste franquia e permissoes acima. A suprema controla a credencial e pode acompanhar consumo por empresa cadastrada.'
                : 'Credencial da plataforma nao detectada agora; o assistente pode falhar ate a suprema concluir OPENAI_API_KEY. Avise o suporte se continuar indisponivel.';

    final updatedAtLabel = status?.updatedAtIso.isNotEmpty == true
        ? _formatIsoDateTime(status!.updatedAtIso)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppBrandColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credencial do assistente',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            bodyText,
            style: TextStyle(color: AppBrandColors.softText),
          ),
          if (showTechnical) ...[
            const SizedBox(height: 10),
            if (_assistantConfigLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppBrandColors.softText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Carregando status tecnico...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppBrandColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppHeaderChip(sourceChip),
                if (status != null)
                  AppHeaderChip('Modelo ${status.model}'),
                if ((status?.keyPreview ?? '').isNotEmpty)
                  AppHeaderChip('Chave ${status!.keyPreview}'),
                if (updatedAtLabel != null)
                  AppHeaderChip('Atualizado $updatedAtLabel'),
                if ((status?.updatedByName ?? '').isNotEmpty)
                  AppHeaderChip('Por ${status!.updatedByName}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _writeAuditLog({
    required Session sessao,
    required String action,
    required String entityPath,
    required String entityId,
    required Map<String, dynamic>? before,
    required Map<String, dynamic>? after,
  }) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'companyId': sessao.companyId,
      'actorUserId': sessao.userId,
      'actorName': sessao.nome,
      'module': 'company',
      'action': action,
      'entityPath': entityPath,
      'entityId': entityId,
      'before': before,
      'after': after,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }

  _CompanyOperationalProfile _operationalProfileFromSettings(
    Map<String, dynamic> settings,
  ) {
    return switch (settings['companyOperationalProfile']?.toString()) {
      'mei' => _CompanyOperationalProfile.mei,
      _ => _CompanyOperationalProfile.empresa,
    };
  }

  String _operationalProfileDescription(_CompanyOperationalProfile profile) {
    return switch (profile) {
      _CompanyOperationalProfile.mei =>
        'Experiencia adaptada para MEI, sem retirar os modulos gerais do sistema. O foco e simplificar a leitura inicial e manter ativo apenas o que realmente fizer sentido para a operacao.',
      _CompanyOperationalProfile.empresa =>
        'Mais recursos ativos por padrao, indicado para operacao com governanca, conferencia e trilha de decisao mais forte.',
    };
  }

  String _formatIsoDateTime(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString().padLeft(4, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  List<Widget> _buildOperationalChecklist(_CompanyOperationalProfile profile) {
    final items = switch (profile) {
      _CompanyOperationalProfile.mei => const <String>[
        'Conferir CNPJ, endereco e dados do emitente no cadastro da empresa.',
        'Usar financeiro, faturamento, fiscal, assistente e contador normalmente, sem perda dos modulos gerais.',
        'Usar o fiscal para NFS-e, tomadores, servicos fiscais e integracao real quando precisar emitir oficialmente.',
        'Usar trabalhista e contratos quando houver empregado ou necessidade operacional.',
        'Manter o DAS como bloco exclusivo do MEI, sem limitar os demais modulos.',
        'Enviar ao contador apenas o que realmente tiver movimento, mas com acesso fiscal completo da empresa vinculada.',
      ],
      _CompanyOperationalProfile.empresa => const <String>[
        'Configurar governanca com aprovacoes, auditoria e perfil dos gestores.',
        'Manter financeiro, trabalhista e fiscal em modo completo.',
        'Usar fechamento mensal, snapshots e historico de aprovacoes.',
        'Padronizar contratos, notas e documentos internos com rastreabilidade.',
        'Planejar integracoes oficiais: NFS-e, eSocial, contador e encargos reais.',
      ],
    };
    return [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppBrandColors.primaryDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(color: AppBrandColors.softText),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _openOperationalSetupAssistant(
    Session sessao,
    _CompanyOperationalProfile currentProfile,
  ) async {
    var selectedProfile = currentProfile;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assistente de ativacao inicial'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escolha o perfil ideal para aplicar a configuracao inicial recomendada.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_CompanyOperationalProfile>(
                  initialValue: selectedProfile,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: const [
                    DropdownMenuItem(
                      value: _CompanyOperationalProfile.mei,
                      child: Text('MEI / Solo'),
                    ),
                    DropdownMenuItem(
                      value: _CompanyOperationalProfile.empresa,
                      child: Text('Empresa / Equipe'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedProfile = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _operationalProfileDescription(selectedProfile),
                  style: const TextStyle(color: AppBrandColors.softText),
                ),
                const SizedBox(height: 14),
                const Text(
                  'O que sera ativado',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._buildOperationalChecklist(selectedProfile),
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
                await _applyOperationalProfile(sessao, selectedProfile);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Aplicar em 1 clique'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyOperationalProfile(
    Session sessao,
    _CompanyOperationalProfile profile,
  ) async {
    try {
      final payload = switch (profile) {
        _CompanyOperationalProfile.mei => <String, dynamic>{
          'companyOperationalProfile': 'mei',
          'companyExperience': {'type': 'MEI', 'plan': 'SOLO'},
          'financeMode': 'advanced',
          'financeFeatures': {
            'enablePayments': true,
            'enableDebts': true,
            'enableCompanyMovements': true,
            'enableCleanup': false,
          },
          'workforceMode': 'advanced',
          'workforceFeatures': {
            'enablePayrollClosures': true,
            'enableMonthlyDashboard': true,
            'enableServiceInvoices': true,
            'enableContracts': true,
            'enableAdvancedDocuments': true,
            'requireClosureDoubleCheck': false,
            'requireOwnerApprovalForClosure': false,
          },
          'fiscalMode': 'advanced',
          'fiscalFeatures': {
            'enableOfficialInvoicePrep': true,
            'enableRealInvoiceIntegration': true,
            'enablePayrollTaxPrep': false,
            'enableThirteenthSalary': false,
            'enableVacation': false,
            'enableTermination': false,
            'enableBenefits': false,
          },
        },
        _CompanyOperationalProfile.empresa => <String, dynamic>{
          'companyOperationalProfile': 'enterprise',
          'companyExperience': {'type': 'EMPRESA', 'plan': 'EQUIPE'},
          'financeMode': 'advanced',
          'financeFeatures': {
            'enablePayments': true,
            'enableDebts': true,
            'enableCompanyMovements': true,
            'enableCleanup': true,
          },
          'workforceMode': 'advanced',
          'workforceFeatures': {
            'enablePayrollClosures': true,
            'enableMonthlyDashboard': true,
            'enableServiceInvoices': false,
            'enableContracts': true,
            'enableAdvancedDocuments': true,
            'requireClosureDoubleCheck': true,
            'requireOwnerApprovalForClosure': true,
          },
          'fiscalMode': 'advanced',
          'fiscalFeatures': {
            'enableOfficialInvoicePrep': true,
            'enablePayrollTaxPrep': false,
            'enableThirteenthSalary': false,
            'enableVacation': false,
            'enableTermination': false,
            'enableBenefits': false,
          },
        },
      };

      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            ...payload,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _msg('Perfil operacional aplicado com sucesso.');
    } catch (_) {
      _msg('Nao foi possivel aplicar o perfil operacional.');
    }
  }

  String _normalizarTexto(String texto, {bool upper = false}) {
    var t = texto
        .replaceAll(RegExp(r'[\u0000-\u001F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    t = t.replaceFirst(RegExp(r'^[^A-Za-z0-9\u00C0-\u00FF]+'), '');
    t = t.replaceFirst(RegExp(r'[^A-Za-z0-9\u00C0-\u00FF]+$'), '');
    return upper ? t.toUpperCase() : t;
  }

  String _normalizarEmail(String texto) =>
      _normalizarTexto(texto).toLowerCase();

  String _meiDasStatusLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'pago' => 'Pago',
      'atrasado' => 'Atrasado',
      _ => 'Pendente',
    };
  }

  int? _parseCurrencyToCents(String value) {
    var text = value.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }
    final parsed = double.tryParse(text);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  String _currencyInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
  }

  String _formatCurrency(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  String _normalizarTelefoneBR(String texto) {
    final digits = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return digits;
    final ddd = digits.substring(0, 2);
    final numeroBase = digits.length >= 11
        ? digits.substring(2, 11)
        : digits.substring(2, 10);
    if (numeroBase.length == 9) {
      return '($ddd) ${numeroBase.substring(0, 5)}-${numeroBase.substring(5)}';
    }
    return '($ddd) ${numeroBase.substring(0, 4)}-${numeroBase.substring(4)}';
  }
}

enum _CompanyOperationalProfile { mei, empresa }

class _AccountantPermissions {
  const _AccountantPermissions({
    required this.allowIssueServiceInvoices,
    required this.allowFinanceRead,
    required this.allowContractsRead,
  });

  factory _AccountantPermissions.fromSettings(Map<String, dynamic> settings) {
    final raw = settings['accountantPermissions'];
    final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    return _AccountantPermissions(
      allowIssueServiceInvoices:
          map['allowIssueServiceInvoices'] as bool? ?? true,
      allowFinanceRead: map['allowFinanceRead'] as bool? ?? true,
      allowContractsRead: map['allowContractsRead'] as bool? ?? true,
    );
  }

  final bool allowIssueServiceInvoices;
  final bool allowFinanceRead;
  final bool allowContractsRead;

  _AccountantPermissions copyWith({
    bool? allowIssueServiceInvoices,
    bool? allowFinanceRead,
    bool? allowContractsRead,
  }) {
    return _AccountantPermissions(
      allowIssueServiceInvoices:
          allowIssueServiceInvoices ?? this.allowIssueServiceInvoices,
      allowFinanceRead: allowFinanceRead ?? this.allowFinanceRead,
      allowContractsRead: allowContractsRead ?? this.allowContractsRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowIssueServiceInvoices': allowIssueServiceInvoices,
      'allowFinanceRead': allowFinanceRead,
      'allowContractsRead': allowContractsRead,
    };
  }
}

class _AssistantSettings {
  const _AssistantSettings({
    required this.enabled,
    required this.allowManagerAccess,
    required this.allowAccountantAccess,
    required this.allowEmployeeAccess,
    required this.blockWhenLimitReached,
    required this.monthlyRequestLimit,
    required this.plan,
  });

  factory _AssistantSettings.fromSettings(Map<String, dynamic> settings) {
    final raw = settings['assistantSettings'];
    final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    final rawPlan = map['plan']?.toString().trim().toLowerCase();
    return _AssistantSettings(
      enabled: map['enabled'] as bool? ?? true,
      allowManagerAccess: map['allowManagerAccess'] as bool? ?? true,
      allowAccountantAccess: map['allowAccountantAccess'] as bool? ?? true,
      allowEmployeeAccess: map['allowEmployeeAccess'] as bool? ?? true,
      blockWhenLimitReached: map['blockWhenLimitReached'] as bool? ?? true,
      monthlyRequestLimit: (map['monthlyRequestLimit'] as num?)?.toInt() ?? 200,
      plan: switch (rawPlan) {
        'equipe' ||
        'empresa' ||
        'growth' ||
        'enterprise' ||
        'custom' => 'equipe',
        _ => 'solo',
      },
    );
  }

  final bool enabled;
  final bool allowManagerAccess;
  final bool allowAccountantAccess;
  final bool allowEmployeeAccess;
  final bool blockWhenLimitReached;
  final int monthlyRequestLimit;
  final String plan;

  _AssistantSettings copyWith({
    bool? enabled,
    bool? allowManagerAccess,
    bool? allowAccountantAccess,
    bool? allowEmployeeAccess,
    bool? blockWhenLimitReached,
    int? monthlyRequestLimit,
    String? plan,
  }) {
    return _AssistantSettings(
      enabled: enabled ?? this.enabled,
      allowManagerAccess: allowManagerAccess ?? this.allowManagerAccess,
      allowAccountantAccess:
          allowAccountantAccess ?? this.allowAccountantAccess,
      allowEmployeeAccess: allowEmployeeAccess ?? this.allowEmployeeAccess,
      blockWhenLimitReached:
          blockWhenLimitReached ?? this.blockWhenLimitReached,
      monthlyRequestLimit: monthlyRequestLimit ?? this.monthlyRequestLimit,
      plan: plan ?? this.plan,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'allowManagerAccess': allowManagerAccess,
      'allowAccountantAccess': allowAccountantAccess,
      'allowEmployeeAccess': allowEmployeeAccess,
      'blockWhenLimitReached': blockWhenLimitReached,
      'monthlyRequestLimit': monthlyRequestLimit,
      'plan': plan,
    };
  }
}
