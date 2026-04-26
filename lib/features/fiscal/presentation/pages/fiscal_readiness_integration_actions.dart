part of 'fiscal_readiness_page.dart';

extension _FiscalReadinessIntegrationActions on _FiscalReadinessPageState {
  Future<void> _openRealIntegrationDialog({
    required Session sessao,
    required _FiscalRealIntegrationSetup current,
  }) async {
    final canManageGlobalApiToken = hasSupremePlatformAccess(sessao);
    final usesGlobalIntegrationDefaults = !canManageGlobalApiToken;
    final environmentController = TextEditingController(text: current.environment);
    final providerController = TextEditingController(text: current.provider);
    final municipalCodeController = TextEditingController(
      text: current.municipalCode,
    );
    final certificateController = TextEditingController(
      text: current.certificateRef,
    );
    final apiBaseUrlController = TextEditingController(text: current.apiBaseUrl);
    final apiTokenController = TextEditingController(
      text: canManageGlobalApiToken ? current.apiToken : '',
    );
    final homologationController = TextEditingController(
      text: current.lastHomologationNote,
    );
    var selectedEnvironment = current.environment.trim().isEmpty
        ? 'homologacao'
        : current.environment.trim();
    var selectedProvider = current.provider.trim();
    var selectedFocusApi =
        current.focusNfseApi.trim().isEmpty ? 'municipal' : current.focusNfseApi.trim();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Preparar emissao fiscal real'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedEnvironment,
                    decoration: const InputDecoration(labelText: 'Ambiente'),
                    items: const [
                      DropdownMenuItem(
                        value: 'homologacao',
                        child: Text('Homologacao'),
                      ),
                      DropdownMenuItem(
                        value: 'producao',
                        child: Text('Producao'),
                      ),
                    ],
                    onChanged: usesGlobalIntegrationDefaults
                        ? null
                        : (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedEnvironment = value;
                        environmentController.text = value;
                        if (selectedProvider.toLowerCase().contains('focus')) {
                          apiBaseUrlController.text = value == 'producao'
                              ? 'https://api.focusnfe.com.br'
                              : 'https://homologacao.focusnfe.com.br';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProvider.isEmpty ? null : selectedProvider,
                    decoration: const InputDecoration(labelText: 'Provedor'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Focus NFe',
                        child: Text('Focus NFe'),
                      ),
                      DropdownMenuItem(
                        value: 'Tecnospeed',
                        child: Text('Tecnospeed'),
                      ),
                      DropdownMenuItem(
                        value: 'Prefeitura direta',
                        child: Text('Prefeitura direta'),
                      ),
                      DropdownMenuItem(
                        value: 'Outro integrador',
                        child: Text('Outro integrador'),
                      ),
                    ],
                    onChanged: usesGlobalIntegrationDefaults
                        ? null
                        : (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedProvider = value;
                        providerController.text = value;
                        if (value.toLowerCase().contains('focus')) {
                          apiBaseUrlController.text =
                              selectedEnvironment == 'producao'
                                  ? 'https://api.focusnfe.com.br'
                                  : 'https://homologacao.focusnfe.com.br';
                        }
                      });
                    },
                  ),
                  if (selectedProvider.toLowerCase().contains('focus')) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFocusApi,
                      decoration: const InputDecoration(
                        labelText: 'API Focus para emissao',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'municipal',
                          child: Text('NFSe municipal Focus'),
                        ),
                        DropdownMenuItem(
                          value: 'national',
                          child: Text('NFSe Nacional'),
                        ),
                      ],
                      onChanged: usesGlobalIntegrationDefaults
                          ? null
                          : (value) {
                        if (value == null) return;
                        setDialogState(() => selectedFocusApi = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: municipalCodeController,
                    decoration: InputDecoration(
                      labelText: selectedFocusApi == 'national'
                          ? 'Codigo fiscal padrao da emissao'
                          : 'Codigo municipal de servico',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: certificateController,
                    decoration: const InputDecoration(
                      labelText: 'Referencia do certificado A1/A3',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: apiBaseUrlController,
                    enabled: !usesGlobalIntegrationDefaults,
                    decoration: InputDecoration(
                      labelText: 'Base URL / endpoint principal',
                      helperText: usesGlobalIntegrationDefaults
                          ? 'Campo global validado pela empresa suprema e bloqueado neste acesso.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canManageGlobalApiToken)
                    TextField(
                      controller: apiTokenController,
                      decoration: const InputDecoration(
                        labelText: 'Token API / chave',
                        helperText:
                            'Campo global da empresa suprema. O valor nao deve ser compartilhado com outras empresas ou contadores.',
                      ),
                    )
                  else
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Token API / chave',
                        hintText: current.apiToken.trim().isNotEmpty
                            ? 'Preenchido globalmente pela empresa suprema'
                            : 'Aguardando token global da empresa suprema',
                        helperText:
                            'Campo global bloqueado neste acesso. Quando estiver correto na empresa suprema, passa a valer para todas as empresas.',
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: homologationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Observacoes de homologacao',
                      helperText: usesGlobalIntegrationDefaults
                          ? 'Use este campo apenas para observacoes da propria empresa; a integracao global ja prevalece.'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final next = _FiscalRealIntegrationSetup(
                  environment: usesGlobalIntegrationDefaults
                      ? current.environment
                      : environmentController.text.trim(),
                  provider: usesGlobalIntegrationDefaults
                      ? current.provider
                      : providerController.text.trim(),
                  focusNfseApi: usesGlobalIntegrationDefaults
                      ? current.focusNfseApi
                      : selectedProvider.toLowerCase().contains('focus')
                      ? selectedFocusApi
                      : current.focusNfseApi,
                  municipalCode: municipalCodeController.text.trim(),
                  certificateRef: certificateController.text.trim(),
                  apiBaseUrl: usesGlobalIntegrationDefaults
                      ? current.apiBaseUrl
                      : apiBaseUrlController.text.trim(),
                  apiToken: canManageGlobalApiToken
                      ? apiTokenController.text.trim()
                      : current.apiToken,
                  lastHomologationNote: homologationController.text.trim(),
                );
                await _saveRealIntegrationSetup(sessao, next);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Salvar estrutura'),
            ),
          ],
        ),
      ),
    );

    environmentController.dispose();
    providerController.dispose();
    municipalCodeController.dispose();
    certificateController.dispose();
    apiBaseUrlController.dispose();
    apiTokenController.dispose();
    homologationController.dispose();
  }

  Future<void> _saveRealIntegrationSetup(
    Session sessao,
    _FiscalRealIntegrationSetup setup,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    final previousFeatures =
        (before.data()?['fiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalRealIntegration': setup.toMap(),
            'fiscalFeatures': {
              ...previousFeatures,
              'enableRealInvoiceIntegration': setup.isPrepared,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'real_invoice_setup_updated',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalRealIntegration': setup.toMap(),
          'enableRealInvoiceIntegration': setup.isPrepared,
        },
      );
      await _refreshCompanyProvisioning(
        successMessage:
            'Base de emissao fiscal real atualizada e automacao reprocessada.',
      );
    } catch (_) {
      _msg('Nao foi possivel salvar a base de emissao real.');
    }
  }

  Future<void> _openComplianceMatrixDialog({
    required Session sessao,
    required _FiscalRealIntegrationSetup setup,
    required _FiscalComplianceMatrix current,
  }) async {
    final municipalityNameController = TextEditingController(
      text: current.municipalityName,
    );
    final municipalityCodeController = TextEditingController(
      text: current.municipalityCode,
    );
    final providerController = TextEditingController(text: current.provider);
    final defaultIssRateController = TextEditingController(
      text: current.defaultIssRateText,
    );
    final customerCostLegalTextController = TextEditingController(
      text: current.customerCostLegalText,
    );
    final generalLegalTextController = TextEditingController(
      text: current.generalLegalText,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matriz fiscal por municipio/provedor'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: municipalityNameController,
                  decoration: const InputDecoration(
                    labelText: 'Municipio base da matriz',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: municipalityCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Codigo municipal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: providerController,
                        decoration: const InputDecoration(
                          labelText: 'Provedor',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: defaultIssRateController,
                  decoration: const InputDecoration(
                    labelText: 'Aliquota ISS padrao (%)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: generalLegalTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Texto juridico padrao da matriz',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: customerCostLegalTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Texto juridico do acrescimo ao tomador',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Regras por servico herdadas automaticamente: ${current.rules.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final next = current.copyWith(
                municipalityName: municipalityNameController.text.trim(),
                municipalityCode: municipalityCodeController.text.trim(),
                provider: providerController.text.trim().isEmpty
                    ? setup.provider
                    : providerController.text.trim(),
                defaultIssRateText: defaultIssRateController.text.trim(),
                generalLegalText: generalLegalTextController.text.trim(),
                customerCostLegalText:
                    customerCostLegalTextController.text.trim(),
              );
              await _saveComplianceMatrix(sessao, next);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('Salvar matriz'),
          ),
        ],
      ),
    );

    municipalityNameController.dispose();
    municipalityCodeController.dispose();
    providerController.dispose();
    defaultIssRateController.dispose();
    customerCostLegalTextController.dispose();
    generalLegalTextController.dispose();
  }

  Future<void> _saveComplianceMatrix(
    Session sessao,
    _FiscalComplianceMatrix matrix,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalComplianceMatrix': matrix.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _msg('Matriz fiscal atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a matriz fiscal.');
    }
  }

  Future<void> _uploadDigitalCertificate(Session sessao) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['pfx', 'p12'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    PreparedUploadData prepared;
    try {
      prepared = await MobileUploadOptimizer.preparePlatformFile(
        file: file,
        fallbackContentType: 'application/x-pkcs12',
      );
    } on MobileUploadOptimizerException catch (error) {
      _msg(error.message);
      return;
    }
    final bytes = prepared.bytes;
    if (bytes.isEmpty) {
      _msg('Nao foi possivel ler o certificado digital.');
      return;
    }

    final passwordController = TextEditingController();
    final loginResponsavelController = TextEditingController();
    final senhaResponsavelController = TextEditingController();
    bool confirm = false;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar certificado digital'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Arquivo selecionado: ${file.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha do certificado',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: loginResponsavelController,
                decoration: const InputDecoration(
                  labelText: 'Login da prefeitura (se houver)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: senhaResponsavelController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha da prefeitura (se houver)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              confirm = true;
              Navigator.of(context).pop();
            },
            child: const Text('Salvar certificado'),
          ),
        ],
      ),
    );

    if (!confirm) {
      passwordController.dispose();
      loginResponsavelController.dispose();
      senhaResponsavelController.dispose();
      return;
    }

    try {
      final extension = (file.extension ?? 'pfx').toLowerCase();
      final storagePath =
          'companies/${sessao.companyId}/fiscal/certificates/certificate.$extension';
      final refStorage = FirebaseStorage.instance.ref(storagePath);
      await refStorage.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/x-pkcs12',
          customMetadata: {
            'companyId': sessao.companyId,
            'uploadedBy': sessao.userId,
            'originalName': prepared.fileName,
          },
        ),
      );

      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
        'companyId': sessao.companyId,
        'fiscalCertificate': {
          'storagePath': storagePath,
          'fileName': prepared.fileName,
          'extension': extension,
          'uploadedAt': FieldValue.serverTimestamp(),
          'uploadedByUserId': sessao.userId,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('fiscal_secure')
          .doc(sessao.companyId)
          .set({
        'companyId': sessao.companyId,
        'fiscalCertificateSecrets': {
          'password': passwordController.text.trim(),
          'loginResponsavel': loginResponsavelController.text.trim(),
          'senhaResponsavel': senhaResponsavelController.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _writeAuditLog(
        sessao: sessao,
        action: 'fiscal_certificate_uploaded',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        after: {
          'storagePath': storagePath,
          'fileName': file.name,
        },
      );

      await _refreshCompanyProvisioning(
        successMessage:
            'Certificado salvo e automacao fiscal reprocessada com sucesso.',
      );
    } catch (_) {
      _msg('Nao foi possivel salvar o certificado digital.');
    } finally {
      passwordController.dispose();
      loginResponsavelController.dispose();
      senhaResponsavelController.dispose();
    }
  }

  Future<void> _syncFocusCompany({required Session sessao}) async {
    try {
      final callable = _fiscalFunctions.httpsCallable('fiscalSyncFocusCompany');
      final response = await callable.call();
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final focusCompanyId = map['focusCompanyId']?.toString().trim() ?? '';
      final validUntil = map['certificadoValidoAte']?.toString().trim() ?? '';
      _msg(
        focusCompanyId.isEmpty
            ? 'Empresa sincronizada com a Focus NFe.'
            : 'Focus sincronizada. Empresa ID $focusCompanyId${validUntil.isEmpty ? '' : ' | certificado ate $validUntil'}',
      );
    } on FirebaseFunctionsException catch (e) {
      _msg(e.message ?? 'Nao foi possivel sincronizar com a Focus NFe.');
    } catch (_) {
      _msg('Nao foi possivel sincronizar com a Focus NFe.');
    }
  }

  Future<void> _refreshCompanyProvisioning({
    String? successMessage,
    String? fallbackErrorMessage,
  }) async {
    try {
      final callable = _fiscalFunctions.httpsCallable(
        'fiscalRefreshCompanyProvisioning',
      );
      final response = await callable.call();
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final status = map['focusProvisioningStatus']?.toString().trim() ?? '';
      final focusCompanyId = map['focusCompanyId']?.toString().trim() ?? '';
      final missing = (map['focusProvisioningMissing'] as List?)
              ?.map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const <String>[];
      final error = map['focusProvisioningError']?.toString().trim() ?? '';

      if (status == 'SYNCED') {
        _msg(
          successMessage ??
              (focusCompanyId.isEmpty
                  ? 'Provisionamento automatico da Focus concluido.'
                  : 'Provisionamento automatico concluido. Empresa Focus ID $focusCompanyId.'),
        );
        return;
      }

      if (status == 'PENDING') {
        final pendencias = missing.isEmpty ? 'dados pendentes' : missing.join(', ');
        _msg('Automacao fiscal reprocessada. Pendencias atuais: $pendencias.');
        return;
      }

      if (status == 'ERROR') {
        _msg(
          error.isEmpty
              ? (fallbackErrorMessage ??
                  'A automacao fiscal foi reprocessada, mas a Focus rejeitou a sincronizacao.')
              : 'A automacao fiscal foi reprocessada, mas a Focus retornou: $error',
        );
        return;
      }

      if ((successMessage ?? '').trim().isNotEmpty) {
        _msg(successMessage!.trim());
      }
    } on FirebaseFunctionsException catch (e) {
      _msg(
        e.message ??
            fallbackErrorMessage ??
            'Nao foi possivel reprocessar a automacao fiscal da empresa.',
      );
    } catch (_) {
      _msg(
        fallbackErrorMessage ??
            'Nao foi possivel reprocessar a automacao fiscal da empresa.',
      );
    }
  }

  Future<void> _saveFiscalHomologationChecklist({
    required Session sessao,
    required _FiscalHomologationChecklist checklist,
  }) async {
    final settingsRef = FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId);
    final before = await settingsRef.get();
    try {
      await settingsRef.set({
        'companyId': sessao.companyId,
        'fiscalHomologationChecklist': checklist.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'fiscal_homologation_checklist_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalHomologationChecklist': checklist.toMap(),
        },
      );
    } catch (_) {
      _msg('Nao foi possivel salvar o checklist de homologacao.');
    }
  }

}
