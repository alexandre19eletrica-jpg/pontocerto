import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_landing_ui.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_screenshot_block.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_whatsapp_button.dart';

/// Landing de vendas - empresa.
class VendasEmpresaPage extends StatefulWidget {
  const VendasEmpresaPage({super.key});

  @override
  State<VendasEmpresaPage> createState() => _VendasEmpresaPageState();
}

class _VendasEmpresaPageState extends State<VendasEmpresaPage> {
  final _signupKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      metaFbqTrackVendasEmpresaLandingView();
    });
  }

  void _scrollToSignup() {
    final ctx = _signupKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 720;
    final narrowGrid = compact || w < 900;

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
                    onLogin: () => context.go('/inicio'),
                    loginLabel: 'Inicio',
                  ),
                  VendasLandingHero(
                    compact: compact,
                    headline:
                        'Servico prestado sem nota no prazo vira problema de caixa.',
                    accentLine:
                        'Emitir com seguranca juridico-fiscal e manter tesouraria alinhada a producao custa menos do que reorganizar erro depois.',
                    subhead:
                        'Comece na plataforma com o pre-cadastro da empresa e deixe a documentacao mais sensivel para quando seu escritorio calendarizar o fiscal.'
                        ' Se ja opera com escritorio contabil externo, indique esse vinculo ao avancar; escritorios usam rota comercial propria dedicada a contadores.'
                        ' Se voce e MEI, nao mantem contador e consegue concluir o cadastro fiscal e os dados obrigatorios da empresa por conta propria no que couber ao seu caso, usar o Ponto Certo aqui nao exige contratar escritorio nem contador atraves da nossa ferramenta — pode apenas avancar, contratar apoio quando fizer sentido ou tirar duvidas pelo WhatsApp que ja aparece mais abaixo e no topo.'
                        ' Pode abrir antes a demonstracao seguinte (somente navegacao demonstrativa) ou avancar direto; apos primeira adesao formal, garantimos ate trinta dias para uso avaliativo antes de cobranca inicial acordada nos termos comerciais comunicados nessa fase.',
                    badges: const [
                      'Demonstracao gratuita antes de primeira adesao',
                      'MEI sem contador pode finalizar cadastro fiscal e seguir solo se souber obrigacoes do seu caso',
                      'Pre-cadastro com complemento fiscal no seu ritmo',
                      'Emissao no celular ou no computador',
                      'Trinta dias de avaliacao apos primeira adesao',
                    ],
                    onPrimary: () => context.go('/cadastro-empresa'),
                    primaryLabel: 'COMEÇAR PRÉ-CADASTRO DA EMPRESA',
                    secondaryLabel: 'Falar com alguem',
                    onSecondary: () {
                      abrirWhatsappVendas(
                        mensagemInicial:
                            'Ola! Tenho empresa e quero entender o pre-cadastro e a operacao no Ponto Certo.',
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD7E3F4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Demonstracao gratuita do sistema',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use esta area para navegar em modo apenas demonstrativo: pode observar emissao, financeiro e documentacao sem iniciar primeira adesao empresarial no sistema.',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'MEI ou empresa que nao depende de contador no momento: nao existe exigencia de contratar escritorio pelo Ponto Certo para iniciar.'
                            ' Pode apenas seguir pela demonstracao ou pelo pre-cadastro, contratar apoio contabil mais tarde se quiser, ou falar pelo WhatsApp com o time comercial usando os botoes desta propria pagina.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: VendasLandingTheme.inkMuted,
                                ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/demo-empresa'),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Ver demo da empresa'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VendasTrustStrip(
                    compact: compact,
                    items: const [
                      'Produto nascido na operacao real - nao em slide de agencia',
                      'A empresa pode entrar direto e organizar o processo desde o primeiro dia',
                      'O que prometemos aqui corresponde ao que o sistema ja oferece hoje',
                    ],
                  ),
                  VendasFounderStory(
                    compact: compact,
                    audience: VendasFounderAudience.empresa,
                  ),
                  VendasLandingSection(
                    compact: compact,
                    label: 'Custo do atraso',
                    title: 'Cada hora sem nota e sem controle pesa no caixa.',
                    subtitle:
                        'Servico nao espera voce voltar para o escritorio. Quando a rotina depende de memoria, print e recado solto, o lucro paga a conta do atraso.',
                    child: VendasLandingTwoCol(
                      compact: narrowGrid,
                      left: VendasPainCard(
                        compact: compact,
                        title: 'O que costuma quebrar a rotina',
                        items: const [
                          'Voce prestou o servico, mas a nota ficou para depois',
                          'Cliente cobra NF enquanto a equipe procura informacao espalhada',
                          'Cobranca, pagamento e documento ficam cada um em um canto',
                        ],
                      ),
                      right: VendasWinCard(
                        compact: compact,
                        title: 'O que o Ponto Certo troca na pratica',
                        items: const [
                          'Fluxo de emissao que voce consegue tocar quando o servico acontece',
                          'A empresa organiza a operacao sem travar o inicio com terceiros',
                          'Financeiro e documentos ganham sequencia - menos retrabalho caro',
                        ],
                      ),
                    ),
                  ),
                  VendasLandingSection(
                    compact: compact,
                    label: 'Modulo a modulo',
                    title: 'Da execucao ao recebimento: tudo conversando',
                    subtitle:
                        'Cada bloco abaixo mostra o que a empresa usa no Ponto Certo para emitir, acompanhar e organizar a operacao sem depender de rotina paralela.',
                    child: VendasFeatureList(
                      compact: compact,
                      children: [
                        VendasFeatureTile(
                          compact: compact,
                          icon: Icons.receipt_long,
                          title: 'NFS-e sem fila escondida',
                          body:
                              'Abra o fluxo no celular ou no computador, preencha o servico e avance a nota sem depender de recado solto para fechar depois.',
                        ),
                        VendasFeatureTile(
                          compact: compact,
                          icon: Icons.dashboard,
                          title: 'Painel: o que nao pode esperar',
                          body:
                              'Cobranca vencendo, NF pendente e documento sem resposta aparecem no lugar certo, sem vasculhar grupo de mensagem.',
                        ),
                        VendasFeatureTile(
                          compact: compact,
                          icon: Icons.payments,
                          title: 'Financeiro ligado a nota',
                          body:
                              'Recebimentos e pagamentos ficam ligados ao que ja foi faturado: menos caixa que nao bate com a operacao.',
                        ),
                        VendasFeatureTile(
                          compact: compact,
                          icon: Icons.assignment_turned_in,
                          title: 'Documentos com fila e dono',
                          body:
                              'Solicitacao de PDF, contrato ou comprovante vira pedido numerado: quem enviou, quando e qual anexo ficou pendente.',
                        ),
                      ],
                    ),
                  ),
                  VendasLandingSection(
                    compact: compact,
                    label: 'Modelo atual',
                    title:
                        'A empresa entra primeiro. O apoio contabil pode entrar depois, se desejar.',
                    subtitle:
                        'Hoje o caminho correto e simples: voce faz o pre-cadastro da empresa, entra no sistema e organiza a operacao. Se ja conhece suas obrigacoes fiscais e cadastrais (comum em alguns perfis MEI), seguir assim e suficiente; se quiser escritorio mais tarde, conecte quando precisar. Para perguntas comerciais antes de entrar, o WhatsApp desta landing responde no mesmo lugar.',
                    child: VendasStepsRow(
                      compact: narrowGrid,
                      steps: const [
                        VendasStepItem(
                          title: '1. Empresa entra direto',
                          body:
                              'Voce inicia o pre-cadastro da empresa e abre o seu acesso sem depender de convite para terceiro.',
                        ),
                        VendasStepItem(
                          title: '2. Organiza a rotina',
                          body:
                              'Painel, emissao, financeiro e documentos passam a andar no mesmo fluxo desde o primeiro uso.',
                        ),
                        VendasStepItem(
                          title: '3. Apoio contabil opcional',
                          body:
                              'Sem contador proprio mas confortavel com cadastro fiscal e dados da empresa: continua usando o sistema; com tempo, pode contratar apoio contabil ou apenas esclarecer pelo WhatsApp o que faz sentido para voce.',
                        ),
                      ],
                    ),
                  ),
                  VendasScreenshotSection(
                    compact: compact,
                    title: 'Veja a operacao completa - nao so uma tela bonita',
                    subtitle:
                        'Painel, emissao, caixa e documentos: o fluxo em que "depois eu resolvo" vira "ja esta aqui".',
                    blocks: const [
                      VendasScreenshotBlock(
                        asset: VendasMarketingAssets.empresaPainel,
                        label: 'Seu dia com prioridade visivel',
                        caption:
                            'O que esta verde, o que esta amarelo e o que vai custar caro se ignorar.',
                      ),
                      VendasScreenshotBlock(
                        asset: VendasMarketingAssets.empresaFiscalEmissao,
                        label: 'Emissao onde voce estiver',
                        caption:
                            'Fluxo pensado para quem vende servico e nao pode ficar preso a fila de espera.',
                      ),
                      VendasScreenshotBlock(
                        asset: VendasMarketingAssets.empresaFinanceiro,
                        label: 'Dinheiro com contexto',
                        caption:
                            'Liga cobranca e resultado ao que ja foi formalizado na operacao.',
                      ),
                      VendasScreenshotBlock(
                        asset: VendasMarketingAssets.empresaDocumentos,
                        label: 'Pedido fechado, arquivo no lugar',
                        caption:
                            'Menos "me manda de novo" - mais rastro entre equipe, documentos e operacao.',
                      ),
                    ],
                  ),
                  Container(
                    key: _signupKey,
                    color: VendasLandingTheme.surface,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 40,
                      8,
                      compact ? 18 : 40,
                      12,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMECE O PRE-CADASTRO DA SUA EMPRESA',
                              style: TextStyle(
                                fontSize: compact ? 13 : 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: VendasLandingTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Entre no sistema pelo caminho certo',
                              style: TextStyle(
                                fontSize: compact ? 26 : 30,
                                fontWeight: FontWeight.w900,
                                color: VendasLandingTheme.ink,
                                height: 1.12,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'O pre-cadastro da empresa e direto. Voce abre o acesso, estrutura a operacao e, se mantiver contador, pode integrar o fluxo quando fizer sentido; se opera sem contador (como varios MEI) mas conhece suas obrigacoes, tambem nao precisa contratar escritorio obrigatorio por aqui - use o WhatsApp desta pagina para duvidas antes de clicar.',
                              style: TextStyle(
                                fontSize: compact ? 17 : 17,
                                fontWeight: FontWeight.w600,
                                color: VendasLandingTheme.inkMuted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: EdgeInsets.all(compact ? 18 : 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: VendasLandingTheme.border,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Voce vai para a tela de cadastro da empresa, onde inicia o acesso real no modelo atual do Ponto Certo.',
                                    style: TextStyle(
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                      color: VendasLandingTheme.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const _EmpresaSignupBullet(
                                    icon: Icons.check_circle_outline,
                                    text:
                                        'Comece pela empresa, sem depender de convite nem de aprovacao de terceiro.',
                                  ),
                                  const SizedBox(height: 12),
                                  const _EmpresaSignupBullet(
                                    icon: Icons.check_circle_outline,
                                    text:
                                        'Organize emissao, financeiro e documentos no mesmo fluxo desde o primeiro acesso.',
                                  ),
                                  const SizedBox(height: 12),
                                  const _EmpresaSignupBullet(
                                    icon: Icons.check_circle_outline,
                                    text:
                                        'Contratar escritorio opcional — MEI ou quem faz fiscal so pode continuar assim; duvidas antes de iniciar ficam pelo WhatsApp desta pagina.',
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: () =>
                                        context.go('/cadastro-empresa'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          VendasLandingTheme.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(
                                        double.infinity,
                                        compact ? 52 : 48,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'IR PARA O PRÉ-CADASTRO DA EMPRESA',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.15,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 40,
                      16,
                      compact ? 18 : 40,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: VendasPricingOffer(
                          compact: compact,
                          title: 'Plano unico',
                          billingNote:
                              'Cobranca mensal por empresa cadastrada e ativa no sistema.',
                          priceSuffix: '/mes · por empresa',
                          bullets: const [
                            '30 dias de teste gratis para validar o fluxo real da empresa',
                            'R\$ 97,90/mes por empresa - fiscal, painel, financeiro e documentos no mesmo fluxo',
                            'Sem contador e confortavel com cadastro fiscal: ninguem obriga a contratar — pode apenas seguir ou falar primeiro no WhatsApp',
                          ],
                          primaryChild: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _scrollToSignup,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: VendasLandingTheme.heroTop,
                                minimumSize: Size(
                                  double.infinity,
                                  compact ? 52 : 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'IR PARA O PRÉ-CADASTRO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          whatsapp: const VendasWhatsappButton(
                            label: 'Prefere tirar duvidas no WhatsApp',
                            mensagemInicial:
                                'Ola! Vi a pagina do Ponto Certo para empresas e gostaria de conversar.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 24 : 40,
                      0,
                      compact ? 24 : 40,
                      20,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Amanha voce pode repetir a mesma correria de sempre.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact ? 17 : 19,
                            fontWeight: FontWeight.w800,
                            color: VendasLandingTheme.inkMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ou pode começar hoje o pré-cadastro da empresa e colocar a operação em ordem de verdade.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact ? 20 : 24,
                            fontWeight: FontWeight.w900,
                            color: VendasLandingTheme.primary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  VendasLandingFooter(
                    compact: compact,
                    onInicio: () => context.go('/inicio'),
                    pricingLine:
                        '30 dias de teste gratis · R\$ 97,90/mes por empresa',
                    onWhatsapp: () => abrirWhatsappVendas(
                      mensagemInicial:
                          'Ola! Tenho empresa e vi o Ponto Certo - quero tirar duvidas.',
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

class _EmpresaSignupBullet extends StatelessWidget {
  const _EmpresaSignupBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: VendasLandingTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: VendasLandingTheme.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
