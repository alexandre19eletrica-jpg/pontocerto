import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/app_update/app_update_launcher.dart';
import 'package:pontocerto/core/auth/accountant_company_context_service.dart';
import 'package:pontocerto/core/auth/claims_sync.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class PaginaLoginContador extends ConsumerStatefulWidget {
  const PaginaLoginContador({super.key});

  @override
  ConsumerState<PaginaLoginContador> createState() =>
      _PaginaLoginContadorState();
}

class _PaginaLoginContadorState extends ConsumerState<PaginaLoginContador> {
  final _accountantContextService = AccountantCompanyContextService();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _prefilledFromQuery = false;
  String _linkedCompanyCode = '';

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefilledFromQuery) {
      final query = GoRouterState.of(context).uri.queryParameters;
      final prefillEmail = query['email']?.trim() ?? '';
      final companyCode = query['empresa']?.trim() ?? '';
      if (prefillEmail.isNotEmpty) {
        _emailController.text = prefillEmail;
      }
      _linkedCompanyCode = companyCode;
      _prefilledFromQuery = true;
    }
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltarApp(),
        title: const Text('Login do Contador'),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const HeroBanner(
              tag: 'ACESSO CONTABIL',
              title:
                  'Entre como contador para operar a parte fiscal e financeira.',
              subtitle:
                  'Acesso dedicado para conferencia, emissao fiscal, contratos em leitura e apoio contabil dentro do sistema.',
            ),
            const SizedBox(height: 14),
            const Center(child: BrandLogo(size: 96, radius: 26)),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Acesso do contador',
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppBrandColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use o acesso do escritorio para consultar a carteira, operar o fiscal e depois cadastrar as empresas vinculadas.',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: AppBrandColors.softText,
                          height: 1.45,
                        ),
                      ),
                      if (_linkedCompanyCode.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Empresa vinculada: $_linkedCompanyCode',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: AppBrandColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
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
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _carregando ? null : _entrar,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(_carregando ? 'Entrando...' : 'Entrar'),
                      ),
                      const SizedBox(height: 10),
                      if (!isWebPlatform) ...[
                        OutlinedButton.icon(
                          onPressed: _abrirAtualizacaoApp,
                          icon: const Icon(Icons.system_update_alt_rounded),
                          label: const Text('Atualizar app'),
                        ),
                        const SizedBox(height: 6),
                      ],
                      TextButton(
                        onPressed: _carregando ? null : _esqueciSenha,
                        child: const Text('Esqueci minha senha'),
                      ),
                      TextButton(
                        onPressed: _carregando
                            ? null
                            : () => context.go('/cadastro-escritorio-contabil'),
                        child: const Text(
                          'Cadastrar escritorio de contabilidade',
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

  Future<void> _entrar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      _msg('Informe email e senha.');
      return;
    }

    setState(() => _carregando = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        _msg('Falha ao obter usuario.');
        return;
      }

      await syncClaimsForCurrentUser();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final dados = doc.data();
      if (dados == null) {
        _msg('Perfil nao encontrado.');
        return;
      }

      final role = (dados['role']?.toString() ?? '').trim().toUpperCase();
      const rolesPermitidos = <String>{'ACCOUNTANT', 'CONTADOR'};
      if (!rolesPermitidos.contains(role)) {
        await FirebaseAuth.instance.signOut();
        _msg('Este acesso e apenas para contador.');
        return;
      }

      final resolution = await _accountantContextService
          .resolveAccessibleCompany(userId: uid, userData: dados);
      if (!resolution.hasAccessibleCompany) {
        ref
            .read(sessionProvider.notifier)
            .definirSessaoPorMapa(userId: uid, dados: dados);
        if (!mounted) return;
        _msg(
          resolution.hasLinkedCompanies
              ? resolution.blockedMessage.isNotEmpty
                    ? resolution.blockedMessage
                    : 'Nenhuma empresa vinculada ao contador esta liberada para acesso no momento.'
              : 'Acesso do escritorio liberado. Cadastre a primeira empresa para iniciar a carteira.',
        );
        GoRouter.of(context).refresh();
        context.go('/accountant-companies');
        return;
      }
      final companyId = resolution.companyId;
      if ((dados['currentCompanyId']?.toString().trim() ?? '') != companyId) {
        await _accountantContextService.selectCompany(companyId);
        await syncClaimsForCurrentUser();
      }

      ref
          .read(sessionProvider.notifier)
          .definirSessaoPorMapa(
            userId: uid,
            dados: {...dados, 'companyId': companyId},
          );

      if (!mounted) return;
      _msg('Login realizado com sucesso.');
      GoRouter.of(context).refresh();
      context.go('/accountant-companies');
    } catch (e) {
      _msg(AppErrorMapper.messageFrom(e, fallback: 'Erro ao entrar.'));
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _esqueciSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _msg('Informe o email para recuperar a senha.');
      return;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('publicRequestPasswordResetEmail')
          .call(<String, dynamic>{'email': email});
      _msg('Email de recuperacao enviado.');
    } catch (e) {
      _msg(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel enviar o email de recuperacao.',
        ),
      );
    }
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }

  Future<void> _abrirAtualizacaoApp() async {
    final abriu = await AppUpdateLauncher.open();
    if (!abriu && mounted) {
      _msg('Nao foi possivel abrir a atualizacao do app.');
    }
  }
}
