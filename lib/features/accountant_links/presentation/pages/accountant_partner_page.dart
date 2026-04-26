import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';

class AccountantPartnerPage extends ConsumerStatefulWidget {
  const AccountantPartnerPage({super.key});

  @override
  ConsumerState<AccountantPartnerPage> createState() =>
      _AccountantPartnerPageState();
}

class _AccountantPartnerPageState extends ConsumerState<AccountantPartnerPage> {
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  late Future<_PartnerContact> _contactFuture;

  @override
  void initState() {
    super.initState();
    _contactFuture = _loadContact();
  }

  Future<_PartnerContact> _loadContact() async {
    final callable = _functions.httpsCallable('accountantGetPartnerContact');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return _PartnerContact.fromMap(data);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null || session.role != Role.accountant) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(body: Center(child: Text('Acesso negado.')));
    }

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Seja nosso parceiro',
        subtitle:
            'Uma parceria para ajudar seu escritorio a tirar clientes do improviso, reduzir retrabalho mensal e transformar organizacao em valor percebido.',
        chips: [
          AppHeaderChip('Parceria com contador'),
          AppHeaderChip('Crescimento com recorrencia'),
        ],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: FutureBuilder<_PartnerContact>(
          future: _contactFuture,
          builder: (context, contactSnapshot) {
            final contact = contactSnapshot.data;
            return ListView(
              children: [
                const AppWorkspaceCard(
                    title: 'O que o contador esta indicando',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O Ponto Certo entrega para a empresa uma base unica de operacao, financeiro, documentos, faturamento e organizacao fiscal, sem depender de WhatsApp solto, planilha espalhada e memoria do dono.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Na pratica, a empresa passa a trabalhar com mais controle, historico, previsibilidade e menos improviso. Isso melhora o dia a dia dela e melhora diretamente o que chega para o escritorio contabil.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AppWorkspaceCard(
                    title: 'Beneficios reais para a empresa',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '- mais controle da operacao, da equipe e dos documentos',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- mais leitura financeira e menos decisao no escuro',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- contratos, solicitacoes e rotina em um fluxo mais padronizado',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- base melhor para o fiscal e para a relacao com o contador',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AppWorkspaceCard(
                    title: 'Por que isso e bom para o contador',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '- reduz retrabalho com dado faltando, documento perdido e processo quebrado',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- melhora a qualidade das informacoes que chegam ao escritorio',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- ajuda a sustentar uma cobranca melhor pelo seu servico',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- cria uma carteira mais organizada, previsivel e mais facil de operar',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AppWorkspaceCard(
                    title: 'Historia que o cliente entende',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voce pode apresentar o sistema como uma resposta real a dores que empresario e contador vivem juntos: atraso na entrega de documentos, financeiro sem leitura, emissao fiscal pressionada, processos sem padrao e fechamento sempre em cima da hora.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'A venda fica mais forte quando o cliente percebe que a plataforma nao nasceu de teoria. Ela nasceu da rotina real de empresa de servico e da pressao que isso gera no escritorio contabil.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Planos para indicar ao cliente',
                    subtitle:
                        'Regra comercial atual: sistema inteiro em teste real gratis por 30 dias, sem cobranca de implantacao. Depois do trial, escritorio a R\$ 97,90 por mes com opcao de isencao em parceria aprovada; empresa a R\$ 97,90 por mes; app Play Store a R\$ 19,90 por acesso adicional.',
                    child: Column(
                      children: [
                        _PricingCard(
                          title: 'Uso mensal do sistema para a empresa',
                          priceLabel: 'R\$ 97,90/mes',
                          implantationLabel:
                              'Teste real gratis por 30 dias com contador indicado pela empresa',
                          suggestedPackage:
                              'Depois do trial, a parceria aprovada pode isentar a cobranca do escritorio.',
                          description:
                              'Valor da empresa depois do trial para operar com base unica, organizar a rotina e melhorar a relacao com o contador.',
                        ),
                        const SizedBox(height: 12),
                        _PricingCard(
                          title: 'Uso mensal do escritorio contabil',
                          priceLabel: 'R\$ 97,90/mes',
                          implantationLabel:
                              'Pode ser isento em parceria aprovada',
                          suggestedPackage:
                              'O contador entra primeiro como responsavel pelo cadastro da empresa no trial; parceria aprovada pode zerar essa cobranca recorrente.',
                          description:
                              'A assinatura libera o ambiente do escritorio e pode ser ajustada para isencao comercial quando a parceria for validada.',
                        ),
                        const SizedBox(height: 12),
                        _PricingCard(
                          title: 'Acesso adicional no app Play Store',
                          priceLabel: 'R\$ 19,90/mes',
                          implantationLabel:
                              'Cobrado por acesso adicional do app',
                          suggestedPackage:
                              'Use este valor quando a empresa ampliar a equipe no app depois do trial.',
                          description:
                              'Cada colaborador adicional usando o app Play Store entra nessa faixa para ponto, tarefas, documentos e rotina operacional.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Contato para fechar parceria',
                    subtitle:
                        'Use estes dados para falar direto com a empresa suprema e alinhar a parceria.',
                    child:
                        contactSnapshot.connectionState !=
                                ConnectionState.done &&
                            contact == null
                        ? const Center(child: CircularProgressIndicator())
                        : contact == null
                        ? Text(
                            AppErrorMapper.messageFrom(
                              contactSnapshot.error ??
                                  'Nao foi possivel carregar o contato.',
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.companyName.isNotEmpty
                                    ? contact.companyName
                                    : 'Empresa suprema',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppBrandColors.ink,
                                ),
                              ),
                              if (contact.legalName.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Razao social: ${contact.legalName}'),
                              ],
                              if (contact.email.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SelectableText('Email: ${contact.email}'),
                              ],
                              if (contact.phone.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SelectableText('Telefone: ${contact.phone}'),
                              ],
                              if (contact.city.isNotEmpty ||
                                  contact.state.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Local: ${contact.city}${contact.state.isNotEmpty ? '/${contact.state}' : ''}',
                                ),
                              ],
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

class _PartnerContact {
  const _PartnerContact({
    required this.companyName,
    required this.legalName,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
  });

  final String companyName;
  final String legalName;
  final String email;
  final String phone;
  final String city;
  final String state;

  factory _PartnerContact.fromMap(Map<String, dynamic> map) {
    return _PartnerContact(
      companyName: map['companyName']?.toString() ?? '',
      legalName: map['legalName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.priceLabel,
    required this.implantationLabel,
    required this.suggestedPackage,
    required this.description,
  });

  final String title;
  final String priceLabel;
  final String implantationLabel;
  final String suggestedPackage;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppBrandColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            priceLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppBrandColors.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            implantationLabel,
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            suggestedPackage,
            style: const TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
