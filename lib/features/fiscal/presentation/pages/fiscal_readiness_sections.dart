part of 'fiscal_readiness_page.dart';

extension _FiscalReadinessSections on _FiscalReadinessPageState {
  Widget _buildRealIntegrationCard({
      required Session sessao,
      required Map<String, dynamic> companyData,
      required Map<String, dynamic> companySettings,
      required _FiscalRealIntegrationSetup setup,
      required bool canConfigureModule,
    }) {
      final complianceMatrix = _FiscalComplianceMatrix.fromSettings(
        companySettings,
        setup,
      );
      final focusProvisioning = (companySettings['focusProvisioning'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final routing = (companySettings['fiscalRouting'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final certificate = (companySettings['fiscalCertificate'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final readiness = _buildFiscalOperationalReadiness(
        setup: setup,
        certificate: certificate,
        companySettings: companySettings,
      );
      final checklist = _FiscalHomologationChecklist.fromSettings(
        companySettings,
      );
      final score = (setup.readinessScore * 100).round();
      return AppWorkspaceCard(
      title: 'Emissao fiscal real',
      subtitle:
          'Estrutura base para integracao NFS-e oficial com ambiente, provedor, certificado e homologacao.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRealIntegrationSummary(
            score: score,
            environmentLabel: setup.environmentLabel,
            providerLabel: setup.providerLabel,
            readiness: readiness,
          ),
          const SizedBox(height: 12),
          Text(
            setup.summary,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildFiscalRouteCard(
            setup: setup,
            routing: routing,
          ),
          const SizedBox(height: 12),
          _buildRealIntegrationDetails(
            sessao: sessao,
            setup: setup,
            certificate: certificate,
            readiness: readiness,
          ),
          const SizedBox(height: 12),
          _buildOperationalReadinessCard(readiness),
          if (setup.provider.trim().toLowerCase().contains('focus') ||
              focusProvisioning.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildFocusProvisioningCard(focusProvisioning),
          ],
          const SizedBox(height: 12),
          _buildHomologationChecklistCard(
            sessao: sessao,
            setup: setup,
            companySettings: companySettings,
            readiness: readiness,
            checklist: checklist,
            canConfigureModule: canConfigureModule,
          ),
          const SizedBox(height: 12),
          _buildComplianceMatrixCard(complianceMatrix),
          if (sessao.role == Role.accountant) ...[
            const SizedBox(height: 12),
            _buildFiscalDailyLinksCard(),
          ],
          const SizedBox(height: 12),
          _buildRealIntegrationActions(
            sessao: sessao,
            companyData: companyData,
            companySettings: companySettings,
            setup: setup,
            complianceMatrix: complianceMatrix,
            canConfigureModule: canConfigureModule,
          ),
        ],
      ),
    );
  }

  Widget _buildRealIntegrationSummary({
    required int score,
    required String environmentLabel,
    required String providerLabel,
    required _FiscalOperationalReadiness readiness,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryChip('Readiness', '$score%'),
        _summaryChip('Ambiente', environmentLabel),
        _summaryChip('Provedor', providerLabel),
        _summaryChip('Operacao', readiness.stageLabel),
      ],
    );
  }

  Widget _buildRealIntegrationDetails({
    required Session sessao,
    required _FiscalRealIntegrationSetup setup,
    required Map<String, dynamic> certificate,
    required _FiscalOperationalReadiness readiness,
  }) {
    final canViewGlobalApiToken = hasSupremePlatformAccess(sessao);
    final tokenStatusLabel = canViewGlobalApiToken
        ? (setup.apiToken.isEmpty ? 'nao informado' : setup.apiTokenMasked)
        : (setup.apiToken.isEmpty
              ? 'aguardando token global da empresa suprema'
              : 'preenchido globalmente pela empresa suprema');
    return Container(
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
          Text(
            'Certificado: ${setup.certificateRef.isEmpty ? 'pendente' : setup.certificateRef}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${setup.usesFocusNationalApi ? 'Codigo fiscal nacional' : 'Codigo municipal'}: ${setup.municipalCode.isEmpty ? '-' : setup.municipalCode}',
          ),
          const SizedBox(height: 6),
          Text(
            'Endpoint fiscal: ${setup.apiBaseUrl.isEmpty ? '-' : setup.apiBaseUrl}',
          ),
          const SizedBox(height: 6),
          Text(
            'Token API: $tokenStatusLabel',
          ),
          const SizedBox(height: 6),
          Text(
            'Certificado digital: ${(certificate['fileName']?.toString().trim() ?? '').isEmpty ? 'nao enviado' : certificate['fileName']}',
          ),
          const SizedBox(height: 6),
          Text(
            'Validade certificado: ${(certificate['validUntil']?.toString().trim() ?? '').isEmpty ? 'pendente' : certificate['validUntil']}',
          ),
          const SizedBox(height: 6),
          Text(
            'Homologacao: ${setup.lastHomologationNote.isEmpty ? 'sem observacao registrada' : setup.lastHomologationNote}',
          ),
          const SizedBox(height: 6),
          Text(
            'Liberacao de producao: ${readiness.canOperateInProduction ? 'apta' : 'bloqueada'}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: readiness.canOperateInProduction
                  ? AppBrandColors.accent
                  : AppBrandColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiscalRouteCard({
    required _FiscalRealIntegrationSetup setup,
    required Map<String, dynamic> routing,
  }) {
    final routeType = routing['routeType']?.toString().trim() ?? '';
    final source = routing['source']?.toString().trim() ?? '';
    final detectionReason = routing['detectionReason']?.toString().trim() ?? '';
    final routeLabel = routeType == 'focus_national'
        ? 'Focus NFSe Nacional'
        : routeType == 'focus_municipal'
        ? 'Focus municipal'
        : routeType == 'manual_review'
        ? 'Revisao manual'
        : setup.usesFocusNationalApi
        ? 'Focus NFSe Nacional'
        : setup.provider.toLowerCase().contains('focus')
        ? 'Focus municipal'
        : 'Rota em definicao';
    final routeDescription = routeType == 'focus_national' || setup.usesFocusNationalApi
        ? 'Esta empresa esta no fluxo NFSe Nacional da Focus. O sistema evita duplicar tratativa de prefeitura municipal quando a emissao nacional ja cobre o caso.'
        : routeType == 'focus_municipal' || setup.provider.toLowerCase().contains('focus')
        ? 'Esta empresa esta no fluxo municipal da Focus. O trabalho operacional deve seguir a rota municipal ja integrada, sem criar processo nacional paralelo.'
        : 'Esta empresa exige revisao manual da rota fiscal antes da liberacao. Nao trate como fluxo automatico normal da Focus ate revisar a configuracao.';

    return Container(
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
            'Rota fiscal ativa',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('Rota', routeLabel),
              if (setup.provider.trim().isNotEmpty)
                _summaryChip('Provedor', setup.providerLabel),
              if (source.isNotEmpty) _summaryChip('Origem', source),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            routeDescription,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.4,
            ),
          ),
          if (detectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo da rota: $detectionReason',
              style: const TextStyle(
                color: AppBrandColors.softText,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationalReadinessCard(_FiscalOperationalReadiness readiness) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: readiness.isBlocked
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: readiness.isBlocked
              ? const Color(0xFFF5C28B)
              : const Color(0xFFB7E4C7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            readiness.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            readiness.description,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.4,
            ),
          ),
          if (readiness.blockers.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Bloqueios atuais',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...readiness.blockers.map(
              (blocker) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppBrandColors.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(blocker)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusProvisioningCard(Map<String, dynamic> provisioning) {
    final status = provisioning['status']?.toString().trim() ?? 'PENDING';
    final focusCompanyId = provisioning['focusCompanyId']?.toString().trim() ?? '';
    final lastError = provisioning['lastError']?.toString().trim() ?? '';
    final missing = (provisioning['missing'] as List?)
            ?.map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
    final tone = _focusProvisioningTone(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provisionamento automatico Focus',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: tone.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _focusProvisioningStatusLabel(status),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tone.foreground,
            ),
          ),
          if (focusCompanyId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Empresa Focus ID: $focusCompanyId'),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pendencias: ${missing.join(', ')}',
              style: const TextStyle(height: 1.4),
            ),
          ],
          if (lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ultimo erro: $lastError',
              style: const TextStyle(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  _ProvisioningTone _focusProvisioningTone(String status) {
    switch (status) {
      case 'SYNCED':
        return const _ProvisioningTone(
          background: Color(0xFFF0FDF4),
          border: Color(0xFFB7E4C7),
          foreground: Color(0xFF166534),
        );
      case 'ERROR':
        return const _ProvisioningTone(
          background: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
          foreground: Color(0xFF991B1B),
        );
      case 'SKIPPED':
        return const _ProvisioningTone(
          background: Color(0xFFF8FAFC),
          border: AppBrandColors.border,
          foreground: AppBrandColors.softText,
        );
      default:
        return const _ProvisioningTone(
          background: Color(0xFFFFF7ED),
          border: Color(0xFFF5C28B),
          foreground: Color(0xFF9A3412),
        );
    }
  }

  String _focusProvisioningStatusLabel(String status) {
    switch (status) {
      case 'SYNCED':
        return 'Empresa provisionada automaticamente na Focus.';
      case 'ERROR':
        return 'A automacao tentou sincronizar a empresa, mas a Focus retornou erro.';
      case 'SKIPPED':
        return 'Provisionamento automatico ignorado para esta configuracao.';
      case 'PENDING':
        return 'Automacao ativa, aguardando dados obrigatorios para sincronizar.';
      default:
        return 'Provisionamento automatico em analise.';
    }
  }

  Widget _buildHomologationChecklistCard({
    required Session sessao,
    required _FiscalRealIntegrationSetup setup,
    required Map<String, dynamic> companySettings,
    required _FiscalOperationalReadiness readiness,
    required _FiscalHomologationChecklist checklist,
    required bool canConfigureModule,
  }) {
    final certificate = (companySettings['fiscalCertificate'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final routeType =
        (companySettings['fiscalRouting']?['routeType']?.toString().trim() ?? '');
    final usesNationalFocus =
        routeType == 'focus_national' || setup.usesFocusNationalApi;
    final hasFocusSync =
        (companySettings['focusCompanyId']?.toString().trim() ?? '').isNotEmpty;
    final helperItems = <_ChecklistTileConfig>[
      _ChecklistTileConfig(
        value: checklist.companyBaseReviewed,
        title: 'Cadastro base revisado',
        subtitle:
            'Confirme emitente, CNPJ, inscricao municipal, endereco e municipio.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(companyBaseReviewed: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.certificateValidated,
        title: 'Certificado validado',
        subtitle:
            (certificate['validUntil']?.toString().trim() ?? '').isEmpty
                ? 'Envie e valide a vigencia do certificado digital.'
                : 'Certificado com validade registrada em ${certificate['validUntil']}.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(certificateValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.matrixValidated,
        title: 'Matriz fiscal conferida',
        subtitle:
            usesNationalFocus
                ? 'Revise enquadramento da NFSe Nacional, servico, CNAE e regras fiscais da empresa.'
                : 'Revise municipio base, ISS padrao, regras por servico e CNAE.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(matrixValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.providerConnectionValidated,
        title: 'Conexao com provedor validada',
        subtitle: setup.provider.trim().toLowerCase().contains('focus')
            ? hasFocusSync
                ? usesNationalFocus
                    ? 'Empresa sincronizada com a Focus pela NFSe Nacional. Validar retorno e credenciais sem duplicar fluxo municipal.'
                    : 'Empresa sincronizada com a Focus. Validar retorno e credenciais.'
                : usesNationalFocus
                    ? 'Sincronize a empresa com a Focus na rota nacional e valide as credenciais.'
                    : 'Sincronize a empresa com a Focus e valide as credenciais.'
            : 'Valide token, endpoint e retorno basico do integrador.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(providerConnectionValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.pilotInvoiceValidated,
        title: 'Emissao piloto validada',
        subtitle:
            'Confirme emissao real, numero oficial, portal e retorno operacional da primeira nota.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(pilotInvoiceValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.productionAuthorized,
        title: 'Producao autorizada',
        subtitle: readiness.canOperateInProduction
            ? 'Empresa pronta para operar oficialmente em producao.'
            : 'A autorizacao final deve ser marcada apenas quando o readiness estiver sem bloqueios.',
        onChanged: readiness.canOperateInProduction
            ? (value) => _saveFiscalHomologationChecklist(
                sessao: sessao,
                checklist: checklist.copyWith(productionAuthorized: value),
              )
            : null,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Checklist assistido de homologacao',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Use este checklist para fechar pendencias reais por empresa antes de liberar operacao oficial. Parte do progresso agora e atualizada automaticamente apos sincronizacao e emissao oficial valida. Em ambiente de producao, o backend bloqueia emissao oficial sem checklist completo e autorizacao final.',
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryChip(
                'Concluidos',
                '${checklist.completedCount}/${checklist.totalCount}',
              ),
              _summaryChip(
                'Pendentes',
                (checklist.totalCount - checklist.completedCount).toString(),
              ),
              _summaryChip(
                'Producao',
                checklist.productionAuthorized ? 'Autorizada' : 'Nao autorizada',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...helperItems.map(
            (item) => SwitchListTile(
              value: item.value,
              onChanged: canConfigureModule ? item.onChanged : null,
              contentPadding: EdgeInsets.zero,
              title: Text(item.title),
              subtitle: Text(item.subtitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceMatrixCard(_FiscalComplianceMatrix complianceMatrix) {
    return Container(
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
            'Matriz fiscal ativa',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Municipio: ${complianceMatrix.municipalityName.isEmpty ? '-' : complianceMatrix.municipalityName}'
            ' | Codigo: ${complianceMatrix.municipalityCode.isEmpty ? '-' : complianceMatrix.municipalityCode}',
          ),
          const SizedBox(height: 6),
          Text(
            'ISS padrao: ${complianceMatrix.defaultIssRateText} | Regras de servico: ${complianceMatrix.rules.length}',
          ),
          const SizedBox(height: 6),
          Text(
            complianceMatrix.summary,
            style: const TextStyle(
              color: AppBrandColors.softText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealIntegrationActions({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup setup,
    required _FiscalComplianceMatrix complianceMatrix,
    required bool canConfigureModule,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: canConfigureModule
                ? () => _openRealIntegrationDialog(
                    sessao: sessao,
                    current: setup,
                  )
                : null,
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Configurar emissao real'),
          ),
          OutlinedButton.icon(
            onPressed: canConfigureModule
                ? () => _openComplianceMatrixDialog(
                    sessao: sessao,
                    setup: setup,
                    current: complianceMatrix,
                  )
                : null,
            icon: const Icon(Icons.rule_folder_outlined),
            label: const Text('Matriz fiscal'),
          ),
          OutlinedButton.icon(
            onPressed: canConfigureModule
                ? () => _uploadDigitalCertificate(sessao)
                : null,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Subir certificado'),
          ),
          OutlinedButton.icon(
            onPressed: canConfigureModule
                ? () => _prepareFiscalBaseFromCompany(
                    sessao: sessao,
                    companyData: companyData,
                    companySettings: companySettings,
                    current: setup,
                  )
                : null,
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Preparar pelo CNPJ'),
          ),
          OutlinedButton.icon(
            onPressed: canConfigureModule
                ? () => _refreshCompanyProvisioning(
                    successMessage:
                        'Automacao fiscal multiempresa reprocessada com sucesso.',
                  )
                : null,
            icon: const Icon(Icons.settings_suggest_outlined),
            label: const Text('Reprocessar automacao'),
          ),
          if (setup.provider.trim().toLowerCase().contains('focus'))
            OutlinedButton.icon(
              onPressed: canConfigureModule
                  ? () => _syncFocusCompany(sessao: sessao)
                  : null,
              icon: const Icon(Icons.sync_outlined),
              label: const Text('Sincronizar Focus'),
            ),
        ],
      ),
    );
  }

  Widget _buildFiscalDailyLinksCard() {
    final year = DateTime.now().year;
    final links = <Map<String, String>>[
      {
        'label': 'Agenda tributária (Receita)',
        'url': ReceitaOfficialUrls.receitaAgendaTributariaAno(year),
      },
      {
        'label': 'eSocial (acesso)',
        'url': ReceitaOfficialUrls.esocialPortal,
      },
      {
        'label': 'e-CAC (login Receita)',
        'url': ReceitaOfficialUrls.ecacLogin,
      },
      {
        'label': 'FGTS Digital (sistema)',
        'url': ReceitaOfficialUrls.fgtsDigitalSistema,
      },
      {
        'label': 'Integra / Serpro (login)',
        'url': ReceitaOfficialUrls.serproIntegraLogin,
      },
      {
        'label': 'NFS-e — Emissor Nacional',
        'url': ReceitaOfficialUrls.nfseEmissorNacional,
      },
    ];

    return AppWorkspaceCard(
      title: 'Acessos fiscais do contador',
      subtitle:
          'Acesso operacional: agenda da Receita, e-Social, e-CAC, FGTS Digital, login Serpro e Emissor Nacional.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: links.map((entry) {
          final uri = entry['url'];
          return FilledButton.icon(
            onPressed: () => _openUrl(uri),
            icon: const Icon(Icons.link),
            label: Text(entry['label']!),
          );
        }).toList(),
      ),
    );
  }

}

