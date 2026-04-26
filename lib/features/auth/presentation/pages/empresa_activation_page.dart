import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';
import 'package:pontocerto/features/auth/presentation/services/company_activation_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class EmpresaActivationPage extends ConsumerStatefulWidget {
  const EmpresaActivationPage({super.key});

  @override
  ConsumerState<EmpresaActivationPage> createState() => _EmpresaActivationPageState();
}

class _EmpresaActivationPageState extends ConsumerState<EmpresaActivationPage> {
  final _service = CompanyActivationService();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _codigoController = TextEditingController();

  bool _carregando = false;
  bool _carregouPerfil = false;
  String _statusLabel = 'Aguardando codigo de liberacao';
  String _empresaLabel = '';

  @override
  void initState() {
    super.initState();
    _carregarContextoAtual();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _carregarContextoAtual() async {
    if (_carregouPerfil) return;
    final profile = await _service.currentUserProfile();
    final settings = await _service.currentCompanySettings();
    if (!mounted) return;
    final commercial = (settings?['commercialSettings'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    setState(() {
      _carregouPerfil = true;
      _emailController.text = profile?['email']?.toString() ?? _emailController.text;
      _empresaLabel =
          profile?['companyName']?.toString() ??
          (profile?['companyData'] is Map
              ? (profile?['companyData'] as Map)['nomeFantasia']?.toString() ?? ''
              : '');
      _statusLabel = commercial['activationStatus']?.toString() == 'code_issued'
          ? 'Codigo emitido pela plataforma'
          : commercial['activationStatus']?.toString() == 'released'
              ? 'Liberado apos pagamento'
              : 'Aguardando codigo de liberacao';
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = FirebaseAuth.instance.currentUser != null;
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltarApp(),
        title: const Text('Ativacao da Empresa'),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const HeroBanner(
              tag: 'LIBERACAO',
              title: 'Ative o acesso da empresa com o codigo da plataforma.',
              subtitle:
                  'O cadastro fica registrado, mas o uso operacional so e liberado apos o resgate do codigo emitido pela plataforma.',
              trailing: BrandLogo(size: 88, radius: 24),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Controle de liberacao',
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppBrandColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Empresa: ${_empresaLabel.isNotEmpty ? _empresaLabel : 'Nao identificada ainda'}',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: AppBrandColors.softText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status atual: $_statusLabel',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: AppBrandColors.softText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!usuarioLogado) ...[
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email de acesso',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _senhaController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _codigoController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Codigo de liberacao',
                          prefixIcon: Icon(Icons.key_outlined),
                          hintText: 'PC-XXXX-XXXX-XXXX',
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _carregando ? null : _ativar,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: Text(_carregando ? 'Validando...' : 'Liberar acesso'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'O codigo e emitido pela administracao da plataforma, fica vinculado a empresa e so pode ser usado uma vez.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: AppBrandColors.softText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ativar() async {
    final usuarioLogado = FirebaseAuth.instance.currentUser != null;
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final codigo = _codigoController.text.trim();

    if (!usuarioLogado && (email.isEmpty || senha.isEmpty)) {
      _msg('Informe email e senha para validar a empresa.');
      return;
    }
    if (codigo.isEmpty) {
      _msg('Informe o codigo de liberacao.');
      return;
    }

    setState(() => _carregando = true);
    try {
      await _service.ensureSignedIn(email: email, password: senha);
      await _service.redeemCode(codigo);
      final profile = await _service.currentUserProfile();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && profile != null) {
        ref.read(sessionProvider.notifier).definirSessaoPorMapa(
          userId: uid,
          dados: profile,
        );
      }
      if (!mounted) return;
      _msg('Liberacao concluida com sucesso.');
      context.go('/home');
    } catch (error) {
      _msg(
        AppErrorMapper.messageFrom(
          error,
          fallback: 'Nao foi possivel validar o codigo de liberacao.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }
}
