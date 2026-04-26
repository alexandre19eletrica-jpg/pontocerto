import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/app_update/app_update_launcher.dart';
import 'package:pontocerto/core/auth/claims_sync.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_access_state.dart';
import 'package:pontocerto/core/company/empresa_cache.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';

class PaginaLoginEmpresa extends ConsumerStatefulWidget {
  const PaginaLoginEmpresa({super.key});

  @override
  ConsumerState<PaginaLoginEmpresa> createState() => _PaginaLoginEmpresaState();
}

class _PaginaLoginEmpresaState extends ConsumerState<PaginaLoginEmpresa> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final employeeWebDenied =
        isWebPlatform &&
        GoRouterState.of(context).uri.queryParameters['employee-web-denied'] ==
            '1';
    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltarApp(),
        title: const Text('Login da Empresa'),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const HeroBanner(
              tag: 'ACESSO DA EMPRESA',
              title: 'Entre no painel administrativo da empresa.',
              subtitle:
                  'Abra o ambiente principal para acompanhar equipe, financeiro, contratos e configuracoes.',
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
                      if (employeeWebDenied) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFFD08A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFF8A4B00),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No navegador, o acesso de funcionario permanece exclusivo do app da Play Store.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        'Acesso administrativo',
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppBrandColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use a conta da empresa para acessar o painel principal e os modulos administrativos.',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: AppBrandColors.softText,
                          height: 1.45,
                        ),
                      ),
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
      if (!mounted) return;
      context.showUserMessage('Informe email e senha.');
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
        if (!mounted) return;
        context.showUserError('Falha ao obter usuario.');
        return;
      }

      await syncClaimsForCurrentUser();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final dados = doc.data();
      if (dados == null) {
        if (!mounted) return;
        context.showUserError('Perfil nao encontrado.');
        return;
      }

      final role = (dados['role']?.toString() ?? '').trim().toUpperCase();
      const rolesPermitidos = <String>{'OWNER', 'DONO', 'MANAGER', 'GERENTE'};
      if (!rolesPermitidos.contains(role)) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        context.showUserError('Este acesso e apenas para empresa.');
        return;
      }

      final companyId = dados['companyId']?.toString() ?? '';
      if (companyId.isNotEmpty) {
        final settingsSnap = await FirebaseFirestore.instance
            .collection('company_settings')
            .doc(companyId)
            .get();
        final accessState = CompanyAccessState.fromSettings(
          settingsSnap.data() ?? <String, dynamic>{},
          companyId: companyId,
        );
        if (!accessState.allowLogin) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          context.showUserError(
            accessState.message.isNotEmpty
                ? accessState.message
                : 'A empresa nao esta liberada para acesso no momento.',
          );
          return;
        }
      }

      ref
          .read(sessionProvider.notifier)
          .definirSessaoPorMapa(userId: uid, dados: dados);

      final companyData = dados['companyData'];
      final nomeEmpresa = companyData is Map<String, dynamic>
          ? companyData['nomeFantasia']?.toString()
          : dados['companyName']?.toString();
      if (nomeEmpresa != null && nomeEmpresa.isNotEmpty) {
        ref.read(nomeEmpresaCacheProvider.notifier).state = nomeEmpresa;
        await salvarNomeEmpresaCache(nomeEmpresa);
      }

      if (!mounted) return;
      context.showUserSuccess('Login realizado com sucesso.');
      GoRouter.of(context).refresh();
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      context.showUserError(
        AppErrorMapper.messageFrom(e, fallback: 'Erro ao entrar.'),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _esqueciSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      context.showUserMessage('Informe o email para recuperar a senha.');
      return;
    }
    try {
      await FirebaseFunctions.instance
          .httpsCallable('publicRequestPasswordResetEmail')
          .call(<String, dynamic>{'email': email});
      if (!mounted) return;
      context.showUserSuccess('Email de recuperacao enviado.');
    } catch (e) {
      if (!mounted) return;
      context.showUserError(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel enviar o email de recuperacao.',
        ),
      );
    }
  }

  Future<void> _abrirAtualizacaoApp() async {
    final abriu = await AppUpdateLauncher.open();
    if (!abriu && mounted) {
      context.showUserError('Nao foi possivel abrir a atualizacao do app.');
    }
  }
}
