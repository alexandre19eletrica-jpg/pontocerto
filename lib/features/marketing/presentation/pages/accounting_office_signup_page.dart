import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/core/widgets/botao_voltar_app.dart';
import 'package:pontocerto/core/widgets/external_labeled_field.dart';
import 'package:pontocerto/features/fiscal/presentation/services/fiscal_registry_lookup_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/accounting_office_signup_service.dart';
import 'package:pontocerto/features/marketing/presentation/services/meta_fbq_events.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class AccountingOfficeSignupPage extends StatefulWidget {
  const AccountingOfficeSignupPage({super.key, required this.token});

  final String token;

  @override
  State<AccountingOfficeSignupPage> createState() =>
      _AccountingOfficeSignupPageState();
}

class _AccountingOfficeSignupPageState
    extends State<AccountingOfficeSignupPage> {
  final _service = AccountingOfficeSignupService();
  final _registryLookup = FiscalRegistryLookupService();
  final _officeNameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _responsibleNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _notesController = TextEditingController();
  final _cepSignupController = TextEditingController();

  bool _loadingPrefill = false;
  bool _loadingCnpj = false;
  bool _submitting = false;
  AccountingOfficeSignupPrefill? _prefill;
  String _billingChoice = 'office';
  String _cnpjLookupMessage =
      'Use o CNPJ para preencher automaticamente os dados disponiveis do escritorio.';

  bool get _lightweightMode => widget.token.trim().isEmpty;
  bool _leadGeoHydrated = false;

  String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_lightweightMode || _leadGeoHydrated) return;
    _leadGeoHydrated = true;
    final q = GoRouterState.of(context).uri.queryParameters;
    if (_stateController.text.isEmpty) {
      _stateController.text = (q['uf'] ?? q['estado'] ?? '').trim();
    }
    if (_cityController.text.isEmpty) {
      _cityController.text = (q['cidade'] ?? '').trim();
    }
    if (_cepSignupController.text.isEmpty) {
      _cepSignupController.text = (q['cep'] ?? '').trim();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      metaFbqTrackCadastroEscritorioView();
    });
    if (widget.token.trim().isNotEmpty) {
      _loadPrefill();
    }
  }

  @override
  void dispose() {
    _officeNameController.dispose();
    _cnpjController.dispose();
    _responsibleNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _notesController.dispose();
    _cepSignupController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefill() async {
    setState(() => _loadingPrefill = true);
    try {
      final prefill = await _service.getPrefill(token: widget.token.trim());
      if (!mounted) return;
      _officeNameController.text = prefill.officeName;
      _emailController.text = prefill.email;
      _phoneController.text = prefill.phone;
      setState(() => _prefill = prefill);
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      if (mounted) {
        setState(() => _loadingPrefill = false);
      }
    }
  }

  Future<void> _lookupCnpj() async {
    final cnpj = _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpj.length != 14) {
      _showMessage('Informe um CNPJ valido com 14 digitos.');
      return;
    }

    setState(() => _loadingCnpj = true);
    try {
      final map = await _registryLookup.lookupCnpj(cnpj);
      if (!mounted) return;

      final legalName = map['legalName']?.toString().trim() ?? '';
      final tradeName = map['tradeName']?.toString().trim() ?? '';
      final email = map['email']?.toString().trim() ?? '';
      final phone = map['phone']?.toString().trim() ?? '';
      final city = map['city']?.toString().trim() ?? '';
      final state = map['state']?.toString().trim() ?? '';
      final address = [
        map['street']?.toString().trim(),
        map['number']?.toString().trim(),
        map['neighborhood']?.toString().trim(),
      ].where((item) => item != null && item.isNotEmpty).join(', ');

      if (tradeName.isNotEmpty) {
        _officeNameController.text = tradeName;
      } else if (legalName.isNotEmpty &&
          _officeNameController.text.trim().isEmpty) {
        _officeNameController.text = legalName;
      }
      if (email.isNotEmpty && _emailController.text.trim().isEmpty) {
        _emailController.text = email;
      }
      if (phone.isNotEmpty && _phoneController.text.trim().isEmpty) {
        _phoneController.text = phone;
      }
      if (address.isNotEmpty && _addressController.text.trim().isEmpty) {
        _addressController.text = address;
      }
      if (city.isNotEmpty && _cityController.text.trim().isEmpty) {
        _cityController.text = city;
      }
      if (state.isNotEmpty && _stateController.text.trim().isEmpty) {
        _stateController.text = state.toUpperCase();
      }

      setState(() {
        _cnpjLookupMessage = legalName.isNotEmpty || tradeName.isNotEmpty
            ? 'Consulta concluida. Os dados disponiveis do CNPJ foram aplicados ao cadastro do escritorio.'
            : 'Consulta concluida. O CNPJ foi validado, mas retornou poucos dados para preenchimento automatico.';
      });
      _showMessage('Dados do CNPJ carregados.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppErrorMapper.messageFrom(error));
    } finally {
      if (mounted) {
        setState(() => _loadingCnpj = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_lightweightMode) {
      if (_officeNameController.text.trim().isEmpty ||
          _responsibleNameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        _showMessage(
          'Preencha nome do escritorio, responsavel e e-mail.',
        );
        return;
      }
      final ufs = _stateController.text.trim().toUpperCase();
      final cidade = _cityController.text.trim();
      final cep = _onlyDigits(_cepSignupController.text);
      if (ufs.length != 2 || cidade.isEmpty || cep.length != 8) {
        _showMessage(
          'Informe UF com 2 letras, cidade e CEP com 8 digitos.',
        );
        return;
      }

      setState(() => _submitting = true);
      try {
        final result = await _service.createWorkspaceAccess(
          payload: AccountingOfficeLightweightPayload(
            officeName: _officeNameController.text.trim(),
            responsibleName: _responsibleNameController.text.trim(),
            email: _emailController.text.trim().toLowerCase(),
            password: '',
            confirmPassword: '',
            leadOrigin: <String, String>{
              'estado': ufs,
              'cidade': cidade,
              'cep': cep,
            },
          ),
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Acesso criado'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
              FilledButton(
                onPressed: () => context.go(
                  '/login-contador?email=${Uri.encodeComponent(result.email)}',
                ),
                child: const Text('Ir para login'),
              ),
            ],
          ),
        );
      } catch (error) {
        if (!mounted) return;
        _showMessage(AppErrorMapper.messageFrom(error));
      } finally {
        if (mounted) {
          setState(() => _submitting = false);
        }
      }
      return;
    }

    if (        _officeNameController.text.trim().isEmpty ||
        _cnpjController.text.trim().isEmpty ||
        _responsibleNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty) {
      _showMessage('Preencha todos os campos obrigatorios do escritorio.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.submit(
        payload: AccountingOfficeSignupPayload(
          token: widget.token.trim(),
          officeName: _officeNameController.text.trim(),
          cnpj: _cnpjController.text.trim(),
          responsibleName: _responsibleNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          password: '',
          confirmPassword: '',
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim().toUpperCase(),
          billingChoice: _billingChoice,
          notes: _notesController.text.trim(),
        ),
      );
      if (!mounted) return;
      metaFbqTrackCompleteRegistrationEscritorio(
        officeId: result.officeId,
        contentName: result.officeName.isNotEmpty
            ? result.officeName
            : 'escritorio_contabil',
      );
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Escritorio cadastrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.message.isNotEmpty
                    ? result.message
                    : 'O escritorio foi cadastrado e subiu para a base da plataforma.',
              ),
              const SizedBox(height: 12),
              Text('Escritorio: ${result.officeName}'),
              Text('Login: ${result.email}'),
              Text(
                'E-mail de acesso: ${result.emailDispatched ? 'enviado' : 'pendente'}',
              ),
              Text(
                'Base da plataforma: ${result.platformLinked ? 'atualizada' : 'pendente'}',
              ),
              if (result.loginUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(result.loginUrl),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: () => context.go(
                '/login-contador?email=${Uri.encodeComponent(result.email)}',
              ),
              child: const Text('Ir para login'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(AppErrorMapper.messageFrom(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    if (context.mounted) { context.showUserMessage(message); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefill = _prefill;
    final lightweightMode = _lightweightMode;

    return Scaffold(
      appBar: AppBar(
        leading: lightweightMode
            ? const BotaoVoltarApp()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/login-contador'),
              ),
        title: Text(
          lightweightMode
              ? 'Seu acesso em minutos'
              : 'Cadastro do escritorio de contabilidade',
        ),
      ),
      body: AppGradientBackground(
        child: lightweightMode
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Text(
                          'Um painel só para carteira fiscal e empresa — menos troca de planilhas, mais cobrança justa pelo que você faz.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppBrandColors.ink,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Em poucos minutos você recebe o link no e-mail e entra antes do próximo ciclo cobrar caro pela desorganização.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppBrandColors.softText,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: BrandLogo(size: 84, radius: 28),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Carteira fiscal no Ponto Certo',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Escritório, responsável, e-mail e sua localização. '
                              'A senha é criada só pelo link — você confirma e já opera.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppBrandColors.softText,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _field(
                              controller: _officeNameController,
                              label: 'Nome do escritorio *',
                              icon: Icons.apartment_rounded,
                              lightSurface: true,
                            ),
                            _field(
                              controller: _responsibleNameController,
                              label: 'Responsavel principal *',
                              icon: Icons.person_rounded,
                              lightSurface: true,
                            ),
                            _field(
                              controller: _emailController,
                              label: 'E-mail de acesso *',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              lightSurface: true,
                            ),
                            _leadGeoRowOrColumnLight(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                'Cheque também o spam — o convite oficial chega rápido.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppBrandColors.softText,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.how_to_reg_rounded),
                              label: Text(
                                _submitting
                                    ? 'Criando acesso...'
                                    : 'Receber link e abrir carteira',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : AppPageLayout(
                child: ListView(
                  children: [
                    AppWorkspaceCard(
                      title: 'Escritorio de contabilidade',
                      subtitle:
                          'Cadastro dedicado para o contador indicado pela empresa. Primeiro o escritorio e cadastrado; depois a empresa indicada entra no fluxo oficial desse escritorio.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fluxo previsto',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppBrandColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. A empresa ou a plataforma envia um convite quando aplicavel.\n'
                            '2. O escritorio completa dados cadastrais e fiscais no formulario oficial.\n'
                            '3. O sistema envia e-mail com acesso ao ambiente web e orientacao para o app quando couber.\n'
                            '4. O escritorio fica disponivel na base da plataforma para vinculos e operacao.\n'
                            '5. Em seguida, cadastre ou vincule as empresas da carteira no fluxo interno.',
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppBrandColors.border),
                            ),
                            child: const Text(
                              'Modelo atual: entrada com teste gratuito quando previsto na proposta comercial. Depois da abertura do escritorio, a carteira centraliza cadastro das empresas e acompanha o consumo pelo periodo combinado.',
                              style: TextStyle(
                                color: AppBrandColors.softText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_loadingPrefill) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          if (prefill != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
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
                                    'Convite identificado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppBrandColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    prefill.inviterName.trim().isNotEmpty ||
                                            prefill.inviterEmail
                                                .trim()
                                                .isNotEmpty
                                        ? 'Origem: ${prefill.inviterName.isNotEmpty ? prefill.inviterName : prefill.inviterEmail}'
                                        : 'Origem do convite nao informada',
                                  ),
                                  if (prefill.accepted)
                                    const Text(
                                      'Este convite ja foi aceito.',
                                    )
                                  else if (prefill.expired)
                                    const Text(
                                      'Este convite esta expirado.',
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppWorkspaceCard(
                      title: 'Dados do escritorio',
                      subtitle:
                          'Base cadastral necessaria para criar o acesso do escritorio e preparar o monitoramento na plataforma.',
                      child: Column(
                        children: [
                          _field(
                            controller: _officeNameController,
                            label: 'Nome do escritorio *',
                            icon: Icons.apartment_rounded,
                          ),
                          _field(
                            controller: _cnpjController,
                            label: 'CNPJ *',
                            icon: Icons.badge_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CnpjInputFormatter()],
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _loadingCnpj ? null : _lookupCnpj,
                                  icon: const Icon(
                                    Icons.travel_explore_outlined,
                                  ),
                                  label: Text(
                                    _loadingCnpj
                                        ? 'Buscando CNPJ...'
                                        : 'Buscar dados do CNPJ',
                                  ),
                                ),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  child: Text(
                                    _cnpjLookupMessage,
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: AppBrandColors.softText,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _responsibleNameController,
                            label: 'Responsavel principal *',
                            icon: Icons.person_rounded,
                          ),
                          _field(
                            controller: _phoneController,
                            label: 'Telefone *',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [TelefoneInputFormatter()],
                          ),
                          _field(
                            controller: _emailController,
                            label: 'Login por e-mail *',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _field(
                            controller: _addressController,
                            label: 'Endereco completo *',
                            icon: Icons.location_on_outlined,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _cityController,
                                  label: 'Cidade *',
                                  icon: Icons.location_city_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  controller: _stateController,
                                  label: 'UF *',
                                  icon: Icons.map_outlined,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              initialValue: _billingChoice,
                              decoration: const InputDecoration(
                                labelText:
                                    'Regra padrao de cobranca das empresas indicadas *',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'office',
                                  child:
                                      Text('Cobrar do escritorio por padrao'),
                                ),
                                DropdownMenuItem(
                                  value: 'company',
                                  child:
                                      Text('Cobrar da empresa por padrao'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _billingChoice = value);
                              },
                            ),
                          ),
                          _field(
                            controller: _notesController,
                            label: 'Observacoes operacionais',
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Este mesmo fluxo sera reutilizado depois na pagina dedicada para escritorios de contabilidade.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppBrandColors.softText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.how_to_reg_rounded),
                            label: Text(
                              _submitting
                                  ? 'Finalizando cadastro...'
                                  : 'Cadastrar escritorio',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static const double _kLeadGeoBreakpoint = 560;

  Widget _leadGeoRowOrColumnLight() {
    void onUfChanged(String v) {
      final u = v.toUpperCase().trim();
      if (u != v) {
        final c = u.length > 2 ? u.substring(0, 2) : u;
        _stateController.value = TextEditingValue(
          text: c,
          selection: TextSelection.collapsed(offset: c.length),
        );
      }
    }

    final ufField = TextField(
      controller: _stateController,
      maxLength: 2,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        hintText: 'Ex.: SP',
        counterText: '',
        filled: true,
        fillColor: Colors.white,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
      ],
      onChanged: onUfChanged,
    );

    final cidadeField = TextField(
      controller: _cityController,
      decoration: const InputDecoration(
        hintText: 'Nome da cidade',
        prefixIcon: Icon(Icons.location_city_outlined),
        filled: true,
        fillColor: Colors.white,
      ),
    );

    final cepField = TextField(
      controller: _cepSignupController,
      keyboardType: TextInputType.number,
      maxLength: 8,
      decoration: const InputDecoration(
        hintText: 'Somente numeros (8)',
        counterText: '',
        prefixIcon: Icon(Icons.markunread_mailbox_outlined),
        filled: true,
        fillColor: Colors.white,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );

    final narrow = MediaQuery.sizeOf(context).width < _kLeadGeoBreakpoint;
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExternalLabeledField(label: 'Estado (UF) *', child: ufField),
          ExternalLabeledField(label: 'Cidade *', child: cidadeField),
          ExternalLabeledField(label: 'CEP *', child: cepField),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 22,
            child: ExternalLabeledField(
              label: 'Estado (UF) *',
              bottomSpacing: 0,
              child: ufField,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 48,
            child: ExternalLabeledField(
              label: 'Cidade *',
              bottomSpacing: 0,
              child: cidadeField,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 30,
            child: ExternalLabeledField(
              label: 'CEP *',
              bottomSpacing: 0,
              child: cepField,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    int maxLines = 1,
    bool lightSurface = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: lightSurface,
          fillColor: lightSurface ? Colors.white : null,
        ),
      ),
    );
  }
}
