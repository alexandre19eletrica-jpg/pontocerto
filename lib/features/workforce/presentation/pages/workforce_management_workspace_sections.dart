part of 'workforce_management_page.dart';

// ignore_for_file: invalid_use_of_protected_member, unused_element

extension _WorkforceManagementWorkspaceSections on _WorkforceManagementPageState {
  Widget _buildInvoicesTab({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
  }) {
    final featureSettings = _workforceFeatureSettings(companySettings);
    final managerPermissions = _workforceManagerPermissions(companySettings);
    final canManageServiceInvoices =
        sessao.role == Role.owner || managerPermissions.allowServiceInvoices;
    if (!featureSettings.enableServiceInvoices) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAreaSelectorCard(),
          const SizedBox(height: 12),
          AppWorkspaceCard(
            title: 'Notas de servico desativadas',
            subtitle:
                'Ative esse recurso no modo operacional quando precisar controlar faturamento/NFS-e interna.',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: sessao.role == Role.owner
                    ? () => _saveWorkforceFeatureSettings(
                        sessao,
                        featureSettings.copyWith(enableServiceInvoices: true),
                      )
                    : null,
                child: const Text('Ativar'),
              ),
            ),
          ),
        ],
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('service_invoices')
          .where('companyId', isEqualTo: sessao.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final invoices = snapshot.data?.docs ?? const [];
        final ordered = [...invoices]
          ..sort(
            (a, b) => _toDate(
              b.data()['issueDate'],
            ).compareTo(_toDate(a.data()['issueDate'])),
          );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAreaSelectorCard(),
            const SizedBox(height: 12),
            const AppWorkspaceCard(
              title: 'Faturamento / NFS-e',
              subtitle:
                  'Controle interno das notas de servico. A emissao fiscal oficial depende do portal da prefeitura ou do ambiente oficial de NFS-e.',
              child: SizedBox.shrink(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: canManageServiceInvoices
                    ? () => _openInvoiceDialog(sessao: sessao)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Nova nota de servico'),
              ),
            ),
            const SizedBox(height: 12),
            if (ordered.isEmpty)
              const AppWorkspaceCard(
                title: 'Sem notas cadastradas',
                subtitle: 'Nenhuma nota de servico cadastrada.',
                child: SizedBox.shrink(),
              )
            else
              for (final doc in ordered)
                _buildWorkforceInvoiceTile(
                  data: doc.data(),
                  canManageServiceInvoices: canManageServiceInvoices,
                  onPreviewPdf: () => _previewInvoicePdf(
                    companyData: companyData,
                    data: doc.data(),
                  ),
                  onEdit: canManageServiceInvoices
                      ? () => _openInvoiceDialog(
                          sessao: sessao,
                          editing: doc,
                        )
                      : null,
                  onOpenPortal: () => _openUrl(
                    doc.data()['officialPortalUrl']?.toString(),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _buildContractsTab({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required List<Employee> employees,
    required Employee? selectedEmployee,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    final featureSettings = _workforceFeatureSettings(companySettings);
    final managerPermissions = _workforceManagerPermissions(companySettings);
    final canManageContracts =
        sessao.role == Role.owner || managerPermissions.allowContracts;
    if (!featureSettings.enableContracts) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAreaSelectorCard(),
          const SizedBox(height: 12),
          AppWorkspaceCard(
            title: 'Contratos desativados',
            subtitle:
                'Empresas menores podem operar sem esse modulo. Ative quando quiser gerar contratos e historico.',
            trailing: OutlinedButton.icon(
              onPressed: () {
                setState(() => _selectedAreaIndex = 0);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Voltar para folha'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: sessao.role == Role.owner
                      ? () => _saveWorkforceFeatureSettings(
                          sessao,
                          featureSettings.copyWith(enableContracts: true),
                        )
                      : null,
                  child: const Text('Ativar contratos'),
                ),
                if (sessao.role != Role.owner) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Somente a empresa pode ativar esse modulo.',
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    final competence = _competenciaController.text.trim();
    final metrics = selectedEmployee == null
        ? null
        : _buildPayrollMetrics(
            employee: selectedEmployee,
            competence: competence,
            workEntries: workEntries,
            tasks: tasks,
          );
    final payment = selectedEmployee == null
        ? null
        : _findPayment(payments, selectedEmployee.id, competence);

    VoidCallback? buildCreateContractAction() {
      if (selectedEmployee == null || !canManageContracts) {
        return null;
      }
      return () => _generatePayrollDocument(
            context,
            sessao: sessao,
            companyData: companyData,
            companySettings: companySettings,
            employee: selectedEmployee,
            payment: payment,
            metrics: metrics,
            type: _PayrollDocumentType.contract,
            competence: competence,
          );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payroll_documents')
          .where('companyId', isEqualTo: sessao.companyId)
          .where('docGroup', isEqualTo: 'contract')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final ordered = [...docs]
          ..sort(
            (a, b) => _toDate(
              b.data()['createdAt'],
            ).compareTo(_toDate(a.data()['createdAt'])),
          );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAreaSelectorCard(),
            const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Cadastro trabalhista',
              subtitle:
                  'Cadastre o colaborador por aqui e, se quiser, anexe documentos de registro do PC ou do celular.',
              trailing: ElevatedButton.icon(
                onPressed: canManageContracts
                    ? () => _openEmployeeRegistrationDialog()
                    : null,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Cadastrar funcionario'),
              ),
              child: const Text(
                'A tela Funcionarios agora fica focada em leitura. A entrada operacional da equipe passa por este modulo.',
              ),
            ),
            const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Pasta de funcionarios cadastrados',
              subtitle:
                  'Revise salario, tipo de remuneracao, status e edite o cadastro trabalhista por aqui.',
              child: employees.isEmpty
                  ? const Text('Nenhum funcionario cadastrado ainda.')
                  : AppHorizontalCardGrid(
                      minItemWidth: 280,
                      maxColumns: 3,
                      children: [
                        for (final employee in employees)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: employee.id == _employeeId
                                    ? AppBrandColors.accent
                                    : AppBrandColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            employee.nomeCompleto,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppBrandColors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            employee.cargo?.trim().isNotEmpty == true
                                                ? employee.cargo!
                                                : 'Cargo nao informado',
                                            style: const TextStyle(
                                              color: AppBrandColors.softText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: employee.ativo
                                            ? const Color(0xFFE8F7EF)
                                            : const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        employee.ativo ? 'Ativo' : 'Inativo',
                                        style: TextStyle(
                                          color: employee.ativo
                                              ? const Color(0xFF047857)
                                              : const Color(0xFFBE123C),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _compensationLabel(employee),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppBrandColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tipo: ${_compensationTypeLabel(employee.compensationType)}',
                                ),
                                Text(
                                  'Documento: ${employee.documento.isNotEmpty ? employee.documento : '-'}',
                                ),
                                Text(
                                  'Email: ${employee.email?.trim().isNotEmpty == true ? employee.email! : '-'}',
                                ),
                                Text(
                                  'Admissao: ${_formatDate(employee.admissionDate)}',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() => _employeeId = employee.id);
                                      },
                                      icon: const Icon(Icons.folder_open_outlined),
                                      label: const Text('Selecionar'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: canManageContracts
                                          ? () => _openEmployeeRegistrationDialog(
                                                editingEmployee: employee,
                                              )
                                          : null,
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Editar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            if (selectedEmployee != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('employee_registration_documents')
                    .where('companyId', isEqualTo: sessao.companyId)
                    .where('employeeId', isEqualTo: selectedEmployee.id)
                    .snapshots(),
                builder: (context, docsSnapshot) {
                  final docs = docsSnapshot.data?.docs ?? const [];
                  final ordered = [...docs]
                    ..sort(
                      (a, b) => _toDate(
                        b.data()['createdAt'],
                      ).compareTo(_toDate(a.data()['createdAt'])),
                    );
                  final availableCategories = ordered
                      .map(
                        (doc) => doc.data()['category']?.toString().trim() ?? '',
                      )
                      .where((item) => item.isNotEmpty)
                      .toSet();
                  final missingCategories = _employeeRegistrationDocumentOptions
                      .where(
                        (item) => !availableCategories.contains(item.category),
                      )
                      .toList();
                  final missingCoreData = <String>[
                    if (selectedEmployee.documento.trim().isEmpty)
                      'documento principal',
                    if (selectedEmployee.admissionDate == null)
                      'data de admissao',
                    if (selectedEmployee.cargo?.trim().isEmpty ?? true)
                      'cargo',
                    if (selectedEmployee.endereco?.trim().isEmpty ?? true)
                      'endereco',
                    if (selectedEmployee.telefone?.trim().isEmpty ?? true)
                      'telefone',
                  ];
                  final dossierStatus =
                      missingCategories.isEmpty && missingCoreData.isEmpty;
                  final missingSummary = [
                    ...missingCoreData,
                    ...missingCategories.map((item) => item.label),
                  ];
                  return Column(
                    children: [
                      AppWorkspaceCard(
                        title: 'Dossie trabalhista do colaborador',
                        subtitle:
                            'Leitura do que ja existe no cadastro e do que ainda falta para um registro mais completo deste funcionario na empresa ativa.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                AppMetricCard(
                                  label: 'Status',
                                  value: dossierStatus
                                      ? 'Completo'
                                      : 'Pendente',
                                  caption:
                                      dossierStatus
                                          ? 'Campos base e documentos principais presentes'
                                          : 'Ainda faltam itens do registro',
                                ),
                                AppMetricCard(
                                  label: 'Documentos enviados',
                                  value: ordered.length.toString(),
                                  caption: 'Arquivos na pasta do colaborador',
                                ),
                                AppMetricCard(
                                  label: 'Obrigatorios faltando',
                                  value: missingCategories.length.toString(),
                                  caption:
                                      'RG/CPF, CTPS, residencia e dados bancarios',
                                ),
                              ],
                            ),
                            if (missingSummary.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Pendencias atuais: ${missingSummary.join(', ')}.',
                                style: const TextStyle(
                                  color: AppBrandColors.softText,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppWorkspaceCard(
                        title: 'Documentos do registro',
                        subtitle:
                            'Arquivos opcionais ligados ao cadastro trabalhista do colaborador selecionado.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ordered.isEmpty)
                              const Text('Nenhum documento enviado ainda.')
                            else
                              for (final doc in ordered.take(12))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.attach_file_outlined,
                                  ),
                                  title: Text(
                                    doc.data()['label']?.toString() ??
                                        'Documento do colaborador',
                                  ),
                                  subtitle: Text(
                                    doc.data()['fileName']?.toString() ??
                                        'arquivo sem nome',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _openUrl(
                                      doc.data()['downloadUrl']?.toString(),
                                    ),
                                    icon: const Icon(
                                      Icons.open_in_new_outlined,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (selectedEmployee != null) const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Contratos com funcionarios',
              subtitle:
                  'Modelo simples para formalizacao e arquivo interno da equipe.',
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedAreaIndex = 0);
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Voltar para folha'),
                  ),
                  ElevatedButton.icon(
                    onPressed: buildCreateContractAction(),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Criar contrato'),
                  ),
                ],
              ),
              child: const SizedBox.shrink(),
            ),
            if (employees.isEmpty)
              const AppWorkspaceCard(
                title: 'Equipe necessaria',
                subtitle: 'Cadastre funcionarios ativos para gerar contratos.',
                child: SizedBox.shrink(),
              )
            else ...[
              AppWorkspaceCard(
                title: 'Geracao de contrato',
                subtitle:
                    'Selecione o colaborador e gere um contrato simples para arquivo interno.',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _employeeId,
                      decoration: const InputDecoration(
                        labelText: 'Funcionario',
                      ),
                      items: [
                        for (final employee in employees)
                          DropdownMenuItem(
                            value: employee.id,
                            child: Text(employee.nomeCompleto),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _employeeId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: buildCreateContractAction(),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Gerar contrato simples'),
                      ),
                    ),
                  ],
                ),
              ),
              AppWorkspaceCard(
                title: 'Clausulas da empresa',
                subtitle: ((companySettings['employeeClausesFullText'] ??
                                    companySettings['clausesFullText'])
                                ?.toString()
                                .trim()
                                .isNotEmpty ??
                            false)
                    ? 'Clausulas completas cadastradas e incorporadas como anexo textual.'
                    : 'Nenhuma clausula completa cadastrada. O contrato usara clausulas padrao do app.',
                child: const SizedBox.shrink(),
              ),
              AppWorkspaceCard(
                title: 'Historico de contratos',
                subtitle: 'Ultimos contratos gerados pela empresa.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ordered.isEmpty)
                      const Text('Nenhum contrato gerado ainda.')
                    else
                      for (final doc in ordered.take(12))
                        _buildGeneratedDocumentTile(
                          doc.data(),
                          icon: Icons.article_outlined,
                          fallbackTitle: 'Contrato',
                          primaryLabel: doc.data()['employeeName']?.toString(),
                        ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
}
}
