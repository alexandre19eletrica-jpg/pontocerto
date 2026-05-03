import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/urls/receita_official_urls.dart';
import 'package:pontocerto/core/utils/bytes_download.dart';
import 'package:pontocerto/features/accountant_declarations/domain/focus_incoming_document.dart';
import 'package:pontocerto/features/accountant_declarations/presentation/services/accountant_focus_xml_service.dart';
import 'package:pontocerto/features/accountant_links/presentation/accountant_company_links_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class _OfficialRfLink {
  const _OfficialRfLink({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final String title;
  final String subtitle;
  final String url;
}

/// Acessos operacionais (login Receita, downloads oficiais, PGMEI/DASN/PGDAS)
/// e captura de XML por empresa ativa do contador.
class AccountantDeclarationsPage extends ConsumerWidget {
  const AccountantDeclarationsPage({super.key});

  static const _pfAvulsoLinks = <_OfficialRfLink>[
    _OfficialRfLink(
      title: 'e-CAC (login com gov.br)',
      subtitle:
          'Entrada unica de servicos da Receita; apos o login, e-CAC completo.',
      url: ReceitaOfficialUrls.ecacLogin,
    ),
    _OfficialRfLink(
      title: 'Baixar o programa do IRPF (PGD / DIRPF)',
      subtitle:
          'Central oficial de download do gerador de declaracao (receitafederal.gov.br).',
      url:
          'https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/download/pgd/dirpf',
    ),
  ];

  static const _empresaCarteiraLinks = <_OfficialRfLink>[
    _OfficialRfLink(
      title: 'MEI - PGMEI (emitir DAS)',
      subtitle: 'Programa gerador de DAS do MEI (portal Simples / Receita).',
      url: ReceitaOfficialUrls.pgmeiEmissaoDas,
    ),
    _OfficialRfLink(
      title: 'MEI - DASN-SIMEI (declaracao anual)',
      subtitle:
          'Declaracao anual no sistema oficial (Simples Nacional / Receita).',
      url: ReceitaOfficialUrls.dasnSimei,
    ),
    _OfficialRfLink(
      title: 'Simples Nacional - PGDAS e servicos',
      subtitle:
          'Apuracao, DAS, parcelamento - grupo de servicos no portal do Simples.',
      url: ReceitaOfficialUrls.simplesNacionalPgdasGrupo,
    ),
    _OfficialRfLink(
      title: 'SPED - baixar programa ECF',
      subtitle: 'Download do validador ECF (central de download oficial SPED).',
      url: ReceitaOfficialUrls.spedEcfDownload,
    ),
  ];

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final linksAsync = ref.watch(accountantCompanyLinksProvider);

    if (session == null || session.role != Role.accountant) {
      return const Scaffold(
        body: Center(child: Text('Acesso restrito ao contador.')),
      );
    }

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Declaracoes e obrigacoes',
        subtitle:
            'Acessos oficiais com acao, isolamento por empresa ativa e captura de XML via Focus dentro da carteira do contador.',
        chips: [AppHeaderChip('Empresa ativa: ${session.companyId}')],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            AppWorkspaceCard(
              title: 'Escopo e isolamento',
              subtitle:
                  'Troque a empresa na sua carteira antes de operar modulos da empresa. A secao de PF e independente do cadastro CNPJ no Ponto Certo.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Identificador do contador (escopo do escritorio no login):',
                    style: TextStyle(
                      color: AppBrandColors.softText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    session.userId,
                    style: const TextStyle(
                      color: AppBrandColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  linksAsync.when(
                    data: (list) => Text(
                      'Empresas vinculadas na carteira: ${list.length}.',
                      style: const TextStyle(color: AppBrandColors.ink),
                    ),
                    loading: () => const Text('Carregando carteira...'),
                    error: (Object? e, StackTrace? s) =>
                        const Text('Nao foi possivel ler a carteira.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppWorkspaceCard(
              title: 'Clientes PF avulsos',
              subtitle:
                  'Pessoas fisicas acompanhadas pelo escritorio, fora do cadastro-empresa no sistema. Apenas portais oficiais abaixo.',
              child: _LinkColumn(links: _pfAvulsoLinks, onOpen: _open),
            ),
            const SizedBox(height: 16),
            AppWorkspaceCard(
              title: 'Empresas na carteira (MEI, ME, LTDA)',
              subtitle:
                  'Use a empresa ativa selecionada na carteira para modulos fiscais e societarios. Declaracoes e obrigacoes seguem o CNPJ e o calendario da Receita.',
              child: _LinkColumn(links: _empresaCarteiraLinks, onOpen: _open),
            ),
            const SizedBox(height: 16),
            _AccountantFocusXmlSection(session: session),
            const SizedBox(height: 16),
            const AppWorkspaceCard(
              title: 'Responsabilidade',
              subtitle:
                  'Links levam a sistemas oficiais e a captura Focus respeita o CNPJ da empresa ativa. Manifestacao do destinatario e automacoes fiscais adicionais ficam para outra rodada.',
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountantFocusXmlSection extends StatefulWidget {
  const _AccountantFocusXmlSection({required this.session});

  final Session session;

  @override
  State<_AccountantFocusXmlSection> createState() =>
      _AccountantFocusXmlSectionState();
}

class _AccountantFocusXmlSectionState
    extends State<_AccountantFocusXmlSection> {
  final _service = AccountantFocusXmlService();
  bool _syncingNfe = false;
  bool _syncingNfse = false;

  Future<void> _sync(String documentType) async {
    setState(() {
      if (documentType == 'nfe') {
        _syncingNfe = true;
      } else {
        _syncingNfse = true;
      }
    });
    try {
      final result = await _service.sync(documentType: documentType);
      if (!mounted) return;
      context.showUserSuccess(
        '${result.label}: ${result.documentsFetched} documento(s) sincronizado(s), ${result.xmlCaptured} XML capturado(s), ultimo NSU ${result.ultimoNsu.isEmpty ? '-' : result.ultimoNsu}.',
      );
    } catch (error) {
      if (!mounted) return;
      context.showUserError(
        'Nao foi possivel sincronizar ${documentType == 'nfe' ? 'NF-e' : 'NFS-e nacional'} pela Focus: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          if (documentType == 'nfe') {
            _syncingNfe = false;
          } else {
            _syncingNfse = false;
          }
        });
      }
    }
  }

  Future<void> _downloadXml(FocusIncomingDocument doc) async {
    if (!doc.canDownloadXml) {
      context.showUserError(
        'Este documento ainda nao possui XML salvo para download.',
      );
      return;
    }
    try {
      final result = await _service.downloadXml(documentId: doc.id);
      await saveBytesFile(
        filename: result.filename,
        bytes: result.bytes,
        mimeType: 'application/xml',
      );
      if (!mounted) return;
      context.showUserSuccess('XML preparado para download.');
    } catch (_) {
      if (!mounted) return;
      context.showUserError('O navegador bloqueou o download do XML.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyStream =
        FirebaseFirestore.instance.collection('empresas').doc(
          widget.session.companyId,
        ).snapshots();
    final docsStream = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.session.companyId)
        .collection('documentos_fiscais')
        .limit(60)
        .snapshots();

    return AppWorkspaceCard(
      title: 'Documentos fiscais via Focus',
      subtitle:
          'Importacao isolada por empresa ativa, sem alterar a emissao fiscal ja validada.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppHeaderChip('Empresa ativa: ${widget.session.companyId}'),
              const AppHeaderChip('Multiempresa isolado por companyId'),
              const AppHeaderChip('Focus como fonte de importacao'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'A emissao continua intacta. Esta area trata apenas da busca, armazenamento, listagem e download dos XMLs por empresa.',
            style: TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: companyStream,
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final status = data['xml_sync_status']?.toString() ?? 'sem_sync';
              final nsu = data['ultimo_nsu']?.toString() ?? '-';
              final lastSync = _formatDateTime(data['xml_ultima_sincronizacao']);
              final lastError = data['xml_ultimo_erro']?.toString() ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppHeaderChip('Status sync: $status'),
                      AppHeaderChip('Ultimo NSU: $nsu'),
                      AppHeaderChip('Ultima sync: $lastSync'),
                    ],
                  ),
                  if (lastError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ultimo erro: $lastError',
                      style: const TextStyle(
                        color: AppBrandColors.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _syncingNfe ? null : () => _sync('nfe'),
                icon: _syncingNfe
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _syncingNfe ? 'Sincronizando NF-e...' : 'Sincronizar NF-e',
                ),
              ),
              FilledButton.icon(
                onPressed: _syncingNfse ? null : () => _sync('nfse_nacional'),
                icon: _syncingNfse
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _syncingNfse
                      ? 'Sincronizando NFS-e nacional...'
                      : 'Sincronizar NFS-e nacional',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Lista de XMLs importados',
            style: TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: docsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Nao foi possivel carregar os XMLs capturados.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs =
                  snapshot.data!.docs
                      .map(FocusIncomingDocument.fromSnapshot)
                      .toList()
                    ..sort((a, b) {
                      final aTime =
                          a.dataEmissao ??
                          a.receivedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime =
                          b.dataEmissao ??
                          b.receivedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });
              if (docs.isEmpty) {
                return const Text(
                  'Nenhum documento recebido foi capturado ainda para a empresa ativa.',
                );
              }
              return Column(
                children: [
                  for (final doc in docs) ...[
                    _IncomingXmlTile(
                      doc: doc,
                      onDownloadXml: doc.canDownloadXml
                          ? () => _downloadXml(doc)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IncomingXmlTile extends StatelessWidget {
  const _IncomingXmlTile({required this.doc, required this.onDownloadXml});

  final FocusIncomingDocument doc;
  final VoidCallback? onDownloadXml;

  @override
  Widget build(BuildContext context) {
    final issuedLabel = _formatDateTime(doc.dataEmissao, dateOnly: true);
    final totalLabel = doc.valorTotal == null
        ? '-'
        : 'R\$ ${doc.valorTotal!.toStringAsFixed(2).replaceAll('.', ',')}';

    return Material(
      color: const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppHeaderChip(doc.typeLabel),
                AppHeaderChip('Status: ${doc.status.isEmpty ? 'novo' : doc.status}'),
                if (doc.manifestStatus.isNotEmpty)
                  AppHeaderChip('Manifesto: ${doc.manifestStatus}'),
                AppHeaderChip(doc.canDownloadXml ? 'XML salvo' : 'XML pendente'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              doc.emitente.isEmpty
                  ? 'Emitente nao informado'
                  : doc.emitente,
              style: const TextStyle(
                color: AppBrandColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chave: ${doc.chave.isEmpty ? '-' : doc.chave}\n'
              'NSU: ${doc.nsu.isEmpty ? '-' : doc.nsu}\n'
              'Numero/Serie: ${doc.number.isEmpty ? '-' : doc.number} / ${doc.series.isEmpty ? '-' : doc.series}\n'
              'Documento emitente: ${doc.cnpjEmitente.isEmpty ? '-' : doc.cnpjEmitente}\n'
              'Destinatario: ${doc.destinatario.isEmpty ? '-' : doc.destinatario}\n'
              'Emissao: $issuedLabel\n'
              'Valor: $totalLabel',
              style: const TextStyle(color: AppBrandColors.ink),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onDownloadXml,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Baixar XML'),
                ),
                if (!doc.canDownloadXml)
                  const Text(
                    'Quando a Focus devolver o XML completo e ele for salvo no Storage, o download aparece aqui.',
                    style: TextStyle(
                      color: AppBrandColors.softText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(Object? value, {bool dateOnly = false}) {
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  } else if (value is String) {
    date = DateTime.tryParse(value);
  }
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  if (dateOnly) return '$day/$month/$year';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

class _LinkColumn extends StatelessWidget {
  const _LinkColumn({required this.links, required this.onOpen});

  final List<_OfficialRfLink> links;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < links.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Material(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              title: Text(
                links[i].title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(links[i].subtitle),
              trailing: const Icon(Icons.open_in_new, color: Color(0xFF1565C0)),
              onTap: () => onOpen(links[i].url),
            ),
          ),
        ],
      ],
    );
  }
}
