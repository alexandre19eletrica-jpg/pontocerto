import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/claims_sync.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/empresa_cache.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';
import 'package:pontocerto/features/fiscal/presentation/services/fiscal_registry_lookup_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class PaginaCadastroEmpresa extends ConsumerStatefulWidget {
  const PaginaCadastroEmpresa({
    super.key,
    this.accountantMode = false,
    this.trialInviteToken,
    this.publicAccountantMode = false,
  });

  final bool accountantMode;
  final String? trialInviteToken;
  final bool publicAccountantMode;

  @override
  ConsumerState<PaginaCadastroEmpresa> createState() =>
      _PaginaCadastroEmpresaState();
}

class _PaginaCadastroEmpresaState extends ConsumerState<PaginaCadastroEmpresa> {
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
  final _accountantNameController = TextEditingController();
  final _accountantEmailController = TextEditingController();

  String _businessCategory = 'service';
  String _accountantBillingChoice = 'office';
  bool _companyAccessEnabled = true;
  bool _accountantTrial30d = false;
  bool _carregandoCnpj = false;
  String _companyType = 'EMPRESA';
  String _companyPlan = 'EQUIPE';
  String _classificationValidationLabel =
      'Validacao oficial: natureza juridica, porte e atividade principal retornados na consulta do CNPJ.';
  String _classificationReason =
      'Sem consulta ainda. Busque o CNPJ para o sistema classificar a empresa e o plano.';
  Map<String, dynamic> _registrySnapshot = const {};
  bool _hasAccountant = false;
  bool _carregando = false;

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void dispose() {
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
    _accountantNameController.dispose();
    _accountantEmailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.accountantMode) {
      final session = ref.read(sessionProvider);
      _hasAccountant = true;
      if (session?.role == Role.accountant) {
        _accountantNameController.text = session?.nome ?? '';
      }
      final accountantEmail = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
      if (accountantEmail.isNotEmpty) {
        _accountantEmailController.text = accountantEmail.toLowerCase();
      }
    }
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
    final tema = Theme.of(context);
    final accountantMode = widget.accountantMode;
    final trialToken = (widget.trialInviteToken ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltarApp(),
        title: Text(accountantMode ? 'Cadastrar empresa indicada' : 'Cadastrar empresa'),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HeroBanner(
              tag: accountantMode ? 'CONTADOR CADASTRA EMPRESA' : 'CADASTRO EMPRESA',
              title: accountantMode
                  ? 'Cadastre a empresa da carteira com o escritorio no centro do fluxo.'
                  : 'Crie a conta da empresa e entre no painel principal.',
              subtitle: accountantMode
                  ? 'Use este modulo para abrir uma nova empresa vinculada ao escritorio contabil. A cobranca e o acesso da empresa sao definidos no mesmo fluxo.'
                  : 'Configure os dados principais da empresa e inicie o uso da plataforma administrativa.',
            ),
            const SizedBox(height: 16),
            if (trialToken.isNotEmpty && !accountantMode) ...[
              AppWorkspaceCard(
                title: 'Teste gratuito por 90 dias',
                subtitle:
                    'Este cadastro foi aberto por um link de teste. Ao concluir, sua empresa entra com acesso liberado por 90 dias e sem cobranca.',
                child: const Text(
                  'Se precisar, voce pode compartilhar este link com o escritorio contabil para ele acompanhar o cadastro e operar no fiscal junto com voce.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Center(child: BrandLogo(size: 120, radius: 32)),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        accountantMode ? 'Cadastro de nova empresa' : 'Criacao da empresa',
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppBrandColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        accountantMode
                            ? 'Preencha os dados da empresa e do responsavel. O escritorio atual entra vinculado automaticamente no cadastro.'
                            : 'Preencha os dados da empresa para concluir o cadastro.',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: AppBrandColors.softText,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (accountantMode) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppBrandColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Escritorio responsavel',
                                style: TextStyle(
                                  color: AppBrandColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _accountantNameController.text.trim().isEmpty
                                    ? 'Seu acesso de escritorio sera vinculado automaticamente a esta nova empresa.'
                                    : '${_accountantNameController.text.trim()} | ${_accountantEmailController.text.trim().isEmpty ? 'email nao identificado no login atual' : _accountantEmailController.text.trim()}',
                                style: tema.textTheme.bodyMedium?.copyWith(
                                  color: AppBrandColors.softText,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppBrandColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '1. Informe o CNPJ e deixe o sistema preencher o cadastro',
                              style: TextStyle(
                                color: AppBrandColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'O sistema identifica automaticamente se a empresa entra como MEI / Solo ou Empresa / Equipe e preenche os dados disponiveis na consulta.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: AppBrandColors.softText,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _campo(
                              controller: _cnpjController,
                              label: 'CNPJ *',
                              keyboardType: TextInputType.number,
                              maxLength: 18,
                              inputFormatters: [CnpjInputFormatter()],
                              icon: Icons.badge_rounded,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AppHeaderChip('Tipo $_companyType'),
                                AppHeaderChip('Plano $_companyPlan'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _classificationValidationLabel,
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: AppBrandColors.softText,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _classificationReason,
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: AppBrandColors.ink,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _carregandoCnpj ? null : _buscarCnpj,
                              icon: const Icon(Icons.travel_explore_outlined),
                              label: Text(
                                _carregandoCnpj
                                    ? 'Buscando CNPJ...'
                                    : 'Buscar dados do CNPJ',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _campo(
                        controller: _cadEmailController,
                        label: accountantMode
                            ? 'Email de acesso da empresa${_companyAccessEnabled ? ' *' : ''}'
                            : 'Email de acesso *',
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.alternate_email_rounded,
                      ),
                      if (!accountantMode)
                        _campo(
                          controller: _cadSenhaController,
                          label: 'Senha *',
                          obscureText: true,
                          icon: Icons.lock_outline_rounded,
                        ),
                      _campo(
                        controller: _responsavelController,
                        label: accountantMode
                            ? 'Nome do responsavel da empresa *'
                            : 'Nome do responsavel *',
                        icon: Icons.person_rounded,
                      ),
                      _campo(
                        controller: _razaoSocialController,
                        label: 'Razao social *',
                        icon: Icons.domain_rounded,
                      ),
                      _campo(
                        controller: _nomeFantasiaController,
                        label: 'Nome fantasia *',
                        icon: Icons.business_center_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _businessCategory,
                          decoration: const InputDecoration(
                            labelText: 'Ramo principal *',
                            prefixIcon: Icon(Icons.apartment_rounded),
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
                      ),
                      _campo(
                        controller: _inscricaoEstadualController,
                        label: _stateRegistrationRequired
                            ? 'Inscricao estadual *'
                            : 'Inscricao estadual (dispensada para servicos)',
                        icon: Icons.feed_rounded,
                      ),
                      if (!_stateRegistrationRequired)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Para prestacao de servicos, a base ja considera IE dispensada por padrao. O foco fiscal fica na inscricao municipal.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: AppBrandColors.softText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      _campo(
                        controller: _inscricaoMunicipalController,
                        label: _businessCategory == 'service'
                            ? 'Inscricao municipal *'
                            : 'Inscricao municipal',
                        icon: Icons.location_city_rounded,
                      ),
                      _campo(
                        controller: _telefoneController,
                        label: 'Telefone *',
                        keyboardType: TextInputType.phone,
                        maxLength: 15,
                        inputFormatters: [TelefoneInputFormatter()],
                        icon: Icons.phone_android_rounded,
                      ),
                      _campo(
                        controller: _emailEmpresaController,
                        label: 'Email da empresa *',
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.email_rounded,
                      ),
                      _campo(
                        controller: _enderecoController,
                        label: 'Endereco *',
                        icon: Icons.location_on_outlined,
                      ),
                      if (accountantMode)
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppBrandColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                value: _companyAccessEnabled,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Empresa vai acessar o sistema'),
                                subtitle: const Text(
                                  'Se ativo, a empresa recebe email com link de acesso e definicao de senha assim que o cadastro terminar.',
                                ),
                                onChanged: _accountantTrial30d
                                    ? null
                                    : (value) {
                                  setState(() => _companyAccessEnabled = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                value: _accountantTrial30d,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Marcar como teste (30 dias)'),
                                subtitle: const Text(
                                  'Quando ativo, a empresa entra em trial por 30 dias e este cadastro nao gera cobranca inicial.',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _accountantTrial30d = value;
                                    if (value) {
                                      _companyAccessEnabled = true;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _accountantBillingChoice,
                                decoration: const InputDecoration(
                                  labelText: 'Quem paga os R\$ 97,90 desta empresa',
                                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'office',
                                    child: Text('Escritorio contabil'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'company',
                                    child: Text('Empresa cadastrada'),
                                  ),
                                ],
                                onChanged: _accountantTrial30d
                                    ? null
                                    : (value) {
                                  if (value == null) return;
                                  setState(() => _accountantBillingChoice = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _accountantTrial30d
                                    ? 'No modo de teste, a empresa recebe acesso proprio por e-mail e entra com trial de 30 dias sem cobranca inicial.'
                                    : _companyAccessEnabled
                                        ? 'A empresa entrara com o email acima e definira a senha pelo e-mail enviado pelo sistema.'
                                        : 'A empresa ficara sem acesso proprio. O escritorio continua operando e monitorando essa empresa dentro da carteira.',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: AppBrandColors.softText,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!accountantMode)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppBrandColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                value: _hasAccountant,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Cadastrar contador agora'),
                                subtitle: const Text(
                                  'Opcional. Se a empresa ja tiver contador, o sistema tenta vincular o escritorio no momento do cadastro.',
                                ),
                                onChanged: (value) {
                                  setState(() => _hasAccountant = value);
                                },
                              ),
                              if (_hasAccountant) ...[
                                const SizedBox(height: 8),
                                _campo(
                                  controller: _accountantNameController,
                                  label: 'Nome do contador *',
                                  icon: Icons.badge_outlined,
                                ),
                                _campo(
                                  controller: _accountantEmailController,
                                  label: 'Email do contador *',
                                  keyboardType: TextInputType.emailAddress,
                                  icon: Icons.contact_mail_outlined,
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _carregando ? null : _criarContaEmpresa,
                        icon: const Icon(Icons.apartment_rounded),
                        label: Text(
                          _carregando
                              ? 'Criando conta...'
                              : accountantMode
                                  ? 'Cadastrar empresa indicada'
                                  : 'Cadastrar empresa',
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

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
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
    final accountantName = _accountantNameController.text.trim();
    final accountantEmail = _accountantEmailController.text.trim().toLowerCase();
    final accountantMode = widget.accountantMode;

    if ((!accountantMode && email.isEmpty) ||
        (!accountantMode && senha.isEmpty) ||
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
    if (accountantMode && (_companyAccessEnabled || _accountantTrial30d) && email.isEmpty) {
      _msg('Informe o email de acesso da empresa.');
      return;
    }
    if ((accountantMode || _hasAccountant) &&
        (accountantName.isEmpty || accountantEmail.isEmpty)) {
      _msg(
        accountantMode
            ? 'Nao foi possivel identificar o escritorio responsavel no acesso atual.'
            : 'Informe nome e email do contador ou desative essa opcao.',
      );
      return;
    }

    setState(() => _carregando = true);
    try {
      final callable = _functions.httpsCallable(
        accountantMode
            ? (_accountantTrial30d
                  ? 'accountantRegisterCompanyTrial30d'
                  : 'accountantRegisterCompanyIndication')
            : 'publicRegisterCompanyDirectSignup',
      );
      final response = await callable.call(<String, dynamic>{
        'ownerEmail': email,
        'ownerPassword': accountantMode ? '' : senha,
        'ownerName': responsavel,
        'legalName': razaoSocial,
        'tradeName': nomeFantasia,
        'cnpj': cnpj,
        'businessCategory': _businessCategory,
        'stateRegistration': _stateRegistrationRequired ? ie : '',
        'municipalRegistration': im,
        'phone': telefone,
        'companyEmail': emailEmpresa,
        'address': endereco,
        'accountantName': (accountantMode || _hasAccountant) ? accountantName : '',
        'accountantEmail': (accountantMode || _hasAccountant) ? accountantEmail : '',
        'companyAccessEnabled': accountantMode ? (_accountantTrial30d ? true : _companyAccessEnabled) : true,
        'companyAccessEmail': accountantMode ? email : email,
        'billingChoice': accountantMode ? _accountantBillingChoice : 'company',
        'registrySnapshot': _registrySnapshot,
        'trialInviteToken': widget.trialInviteToken ?? '',
        'trialDays': _accountantTrial30d ? 30 : null,
      });
      final result = Map<String, dynamic>.from(response.data as Map);

      if (accountantMode) {
        if (!mounted) return;
        if (_accountantTrial30d) {
          await _mostrarResumoCadastroTesteContador(
            companyName: nomeFantasia,
            companyDisplayCode: result['companyDisplayCode']?.toString() ?? '',
            trialDays: 30,
            accessEmail: email,
          );
        } else {
          await _mostrarResumoCadastroContador(
            companyName: result['companyName']?.toString() ?? nomeFantasia,
            companyDisplayCode: result['companyDisplayCode']?.toString() ?? '',
            companyAccessEnabled: result['companyAccessEnabled'] == true,
            companyAccessEmail: result['companyAccessEmail']?.toString() ?? '',
            companyAccessEmailSent: result['companyAccessEmailSent'] == true,
            loginUrl: result['loginUrl']?.toString() ?? '',
            billingChoice: result['billingChoice']?.toString() ?? '',
            paymentLinkUrl: result['paymentLinkUrl']?.toString() ?? '',
          );
        }
        if (!mounted) return;
        context.go('/accountant-companies');
        return;
      }

      final released = result['released'] == true;
      final requiresPayment = result['requiresPayment'] == true;
      final paymentLinkUrl = result['paymentLinkUrl']?.toString().trim() ?? '';

      setState(() {
        _companyType = result['companyType']?.toString().trim().isNotEmpty == true
            ? result['companyType'].toString()
            : _companyType;
        _companyPlan = result['companyPlan']?.toString().trim().isNotEmpty == true
            ? result['companyPlan'].toString()
            : _companyPlan;
        _classificationValidationLabel =
            result['validationLabel']?.toString().trim().isNotEmpty == true
            ? result['validationLabel'].toString()
            : _classificationValidationLabel;
        _classificationReason =
            result['validationReason']?.toString().trim().isNotEmpty == true
            ? result['validationReason'].toString()
            : _classificationReason;
      });

      if (!released) {
        if (!mounted) return;
        await _mostrarResumoCobranca(
          planTitle: result['planTitle']?.toString() ?? _companyPlan,
          paymentLinkUrl: paymentLinkUrl,
          requiresPayment: requiresPayment,
        );
        return;
      }

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        _msg('Conta criada, mas nao foi possivel abrir a sessao automaticamente.');
        return;
      }

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

      ref.read(sessionProvider.notifier).definirSessaoPorMapa(
            userId: uid,
            dados: {
              'companyId': result['companyId'],
              'role': 'OWNER',
              'nome': responsavel,
            },
          );

      ref.read(nomeEmpresaCacheProvider.notifier).state = nomeFantasia;
      await salvarNomeEmpresaCache(nomeFantasia);

      if (!mounted) return;
      _msg('Conta criada e liberada com sucesso.');
      context.go('/home');
    } catch (e) {
      _msg(AppErrorMapper.messageFrom(e, fallback: 'Erro ao criar conta.'));
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

  Future<void> _buscarCnpj() async {
    final cnpj = _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpj.length != 14) {
      _msg('Informe um CNPJ valido com 14 digitos.');
      return;
    }
    setState(() => _carregandoCnpj = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'lookupBrazilCnpjForSignup',
      );
      final response = await callable.call(<String, dynamic>{'cnpj': cnpj});
      final map = Map<String, dynamic>.from(response.data as Map);
      _razaoSocialController.text =
          map['legalName']?.toString().trim().isNotEmpty == true
          ? map['legalName'].toString()
          : _razaoSocialController.text;
      _nomeFantasiaController.text =
          map['tradeName']?.toString().trim().isNotEmpty == true
          ? map['tradeName'].toString()
          : _nomeFantasiaController.text;
      _emailEmpresaController.text =
          map['email']?.toString().trim().isNotEmpty == true
          ? map['email'].toString()
          : _emailEmpresaController.text;
      _telefoneController.text =
          map['phone']?.toString().trim().isNotEmpty == true
          ? map['phone'].toString()
          : _telefoneController.text;
      _inscricaoEstadualController.text =
          map['stateRegistration']?.toString() ?? _inscricaoEstadualController.text;
      _inscricaoMunicipalController.text = sanitizeMunicipalRegistrationFromCnpjLookup(
        map,
        _inscricaoMunicipalController.text,
      );
      final enderecoPartes = [
        map['street']?.toString().trim(),
        map['number']?.toString().trim(),
        map['neighborhood']?.toString().trim(),
        map['city']?.toString().trim(),
        map['state']?.toString().trim(),
      ].where((item) => item != null && item.isNotEmpty).join(', ');
      if (enderecoPartes.trim().isNotEmpty) {
        _enderecoController.text = enderecoPartes;
      }
      final legalNature = map['legalNature']?.toString().toLowerCase() ?? '';
      final companySize = map['companySize']?.toString().toLowerCase() ?? '';
      final isMei =
          legalNature.contains('microempreendedor individual') ||
          legalNature.contains('mei') ||
          companySize.contains('microempreendedor individual');
      setState(() {
        _registrySnapshot = map;
        _companyType = isMei ? 'MEI' : 'EMPRESA';
        _companyPlan = isMei ? 'SOLO' : 'EQUIPE';
        _classificationValidationLabel = isMei
            ? 'Validacao oficial: natureza juridica e porte retornados na consulta do CNPJ.'
            : 'Validacao oficial: natureza juridica, porte e atividade principal retornados na consulta do CNPJ.';
        _classificationReason = isMei
            ? 'Classificacao oficial do CNPJ indica MEI. O sistema aplica fluxo Solo com 1 acesso base.'
            : 'O CNPJ nao foi identificado como MEI. O sistema trata a empresa como operacao de equipe e usa o plano Equipe.';
        if (isMei) {
          _businessCategory = 'service';
        }
      });
      _msg('Dados do CNPJ carregados.');
    } catch (e) {
      _msg(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel buscar os dados do CNPJ.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregandoCnpj = false);
      }
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
      // O cadastro nao deve falhar se a provision inicial travar; o owner
      // ainda consegue reprocessar ao salvar os dados da empresa depois.
    }
  }

  Future<void> _mostrarResumoCobranca({
    required String planTitle,
    required String paymentLinkUrl,
    required bool requiresPayment,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastro iniciado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requiresPayment
                  ? 'A empresa foi cadastrada e a cobranca do plano $planTitle ja foi criada. Assim que o pagamento for confirmado, o acesso sera liberado automaticamente.'
                  : 'A empresa foi cadastrada. O sistema vai concluir a liberacao no proximo passo.',
            ),
            if (paymentLinkUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Link da cobranca',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(paymentLinkUrl),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: paymentLinkUrl));
                  if (!mounted) return;
                  _msg('Link da cobranca copiado.');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar link'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarResumoCadastroContador({
    required String companyName,
    required String companyDisplayCode,
    required bool companyAccessEnabled,
    required String companyAccessEmail,
    required bool companyAccessEmailSent,
    required String loginUrl,
    required String billingChoice,
    required String paymentLinkUrl,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empresa cadastrada na carteira'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empresa: $companyName'),
            if (companyDisplayCode.isNotEmpty) Text('Codigo: $companyDisplayCode'),
            Text(
              billingChoice == 'company'
                  ? 'Pagador da mensalidade: empresa'
                  : 'Pagador da mensalidade: escritorio contabil',
            ),
            const SizedBox(height: 10),
            Text(
              companyAccessEnabled
                  ? 'A empresa ficou com acesso proprio habilitado.'
                  : 'A empresa ficou sem acesso proprio. O escritorio continua operando essa empresa.',
            ),
            if (companyAccessEnabled) ...[
              const SizedBox(height: 8),
              Text('Login da empresa: $companyAccessEmail'),
              Text(
                companyAccessEmailSent
                    ? 'E-mail de acesso enviado com sucesso.'
                    : 'E-mail de acesso ainda nao confirmado.',
              ),
              if (loginUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(loginUrl),
              ],
            ],
            if (paymentLinkUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Link da cobranca',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(paymentLinkUrl),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarResumoCadastroTesteContador({
    required String companyName,
    required String companyDisplayCode,
    required int trialDays,
    required String accessEmail,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empresa cadastrada em teste'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empresa: $companyName'),
            if (companyDisplayCode.isNotEmpty) Text('Codigo: $companyDisplayCode'),
            Text('Periodo de teste: $trialDays dias'),
            const SizedBox(height: 10),
            Text('Login da empresa: $accessEmail'),
            const SizedBox(height: 8),
            const Text(
              'A empresa recebeu acesso proprio e entrou no trial sem cobranca inicial.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
