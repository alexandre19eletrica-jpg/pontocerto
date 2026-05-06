import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/media/mobile_upload_optimizer.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/marketing/presentation/services/sales_onboarding_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class SalesOnboardingPage extends StatefulWidget {
  const SalesOnboardingPage({super.key, required this.token});

  final String token;

  @override
  State<SalesOnboardingPage> createState() => _SalesOnboardingPageState();
}

class _SalesOnboardingPageState extends State<SalesOnboardingPage> {
  final _service = SalesOnboardingService();
  final _legalName = TextEditingController();
  final _tradeName = TextEditingController();
  final _document = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _phone = TextEditingController();
  final _stateRegistration = TextEditingController();
  final _municipalRegistration = TextEditingController();
  final _zipCode = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _preferredLoginEmail = TextEditingController();
  final _taxRegime = TextEditingController();
  final _legalNature = TextEditingController();
  final _companySize = TextEditingController();
  final _mainCnae = TextEditingController();
  final _mainCnaeDescription = TextEditingController();
  final _municipalCode = TextEditingController();
  final _standardServiceCode = TextEditingController();
  final _certificatePassword = TextEditingController();
  final _responsibleLogin = TextEditingController();
  final _responsiblePassword = TextEditingController();
  final _accountantName = TextEditingController();
  final _accountantEmail = TextEditingController();
  String _businessCategory = 'service';
  bool _hasAccountant = false;
  bool _loading = true;
  bool _saving = false;
  SalesOnboardingRequestSnapshot? _snapshot;
  final List<_UploadDraft> _uploads = <_UploadDraft>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _legalName.dispose();
    _tradeName.dispose();
    _document.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _phone.dispose();
    _stateRegistration.dispose();
    _municipalRegistration.dispose();
    _zipCode.dispose();
    _street.dispose();
    _number.dispose();
    _complement.dispose();
    _neighborhood.dispose();
    _city.dispose();
    _state.dispose();
    _preferredLoginEmail.dispose();
    _taxRegime.dispose();
    _legalNature.dispose();
    _companySize.dispose();
    _mainCnae.dispose();
    _mainCnaeDescription.dispose();
    _municipalCode.dispose();
    _standardServiceCode.dispose();
    _certificatePassword.dispose();
    _responsibleLogin.dispose();
    _responsiblePassword.dispose();
    _accountantName.dispose();
    _accountantEmail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.getRequest(widget.token);
      if (!snapshot.isAccountantMode) {
        _ownerName.text = snapshot.customerName;
        _ownerEmail.text = snapshot.customerEmail;
        _preferredLoginEmail.text = snapshot.customerEmail;
      }
      _accountantName.text = snapshot.accountantName;
      _accountantEmail.text = snapshot.accountantEmail;
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _hasAccountant =
            snapshot.accountantEmail.trim().isNotEmpty ||
            snapshot.accountantName.trim().isNotEmpty;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
      setState(() => _loading = false);
    }
  }

  Future<void> _pickUpload(String category) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'pfx', 'p12'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    PreparedUploadData prepared;
    try {
      prepared = await MobileUploadOptimizer.preparePlatformFile(
        file: file,
        fallbackContentType: _contentTypeForExtension(file.extension),
      );
    } on MobileUploadOptimizerException catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        context.showUserError(error.message);
      }
      return;
    }
    final bytes = prepared.bytes;
    if (bytes.isEmpty) return;
    setState(() {
      _uploads.add(
        _UploadDraft(
          category: category,
          fileName: prepared.fileName,
          contentType: prepared.contentType,
          base64: base64Encode(bytes),
        ),
      );
    });
  }

  String _contentTypeForExtension(String? extension) {
    final ext = extension?.toLowerCase() ?? '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pfx':
      case 'p12':
        return 'application/x-pkcs12';
      default:
        return 'application/octet-stream';
    }
  }

  bool _hasUpload(String category) {
    return _uploads.any((item) => item.category == category);
  }

  Future<void> _submit() async {
    if (_saving) return;
    final snapshot = _snapshot;
    if (_legalName.text.trim().isEmpty ||
        _tradeName.text.trim().isEmpty ||
        _document.text.trim().isEmpty ||
        _ownerName.text.trim().isEmpty ||
        _ownerEmail.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      if (context.mounted) { context.showUserMessage('Preencha os campos obrigatorios.'); }
      return;
    }
    if (_taxRegime.text.trim().isEmpty ||
        _municipalRegistration.text.trim().isEmpty ||
        _mainCnae.text.trim().isEmpty ||
        _mainCnaeDescription.text.trim().isEmpty ||
        _municipalCode.text.trim().isEmpty ||
        _legalNature.text.trim().isEmpty ||
        _companySize.text.trim().isEmpty ||
        _zipCode.text.trim().isEmpty ||
        _street.text.trim().isEmpty ||
        _number.text.trim().isEmpty ||
        _neighborhood.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _state.text.trim().isEmpty ||
        (_businessCategory == 'service' &&
            _standardServiceCode.text.trim().isEmpty)) {
      if (context.mounted) {
        context.showUserMessage(
          'Preencha a base cadastral e fiscal completa para deixar a empresa pronta para emitir e operar.',
        );
      }
      return;
    }
    if (snapshot != null && !snapshot.isAccountantMode) {
      if (_hasAccountant &&
          (_accountantName.text.trim().isEmpty ||
              _accountantEmail.text.trim().isEmpty)) {
        if (context.mounted) {
          context.showUserMessage(
            'Informe nome e email do contador para fazer o vinculo.',
          );
        }
        return;
      }
    }
    final missing = <String>[];
    if (!_hasUpload('cartao_cnpj')) {
      missing.add('cartao CNPJ');
    }
    if (!_hasUpload('documento_responsavel')) {
      missing.add('documento do responsavel');
    }
    if (!_hasUpload('comprovante_endereco')) {
      missing.add('comprovante de endereco');
    }
    if (!_hasUpload('contrato_social')) {
      missing.add('contrato social');
    }
    if (!_hasUpload('certificado_digital_a1')) {
      missing.add('certificado digital A1');
    }
    if (_certificatePassword.text.trim().isEmpty) {
      missing.add('senha do certificado digital');
    }
    if (missing.isNotEmpty) {
      if (context.mounted) {
        context.showUserMessage(
          'Para deixar a empresa pronta para emitir e operar, envie: ${missing.join(', ')}.',
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.submit(
        token: widget.token,
        payload: {
          'legalName': _legalName.text.trim(),
          'tradeName': _tradeName.text.trim(),
          'document': _document.text.trim(),
          'ownerName': _ownerName.text.trim(),
          'ownerEmail': _ownerEmail.text.trim(),
          'phone': _phone.text.trim(),
          'businessCategory': _businessCategory,
          'stateRegistration': _stateRegistration.text.trim(),
          'municipalRegistration': _municipalRegistration.text.trim(),
          'zipCode': _zipCode.text.trim(),
          'street': _street.text.trim(),
          'number': _number.text.trim(),
          'complement': _complement.text.trim(),
          'neighborhood': _neighborhood.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'preferredLoginEmail': _preferredLoginEmail.text.trim(),
          'taxRegime': _taxRegime.text.trim(),
          'legalNature': _legalNature.text.trim(),
          'companySize': _companySize.text.trim(),
          'mainCnae': _mainCnae.text.trim(),
          'mainCnaeDescription': _mainCnaeDescription.text.trim(),
          'municipalCode': _municipalCode.text.trim(),
          'standardServiceCode': _standardServiceCode.text.trim(),
          'certificatePassword': _certificatePassword.text.trim(),
          'responsibleLogin': _responsibleLogin.text.trim(),
          'responsiblePassword': _responsiblePassword.text.trim(),
          'onboardingMode': snapshot?.implementationMode ?? 'platform',
          'accountantName':
              snapshot?.isAccountantMode == true || !_hasAccountant
              ? ''
              : _accountantName.text.trim(),
          'accountantEmail':
              snapshot?.isAccountantMode == true || !_hasAccountant
              ? ''
              : _accountantEmail.text.trim(),
        },
        uploads: [
          for (final item in _uploads)
            {
              'category': item.category,
              'fileName': item.fileName,
              'contentType': item.contentType,
              'base64': item.base64,
            },
        ],
      );
      if (!mounted) return;
      if (context.mounted) { context.showUserMessage('Cadastro enviado com sucesso.'); }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final snapshot = _snapshot;
    final accountantMode = snapshot?.isAccountantMode == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro da empresa')),
      body: AppGradientBackground(
        child: AppPageLayout(
          child: ListView(
            children: [
              AppWorkspaceCard(
                title: snapshot?.planTitle ?? 'Cadastro da empresa',
                subtitle: accountantMode
                    ? 'Voce esta no modo escritorio contabil. Preencha a base completa da empresa para concluir a ativacao do ambiente real direto no sistema.'
                    : 'Preencha os dados, envie os documentos e anexe o certificado digital para ativar a empresa no ambiente real.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plano: ${snapshot?.planTitle ?? '-'} | ${snapshot?.planPriceLabel ?? '-'}',
                    ),
                    const SizedBox(height: 8),
                    Text(snapshot?.implementationLabel ?? ''),
                    if (accountantMode) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Escritorio solicitante: ${snapshot?.customerName.isNotEmpty == true ? snapshot!.customerName : snapshot?.customerEmail ?? '-'}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: accountantMode ? 'Modo escritorio' : 'Modo cliente',
                subtitle: accountantMode
                    ? 'Como escritorio contabil, voce pode subir tudo direto aqui no sistema e concluir o cadastro completo da empresa.'
                    : 'Como o cadastro precisa passar pelo contador, envie tudo o que a equipe precisa para cadastrar a empresa e preparar a integracao fiscal automatica.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountantMode
                          ? 'Preencha os dados fiscais com mais precisao e anexe os arquivos tecnicos diretamente aqui.'
                          : 'Sem os dados fiscais, contrato social e certificado digital A1, a ativacao e a automacao fiscal podem falhar.',
                    ),
                  ],
                ),
              ),
              if (!accountantMode) ...[
                const SizedBox(height: 12),
                AppWorkspaceCard(
                  title: 'Contador da empresa',
                  subtitle:
                      'Se a empresa ja tiver contador, informe os dados dele para o sistema fazer o vinculo junto com a criacao da empresa.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _hasAccountant,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Esta empresa ja tem contador'),
                        subtitle: const Text(
                          'Se ativado, o contador sera vinculado automaticamente quando a empresa operacional for criada.',
                        ),
                        onChanged: (value) =>
                            setState(() => _hasAccountant = value),
                      ),
                      if (_hasAccountant) ...[
                        const SizedBox(height: 8),
                        _field(_accountantName, 'Nome do contador *'),
                        _field(_accountantEmail, 'Email do contador *'),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Dados principais',
                child: Column(
                  children: [
                    _field(_legalName, 'Razao social *'),
                    _field(_tradeName, 'Nome fantasia *'),
                    _field(_document, 'CNPJ/CPF *'),
                    _field(_ownerName, 'Responsavel *'),
                    _field(_ownerEmail, 'Email do responsavel *'),
                    _field(_phone, 'Telefone *'),
                    DropdownButtonFormField<String>(
                      initialValue: _businessCategory,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: const [
                        DropdownMenuItem(
                          value: 'service',
                          child: Text('Prestacao de servicos'),
                        ),
                        DropdownMenuItem(
                          value: 'commerce',
                          child: Text('Comercio'),
                        ),
                        DropdownMenuItem(
                          value: 'industry',
                          child: Text('Industria'),
                        ),
                        DropdownMenuItem(value: 'mixed', child: Text('Misto')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _businessCategory = value);
                        }
                      },
                    ),
                    _field(_stateRegistration, 'Inscricao estadual'),
                    _field(_municipalRegistration, 'Inscricao municipal *'),
                    _field(_preferredLoginEmail, 'Email desejado para login *'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Endereco',
                child: Column(
                  children: [
                    _field(_zipCode, 'CEP *'),
                    _field(_street, 'Rua *'),
                    _field(_number, 'Numero *'),
                    _field(_complement, 'Complemento'),
                    _field(_neighborhood, 'Bairro *'),
                    _field(_city, 'Cidade *'),
                    _field(_state, 'Estado *'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Dados fiscais e automacao fiscal',
                subtitle:
                    'Esse bloco precisa estar correto para o provisionamento fiscal automatico configurado pela plataforma.',
                child: Column(
                  children: [
                    _field(_taxRegime, 'Regime tributario *'),
                    _field(_legalNature, 'Natureza juridica *'),
                    _field(_companySize, 'Porte da empresa *'),
                    _field(_mainCnae, 'CNAE principal *'),
                    _field(
                      _mainCnaeDescription,
                      'Descricao do CNAE principal *',
                    ),
                    _field(_municipalCode, 'Codigo do municipio / IBGE *'),
                    _field(_standardServiceCode, 'Codigo padrao de servico *'),
                    _field(
                      _certificatePassword,
                      'Senha do certificado digital *',
                    ),
                    _field(
                      _responsibleLogin,
                      'Login do responsavel no portal municipal',
                    ),
                    _field(
                      _responsiblePassword,
                      'Senha do responsavel no portal municipal',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppWorkspaceCard(
                title: 'Documentos',
                subtitle: accountantMode
                    ? 'Como contador, suba aqui os arquivos tecnicos e documentos da empresa para deixar a base pronta.'
                    : 'Para a ativacao da empresa, envie todos os arquivos abaixo no proprio sistema.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickUpload('cartao_cnpj'),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Cartao CNPJ'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickUpload('documento_responsavel'),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Documento responsavel'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickUpload('comprovante_endereco'),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Comprovante endereco'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickUpload('contrato_social'),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Contrato social'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _pickUpload('certificado_digital_a1'),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Certificado digital A1'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Obrigatorios para deixar a empresa pronta para emitir e usar 100% do sistema: cartao CNPJ, documento do responsavel, comprovante de endereco, contrato social, certificado digital A1 e senha do certificado.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      accountantMode
                          ? 'Se o contador ja tiver todos os dados e arquivos, ele conclui tudo aqui mesmo sem depender de envio externo do cliente.'
                          : 'Sem essa base completa, a empresa pode entrar no sistema, mas nao fica pronta para operar emissao fiscal de forma segura.',
                    ),
                    const SizedBox(height: 12),
                    for (final item in _uploads)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${item.category}: ${item.fileName}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _saving
                        ? 'Enviando...'
                        : accountantMode
                        ? 'Concluir cadastro da empresa'
                        : 'Enviar dados para ativacao',
                  ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _UploadDraft {
  const _UploadDraft({
    required this.category,
    required this.fileName,
    required this.contentType,
    required this.base64,
  });

  final String category;
  final String fileName;
  final String contentType;
  final String base64;
}
