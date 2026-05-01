import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_landing_ui.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_screenshot_block.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_whatsapp_button.dart';

/// Landing de vendas — contador (alta conversão, dor real + módulos).
class VendasContadorPage extends StatelessWidget {
  const VendasContadorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 720;

    return Scaffold(
      backgroundColor: VendasLandingTheme.surface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                VendasLandingTopBar(
                  onLogin: () => context.go('/login-contador'),
                  loginLabel: 'Entrar',
                ),
                VendasLandingHero(
                  compact: compact,
                  headline: 'Se a operação vive em áudio e mensagem solta, você não está no comando.',
                  accentLine: 'Você está reagindo. E o escritório paga a conta.',
                  subhead:
                      'O Ponto Certo foi feito para você recuperar organização e controle: a empresa entra no fluxo '
                      '(lança, anexa e emite onde o processo exige) e você fiscaliza com rastro — carteira, fiscal, '
                      'documentos e faturamento no mesmo ritmo.',
                  badges: const [
                    'Carteira com visão do que falta',
                    'Fiscal com status e histórico',
                    'Documentos com pedido fechado',
                    '30 dias de teste grátis',
                  ],
                  onPrimary: () {
                    metaFbqTrackStartTrialEscritorio();
                    context.go('/cadastro-escritorio-contabil');
                  },
                  primaryLabel: 'QUERO ORGANIZAR MEU ESCRITÓRIO',
                  secondaryLabel: 'Falar com alguém',
                  secondaryWhatsappMessage:
                      'Olá! Sou contador e quero entender o Ponto Certo para minha carteira.',
                ),
                VendasTrustStrip(
                  compact: compact,
                  items: const [
                    'Feito na dor operacional real',
                    'Contador no fluxo — não como “outro login solto”',
                    'O que prometemos aqui existe no sistema',
                  ],
                ),
                VendasFounderStory(compact: compact, audience: VendasFounderAudience.contador),
                VendasLandingSection(
                  compact: compact,
                  label: 'O que escala / o que drena',
                  title: 'Controle não é microgerir. É padrão que a empresa segue.',
                  subtitle:
                      'Quando cada cliente inventa o próprio jeito, você vira gargalo. Com processo único, você libera tempo para assessoria de verdade.',
                  child: VendasLandingTwoCol(
                    compact: compact || w < 900,
                    left: VendasPainCard(
                      compact: compact,
                      title: 'Sinais de que o processo está quebrado',
                      items: const [
                        'Você descobre pendência quando já virou emergência',
                        'A mesma dúvida reaparece em três conversas diferentes',
                        'Nota e documento “somem” no meio do WhatsApp',
                      ],
                    ),
                    right: VendasWinCard(
                      compact: compact,
                      title: 'O que o Ponto Certo entrega ao contador',
                      items: const [
                        'Rastreamento: sabe o que foi feito, o que está em aberto e o que bloqueia o andamento',
                        'Padrão: menos exceção — mais escala na carteira',
                        'Menos cobrança emocional — mais cobrança de processo',
                      ],
                    ),
                  ),
                ),
                VendasLandingSection(
                  compact: compact,
                  label: 'Módulo a módulo',
                  title: 'Cada área que você usa está ligada à operação real',
                  subtitle:
                      'Sem lista genérica: é o que o contador enxerga no Ponto Certo para manter ordem e cobrar resultado das empresas.',
                  child: VendasFeatureList(
                    compact: compact,
                    children: [
                      VendasFeatureTile(
                        compact: compact,
                        icon: Icons.business_center,
                        title: 'Carteira: prioridade por cliente',
                        body:
                            'Em cada empresa você enxerga o que está em aberto: NF em processamento, documentos pendentes e o que já foi concluído — sem abrir dez conversas para montar o status.',
                      ),
                      VendasFeatureTile(
                        compact: compact,
                        icon: Icons.receipt_long,
                        title: 'Fiscal: rascunho até autorizada',
                        body:
                            'Acompanhe rascunho, emissão, erro e conciliação do que ficou “no ar”. Você para de perguntar “já saiu?” e cobra o próximo passo com base em tela.',
                      ),
                      VendasFeatureTile(
                        compact: compact,
                        icon: Icons.folder_open,
                        title: 'Documentos: um pedido, um dono',
                        body:
                            'Solicitação com itens definidos e anexos no pedido certo (empresa, colaborador ou você). Histórico auditável — adeus PDF perdido em grupo.',
                      ),
                      VendasFeatureTile(
                        compact: compact,
                        icon: Icons.insert_chart,
                        title: 'Faturamento: número que explica o mês',
                        body:
                            'Leitura do que entrou, do que falta bater com banco e do que sustenta o fechamento — você orienta o cliente com dado, não com palpite.',
                      ),
                    ],
                  ),
                ),
                VendasLandingSection(
                  compact: compact,
                  label: 'Como entra em movimento',
                  title: 'Três passos para instalar padrão — sem recomeçar do zero',
                  child: VendasStepsRow(
                    compact: compact || w < 900,
                    steps: const [
                      VendasStepItem(
                        title: 'Ative o escritório',
                        body: 'Cadastro do escritório e seu acesso de contador, com a carteira pronta para receber empresas.',
                      ),
                      VendasStepItem(
                        title: 'Traga a empresa certa',
                        body: 'Vincule o cliente e comece a operar no mesmo ambiente que ele vai usar no dia a dia.',
                      ),
                      VendasStepItem(
                        title: 'Substitua improviso por roteiro',
                        body: 'Fiscal, documentos e financeiro passam a ter fila, status e responsável — você permanece no comando do processo.',
                      ),
                    ],
                  ),
                ),
                VendasScreenshotSection(
                  compact: compact,
                  title: 'Isso aqui não é render 3D. É o que você usa.',
                  subtitle:
                      'Carteira, fiscal e leitura de fechamento — o tipo de tela que reduz ligações desnecessárias e sustenta uma cobrança justa.',
                  blocks: const [
                    VendasScreenshotBlock(
                      asset: VendasMarketingAssets.contadorPainel,
                      label: 'Carteira com leitura de gestão',
                      caption: 'O que está em dia, o que pede atenção e onde a rotina engasga.',
                    ),
                    VendasScreenshotBlock(
                      asset: VendasMarketingAssets.contadorFiscal,
                      label: 'Fiscal onde dói menos',
                      caption: 'Menos “cadê a nota?” — mais status e histórico em um só lugar.',
                    ),
                    VendasScreenshotBlock(
                      asset: VendasMarketingAssets.relatorios,
                      label: 'Fechamento que conversa com a operação',
                      caption: 'Relaciona fiscal e movimento para explicar o resultado ao cliente com menos improviso.',
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 18 : 40, 8, compact ? 18 : 40, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: VendasPricingOffer(
                        compact: compact,
                        title: 'Plano único',
                        billingNote: 'Cobrança mensal por escritório de contabilidade (CNPJ).',
                        priceSuffix: '/mês · por escritório',
                        bullets: const [
                          '30 dias de teste grátis para validar na carteira',
                          'R\$ 97,90/mês por escritório — carteira, fiscal, documentos e faturamento no mesmo fluxo',
                          'Preço transparente: condições completas constam no contrato de assinatura',
                        ],
                        primaryChild: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              metaFbqTrackStartTrialEscritorio();
                              context.go('/cadastro-escritorio-contabil');
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: VendasLandingTheme.heroTop,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'COMEÇAR TESTE GRÁTIS AGORA',
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.35),
                            ),
                          ),
                        ),
                        whatsapp: const VendasWhatsappButton(
                          label: 'Quero tirar dúvidas antes',
                          mensagemInicial:
                              'Olá! Sou contador e quero entender o Ponto Certo para minha carteira.',
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 24 : 40, 8, compact ? 24 : 40, 20),
                  child: Text(
                    'Você pode continuar sendo o escudo humano de todo mundo.\nOu pode instalar um processo que trabalha com você.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 17 : 19,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      color: VendasLandingTheme.ink,
                    ),
                  ),
                ),
                VendasLandingFooter(
                  compact: compact,
                  onInicio: () => context.go('/inicio'),
                  onEntrar: () => context.go('/login-contador'),
                  entrarLabel: 'Entrar',
                  whatsappFooterPrefill:
                      'Olá! Sou contador e quero falar sobre o Ponto Certo.',
                  pricingLine: '30 dias de teste grátis · R\$ 97,90/mês por escritório',
                  onWhatsapp: () => abrirWhatsappVendas(
                    mensagemInicial: 'Olá! Sou contador e quero falar sobre o Ponto Certo.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
