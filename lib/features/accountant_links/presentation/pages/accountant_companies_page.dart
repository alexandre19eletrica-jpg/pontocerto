import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/accountant_company_context_service.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_visual_identity.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/accountant_links/domain/accountant_link.dart';
import 'package:pontocerto/features/accountant_links/presentation/accountant_fiscal_profile_provider.dart';
import 'package:pontocerto/features/accountant_links/presentation/accountant_company_links_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class AccountantCompaniesPage extends ConsumerWidget {
  const AccountantCompaniesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null || session.role != Role.accountant) {
      return const Scaffold(body: Center(child: Text('Acesso negado.')));
    }
    final linksAsync = ref.watch(accountantCompanyLinksProvider);
    final profileAsync = ref.watch(accountantFiscalProfileProvider);

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Empresas vinculadas',
        subtitle:
            'Ambiente do contador para operar clientes vinculados com mais contexto, menos retrabalho, troca rapida de carteira e um perfil fiscal centralizado do escritorio.',
        chips: [
          AppHeaderChip('Carteira organizada'),
          AppHeaderChip('Troca rapida de contexto'),
        ],
      ),
    );
    return AppGradientBackground(
        child: AppPageLayout(
          child: linksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppWorkspaceCard(
              title: 'Empresas indisponiveis',
              subtitle: error.toString(),
              child: const Text('Nao foi possivel carregar as empresas vinculadas.'),
            ),
            data: (links) {
              final ordered = _dedupeVisualLinks([...links], session.companyId)
                ..sort((a, b) {
                  final aCurrent = a.companyId == session.companyId ? 1 : 0;
                  final bCurrent = b.companyId == session.companyId ? 1 : 0;
                  if (aCurrent != bCurrent) return bCurrent.compareTo(aCurrent);
                  return a.companyName.toLowerCase().compareTo(
                    b.companyName.toLowerCase(),
                  );
                });

              final currentLink = ordered.cast<AccountantLink?>().firstWhere(
                    (item) => item?.companyId == session.companyId,
                    orElse: () => ordered.isNotEmpty ? ordered.first : null,
                  ) ??
                  AccountantLink(
                    id: '',
                    companyId: session.companyId,
                    companyName: '',
                    companyDocument: '',
                    companyDisplayCode: '',
                    accountantUserId: session.userId,
                    accountantName: session.nome,
                    accountantEmail: '',
                    linkedByUserId: '',
                    linkedByName: '',
                    status: AccountantLinkStatus.active,
                  );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  AppWorkspaceCard(
                    title: 'Resumo',
                    subtitle:
                        'Veja sua carteira ativa e entre na empresa certa sem perder o contexto do escritorio.',
                    trailing: FilledButton.icon(
                      onPressed: () => context.go('/accountant-register-company'),
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Cadastrar empresa'),
                    ),
                    child: AppHorizontalCardGrid(
                      minItemWidth: 240,
                      maxColumns: 3,
                      children: [
                        AppMetricCard(
                          label: 'Empresas vinculadas',
                          value: ordered.length.toString(),
                          caption: 'Empresas ativas para este contador',
                        ),
                        AppMetricCard(
                          label: 'Empresa atual',
                          value: _shortCompanyLabel(currentLink),
                          caption: 'Contexto atualmente carregado',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Nova empresa indicada',
                    subtitle:
                        'Quando um novo cliente vier pelo contador, use este modulo para cadastrar a empresa direto no sistema. O escritorio fica vinculado no mesmo fluxo e a cobranca automatica continua sendo gerada normalmente.',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/accountant-register-company'),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Abrir cadastro de empresa'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Perfil fiscal centralizado',
                    subtitle:
                        'Os dados oficiais do escritorio para Receita Federal e Integra Contador passam a ser preparados uma vez e reaproveitados em toda a carteira.',
                    child: profileAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text(error.toString()),
                      data: (profile) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              AppHeaderChip(
                                profile.isReady
                                    ? 'Perfil do escritorio pronto'
                                    : 'Perfil do escritorio pendente',
                              ),
                              AppHeaderChip(
                                profile.officeName.trim().isEmpty
                                    ? 'Escritorio sem identificacao'
                                    : profile.officeName.trim(),
                              ),
                              const AppHeaderChip(
                                'Vale para empresas vinculadas',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            profile.isReady
                                ? 'Quando esse perfil estiver pronto, o contador nao precisa reconfigurar a base oficial do escritorio a cada empresa. O que segue por cliente fica restrito a procuracoes, autorizacoes e dados da propria empresa.'
                                : 'Prepare o perfil fiscal do contador uma vez. Assim, o escritorio centraliza suas referencias oficiais e evita repetir a mesma configuracao cliente por cliente.',
                            style: const TextStyle(
                              color: AppBrandColors.softText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => context.go('/accountant-fiscal-profile'),
                            icon: const Icon(Icons.verified_user_outlined),
                            label: Text(
                              profile.isReady
                                  ? 'Revisar perfil fiscal'
                                  : 'Configurar perfil fiscal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ordered.isEmpty)
                    const AppWorkspaceCard(
                      title: 'Nenhuma empresa vinculada',
                      child: Text(
                        'Este contador ainda nao possui empresas ativas vinculadas.',
                      ),
                    )
                  else
                    AppWorkspaceCard(
                      title: 'Lista de empresas',
                      subtitle:
                          'Abra a empresa desejada para continuar o trabalho com o contexto correto. A pasta da implantacao e os dados do escritorio ficam organizados sem repetir base oficial por cliente.',
                      child: AppHorizontalCardGrid(
                        minItemWidth: 340,
                        maxColumns: 2,
                        children: [
                          for (final link in ordered)
                            _AccountantCompanyTile(link: link),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
    );
  }
}

List<AccountantLink> _dedupeVisualLinks(
  List<AccountantLink> links,
  String currentCompanyId,
) {
  final richLinks = links.where(_isRichVisualLink).toList();
  final richCompanyIds = richLinks.map((item) => item.companyId.trim()).toSet();
  final richDocuments = richLinks
      .map((item) => item.companyDocument.replaceAll(RegExp(r'[^0-9]'), ''))
      .where((item) => item.isNotEmpty)
      .toSet();
  final richNames = richLinks
      .map((item) => _normalizedCompanyName(item.companyName))
      .where((item) => item.isNotEmpty)
      .toSet();

  final filtered = links.where((item) {
    if (_isRichVisualLink(item)) return true;

    final companyId = item.companyId.trim();
    final document = item.companyDocument.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedName = _normalizedCompanyName(item.companyName);

    if (companyId.isNotEmpty &&
        (companyId == currentCompanyId || richCompanyIds.contains(companyId))) {
      return false;
    }
    if (document.isNotEmpty && richDocuments.contains(document)) {
      return false;
    }
    if (normalizedName.isNotEmpty && richNames.contains(normalizedName)) {
      return false;
    }
    return true;
  }).toList();

  final deduped = <String, AccountantLink>{};
  for (final item in filtered) {
    final key = _visualCompanyKey(item);
    final current = deduped[key];
    if (current == null) {
      deduped[key] = item;
      continue;
    }

    final currentScore = _visualLinkScore(current, currentCompanyId);
    final nextScore = _visualLinkScore(item, currentCompanyId);
    if (nextScore >= currentScore) {
      deduped[key] = item;
    }
  }
  return deduped.values.toList();
}

int _visualLinkScore(AccountantLink link, String currentCompanyId) {
  var score = 0;
  if (link.companyId == currentCompanyId) score += 1000000;
  if (link.companyDocument.trim().isNotEmpty) score += 10000;
  if (link.companyDisplayCode.trim().isNotEmpty) score += 1000;
  if (link.companyName.trim().isNotEmpty) score += 1000;
  if (link.updatedAt != null) score += link.updatedAt!.millisecondsSinceEpoch;
  return score;
}

String _visualCompanyKey(AccountantLink link) {
  final document = link.companyDocument.replaceAll(RegExp(r'[^0-9]'), '');
  if (document.isNotEmpty) return 'doc:$document';

  final normalizedName = link.companyName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (normalizedName.isNotEmpty) return 'name:$normalizedName';

  final displayCode = link.companyDisplayCode
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (displayCode.isNotEmpty) return 'code:$displayCode';

  return 'company:${link.companyId.trim().toLowerCase()}';
}

bool _isRichVisualLink(AccountantLink link) {
  return link.companyName.trim().isNotEmpty ||
      link.companyDocument.trim().isNotEmpty ||
      link.companyDisplayCode.trim().isNotEmpty;
}

String _normalizedCompanyName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _shortCompanyLabel(AccountantLink link) {
  if (link.companyName.trim().isNotEmpty) {
    return link.companyName.trim();
  }
  return link.companyId;
}

class _AccountantCompanyTile extends ConsumerWidget {
  const _AccountantCompanyTile({required this.link});

  final AccountantLink link;

  Future<void> _selectCompany(BuildContext context, WidgetRef ref) async {
    try {
      await AccountantCompanyContextService().selectCompany(link.companyId);
      ref.read(sessionProvider.notifier).trocarEmpresa(companyId: link.companyId);
      if (!context.mounted) return;
      context.go('/home');
    } catch (error) {
      if (!context.mounted) return;
      context.showUserError(error.toString());
    }
  }

  Future<void> _openImplementationRecord(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(link.companyId)
          .collection('implementation_records')
          .doc('current')
          .get();
      if (!context.mounted) return;
      if (!snap.exists) {
        context.showUserMessage(
          'Nenhuma pasta de implantacao encontrada para esta empresa.',
        );
        return;
      }
      final data = (snap.data() ?? <String, dynamic>{}).cast<String, dynamic>();
      final implementationChargeRaw = data['implementationCharge'];
      final implementationCharge = implementationChargeRaw is Map
          ? implementationChargeRaw.cast<String, dynamic>()
          : <String, dynamic>{};
      final uploads = (data['uploads'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pasta da implantacao'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Empresa: ${data['companyName'] ?? link.companyId}'),
                  if ((data['planTitle']?.toString() ?? '').isNotEmpty)
                    Text('Plano: ${data['planTitle']}'),
                  if ((data['implementationMode']?.toString() ?? '').isNotEmpty)
                    Text('Modo: ${data['implementationMode']}'),
                  if ((data['customerEmail']?.toString() ?? '').isNotEmpty)
                    Text('Solicitante: ${data['customerEmail']}'),
                  if ((data['accountantEmail']?.toString() ?? '').isNotEmpty)
                    Text('Contador: ${data['accountantEmail']}'),
                  if ((implementationCharge['paymentId']?.toString() ?? '').isNotEmpty)
                    Text(
                      'Cobranca implantacao: ${implementationCharge['status'] ?? implementationCharge['paymentId']}',
                    ),
                  if ((implementationCharge['invoiceUrl']?.toString() ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SelectableText(
                        'Boleto: ${implementationCharge['invoiceUrl']}',
                        style: const TextStyle(color: AppBrandColors.softText),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Arquivos enviados: ${uploads.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppBrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (uploads.isEmpty)
                    const Text('Nenhum arquivo arquivado nesta pasta.')
                  else
                    for (final upload in uploads)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          '${upload['category'] ?? 'arquivo'} | ${upload['fileName'] ?? ''}\n${upload['publicUrl'] ?? ''}',
                          style: const TextStyle(color: AppBrandColors.softText),
                        ),
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
      if (!context.mounted) return;
      context.showUserError(error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isCurrent = session?.companyId == link.companyId;
    final visualCode = link.companyDisplayCode.trim().isNotEmpty
        ? link.companyDisplayCode
        : buildCompanyDisplayCode(
            cnpj: link.companyDocument,
            companyName: link.companyName,
          );
    final formattedDocument = _formatCnpj(link.companyDocument);
    final title = link.companyName.trim().isEmpty ? link.companyId : link.companyName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? AppBrandColors.primaryDeep
              : AppBrandColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCurrent
                ? 'Empresa atual do contador'
                : 'Empresa disponivel para abrir',
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppHeaderChip(visualCode),
              if (formattedDocument.isNotEmpty) AppHeaderChip(formattedDocument),
              AppHeaderChip(isCurrent ? 'Empresa atual' : 'Disponivel'),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('company_settings')
                .doc(link.companyId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              return _AccountantFiscalStatusPanel(companySettings: data);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _selectCompany(context, ref),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(isCurrent ? 'Continuar nesta empresa' : 'Abrir empresa'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openImplementationRecord(context),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Ver pasta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountantFiscalStatusPanel extends StatelessWidget {
  const _AccountantFiscalStatusPanel({required this.companySettings});

  final Map<String, dynamic> companySettings;

  @override
  Widget build(BuildContext context) {
    final companyData =
        (companySettings['companyData'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final routing =
        (companySettings['fiscalRouting'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final integration =
        (companySettings['fiscalRealIntegration'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final certificate =
        (companySettings['fiscalCertificate'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final provisioning =
        (companySettings['focusProvisioning'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final checklist =
        (companySettings['fiscalHomologationChecklist'] as Map?)
            ?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final routeType = routing['routeType']?.toString().trim() ?? '';
    final focusApiMode =
        (integration['focusNfseApi']?.toString().trim().isNotEmpty == true
                ? integration['focusNfseApi']
                : routing['focusNfseApi'])
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final usesFocus = (integration['provider']?.toString().trim() ?? '')
        .toLowerCase()
        .contains('focus');
    final usesNationalFocus =
        focusApiMode == 'national' || routeType == 'focus_national';
    final usesMunicipalFocus =
        usesFocus && !usesNationalFocus && routeType != 'manual_review';
    final routeLabel = routeType == 'focus_national'
        ? 'Focus NFSe Nacional'
        : routeType == 'focus_municipal'
        ? 'Focus municipal'
        : routeType == 'manual_review'
        ? 'Revisao manual'
        : usesNationalFocus
        ? 'Focus NFSe Nacional'
        : usesMunicipalFocus
        ? 'Focus municipal'
        : 'Rota em definicao';

    final automaticChecks = <String>[
      if (usesFocus)
        'Provedor Focus configurado',
      if (usesNationalFocus)
        'Sistema definiu emissao pela NFSe Nacional da Focus',
      if (usesMunicipalFocus)
        'Sistema definiu emissao pela integracao municipal da Focus',
      if (integration['usesPlatformFocusToken'] == true ||
          (integration['apiToken']?.toString().trim() ?? '').isNotEmpty)
        'Token da integracao ativo (global ou preenchido)',
      if ((integration['municipalCode']?.toString().trim() ?? '').isNotEmpty)
        usesNationalFocus
            ? 'Codigo fiscal/base nacional informado'
            : 'Codigo do municipio/base informado',
      if ((certificate['fileName']?.toString().trim() ?? '').isNotEmpty)
        'Certificado digital enviado',
      if ((certificate['validUntil']?.toString().trim() ?? '').isNotEmpty)
        'Validade do certificado retornada',
      if ((companySettings['focusCompanyId']?.toString().trim() ?? '').isNotEmpty)
        'Empresa sincronizada na Focus',
      if (checklist['providerConnectionValidated'] == true)
        'Conexao com provedor validada',
      if (checklist['pilotInvoiceValidated'] == true)
        'Emissao piloto validada',
    ];

    final pendingManual = <String>[
      if ((companyData['inscricaoMunicipal']?.toString().trim() ?? '').isEmpty)
        'Inscricao municipal ainda nao informada',
      if ((companyData['cidade']?.toString().trim() ?? '').isEmpty ||
          (companyData['estado']?.toString().trim() ?? '').isEmpty)
        'Cidade e UF da empresa ainda precisam ser conferidas',
      if ((companyData['codigoServicoPadrao']?.toString().trim() ?? '').isEmpty &&
          (companyData['defaultServiceCode']?.toString().trim() ?? '').isEmpty)
        'Codigo padrao de servico ainda nao informado',
      if ((integration['lastHomologationNote']?.toString().trim() ?? '').isEmpty)
        'Observacao de homologacao ainda nao registrada',
      if (checklist['companyBaseReviewed'] != true)
        'Cadastro base ainda nao revisado',
      if (checklist['certificateValidated'] != true)
        'Certificado ainda nao foi validado operacionalmente',
      if (checklist['matrixValidated'] != true)
        'Matriz fiscal ainda nao foi conferida',
      if (checklist['productionAuthorized'] != true)
        'Liberacao final de producao ainda nao foi marcada',
      ...((provisioning['missing'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .map((item) => 'Focus ainda aponta pendencia: $item'),
    ];

    final focusAlreadySolves = <String>[
      'Cadastro/sincronizacao da empresa emitente na Focus',
      'Leitura do certificado enviado e retorno de validade',
      'Emissao, consulta de status e cancelamento de NFS-e quando a empresa estiver pronta',
    ];

    final focusDoesNotSolve = <String>[
      'Radar fiscal da rotina do escritorio',
      'Apuracao e emissao de tributos e guias de impostos',
      'Obrigacoes acessorias da rotina do contador',
      if (usesMunicipalFocus || routeType == 'manual_review')
        'Liberacao municipal, RPS, credenciamento ou exigencias especificas da prefeitura',
      if (usesNationalFocus)
        'Conferencia do enquadramento correto na NFSe Nacional e das regras do servico',
      'Conferencia contábil de regime, servico, retencoes e fechamento da competencia',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppHeaderChip(routeLabel),
              AppHeaderChip(
                'Focus ${provisioning['status']?.toString().trim().isEmpty == true ? 'PENDING' : provisioning['status']}',
              ),
              AppHeaderChip(
                automaticChecks.isEmpty
                    ? 'Base automatica pendente'
                    : '${automaticChecks.length} validacoes automaticas',
              ),
              AppHeaderChip(
                pendingManual.isEmpty
                    ? 'Sem pendencias manuais'
                    : '${pendingManual.length} pontos para revisar',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Leitura fiscal da empresa para o contador',
            style: TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            usesNationalFocus
                ? 'Esta empresa esta no fluxo NFSe Nacional da Focus. O sistema ja distingue isso do fluxo municipal para evitar processo duplicado de prefeitura.'
                : usesMunicipalFocus
                ? 'Esta empresa esta no fluxo municipal da Focus. O contador continua vendo apenas o que falta na rota municipal, sem duplicar processo nacional.'
                : 'A leitura abaixo respeita a rota fiscal detectada para a empresa e evita duplicar processo entre Focus municipal, Focus nacional e revisao manual.',
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _section(
            title: 'O que a Focus ja valida ou resolve',
            items: [
              ...automaticChecks,
              ...focusAlreadySolves.where((item) => !automaticChecks.contains(item)),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'O que ainda depende de rotina contábil ou municipal',
            items: pendingManual.isEmpty ? focusDoesNotSolve : [...pendingManual, ...focusDoesNotSolve],
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<String> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppBrandColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Text(
            'Nenhum item neste bloco.',
            style: TextStyle(color: AppBrandColors.softText),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: AppBrandColors.softText,
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
      ],
    );
  }
}

String _formatCnpj(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 14) return raw.trim();
  return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
}
