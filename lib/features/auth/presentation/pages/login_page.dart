import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/app_update/app_update_launcher.dart';
import 'package:pontocerto/core/auth/claims_sync.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/empresa_cache.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';

class PaginaLogin extends ConsumerStatefulWidget {
  const PaginaLogin({super.key});

  @override
  ConsumerState<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends ConsumerState<PaginaLogin> {
  final _loginEmailController = TextEditingController();
  final _loginSenhaController = TextEditingController();

  bool _carregando = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltarApp(),
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: firebaseDisponivel ? _buildFirebase() : _buildLocal(),
      ),
    );
  }

  Widget _buildFirebase() {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entrar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _loginEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _loginSenhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _carregando ? null : _entrar,
                    icon: const Icon(Icons.login),
                    label: const Text('Entrar'),
                  ),
                ),
                const SizedBox(height: 8),
                if (!isWebPlatform) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _abrirAtualizacaoApp,
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: const Text('Atualizar app'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Funcionario nao cria conta aqui. O acesso e criado pela empresa e enviado por email.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cadastrar escritorio de contabilidade',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O cadastro do escritorio agora acontece em uma tela propria, mais simples e alinhada ao fluxo atual do contador.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _carregando
                        ? null
                        : () => context.go('/cadastro-escritorio-contabil'),
                    icon: const Icon(Icons.apartment),
                    label: const Text('Ir para cadastro do escritorio'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocal() {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Firebase nao configurado. Entrando em modo local.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _entrarLocal(Role.owner),
                    child: const Text('Entrar como DONO (Local)'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _entrarLocal(Role.manager),
                    child: const Text('Entrar como GERENTE (Local)'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _entrarLocal(Role.accountant),
                    child: const Text('Entrar como CONTADOR (Local)'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _entrarLocal(Role.employee),
                    child: const Text('Entrar como FUNCIONARIO (Local)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _entrarLocal(Role role) {
    ref.read(sessionProvider.notifier).loginLocal(role);
    context.go('/home');
  }

  Future<void> _entrar() async {
    final email = _loginEmailController.text.trim();
    final senha = _loginSenhaController.text;
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

      final dados = await _carregarSessao(uid);
      await _cacheNomeEmpresa(dados);

      if (!mounted) return;
      _msg('Login realizado com sucesso.');
      GoRouter.of(context).refresh();
      context.go('/home');
    } catch (e) {
      _msg(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Erro ao entrar. Verifique o perfil no Firestore.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<Map<String, dynamic>> _carregarSessao(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) {
      throw Exception('Usuario sem perfil no Firestore.');
    }

    final dados = doc.data();
    if (dados == null) {
      throw Exception('Dados de usuario invalidos.');
    }

    ref
        .read(sessionProvider.notifier)
        .definirSessaoPorMapa(userId: uid, dados: dados);

    return dados;
  }

  Future<void> _cacheNomeEmpresa(Map<String, dynamic> dados) async {
    final companyData = dados['companyData'];
    String? nomeEmpresa;

    if (companyData is Map<String, dynamic>) {
      nomeEmpresa = companyData['nomeFantasia']?.toString();
    }

    nomeEmpresa ??= dados['companyName']?.toString();

    if (nomeEmpresa == null || nomeEmpresa.isEmpty) {
      return;
    }

    ref.read(nomeEmpresaCacheProvider.notifier).state = nomeEmpresa;
    await salvarNomeEmpresaCache(nomeEmpresa);
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
