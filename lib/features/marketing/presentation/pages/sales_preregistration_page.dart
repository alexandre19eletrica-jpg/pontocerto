import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_sales_config_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_analytics_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_preregistration_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class SalesPreRegistrationPage extends StatefulWidget {
  const SalesPreRegistrationPage({super.key, required this.planCode});

  final String planCode;

  @override
  State<SalesPreRegistrationPage> createState() =>
      _SalesPreRegistrationPageState();
}

class _SalesPreRegistrationPageState extends State<SalesPreRegistrationPage> {
  final _configService = PublicSalesConfigService();
  final _service = SalesPreRegistrationService();
  final _analyticsService = SalesAnalyticsService();
  final _companyName = TextEditingController();
  final _companyEmail = TextEditingController();
  final _accountantName = TextEditingController();
  final _accountantEmail = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  PublicSalesPlan? _plan;
  final String _implementationMode = 'accountant';
  bool _pageViewTracked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _companyName.dispose();
    _companyEmail.dispose();
    _accountantName.dispose();
    _accountantEmail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await _configService.fetch();
      final plan = switch (widget.planCode.trim().toLowerCase()) {
        'solo' => config.planSolo,
        'equipe' => config.planEquipe,
        _ => null,
      };
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
      if (!_pageViewTracked) {
        _pageViewTracked = true;
        _analyticsService.trackPageView(
          pagePath: '/contratar',
          planCode: widget.planCode,
        );
        metaFbqTrackSolicitacaoTesteView();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final plan = _plan;
    if (plan == null) {
      if (context.mounted) { context.showUserMessage('Plano invalido para esta pagina.'); }
      return;
    }
    if (_companyName.text.trim().isEmpty ||
        _companyEmail.text.trim().isEmpty ||
        _accountantName.text.trim().isEmpty ||
        _accountantEmail.text.trim().isEmpty) {
      if (context.mounted) {
        context.showUserMessage('Informe os quatro contatos para continuar.');
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final tracking = await _analyticsService.currentTrackingPayload();
      final result = await _service.create(
        planCode: widget.planCode,
        customerName: _companyName.text.trim(),
        customerEmail: _companyEmail.text.trim(),
        implementationMode: _implementationMode,
        accountantName: _accountantName.text.trim(),
        accountantEmail: _accountantEmail.text.trim(),
        tracking: tracking,
      );
      await _analyticsService.trackPreregistrationSubmitted(
        planCode: widget.planCode,
        implementationMode: _implementationMode,
        leadId: result.leadId,
      );
      metaFbqTrackLeadPreCadastro(
        leadId: result.leadId,
        planCode: widget.planCode,
      );
      if (!mounted) return;
      final empresaOk = result.precadastroEmpresaEmailOk;
      final parceiroOk = result.conviteParceiroEmailOk;
      final msg = empresaOk && parceiroOk
          ? 'Registro recebido. Enviamos orientacoes para o e-mail da empresa e do contador.'
          : empresaOk
              ? 'Registro recebido. Enviamos orientacoes para o e-mail da empresa; o e-mail ao contador pode falhar se o envio estiver incompleto.'
              : parceiroOk
                  ? 'Registro recebido; o e-mail da empresa nao foi enviado automaticamente. Confira spam ou use outro contato.'
                  : 'Registro recebido, mas os e-mails automaticos nao foram enviados — confira SMTP/SendGrid nas Functions (MAIL_FROM, SMTP ou SendGrid).';
      context.showUserSuccess(msg);
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar entrada no plano'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendas'),
        ),
      ),
      body: AppGradientBackground(
        child: AppPageLayout(
          child: ListView(
            children: [
              AppWorkspaceCard(
                title: plan?.title ?? 'Plano',
                subtitle:
                    'Pedido inicial recebido pela equipe do Ponto Certo. Liberamos ambiente web e fluxo complementar assim que confirmarmos seus contatos.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valor recorrente: ${plan?.priceLabel ?? '-'}'),
                    const SizedBox(height: 8),
                    Text(
                      plan?.implantationLabel ??
                          'Combinamos detalhes de uso com voce antes de iniciar cobranca recorrente.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este envio registra dados comerciais e a operacao prepara os acessos quando previstos.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Informe dois contatos: empresa e parceiro contabil. Ambos recebem atualizacao por e-mail quando o envio automatico estiver disponivel.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Contatos da implantacao',
                child: Column(
                  children: [
                    _field(_companyName, 'Nome da empresa *'),
                    _field(_companyEmail, 'Email da empresa *'),
                    _field(_accountantName, 'Nome do contador *'),
                    _field(_accountantEmail, 'Email do contador *'),
                    const SizedBox(height: 8),
                    const _ImplementationModeCard(
                      title: 'Como seguimos internamente',
                      text:
                          'Dados entram no funil comercial, criamos os acessos leves quando disponiveis e notificamos empresa e parceiro cadastrado sobre o proximo passo. Prazos podem variar conforme fila e validacao de seguranca.',
                      selected: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(
                  _saving ? 'Enviando...' : 'Registrar interesse e contatos',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ImplementationModeCard extends StatelessWidget {
  const _ImplementationModeCard({
    required this.title,
    required this.text,
    required this.selected,
  });

  final String title;
  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF4FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF93C5FD) : const Color(0xFFDCE6F2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppBrandColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
