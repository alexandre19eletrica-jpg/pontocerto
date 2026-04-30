part of 'fiscal_readiness_page.dart';

extension _FiscalReadinessIntegrationActions on _FiscalReadinessPageState {
  Future<void> _openRealIntegrationDialog({
    required Session sessao,
    required _FiscalRealIntegrationSetup current,
  }) async {
    final usesGlobalIntegrationDefaults = !hasSupremePlatformAccess(sessao);
    final environmentController = TextEditingController(text: current.environment);
    final providerController = TextEditingController(text: current.provider);
    final municipalCodeController = TextEditingController(
      text: current.municipalCode,
    );
    final certificateController = TextEditingController(
      text: current.certificateRef,
    );
    final apiBaseUrlController = TextEditingController(text: current.apiBaseUrl);
    final isFocusAtOpen = current.provider.trim().toLowerCase().contains('focus');
    final apiTokenController = TextEditingController(
      text: isFocusAtOpen ? '' : current.apiToken,
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
                  if (usesGlobalIntegrationDefaults) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ambiente, provedor, modalidade de API Focus para emissao e URL base '
                        'sao configuracao global da plataforma (empresa suprema). Abaixo aparecem '
                        'preenchidos para conferencia; edite apenas codigo fiscal, certificado '
                        'e observacoes desta empresa.',
                        style: TextStyle(height: 1.38),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedEnvironment,
                    decoration: InputDecoration(
                      labelText: 'Ambiente',
                      helperText: usesGlobalIntegrationDefaults
                          ? 'Global da plataforma (suprema); travado nesta empresa.'
                          : null,
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Provedor',
                      helperText: usesGlobalIntegrationDefaults
                          ? 'Global da plataforma (suprema); travado nesta empresa.'
                          : null,
                    ),
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
                      decoration: InputDecoration(
                        labelText: 'API Focus para emissao',
                        helperText: usesGlobalIntegrationDefaults
                            ? 'Global da plataforma (suprema); travado nesta empresa.'
                            : null,
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
                          ? 'Global da plataforma (suprema); travado nesta empresa.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedProvider.toLowerCase().contains('focus')) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Token API Focus: a plataforma ja provisiona a credencial de forma segura. '
                        'Ninguem ve o valor nesta tela; ela fica apenas na infraestrutura (Functions / ambiente).',
                        style: TextStyle(height: 1.38),
                      ),
                    ),
                  ] else
                    TextField(
                      controller: apiTokenController,
                      enabled: !usesGlobalIntegrationDefaults,
                      decoration: InputDecoration(
                        labelText: 'Token API / chave',
                        helperText: usesGlobalIntegrationDefaults
                            ? 'Credencial global ou da suprema; travado nesta empresa.'
                            : 'Apenas para integradores fora do fluxo Focus global.',
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
                final isFocus = selectedProvider.toLowerCase().contains('focus');
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
                  apiToken: usesGlobalIntegrationDefaults
                      ? current.apiToken
                      : (isFocus ? '' : apiTokenController.text.trim()),
                  usesPlatformFocusToken: usesGlobalIntegrationDefaults
                      ? current.usesPlatformFocusToken
                      : isFocus,
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
}
