import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/services/vendas_public_flow_service.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_landing_ui.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_screenshot_block.dart';
import 'package:pontocerto/features/marketing/presentation/widgets/vendas_whatsapp_button.dart';

/// Landing de vendas — empresa (lead para contador).
class VendasEmpresaPage extends StatefulWidget {
  const VendasEmpresaPage({super.key});

  @override
  State<VendasEmpresaPage> createState() => _VendasEmpresaPageState();
}

class _VendasEmpresaPageState extends State<VendasEmpresaPage> {
  final _nomeEmpresa = TextEditingController();
  final _nomeContabilidade = TextEditingController();
  final _emailContador = TextEditingController();
  final _emailEmpresa = TextEditingController();
  final _inviteKey = GlobalKey();
  bool _enviando = false;
  String? _mensagem;
  bool _envioOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      metaFbqTrackVendasEmpresaLandingView();
    });
  }

  @override
  void dispose() {
    _nomeEmpresa.dispose();
    _nomeContabilidade.dispose();
    _emailContador.dispose();
    _emailEmpresa.dispose();
    super.dispose();
  }

  void _scrollToInvite() {
    final ctx = _inviteKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    }
  }

  Future<void> _enviar() async {
    final ne = _nomeEmpresa.text.trim();
    final nc = _nomeContabilidade.text.trim();
    final ec = _emailContador.text.trim().toLowerCase();
    final ee = _emailEmpresa.text.trim().toLowerCase();
    if (ne.isEmpty || nc.isEmpty || ec.isEmpty) {
      setState(() {
        _mensagem = 'Preencha o nome da empresa, o nome da contabilidade e o e-mail do contador.';
        _envioOk = false;
      });
      return;
    }
    setState(() {
      _enviando = true;
      _mensagem = null;
      _envioOk = false;
    });
    try {
      final uri = vendasLeadContabilidadeUri();
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome_empresa': ne,
          'nome_contabilidade': nc,
          'email_contador': ec,
          if (ee.isNotEmpty) 'email_empresa': ee,
        }),
      );
      final map = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic> : <String, dynamic>{};
      if (!mounted) return;
      if (res.statusCode == 200 && map['ok'] == true) {
        final leadId = map['leadId']?.toString() ?? '';
        metaFbqTrackLeadConviteContadorLandingEmpresa(leadId: leadId);
        setState(() {
          _envioOk = true;
          _mensagem =
              'Pronto. Enviamos um e-mail ao seu contador com o link para criar o acesso do escritório. '
              'Depois que ele entrar no sistema, cadastrará a sua empresa pelo painel dele. '
              'Você não abre conta sozinha por aqui. Se você informou o seu e-mail, também enviamos um resumo.';
        });
      } else {
        final err = map['error']?.toString() ?? 'erro';
        setState(() {
          _envioOk = false;
          _mensagem = switch (err) {
            'email-invalido' => 'O e-mail do contador parece inválido. Confira e tente de novo.',
            'email-empresa-invalido' => 'O seu e-mail parece inválido. Confira ou deixe em branco.',
            'campos-obrigatorios' => 'Preencha todos os campos obrigatórios.',
            _ => 'Não foi possível enviar agora. Tente de novo em instantes.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _envioOk = false;
          _mensagem = 'Sem conexão ou erro no envio. Verifique a internet e tente de novo.';
        });
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
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
                      loginLabel: 'Início',
                    ),
                    VendasLandingHero(
                      compact: compact,
                      headline: 'Serviço bom com nota atrasada vira problema de caixa.',
                      accentLine: 'Você precisa emitir com segurança — até do celular, longe do escritório.',
                      subhead:
                          'No Ponto Certo você avança na NFS-e com fluxo guiado: na obra, no carro ou na recepção. '
                          'Seu contador vê o mesmo processo, com status e histórico — acaba a novela de print no WhatsApp e '
                          'do “depois eu vejo”.',
                      badges: const [
                        'Emissão pelo celular ou computador',
                        'Contador no mesmo sistema',
                        'Financeiro e documentos ligados à operação',
                        '30 dias de teste grátis',
                      ],
                      onPrimary: _scrollToInvite,
                      primaryLabel: 'LIBERAR MEU CONTADOR AGORA',
                      secondaryLabel: 'Falar com alguém',
                      onSecondary: () {
                        abrirWhatsappVendas(
                          mensagemInicial:
                              'Olá! Tenho empresa e quero entender o Ponto Certo (nota pelo celular + contador).',
                        );
                      },
                    ),
                    VendasTrustStrip(
                      compact: compact,
                      items: const [
                        'Produto nascido na operação real — não em slide de agência',
                        'Empresa executa; contador fiscaliza no mesmo ambiente',
                        'O que prometemos aqui corresponde ao que o sistema já oferece hoje',
                      ],
                    ),
                    VendasFounderStory(compact: compact, audience: VendasFounderAudience.empresa),
                    VendasLandingSection(
                      compact: compact,
                      label: 'Custo de ficar no improviso',
                      title: 'Cada hora sem nota é cliente cobrando e dinheiro travado.',
                      subtitle:
                          'Obra e serviço não esperam você “voltar para o PC”. Quando o processo depende só de memória e mensagem, quem paga o preço é o lucro.',
                      child: VendasLandingTwoCol(
                        compact: narrowGrid,
                        left: VendasPainCard(
                          compact: compact,
                          title: 'O que costuma dar errado',
                          items: const [
                            'Você até faturou — mas a nota ficou pra depois',
                            'Cliente pediu NF e você virou refém do horário do contador',
                            'Cobrança, pagamento e documento: cada um isolado no seu canto',
                          ],
                        ),
                        right: VendasWinCard(
                          compact: compact,
                          title: 'O que o Ponto Certo troca na prática',
                          items: const [
                            'Fluxo de emissão que você consegue tocar quando o serviço acontece',
                            'Contador acompanha o status e tira dúvidas com base em dados, não em áudio',
                            'Financeiro e documentos ganham sequência — menos retrabalho caro',
                          ],
                        ),
                      ),
                    ),
                    VendasLandingSection(
                      compact: compact,
                      label: 'Módulo a módulo',
                      title: 'Da obra ao fechamento: tudo conversando',
                      subtitle:
                          'Cada bloco abaixo mostra, na prática, o que a empresa usa no Ponto Certo — com ênfase na emissão ágil e no contador dentro do processo.',
                      child: VendasFeatureList(
                        compact: compact,
                        children: [
                          VendasFeatureTile(
                            compact: compact,
                            icon: Icons.receipt_long,
                            title: 'NFS-e: do canteiro ou do carro',
                            body:
                                'Abra o fluxo no celular, preencha o serviço e avance a nota sem esperar “voltar ao escritório”. '
                                'Seu contador vê o mesmo status — acabou o “manda print que eu emito depois”.',
                          ),
                          VendasFeatureTile(
                            compact: compact,
                            icon: Icons.dashboard,
                            title: 'Painel: o que não pode esperar',
                            body:
                                'Cobrança vencendo, NF pendente, documento sem resposta — o resumo do que exige decisão hoje, sem vasculhar grupo de mensagem.',
                          ),
                          VendasFeatureTile(
                            compact: compact,
                            icon: Icons.payments,
                            title: 'Financeiro ligado à nota',
                            body:
                                'Recebimentos e pagamentos com vínculo ao que já foi faturado: menos caixa que não bate com o fiscal.',
                          ),
                          VendasFeatureTile(
                            compact: compact,
                            icon: Icons.assignment_turned_in,
                            title: 'Documentos com fila e dono',
                            body:
                                'Solicitação de PDF, contrato ou holerite vira pedido numerado: quem enviou, quando e o anexo certo.',
                          ),
                        ],
                      ),
                    ),
                    VendasLandingSection(
                      compact: compact,
                      label: 'Transparência',
                      title: 'Sem contador dentro, não fecha o quebra-cabeça.',
                      subtitle:
                        'Neste fluxo você indica a contabilidade: enviamos o convite, o escritório cria o acesso e você é vinculado. '
                        'Assim, todos enxergam o mesmo processo — você ganha velocidade sem abrir mão da governança fiscal.',
                      child: VendasStepsRow(
                        compact: narrowGrid,
                        steps: const [
                          VendasStepItem(
                            title: 'Você dispara o convite',
                            body: 'Informe o nome da empresa, o nome da contabilidade e o e-mail de quem opera a parte fiscal.',
                          ),
                          VendasStepItem(
                            title: 'Contador entra no Ponto Certo',
                            body: 'Ele cadastra o escritório, inclui você na carteira e alinha como usar o sistema.',
                          ),
                          VendasStepItem(
                            title: 'Operação de verdade',
                            body: 'A partir daí, o teste vale no sistema real — nota, financeiro e documentos no mesmo lugar.',
                          ),
                        ],
                      ),
                    ),
                    VendasScreenshotSection(
                      compact: compact,
                      title: 'Veja a operação completa — não só uma tela bonita',
                      subtitle:
                          'Painel, emissão, caixa e documentos: o fluxo em que “depois eu resolvo” vira “já está aqui”.',
                      blocks: const [
                        VendasScreenshotBlock(
                          asset: VendasMarketingAssets.empresaPainel,
                          label: 'Seu dia com prioridade visível',
                          caption: 'O que está verde, o que amarelo e o que vai custar caro se ignorar.',
                        ),
                        VendasScreenshotBlock(
                          asset: VendasMarketingAssets.empresaFiscalEmissao,
                          label: 'Emissão onde você estiver',
                          caption: 'Fluxo pensado para quem vende serviço e não pode ficar preso a fila de espera.',
                        ),
                        VendasScreenshotBlock(
                          asset: VendasMarketingAssets.empresaFinanceiro,
                          label: 'Dinheiro com contexto',
                          caption: 'Liga cobrança e resultado ao que já foi formalizado na operação.',
                        ),
                        VendasScreenshotBlock(
                          asset: VendasMarketingAssets.empresaDocumentos,
                          label: 'Pedido fechado, arquivo no lugar',
                          caption: 'Menos “me manda de novo” — mais rastro entre empresa, contador e equipe.',
                        ),
                      ],
                    ),
                    Container(
                      key: _inviteKey,
                      color: VendasLandingTheme.surface,
                      padding: EdgeInsets.fromLTRB(compact ? 18 : 40, 8, compact ? 18 : 40, 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INDIQUE O SEU CONTADOR',
                                style: TextStyle(
                                  fontSize: compact ? 13 : 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: VendasLandingTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Preencha em um minuto',
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
                                'Enviamos o convite para o seu contador: ele cadastra o escritório e vincula a sua empresa ao sistema. Sem cadastro escondido nem surpresa.',
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
                                  border: Border.all(color: VendasLandingTheme.border),
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
                                    TextField(
                                      controller: _nomeEmpresa,
                                      decoration: InputDecoration(
                                        labelText: 'Nome da sua empresa',
                                        filled: true,
                                        fillColor: VendasLandingTheme.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _nomeContabilidade,
                                      decoration: InputDecoration(
                                        labelText: 'Nome da contabilidade (escritório)',
                                        filled: true,
                                        fillColor: VendasLandingTheme.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _emailContador,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'E-mail do contador (convite)',
                                        filled: true,
                                        fillColor: VendasLandingTheme.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _emailEmpresa,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Seu e-mail (opcional, resumo para você)',
                                        filled: true,
                                        fillColor: VendasLandingTheme.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: _enviando ? null : _enviar,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: VendasLandingTheme.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(double.infinity, compact ? 52 : 48),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _enviando
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'ENVIAR CONVITE AO MEU CONTADOR',
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
                              if (_mensagem != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _mensagem!,
                                  style: TextStyle(
                                    color: _envioOk ? VendasLandingTheme.success : const Color(0xFFB45309),
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                    fontSize: compact ? 15 : 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 18 : 40, 16, compact ? 18 : 40, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: VendasPricingOffer(
                            compact: compact,
                            title: 'Plano único',
                            billingNote: 'Cobrança mensal por empresa cadastrada e ativa no sistema.',
                            priceSuffix: '/mês · por empresa',
                            bullets: const [
                              '30 dias de teste grátis — valide a emissão pelo celular junto com o seu contador',
                              'R\$ 97,90/mês por empresa — fiscal, painel, financeiro e documentos no mesmo fluxo',
                              'Condições formais ficam com o seu escritório no fechamento da contratação',
                            ],
                            primaryChild: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _scrollToInvite,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: VendasLandingTheme.heroTop,
                                  minimumSize: Size(double.infinity, compact ? 52 : 48),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text(
                                  'IR PARA O FORMULÁRIO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            whatsapp: const VendasWhatsappButton(
                              label: 'Prefere tirar dúvidas no WhatsApp',
                              mensagemInicial:
                                  'Olá! Vi a página do Ponto Certo para empresas e gostaria de conversar.',
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 24 : 40, 0, compact ? 24 : 40, 20),
                      child: Column(
                        children: [
                          Text(
                            'Amanhã você pode ter a mesma história de sempre.',
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
                            'Ou, hoje mesmo, você integra o seu contador ao processo e destrava a nota de onde estiver.',
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
                      pricingLine: '30 dias de teste grátis · R\$ 97,90/mês por empresa',
                      onWhatsapp: () => abrirWhatsappVendas(
                        mensagemInicial:
                            'Olá! Tenho empresa e vi o Ponto Certo — quero tirar dúvidas.',
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
