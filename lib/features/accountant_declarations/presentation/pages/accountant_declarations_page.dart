import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/urls/receita_official_urls.dart';
import 'package:pontocerto/features/accountant_links/presentation/accountant_company_links_provider.dart';
import 'package:pontocerto/features/fiscal/presentation/widgets/focus_incoming_xml_section.dart';
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
/// e captura de XML por empresa ativa do contador (mesmo painel da rota Fiscal).
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
            'Acessos oficiais com acao, isolamento por empresa ativa e captura de XML via Focus (painel igual ao modulo Fiscal da empresa).',
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
            FocusIncomingXmlSection(session: session),
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
