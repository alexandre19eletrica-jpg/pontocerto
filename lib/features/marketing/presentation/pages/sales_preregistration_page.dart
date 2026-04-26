import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/marketing/presentation/services/public_sales_config_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_analytics_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_preregistration_service.dart';
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
        context.showUserMessage('Informe empresa e contador para continuar.');
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
      if (!mounted) return;
      context.showUserSuccess(
        'Pedido de teste salvo. O contador indicado vai receber o caminho para cadastrar a empresa e iniciar os 30 dias gratis no sistema real.',
      );
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
        title: const Text('Solicitar teste com contador'),
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
                    'O teste real de 30 dias comeca sem cobranca de implantacao. Para usar, a empresa precisa indicar o contador que vai iniciar primeiro o cadastro do escritorio.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valor recorrente: ${plan?.priceLabel ?? '-'}'),
                    const SizedBox(height: 8),
                    Text(
                      plan?.implantationLabel ??
                          'O teste real de 30 dias sera iniciado com contador indicado pela empresa.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este fluxo inicial libera o sistema web e tambem prepara o app dos funcionarios dentro do mesmo teste real.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nesta etapa, a empresa solicita a entrada, informa seu nome e e-mail, informa nome e e-mail do contador e o contador indicado vira o contato principal para primeiro cadastrar o escritorio e depois cadastrar a empresa que o indicou.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Empresa e contador',
                child: Column(
                  children: [
                    _field(_companyName, 'Nome da empresa *'),
                    _field(_companyEmail, 'Email da empresa *'),
                    _field(_accountantName, 'Nome do contador *'),
                    _field(_accountantEmail, 'Email do contador *'),
                    const SizedBox(height: 8),
                    const _ImplementationModeCard(
                      title: 'Fluxo oficial de entrada',
                      text:
                          'A empresa pede a entrada, indica o contador e o contador recebe os dados para primeiro cadastrar o escritorio de contabilidade. Depois disso, ele cadastra a empresa que o indicou no sistema. O teste real fica liberado por 30 dias, sem cobranca de implantacao.',
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
                  _saving ? 'Enviando...' : 'Solicitar teste real de 30 dias',
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
