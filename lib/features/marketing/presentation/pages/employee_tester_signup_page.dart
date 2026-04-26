import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/marketing/presentation/services/employee_tester_lead_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_analytics_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class EmployeeTesterSignupPage extends StatefulWidget {
  const EmployeeTesterSignupPage({super.key});

  @override
  State<EmployeeTesterSignupPage> createState() =>
      _EmployeeTesterSignupPageState();
}

class _EmployeeTesterSignupPageState extends State<EmployeeTesterSignupPage> {
  final _service = EmployeeTesterLeadService();
  final _analytics = SalesAnalyticsService();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _occupation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _state.dispose();
    _occupation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_fullName.text.trim().isEmpty || _email.text.trim().isEmpty) {
      if (context.mounted) {
        context.showUserMessage('Preencha nome e email para entrar na fila.');
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final tracking = await _analytics.currentTrackingPayload();
      await _service.create(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        occupation: _occupation.text.trim(),
        tracking: tracking,
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cadastro recebido'),
          content: const Text(
            'Seu nome entrou na fila de testadores do app de funcionario. Assim que o acesso for liberado na Play Store, voce recebera email para definir a senha e instalar o app.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/vendas');
              },
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      _fullName.clear();
      _email.clear();
      _phone.clear();
      _city.clear();
      _state.clear();
      _occupation.clear();
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de testador'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendas'),
        ),
      ),
      body: SelectionArea(
        child: AppGradientBackground(
          child: AppPageLayout(
            child: ListView(
              children: [
                AppWorkspaceCard(
                  title: 'Teste gratuito do app de funcionario',
                  subtitle:
                      'Entre na fila para receber acesso antecipado ao app na Play Store e testar o fluxo real do colaborador dentro da rotina da empresa.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Voce entra como usuario real do app, sem precisar contratar empresa.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Quando sua liberacao for feita, o sistema envia email com criacao de senha e o link oficial da Play Store.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Depois do teste, dentro do app voce recebe a Jornada Ponto Certo e entende como o app do funcionario se conecta a documentos, tarefas, financeiro, empresa e contador.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppWorkspaceCard(
                  title: 'Seus dados',
                  subtitle:
                      'Pedimos apenas o necessario para liberar seu acesso no lote de teste.',
                  child: Column(
                    children: [
                      _field(_fullName, 'Nome completo *'),
                      _field(_email, 'Email *'),
                      _field(_phone, 'WhatsApp'),
                      Row(
                        children: [
                          Expanded(child: _field(_city, 'Cidade')),
                          const SizedBox(width: 12),
                          SizedBox(width: 96, child: _field(_state, 'UF')),
                        ],
                      ),
                      _field(_occupation, 'Profissao ou area'),
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
                      : const Icon(Icons.rocket_launch_outlined),
                  label: Text(
                    _saving ? 'Enviando...' : 'Entrar na fila de teste',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
