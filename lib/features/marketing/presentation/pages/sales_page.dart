import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_demo_access_service.dart';

const _ink = Color(0xFF16202B);
const _muted = Color(0xFF5C6B7A);
const _primary = Color(0xFF1E4FD7);
const _surface = Color(0xFFF4F7FB);
const _line = Color(0xFFDCE5EF);

void _irContratarTrialEscritorio(BuildContext context) {
  metaFbqTrackStartTrialEscritorio();
  context.go('/cadastro-escritorio-contabil');
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _demoService = PublicDemoAccessService();
  PublicDemoAccessResult? _demoSummary;
  bool _openingDemoCompany = false;
  bool _openingDemoAccountant = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      metaFbqTrackVendasFunnel();
      _loadDemoSummary();
    });
  }

  Future<void> _loadDemoSummary() async {
    try {
      final summary = await _demoService.getSummary();
      if (!mounted) return;
      setState(() => _demoSummary = summary);
    } catch (_) {}
  }

  Future<void> _openDemo(String profile) async {
    setState(() {
      if (profile == 'company') {
        _openingDemoCompany = true;
      } else {
        _openingDemoAccountant = true;
      }
    });
    try {
      final result = await _demoService.openDemo(
        profile: profile,
        pagePath: '/vendas',
      );
      if (!mounted) return;
      context.go(result.targetRoute);
    } finally {
      if (mounted) {
        setState(() {
          if (profile == 'company') {
            _openingDemoCompany = false;
          } else {
            _openingDemoAccountant = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final medium = width < 1040;
    final pageContent = SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 28,
                vertical: compact ? 14 : 34,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroSection(
                    compact: compact,
                    medium: medium,
                    demoSummary: _demoSummary,
                    openingDemoCompany: _openingDemoCompany,
                    openingDemoAccountant: _openingDemoAccountant,
                    onOpenDemoCompany: () => _openDemo('company'),
                    onOpenDemoAccountant: () => _openDemo('accountant'),
                  ),
                  SizedBox(height: compact ? 16 : 22),
                  const _FiscalHeroSection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _StoryOpeningSection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _OriginSection(),
                  SizedBox(height: compact ? 16 : 22),
                  _SolutionSection(compact: compact),
                  SizedBox(height: compact ? 16 : 22),
                  _DifferenceSection(compact: compact),
                  SizedBox(height: compact ? 16 : 22),
                  _HowItWorksSection(compact: compact),
                  SizedBox(height: compact ? 16 : 22),
                  const _BenefitsSection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _SocialProofSection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _OfferSection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _CredibilitySection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _ClosingSection(),
                  SizedBox(height: compact ? 16 : 22),
                  const _ProfessionalFooterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(backgroundColor: _surface, body: pageContent);
  }
}

class _FiscalHeroSection extends StatelessWidget {
  const _FiscalHeroSection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill('Carro-chefe: NFS-e na operação real'),
          SizedBox(height: 16),
          _SectionTitle(
            'A empresa emite a própria nota, e o contador acompanha tudo organizado',
          ),
          SizedBox(height: 16),
          Text(
            'O maior ganho do Ponto Certo é tirar a emissão de nota da correria do WhatsApp. A empresa prepara os dados, escolhe o serviço fiscal correto, emite a NFS-e no fluxo certo e mantém o contador com visão clara do que foi feito.',
            style: _leadStyle,
          ),
          SizedBox(height: 18),
          _ListBox(
            items: [
              'Menos atraso para emitir nota',
              'Menos informação incompleta chegando ao contador',
              'Serviços fiscais padronizados para reduzir erro',
              'Histórico fiscal e financeiro no mesmo ambiente',
            ],
          ),
          SizedBox(height: 26),
          _ScreenShotCard(
            asset: 'assets/marketing/sales/fiscal-emissao.png',
            label: 'Emissão fiscal real dentro do Ponto Certo',
            caption:
                'A empresa emite, acompanha notas autorizadas e organiza serviços fiscais, enquanto o contador mantém a rotina fiscal sob controle.',
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.compact,
    required this.medium,
    required this.demoSummary,
    required this.openingDemoCompany,
    required this.openingDemoAccountant,
    required this.onOpenDemoCompany,
    required this.onOpenDemoAccountant,
  });

  final bool compact;
  final bool medium;
  final PublicDemoAccessResult? demoSummary;
  final bool openingDemoCompany;
  final bool openingDemoAccountant;
  final VoidCallback onOpenDemoCompany;
  final VoidCallback onOpenDemoAccountant;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Pill('Empresa + contador no mesmo fluxo'),
        const SizedBox(height: 18),
        Text(
          'Pare de depender de WhatsApp pra organizar sua empresa e sua contabilidade',
          style: TextStyle(
            fontSize: compact ? 31 : (medium ? 46 : 58),
            fontWeight: FontWeight.w900,
            color: _ink,
            height: compact ? 1.08 : 1.04,
            letterSpacing: compact ? -0.8 : -1.4,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'O Ponto Certo coloca empresa e contador no mesmo fluxo, com informação organizada, nota emitida no tempo certo e operação sob controle.',
          style: _leadStyle,
        ),
        const SizedBox(height: 26),
        if (demoSummary != null)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill('Demo unico', demoSummary!.visitors.toString()),
              _StatPill('Empresa', demoSummary!.companyUnique.toString()),
              _StatPill('Contador', demoSummary!.accountantUnique.toString()),
            ],
          ),
        if (demoSummary != null) const SizedBox(height: 18),
        _PrimaryButton(
          label: 'Começar teste grátis',
          onPressed: () => _irContratarTrialEscritorio(context),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: openingDemoCompany ? null : onOpenDemoCompany,
              icon: openingDemoCompany
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.storefront_outlined),
              label: const Text('Ver demo empresa'),
            ),
            OutlinedButton.icon(
              onPressed: openingDemoAccountant ? null : onOpenDemoAccountant,
              icon: openingDemoAccountant
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_outlined),
              label: const Text('Ver demo contador'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Abra o demo em leitura para sentir o menu real, navegar pelos modulos e depois avancar para o teste com a sua propria empresa.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );

    final image = const _ScreenShotCard(
      asset: 'assets/marketing/sales/painel.png',
      label: 'Painel da empresa',
      caption:
          'A empresa acompanha financeiro, operação e atalhos principais em uma visão simples.',
    );

    return _SectionCard(
      padding: compact ? 24 : 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 30), image],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StoryOpeningSection extends StatelessWidget {
  const _StoryOpeningSection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eu sei exatamente o que você está passando: informação atrasada, coisa faltando, retrabalho... e a sensação de que nunca está tudo sob controle.',
            style: _strongBodyStyle,
          ),
          SizedBox(height: 16),
          Text(
            'Seja na empresa ou no escritório, a rotina vira isso:',
            style: _bodyStyle,
          ),
          SizedBox(height: 18),
          _ListBox(
            items: [
              'Cliente manda informação incompleta',
              'Dados chegam fora do prazo',
              'Nota precisa emitir em cima da hora',
              'Financeiro não reflete a realidade',
            ],
          ),
          SizedBox(height: 18),
          Text(
            'E no final... sempre alguém precisa correr atrás.',
            style: _bodyStyle,
          ),
          SizedBox(height: 26),
          _ScreenShotCard(
            asset: 'assets/marketing/sales/documentos.png',
            label: 'Tarefas e execução',
            caption:
                'A rotina sai do WhatsApp e vira fila de trabalho com responsável, prazo e histórico.',
          ),
        ],
      ),
    );
  }
}

class _OriginSection extends StatelessWidget {
  const _OriginSection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            'O Ponto Certo não nasceu como ideia. Nasceu da operação real.',
          ),
          SizedBox(height: 16),
          Text(
            'Como empresário na área de serviços e obras, eu vivia exatamente isso: dependência de WhatsApp pra tudo, informação indo e voltando, falta de padrão e retrabalho todo mês.',
            style: _bodyStyle,
          ),
          SizedBox(height: 16),
          Text(
            'Mesmo fazendo minha parte... nada ficava realmente organizado.',
            style: _bodyStyle,
          ),
          SizedBox(height: 18),
          _QuoteBox(
            text:
                'O problema não era o contador. Nem a empresa. Era a falta de um processo que obrigasse a informação a chegar certa.',
          ),
          SizedBox(height: 16),
          Text('E foi isso que eu construí.', style: _strongBodyStyle),
        ],
      ),
    );
  }
}

class _SolutionSection extends StatelessWidget {
  const _SolutionSection({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _TextImageSection(
      compact: compact,
      title: 'Um sistema feito pra operação real',
      body:
          'O Ponto Certo não é um ERP cheio de função. É um fluxo que organiza a operação entre empresa e contador.',
      items: const [
        'A empresa envia tudo no lugar certo',
        'O contador recebe tudo organizado',
        'As informações chegam completas e no tempo certo',
      ],
      asset: 'assets/marketing/sales/contador-fiscal.png',
      imageLabel: 'Fiscal e rotina contábil',
      imageCaption:
          'O contador enxerga ambiente, provedor, e-CAC, DCTFWeb e autorizações em um fluxo organizado.',
    );
  }
}

class _DifferenceSection extends StatelessWidget {
  const _DifferenceSection({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _TextImageSection(
      compact: compact,
      title:
          'Você não precisa trabalhar mais. Você precisa de um processo que funcione.',
      body:
          'Tudo fica dentro do mesmo sistema, com comunicação, emissão, financeiro e rotina contábil organizados.',
      items: const [
        'Organização da comunicação',
        'Organização da emissão de notas',
        'Organização do financeiro',
        'Organização da rotina contábil',
      ],
      asset: 'assets/marketing/sales/financeiro.png',
      imageLabel: 'Financeiro da empresa',
      imageCaption:
          'Receitas, contas a receber, pagamentos e saldo ficam na mesma leitura operacional.',
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Como funciona na prática'),
          const SizedBox(height: 16),
          const _NumberListBox(
            items: [
              'A empresa lança as informações no sistema',
              'O contador acompanha em tempo real',
              'As notas são emitidas com base em dados organizados',
              'O financeiro passa a refletir a operação real',
            ],
          ),
          const SizedBox(height: 18),
          const _SignalGrid(
            items: ['Processo claro', 'Informação confiável', 'Menos erro'],
          ),
          const SizedBox(height: 26),
          _ResponsiveImageGrid(
            compact: compact,
            images: const [
              _SalesImage(
                asset: 'assets/marketing/sales/contador-painel.png',
                label: 'Painel do contador',
                caption:
                    'O escritório acompanha empresas vinculadas e entra direto nas rotinas que precisa operar.',
              ),
              _SalesImage(
                asset: 'assets/marketing/sales/relatorios.png',
                label: 'Relatórios',
                caption:
                    'Fiscal e financeiro aparecem conectados para reduzir conferência manual.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('O que muda no seu dia a dia'),
          SizedBox(height: 18),
          _CheckGrid(
            items: [
              'Menos retrabalho',
              'Menos cobrança de cliente',
              'Informações no prazo',
              'Mais controle sobre notas fiscais',
              'Mais segurança na operação',
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialProofSection extends StatelessWidget {
  const _SocialProofSection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill('Prova social'),
          SizedBox(height: 14),
          _SectionTitle('Rotinas reais que o Ponto Certo ajuda a organizar'),
          SizedBox(height: 16),
          Text(
            'Depoimentos de uso em operação empresarial e rotina contábil, preservando identificação comercial sensível.',
            style: _bodyStyle,
          ),
          SizedBox(height: 22),
          _TestimonialGrid(
            testimonials: [
              _Testimonial(
                role: 'Escritório contábil parceiro',
                segment: 'Atendimento fiscal e empresas de serviço',
                text:
                    'O principal ganho foi parar de procurar informação solta. A empresa lança no fluxo certo e o escritório consegue acompanhar nota, pendência e documento com mais clareza.',
              ),
              _Testimonial(
                role: 'Escritório contábil parceiro',
                segment: 'Rotina mensal e acompanhamento de clientes',
                text:
                    'A comunicação fica mais objetiva. Em vez de conversa espalhada, o sistema mostra o que foi enviado, o que falta e o que precisa de ação.',
              ),
              _Testimonial(
                role: 'Empresa de serviços',
                segment: 'Operação, financeiro e emissão fiscal',
                text:
                    'A emissão de nota ficou mais organizada porque o serviço fiscal, o cliente e o valor ficam no mesmo processo. Isso reduz correria no fechamento.',
              ),
              _Testimonial(
                role: 'Empresa operacional',
                segment: 'Equipe externa, tarefas e documentos',
                text:
                    'A rotina ficou mais fácil de acompanhar. As tarefas, documentos e financeiro saem da conversa informal e viram um fluxo que dá para conferir.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferSection extends StatelessWidget {
  const _OfferSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      color: const Color(0xFF092B63),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Teste sem risco', color: Colors.white),
          const SizedBox(height: 16),
          const _CheckGrid(
            light: true,
            items: ['30 dias grátis', 'Sem contrato', 'Sem implantação'],
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Começar teste grátis agora',
            light: true,
            onPressed: () => _irContratarTrialEscritorio(context),
          ),
        ],
      ),
    );
  }
}

class _CredibilitySection extends StatelessWidget {
  const _CredibilitySection();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Criado a partir da operação real'),
          SizedBox(height: 16),
          _InfoBox(
            lines: [
              'BONFIM AUTOMAÇÃO E INSTALAÇÕES ELÉTRICAS LTDA',
              'CNPJ: 45.467.633/0001-42',
              'Desde 2022',
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Sistema criado a partir da operação real, não teoria.',
            style: _strongBodyStyle,
          ),
        ],
      ),
    );
  }
}

class _ClosingSection extends StatelessWidget {
  const _ClosingSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se hoje sua rotina depende de WhatsApp, planilha e cobrança...',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 18),
          const Text('Você não tem um problema de esforço.', style: _bodyStyle),
          const SizedBox(height: 8),
          const Text(
            'Você tem um problema de processo.',
            style: _strongBodyStyle,
          ),
          const SizedBox(height: 8),
          const Text('E isso dá pra resolver.', style: _bodyStyle),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Começar teste grátis',
            onPressed: () => _irContratarTrialEscritorio(context),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalFooterSection extends StatelessWidget {
  const _ProfessionalFooterSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                'Operação profissional, dados protegidos e processo claro',
              ),
              SizedBox(height: 16),
              _CheckGrid(
                items: [
                  'Ambiente com autenticação por usuário',
                  'Informações organizadas por empresa e perfil de acesso',
                  'Rotinas pensadas para reduzir erro operacional',
                  'Uso responsável de dados fiscais, financeiros e cadastrais',
                ],
              ),
              SizedBox(height: 14),
              Text(
                'O Ponto Certo organiza a rotina entre empresa e contador, mas cada empresa continua responsável pela conferência das informações lançadas e pelo uso correto dos seus dados fiscais.',
                style: _bodyStyle,
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        _LegalFooter(),
      ],
    );
  }
}

class _TextImageSection extends StatelessWidget {
  const _TextImageSection({
    required this.compact,
    required this.title,
    required this.body,
    required this.items,
    required this.asset,
    required this.imageLabel,
    required this.imageCaption,
  });

  final bool compact;
  final String title;
  final String body;
  final List<String> items;
  final String asset;
  final String imageLabel;
  final String imageCaption;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 16),
        Text(body, style: _bodyStyle),
        const SizedBox(height: 18),
        _ListBox(items: items),
      ],
    );
    final image = _ScreenShotCard(
      asset: asset,
      label: imageLabel,
      caption: imageCaption,
    );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 28), image],
      ),
    );
  }
}

class _ResponsiveImageGrid extends StatelessWidget {
  const _ResponsiveImageGrid({required this.compact, required this.images});

  final bool compact;
  final List<_SalesImage> images;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final image in images) ...[
          _ScreenShotCard(
            asset: image.asset,
            label: image.label,
            caption: image.caption,
          ),
          if (image != images.last) const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _SalesImage {
  const _SalesImage({
    required this.asset,
    required this.label,
    required this.caption,
  });

  final String asset;
  final String label;
  final String caption;
}

class _Testimonial {
  const _Testimonial({
    required this.role,
    required this.segment,
    required this.text,
  });

  final String role;
  final String segment;
  final String text;
}

class _TestimonialGrid extends StatelessWidget {
  const _TestimonialGrid({required this.testimonials});

  final List<_Testimonial> testimonials;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    if (compact) {
      return Column(
        children: [
          for (final testimonial in testimonials) ...[
            _TestimonialCard(testimonial: testimonial),
            if (testimonial != testimonials.last) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final testimonial in testimonials)
          SizedBox(
            width: 490,
            child: _TestimonialCard(testimonial: testimonial),
          ),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});

  final _Testimonial testimonial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: _primary, size: 28),
          const SizedBox(height: 10),
          Text(
            testimonial.text,
            style: const TextStyle(
              color: _ink,
              fontSize: 17.5,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            testimonial.role,
            style: const TextStyle(
              color: _ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            testimonial.segment,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = 30,
    this.color = Colors.white,
  });

  final Widget child;
  final double padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        border: Border.all(
          color: color == Colors.white
              ? _line
              : Colors.white.withValues(alpha: 0.14),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(12, 30, 56, 0.08),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.light = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return SizedBox(
      width: compact ? double.infinity : null,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: light ? Colors.white : _primary,
          foregroundColor: light ? _primary : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E1FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF2446A8),
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.color = _ink});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Text(
      text,
      style: TextStyle(
        fontSize: compact ? 25 : 34,
        fontWeight: FontWeight.w900,
        color: color,
        height: compact ? 1.18 : 1.16,
        letterSpacing: -0.6,
      ),
    );
  }
}

class _ListBox extends StatelessWidget {
  const _ListBox({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _InsetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            _IconLine(icon: Icons.check_circle_outline_rounded, text: item),
        ],
      ),
    );
  }
}

class _NumberListBox extends StatelessWidget {
  const _NumberListBox({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _InsetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            _NumberLine(number: i + 1, text: items[i]),
        ],
      ),
    );
  }
}

class _CheckGrid extends StatelessWidget {
  const _CheckGrid({required this.items, this.light = false});

  final List<String> items;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: compact ? constraints.maxWidth : null,
                child: _CheckChip(item: item, light: light),
              ),
          ],
        );
      },
    );
  }
}

class _CheckChip extends StatelessWidget {
  const _CheckChip({required this.item, required this.light});

  final String item;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: light ? Colors.white.withValues(alpha: 0.18) : _line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.check_circle_rounded,
                color: light ? Colors.white : const Color(0xFF0E9F6E),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item,
                softWrap: true,
                style: TextStyle(
                  color: light ? Colors.white : _ink,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          Chip(
            label: Text(item),
            avatar: const Icon(Icons.bolt_rounded, size: 18),
            backgroundColor: const Color(0xFFEAF0FF),
            side: const BorderSide(color: Color(0xFFD6E1FF)),
            labelStyle: const TextStyle(
              color: Color(0xFF2446A8),
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _InsetBox extends StatelessWidget {
  const _InsetBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _itemStyle)),
        ],
      ),
    );
  }
}

class _NumberLine extends StatelessWidget {
  const _NumberLine({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _primary,
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: _itemStyle)),
        ],
      ),
    );
  }
}

class _QuoteBox extends StatelessWidget {
  const _QuoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF7F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCDEBE4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0B5D4E),
          fontSize: 19,
          height: 1.55,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return _InsetBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: _itemStyle),
            ),
        ],
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 4,
        vertical: compact ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: const [
              Text('Ponto Certo', style: _footerStrongStyle),
              Text('Privacidade e segurança', style: _footerMutedStyle),
              Text(
                'Termos de uso aplicáveis ao serviço',
                style: _footerMutedStyle,
              ),
              Text('Suporte e implantação guiada', style: _footerMutedStyle),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '© 2026 Ponto Certo. Todos os direitos reservados. Plataforma criada para organizar operação, comunicação, fiscal e financeiro entre empresa e contador.',
            style: _footerMutedStyle,
          ),
        ],
      ),
    );
  }
}

class _ScreenShotCard extends StatelessWidget {
  const _ScreenShotCard({
    required this.asset,
    required this.label,
    required this.caption,
  });

  final String asset;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final image = Image.asset(
      asset,
      width: double.infinity,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 220,
        alignment: Alignment.center,
        color: const Color(0xFFEAF0F6),
        child: Text(asset, style: const TextStyle(color: _muted)),
      ),
    );

    final imageContent = ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 14),
      child: image,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEDF3FA),
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(color: _line),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 2 : 6),
            child: imageContent,
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _ink,
                  fontSize: compact ? 17 : 18,
                  fontWeight: FontWeight.w900,
                  height: 1.28,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: TextStyle(
                  color: _muted,
                  fontSize: compact ? 16 : 17,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _leadStyle = TextStyle(
  fontSize: 20.5,
  height: 1.55,
  color: _muted,
  fontWeight: FontWeight.w600,
);

const _bodyStyle = TextStyle(fontSize: 19.5, height: 1.68, color: _muted);

const _strongBodyStyle = TextStyle(
  fontSize: 20.5,
  height: 1.62,
  color: _ink,
  fontWeight: FontWeight.w900,
);

const _itemStyle = TextStyle(
  fontSize: 18.5,
  height: 1.52,
  color: _ink,
  fontWeight: FontWeight.w700,
);

const _footerStrongStyle = TextStyle(
  color: _ink,
  fontSize: 15,
  fontWeight: FontWeight.w900,
);

const _footerMutedStyle = TextStyle(
  color: _muted,
  fontSize: 14,
  height: 1.5,
  fontWeight: FontWeight.w600,
);
