import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';

class PaginaLogin extends ConsumerStatefulWidget {
  const PaginaLogin({super.key});

  @override
  ConsumerState<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends ConsumerState<PaginaLogin> {
  final _loginEmailController = TextEditingController();
  final _loginSenhaController = TextEditingController();

  final _cadEmailController = TextEditingController();
  final _cadSenhaController = TextEditingController();
  final _responsavelController = TextEditingController();
  final _razaoSocialController = TextEditingController();
  final _nomeFantasiaController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _inscricaoEstadualController = TextEditingController();
  final _inscricaoMunicipalController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailEmpresaController = TextEditingController();
  final _enderecoController = TextEditingController();
  String _businessCategory = 'service';

  bool _carregando = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginSenhaController.dispose();
    _cadEmailController.dispose();
    _cadSenhaController.dispose();
    _responsavelController.dispose();
    _razaoSocialController.dispose();
    _nomeFantasiaController.dispose();
    _cnpjController.dispose();
    _inscricaoEstadualController.dispose();
    _inscricaoMunicipalController.dispose();
    _telefoneController.dispose();
    _emailEmpresaController.dispose();
    _enderecoController.dispose();
    super.dispose();
  }

  bool get _stateRegistrationRequired => _businessCategory != 'service';

  String _businessCategoryLabel(String value) {
    return switch (value) {
      'service' => 'Prestacao de servicos',
      'commerce' => 'Comercio',
      'industry' => 'Industria',
      'mixed' => 'Misto',
      _ => 'Prestacao de servicos',
    };
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
                TextField(
                  controller: _cadEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de acesso *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cadSenhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _responsavelController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do responsavel *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _razaoSocialController,
                  decoration: const InputDecoration(
                    labelText: 'Razao social *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nomeFantasiaController,
                  decoration: const InputDecoration(
                    labelText: 'Nome fantasia *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cnpjController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CnpjInputFormatter()],
                  maxLength: 18,
                  decoration: const InputDecoration(labelText: 'CNPJ *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _businessCategory,
                  decoration: const InputDecoration(
                    labelText: 'Ramo principal *',
                  ),
                  items: [
                    for (final item in const [
                      'service',
                      'commerce',
                      'industry',
                      'mixed',
                    ])
                      DropdownMenuItem(
                        value: item,
                        child: Text(_businessCategoryLabel(item)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _businessCategory = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inscricaoEstadualController,
                  decoration: InputDecoration(
                    labelText: _stateRegistrationRequired
                        ? 'Inscricao estadual *'
                        : 'Inscricao estadual (dispensada para servicos)',
                  ),
                ),
                const SizedBox(height: 8),
                if (!_stateRegistrationRequired)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Para prestacao de servicos, a IE fica dispensada por padrao. O cadastro fiscal passa a depender principalmente da inscricao municipal.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (!_stateRegistrationRequired) const SizedBox(height: 8),
                TextField(
                  controller: _inscricaoMunicipalController,
                  decoration: InputDecoration(
                    labelText: _businessCategory == 'service'
                        ? 'Inscricao municipal *'
                        : 'Inscricao municipal',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [TelefoneInputFormatter()],
                  maxLength: 15,
                  decoration: const InputDecoration(labelText: 'Telefone *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailEmpresaController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email da empresa *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _enderecoController,
                  decoration: const InputDecoration(labelText: 'Endereco *'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _carregando ? null : _criarContaEmpresa,
                    icon: const Icon(Icons.apartment),
                    label: const Text('Cadastrar escritorio de contabilidade'),
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

  Future<void> _criarContaEmpresa() async {
    final email = _cadEmailController.text.trim();
    final senha = _cadSenhaController.text;
    final responsavel = _responsavelController.text.trim();
    final razaoSocial = _razaoSocialController.text.trim();
    final nomeFantasia = _nomeFantasiaController.text.trim();
    final cnpj = _cnpjController.text.trim();
    final ie = _inscricaoEstadualController.text.trim();
    final im = _inscricaoMunicipalController.text.trim();
    final telefone = _telefoneController.text.trim();
    final emailEmpresa = _emailEmpresaController.text.trim();
    final endereco = _enderecoController.text.trim();

    if (email.isEmpty ||
        senha.isEmpty ||
        responsavel.isEmpty ||
        razaoSocial.isEmpty ||
        nomeFantasia.isEmpty ||
        cnpj.isEmpty ||
        (_stateRegistrationRequired && ie.isEmpty) ||
        (_businessCategory == 'service' && im.isEmpty) ||
        telefone.isEmpty ||
        emailEmpresa.isEmpty ||
        endereco.isEmpty) {
      _msg('Preencha todos os campos obrigatorios da empresa.');
      return;
    }

    setState(() => _carregando = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        _msg('Falha ao criar usuario.');
        return;
      }

      final companyId = 'comp_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'companyId': companyId,
        'companyName': nomeFantasia,
        'role': 'OWNER',
        'nome': responsavel,
        'employeeId': uid,
        'companyData': {
          'razaoSocial': razaoSocial,
          'nomeFantasia': nomeFantasia,
          'cnpj': cnpj,
          'businessCategory': _businessCategory,
          'inscricaoEstadual': _stateRegistrationRequired ? ie : '',
          'inscricaoEstadualDispensada': !_stateRegistrationRequired,
          'inscricaoMunicipalObrigatoria': _businessCategory == 'service',
          'inscricaoMunicipal': im,
          'telefone': telefone,
          'email': emailEmpresa,
          'endereco': endereco,
        },
      });

      await syncClaimsForCurrentUser();
      await _provisionarEmpresa(
        companyName: nomeFantasia,
        companyData: {
          'razaoSocial': razaoSocial,
          'nomeFantasia': nomeFantasia,
          'cnpj': cnpj,
          'businessCategory': _businessCategory,
          'inscricaoEstadual': _stateRegistrationRequired ? ie : '',
          'inscricaoEstadualDispensada': !_stateRegistrationRequired,
          'inscricaoMunicipalObrigatoria': _businessCategory == 'service',
          'inscricaoMunicipal': im,
          'telefone': telefone,
          'email': emailEmpresa,
          'endereco': endereco,
        },
      );

      final dados = await _carregarSessao(uid);
      await _cacheNomeEmpresa(dados);

      if (!mounted) return;
      _msg('Conta da empresa criada com sucesso.');
      GoRouter.of(context).refresh();
      context.go('/home');
    } catch (e) {
      _msg(AppErrorMapper.messageFrom(e, fallback: 'Erro ao criar conta.'));
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

  Future<void> _provisionarEmpresa({
    required String companyName,
    required Map<String, dynamic> companyData,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'syncCompanyProfile',
      );
      await callable.call(<String, dynamic>{
        'companyName': companyName,
        'companyData': companyData,
      });
    } catch (_) {
      // Mantem a criacao resiliente; o backend pode ser acionado novamente
      // ao salvar o cadastro empresarial depois.
    }
  }
}
