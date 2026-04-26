part of 'workforce_management_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _WorkforceManagementPayrollSections on _WorkforceManagementPageState {
  Widget _buildAreaSelectorCard() {
    return AppWorkspaceCard(
      title: 'Area de trabalho',
      subtitle: 'Escolha a parte que deseja usar agora.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Folha da equipe'),
            selected: _selectedAreaIndex == 0,
            onSelected: (_) {
              setState(() => _selectedAreaIndex = 0);
            },
          ),
          ChoiceChip(
            label: const Text('Contratos de trabalho'),
            selected: _selectedAreaIndex == 1,
            onSelected: (_) {
              setState(() => _selectedAreaIndex = 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollTab({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required List<Employee> employees,
    required Employee? selectedEmployee,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    final competence = _competenciaController.text.trim();
    final featureSettings = _workforceFeatureSettings(companySettings);
    final managerPermissions = _workforceManagerPermissions(companySettings);
    final financePermissions = _financeManagerPermissions(companySettings);
    final isOwner = sessao.role == Role.owner;
    final canConfigureModule = isOwner;
    final canManageClosures =
        isOwner || managerPermissions.allowPayrollClosures;
    final canManagePayrollDocuments =
        isOwner || managerPermissions.allowPayrollDocuments;
    final canCreatePayments = isOwner || financePermissions.allowCreatePayments;
    final payrollClosed = _isPayrollClosed(companySettings, competence);
    final payrollSummary = _buildPayrollSummary(
      employees: employees,
      competence: competence,
      payments: payments,
      workEntries: workEntries,
      tasks: tasks,
    );
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
    final requireClosureDoubleCheck = featureSettings.requireClosureDoubleCheck;
    final requireOwnerApproval = featureSettings.requireOwnerApprovalForClosure;
    final divergentEmployees = payrollSummary.lines
        .where((line) => line.hasDivergence)
        .length;
    final pendingEmployees = payrollSummary.lines
        .where((line) => !line.hasRegisteredPayment)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAreaSelectorCard(),
        const SizedBox(height: 12),
        _buildPayrollTopMetrics(
          competence: competence,
          payrollSummary: payrollSummary,
          pendingEmployees: pendingEmployees,
          divergentEmployees: divergentEmployees,
        ),
        const SizedBox(height: 12),
        AppWorkspaceCard(
          title: 'Modo de uso',
          subtitle:
              'Escolha se a tela fica mais simples ou mais completa.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Simples'),
                    selected: featureSettings.mode == _WorkforceMode.simple,
                    onSelected: canConfigureModule
                        ? (_) => _saveWorkforceFeatureSettings(
                            sessao,
                            featureSettings.simplePreset(),
                          )
                        : null,
                  ),
                  ChoiceChip(
                    label: const Text('Completo'),
                    selected: featureSettings.mode == _WorkforceMode.advanced,
                    onSelected: canConfigureModule
                        ? (_) => _saveWorkforceFeatureSettings(
                            sessao,
                            featureSettings.advancedPreset(),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                    _featureToggle(
                      label: 'Fechamento mensal',
                      value: featureSettings.enablePayrollClosures,
                      onChanged: canConfigureModule
                          ? (value) => _saveWorkforceFeatureSettings(
                              sessao,
                              featureSettings.copyWith(
                                enablePayrollClosures: value,
                              ),
                            )
                          : (_) {},
                    ),
                    _featureToggle(
                      label: 'Painel RH mensal',
                      value: featureSettings.enableMonthlyDashboard,
                      onChanged: canConfigureModule
                          ? (value) => _saveWorkforceFeatureSettings(
                              sessao,
                              featureSettings.copyWith(
                                enableMonthlyDashboard: value,
                              ),
                            )
                          : (_) {},
                    ),
                    _featureToggle(
                      label: 'Documentos avancados',
                      value: featureSettings.enableAdvancedDocuments,
                      onChanged: canConfigureModule
                          ? (value) => _saveWorkforceFeatureSettings(
                              sessao,
                              featureSettings.copyWith(
                                enableAdvancedDocuments: value,
                              ),
                            )
                          : (_) {},
                    ),
                    _featureToggle(
                      label: 'Contratos',
                      value: featureSettings.enableContracts,
                      onChanged: canConfigureModule
                          ? (value) => _saveWorkforceFeatureSettings(
                              sessao,
                              featureSettings.copyWith(enableContracts: value),
                            )
                          : (_) {},
                    ),
                    _featureToggle(
                      label: 'Confirmacao reforcada',
                      value: featureSettings.requireClosureDoubleCheck,
                      onChanged: canConfigureModule
                          ? (value) => _saveWorkforceFeatureSettings(
                              sessao,
                              featureSettings.copyWith(
                                requireClosureDoubleCheck: value,
                              ),
                            )
                          : (_) {},
                    ),
                    _featureToggle(
                      label: 'Aprovacao do dono',
                      value: featureSettings.requireOwnerApprovalForClosure,
                      onChanged: canConfigureModule
                          ? (value) => _saveWorkforceFeatureSettings(
                              sessao,
                              featureSettings.copyWith(
                                requireOwnerApprovalForClosure: value,
                              ),
                            )
                          : (_) {},
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (!canConfigureModule)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _openWorkforceSettingsRequestDialog(
                      sessao,
                      featureSettings,
                      managerPermissions,
                    ),
                    icon: const Icon(Icons.lock_clock_outlined),
                    label: const Text('Solicitar ajuste sensivel'),
                  ),
                ),
              if (!canConfigureModule) const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              const Text(
                'Permissoes do gerente',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _featureToggle(
                    label: 'Fechamento mensal',
                    value: managerPermissions.allowPayrollClosures,
                    onChanged: canConfigureModule
                        ? (value) => _saveWorkforceManagerPermissions(
                            sessao,
                            managerPermissions.copyWith(
                              allowPayrollClosures: value,
                            ),
                          )
                        : (_) {},
                  ),
                  _featureToggle(
                    label: 'Documentos da folha',
                    value: managerPermissions.allowPayrollDocuments,
                    onChanged: canConfigureModule
                        ? (value) => _saveWorkforceManagerPermissions(
                            sessao,
                            managerPermissions.copyWith(
                              allowPayrollDocuments: value,
                            ),
                          )
                        : (_) {},
                  ),
                  _featureToggle(
                    label: 'Contratos',
                    value: managerPermissions.allowContracts,
                    onChanged: canConfigureModule
                        ? (value) => _saveWorkforceManagerPermissions(
                            sessao,
                            managerPermissions.copyWith(
                              allowContracts: value,
                            ),
                          )
                        : (_) {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const AppWorkspaceCard(
          title: 'Folha e documentos',
          subtitle:
              'Cadastre remuneracao do funcionario, lance pagamentos e gere recibo, holerite e comprovante de renda.',
          child: SizedBox.shrink(),
        ),
        AppWorkspaceCard(
          title: 'Fechamento da competencia',
          subtitle:
              'Fechamento mensal trava novos lancamentos de pagamento nessa competencia.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    payrollClosed
                        ? Icons.lock_clock_outlined
                        : Icons.lock_open_outlined,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      payrollClosed
                          ? 'Competencia fechada: $competence'
                          : 'Competencia aberta: $competence',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPayrollClosureActions(
                sessao: sessao,
                companyData: companyData,
                companySettings: companySettings,
                competence: competence,
                employees: employees,
                payments: payments,
                workEntries: workEntries,
                tasks: tasks,
                payrollSummary: payrollSummary,
                featureSettings: featureSettings,
                canManageClosures: canManageClosures,
                canManagePayrollDocuments: canManagePayrollDocuments,
                canCreatePayments: canCreatePayments,
                payrollClosed: payrollClosed,
                requireClosureDoubleCheck: requireClosureDoubleCheck,
                requireOwnerApproval: requireOwnerApproval,
              ),
            ],
          ),
        ),
        if (featureSettings.enablePayrollClosures)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('period_closes')
                .where('companyId', isEqualTo: sessao.companyId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final pendingPayroll = docs
                  .where(
                    (doc) =>
                        doc.data()['module']?.toString() == 'workforce' &&
                        doc.data()['competence']?.toString() == competence &&
                        doc.data()['status']?.toString() == 'PENDING_APPROVAL',
                  )
                  .toList();
              final pendingCleanup = docs
                  .where(
                    (doc) =>
                        doc.data()['module']?.toString() == 'finance_cleanup' &&
                        doc.data()['status']?.toString() == 'PENDING_APPROVAL',
                  )
                  .toList();
              final pendingSettings = docs
                  .where(
                    (doc) =>
                        (doc.data()['module']?.toString() ==
                                'finance_settings_change' ||
                            doc.data()['module']?.toString() ==
                                'workforce_settings_change') &&
                        doc.data()['status']?.toString() == 'PENDING_APPROVAL',
                  )
                  .toList();
              final recentResolved =
                  docs
                      .where(
                        (doc) =>
                            doc.data()['status']?.toString() == 'APPROVED' ||
                            doc.data()['status']?.toString() == 'REJECTED',
                      )
                      .where((doc) {
                        if (_approvalHistoryFilter == 'Todos') return true;
                        if (_approvalHistoryFilter == 'Folha') {
                          return doc.data()['module']?.toString() ==
                              'workforce';
                        }
                        if (_approvalHistoryFilter == 'Limpeza') {
                          return doc.data()['module']?.toString() ==
                              'finance_cleanup';
                        }
                        return doc.data()['module']?.toString() ==
                                'finance_settings_change' ||
                            doc.data()['module']?.toString() ==
                                'workforce_settings_change';
                      })
                      .toList()
                    ..sort(
                      (a, b) => _toDate(
                        b.data()['resolvedAt'],
                      ).compareTo(_toDate(a.data()['resolvedAt'])),
                    );
              if (pendingPayroll.isEmpty &&
                  pendingSettings.isEmpty &&
                  pendingCleanup.isEmpty &&
                  recentResolved.isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildApprovalsCard(
                sessao: sessao,
                competence: competence,
                isOwner: isOwner,
                pendingPayroll: pendingPayroll,
                pendingSettings: pendingSettings,
                pendingCleanup: pendingCleanup,
                recentResolved: recentResolved,
              );
            },
          ),
        if (featureSettings.enablePayrollClosures &&
            _closureHistory(companySettings, competence).isNotEmpty)
          _buildCompetenceClosureHistoryCard(
            companySettings: companySettings,
            competence: competence,
          ),
        if (featureSettings.enablePayrollClosures)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payroll_closures')
                .doc('${sessao.companyId}_$competence')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              if (data == null) {
                return const SizedBox.shrink();
              }
              final linesRaw = data['lines'];
              final lineMaps = <Map<String, dynamic>>[
                if (linesRaw is List)
                  for (final item in linesRaw)
                    if (item is Map)
                      item.map((key, value) => MapEntry(key.toString(), value)),
              ];
              return _buildPayrollSnapshotCard(
                data: data,
                lineMaps: lineMaps,
              );
            },
          ),
        if (featureSettings.enablePayrollClosures)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payroll_closures')
                .where('companyId', isEqualTo: sessao.companyId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final ordered = [...docs]
                ..sort(
                  (a, b) => (b.data()['competence']?.toString() ?? '')
                      .compareTo(a.data()['competence']?.toString() ?? ''),
                );
              return _buildPayrollClosuresArchiveCard(
                sessao: sessao,
                companyData: companyData,
                ordered: ordered,
              );
            },
          ),
        if (employees.isNotEmpty && featureSettings.enableMonthlyDashboard)
          _buildPayrollSummaryCard(payrollSummary),
        if (employees.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildMonthlyDashboardPanel(
            employees: employees,
            selectedCompetence: competence,
            payments: payments,
            workEntries: workEntries,
            tasks: tasks,
          ),
        ],
        if (employees.isEmpty)
          const AppWorkspaceCard(
            title: 'Equipe necessaria',
            subtitle: 'Cadastre funcionarios ativos para usar este modulo.',
            child: SizedBox.shrink(),
          )
        else ...[
          AppDesktopSplit(
            breakpoint: 980,
            sidebar: Column(
              children: [
                _buildCompetenceEmployeeSelectorCard(employees),
                if (selectedEmployee != null) ...[
                  const SizedBox(height: 12),
                  _buildSelectedEmployeeCard(selectedEmployee),
                  if (metrics != null) ...[
                    const SizedBox(height: 12),
                    _buildAutomaticPayrollBaseCard(metrics),
                  ],
                ],
              ],
            ),
            content: AppWorkspaceCard(
              title: 'Acoes da competencia',
              subtitle:
                  'Use esta area para lancar pagamentos e emitir documentos do colaborador selecionado.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompetenceActionButtons(
                    context: context,
                    sessao: sessao,
                    companyData: companyData,
                    companySettings: companySettings,
                    employees: employees,
                    selectedEmployee: selectedEmployee,
                    payments: payments,
                    payment: payment,
                    metrics: metrics,
                    competence: competence,
                    workEntries: workEntries,
                    tasks: tasks,
                    canCreatePayments: canCreatePayments,
                    canManagePayrollDocuments: canManagePayrollDocuments,
                    payrollClosed: payrollClosed,
                    enablePayrollClosures:
                        featureSettings.enablePayrollClosures,
                    enableAdvancedDocuments:
                        featureSettings.enableAdvancedDocuments,
                  ),
                ],
              ),
            ),
          ),
            if (!featureSettings.enableAdvancedDocuments)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Modo simples ativo: mantenha recibo e holerite; ligue documentos avancados se quiser comprovante de renda e fechamento operacional mais completo.',
                ),
              ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('fiscal_competence_checks')
                  .doc('${sessao.companyId}_$competence')
                  .snapshots(),
              builder: (context, snapshot) {
                final checkData = snapshot.data?.data() ?? <String, dynamic>{};
                final operationalChecks = _WorkforceOperationalChecks.fromMap(
                  checkData,
                );
                final thirteenthEligible = _isEligibleForThirteenth(
                  selectedEmployee,
                  competence,
                );
                final vacationAttention = _isVacationAttention(selectedEmployee);
                final thirteenthReviewed = selectedEmployee != null &&
                    operationalChecks.thirteenthReviewedEmployeeIds.contains(
                      selectedEmployee.id,
                    );
                final vacationReviewed = selectedEmployee != null &&
                    operationalChecks.vacationReviewedEmployeeIds.contains(
                      selectedEmployee.id,
                    );
                return AppWorkspaceCard(
                  title: 'Operacoes complementares',
                  subtitle:
                      'Conferencias manuais de 13o, ferias e outros pontos sensiveis da competencia.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOperationalStatusChips(
                        thirteenthEligible: thirteenthEligible,
                        thirteenthReviewed: thirteenthReviewed,
                        vacationAttention: vacationAttention,
                        vacationReviewed: vacationReviewed,
                      ),
                      const SizedBox(height: 8),
                      _buildOperationalReviewButtons(
                        sessao: sessao,
                        competence: competence,
                        checks: operationalChecks,
                        selectedEmployee: selectedEmployee,
                        thirteenthReviewed: thirteenthReviewed,
                        vacationReviewed: vacationReviewed,
                      ),
                      const SizedBox(height: 8),
                      _buildOperationalDocumentButtons(
                        context: context,
                        sessao: sessao,
                        companyData: companyData,
                        companySettings: companySettings,
                        selectedEmployee: selectedEmployee,
                        payment: payment,
                        metrics: metrics,
                        competence: competence,
                        canManagePayrollDocuments: canManagePayrollDocuments,
                        thirteenthEligible: thirteenthEligible,
                      ),
                      if (operationalChecks.terminationNotes.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Observacoes de rescisao da competencia: ${operationalChecks.terminationNotes}',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('payroll_documents')
                  .where('companyId', isEqualTo: sessao.companyId)
                  .where('employeeId', isEqualTo: selectedEmployee?.id ?? '')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                final ordered = [...docs]
                  ..sort(
                    (a, b) => _toDate(
                      b.data()['createdAt'],
                    ).compareTo(_toDate(a.data()['createdAt'])),
                  );
                return AppWorkspaceCard(
                  title: 'Historico de documentos',
                  subtitle:
                      'Ultimos documentos gerados para o colaborador selecionado.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ordered.isEmpty)
                        const Text('Nenhum documento gerado ainda.')
                      else
                        for (final doc in ordered.take(10))
                          _buildGeneratedDocumentTile(
                            doc.data(),
                            icon: Icons.description_outlined,
                          ),
                    ],
                  ),
                );
              },
            ),
          ],
      ],
    );
  }

  Widget _buildPayrollTopMetrics({
    required String competence,
    required _PayrollSummary payrollSummary,
    required int pendingEmployees,
    required int divergentEmployees,
  }) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        AppMetricCard(label: 'Competencia', value: competence),
        AppMetricCard(
          label: 'Ativos',
          value: payrollSummary.totalEmployees.toString(),
        ),
        AppMetricCard(
          label: 'Sem lancamento',
          value: pendingEmployees.toString(),
        ),
        AppMetricCard(
          label: 'Divergencias',
          value: divergentEmployees.toString(),
        ),
        AppMetricCard(
          label: 'Base sugerida',
          value: _formatCurrency(payrollSummary.suggestedGrossCents),
        ),
        AppMetricCard(
          label: 'Base lancada',
          value: _formatCurrency(payrollSummary.registeredGrossCents),
        ),
      ],
    );
  }

  Widget _buildPayrollClosureActions({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required String competence,
    required List<Employee> employees,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
    required _PayrollSummary payrollSummary,
    required _WorkforceFeatureSettings featureSettings,
    required bool canManageClosures,
    required bool canManagePayrollDocuments,
    required bool canCreatePayments,
    required bool payrollClosed,
    required bool requireClosureDoubleCheck,
    required bool requireOwnerApproval,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: featureSettings.enablePayrollClosures && canManageClosures
              ? () => _togglePayrollClose(
                  sessao: sessao,
                  competence: competence,
                  close: !payrollClosed,
                  summary: payrollSummary,
                  requireDoubleCheck: requireClosureDoubleCheck,
                  requireOwnerApproval: requireOwnerApproval,
                )
              : null,
          child: Text(
            featureSettings.enablePayrollClosures
                ? (canManageClosures
                      ? (payrollClosed ? 'Reabrir' : 'Fechar')
                      : 'Sem permissao')
                : 'Fechamento desligado',
          ),
        ),
        ElevatedButton(
          onPressed: employees.isEmpty || !canManagePayrollDocuments
              ? null
              : () => _exportBatchPayslips(
                  sessao: sessao,
                  companyData: companyData,
                  companySettings: companySettings,
                  competence: competence,
                  employees: employees,
                  payments: payments,
                  workEntries: workEntries,
                  tasks: tasks,
                ),
          child: const Text('Exportar holerites'),
        ),
        ElevatedButton(
          onPressed: employees.isEmpty || !canManagePayrollDocuments
              ? null
              : () => _exportPayrollSummaryPdf(
                  sessao: sessao,
                  companyData: companyData,
                  competence: competence,
                  summary: payrollSummary,
                ),
          child: const Text('Resumo PDF'),
        ),
        ElevatedButton(
          onPressed: featureSettings.enablePayrollClosures && canManageClosures
              ? () => _exportPayrollClosurePdf(
                  sessao: sessao,
                  companyData: companyData,
                  competence: competence,
                )
              : null,
          child: const Text('Fechamento PDF'),
        ),
        ElevatedButton(
          onPressed: employees.isEmpty ||
                  !canCreatePayments ||
                  (featureSettings.enablePayrollClosures && payrollClosed)
              ? null
              : () => _generateMissingPayments(
                  competence: competence,
                  employees: employees,
                  payments: payments,
                  workEntries: workEntries,
                  tasks: tasks,
                ),
          child: const Text('Gerar faltantes'),
        ),
      ],
    );
  }

  Widget _buildPayrollSummaryChips(_PayrollSummary payrollSummary) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _summaryChip('Funcionarios', payrollSummary.totalEmployees.toString()),
        _summaryChip(
          'Pagamentos lancados',
          payrollSummary.registeredPayments.toString(),
        ),
        _summaryChip(
          'Base sugerida',
          _formatCurrency(payrollSummary.suggestedGrossCents),
        ),
        _summaryChip(
          'Total lancado',
          _formatCurrency(payrollSummary.registeredGrossCents),
        ),
        _summaryChip('Dias aprovados', payrollSummary.approvedDays.toString()),
        _summaryChip(
          'Servicos finalizados',
          payrollSummary.finishedServices.toString(),
        ),
      ],
    );
  }

  Widget _buildPayrollLinesPanel(_PayrollSummary payrollSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Conferencia por funcionario',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            FilterChip(
              selected: _showOnlyPendingPayroll,
              label: const Text('So pendencias'),
              onSelected: (value) {
                setState(() => _showOnlyPendingPayroll = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_filteredPayrollLines(payrollSummary.lines).isEmpty)
          const Text('Nenhum dado encontrado para esta competencia.')
        else
          for (final line in _filteredPayrollLines(payrollSummary.lines))
            _buildPayrollLineTile(line),
      ],
    );
  }

  Widget _buildPayrollLineTile(_PayrollSummaryLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: line.hasDivergence
            ? const Color(0xFFFFF4E8)
            : line.hasRegisteredPayment
            ? const Color(0xFFF2FAF4)
            : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: line.hasDivergence
              ? const Color(0xFFFFC68A)
              : line.hasRegisteredPayment
              ? const Color(0xFFCDE8D3)
              : const Color(0xFFDCE5F2),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          line.hasDivergence
              ? Icons.warning_amber_rounded
              : line.hasRegisteredPayment
              ? Icons.verified_outlined
              : Icons.pending_outlined,
          color: line.hasDivergence ? const Color(0xFFB45F06) : null,
        ),
        title: Text(line.employeeName),
        subtitle: Text(
          'Sugerido: ${_formatCurrency(line.suggestedGrossCents)} | '
          'Lancado: ${_formatCurrency(line.registeredGrossCents)}\n'
          'Dias: ${line.approvedDays} | Horas: ${line.approvedHours} | '
          'Servicos: ${line.finishedServices}',
        ),
        trailing: Text(
          line.hasDivergence
              ? 'Divergente'
              : line.hasRegisteredPayment
              ? 'OK'
              : 'Pendente',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: line.hasDivergence
                ? const Color(0xFFB45F06)
                : line.hasRegisteredPayment
                ? const Color(0xFF2E7D32)
                : const Color(0xFF7A869A),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  List<Widget> _buildMonthlyDashboardCards({
    required List<Employee> employees,
    required String selectedCompetence,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    return _buildMonthlyPayrollDashboard(
      employees: employees,
      selectedCompetence: selectedCompetence,
      payments: payments,
      workEntries: workEntries,
      tasks: tasks,
    ).map(_buildMonthlyDashboardCard).toList();
  }

  Widget _buildMonthlyDashboardCard(_PayrollMonthDashboardLine monthLine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: monthLine.isSelected
            ? const Color(0xFFE8F1FF)
            : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: monthLine.isSelected
              ? const Color(0xFF90B7F8)
              : const Color(0xFFDCE5F2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLine.competence,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (monthLine.isSelected) const Chip(label: Text('Atual')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Base sugerida: ${_formatCurrency(monthLine.summary.suggestedGrossCents)} | '
            'Lancado: ${_formatCurrency(monthLine.summary.registeredGrossCents)}',
          ),
          Text(
            'Pagamentos: ${monthLine.summary.registeredPayments}/${monthLine.summary.totalEmployees} | '
            'Dias: ${monthLine.summary.approvedDays} | '
            'Servicos: ${monthLine.summary.finishedServices}',
          ),
          Text(
            'Pendencias: ${monthLine.pendingEmployees} | '
            'Divergencias: ${monthLine.divergentEmployees}',
            style: TextStyle(
              color: monthLine.pendingEmployees > 0 ||
                      monthLine.divergentEmployees > 0
                  ? const Color(0xFFB45F06)
                  : const Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalTile({
    required String title,
    required String subtitle,
    required bool isOwner,
    required String rejectLabel,
    required String approveLabel,
    required VoidCallback onReject,
    required VoidCallback onApprove,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: true,
      trailing: isOwner
          ? Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: Text(rejectLabel),
                ),
                ElevatedButton(
                  onPressed: onApprove,
                  child: Text(approveLabel),
                ),
              ],
            )
          : const Text('Aguardando dono'),
    );
  }

  Widget _buildResolvedApprovalTile(Map<String, dynamic> data) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        data['status']?.toString() == 'APPROVED'
            ? Icons.verified_outlined
            : Icons.cancel_outlined,
      ),
      title: Text(_periodCloseTitle(data)),
      subtitle: Text(
        'Status: ${data['status'] == 'APPROVED' ? 'Aprovado' : 'Rejeitado'} | '
        'Solicitado por ${data['requestedByUserName'] ?? '-'}\n'
        'Resolvido por ${data['resolvedByUserName'] ?? '-'} em '
        '${_formatDateTime(_toDate(data['resolvedAt']))}\n'
        'Comentario: ${data['resolutionComment'] ?? '-'}',
      ),
      isThreeLine: true,
    );
  }

  Widget _buildPayrollSnapshotChips(Map<String, dynamic> data) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _summaryChip(
          'Base snapshot',
          _formatCurrency((data['suggestedGrossCents'] as num?)?.toInt() ?? 0),
        ),
        _summaryChip(
          'Lancado snapshot',
          _formatCurrency((data['registeredGrossCents'] as num?)?.toInt() ?? 0),
        ),
        _summaryChip(
          'Pagamentos',
          ((data['registeredPayments'] as num?)?.toInt() ?? 0).toString(),
        ),
        _summaryChip(
          'Pendencias',
          ((data['pendingEmployees'] as num?)?.toInt() ?? 0).toString(),
        ),
        _summaryChip(
          'Divergencias',
          ((data['divergentEmployees'] as num?)?.toInt() ?? 0).toString(),
        ),
      ],
    );
  }

  Widget _buildPayrollClosureHistoryTile({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> data,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        data['status'] == 'closed'
            ? Icons.lock_outline
            : Icons.lock_open_outlined,
      ),
      title: Text('Competencia ${data['competence'] ?? '-'}'),
      subtitle: Text(
        'Status: ${data['status'] == 'closed' ? 'Fechada' : 'Reaberta'} | '
        'Lancado: ${_formatCurrency((data['registeredGrossCents'] as num?)?.toInt() ?? 0)}\n'
        'Pendencias: ${(data['pendingEmployees'] as num?)?.toInt() ?? 0} | '
        'Divergencias: ${(data['divergentEmployees'] as num?)?.toInt() ?? 0}',
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () {
              final rawCompetence = data['competence']?.toString();
              if (rawCompetence == null || rawCompetence.isEmpty) {
                return;
              }
              setState(() => _competenciaController.text = rawCompetence);
            },
            child: const Text('Abrir'),
          ),
          TextButton(
            onPressed: () => _exportPayrollClosurePdf(
              sessao: sessao,
              companyData: companyData,
              competence: data['competence']?.toString() ?? '',
            ),
            child: const Text('PDF'),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  Widget _buildPayrollSnapshotLineTile(Map<String, dynamic> line) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(line['employeeName']?.toString() ?? '-'),
      subtitle: Text(
        'Sugerido: ${_formatCurrency((line['suggestedGrossCents'] as num?)?.toInt() ?? 0)} | '
        'Lancado: ${_formatCurrency((line['registeredGrossCents'] as num?)?.toInt() ?? 0)}\n'
        'Dias: ${(line['approvedDays'] as num?)?.toInt() ?? 0} | '
        'Horas: ${(line['approvedHours'] as num?)?.toInt() ?? 0} | '
        'Servicos: ${(line['finishedServices'] as num?)?.toInt() ?? 0}',
      ),
      isThreeLine: true,
    );
  }

  Widget _buildApprovalsCard({
    required Session sessao,
    required String competence,
    required bool isOwner,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingPayroll,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingSettings,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingCleanup,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> recentResolved,
  }) {
    return AppWorkspaceCard(
      title: 'Aprovacoes pendentes',
      subtitle:
          'Fechamentos, limpezas e ajustes sensiveis aguardando decisao da empresa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final doc in pendingPayroll)
            _buildPendingApprovalTile(
              title: 'Competencia ${doc.data()['competence'] ?? competence}',
              subtitle:
                  'Solicitado por ${doc.data()['requestedByUserName'] ?? '-'} em '
                  '${_formatDateTime(_toDate(doc.data()['requestedAt']))}\n'
                  'Obs: ${doc.data()['note'] ?? '-'}',
              isOwner: isOwner,
              rejectLabel: 'Rejeitar',
              approveLabel: 'Aprovar',
              onReject: () => _resolveClosureApproval(
                sessao: sessao,
                requestId: doc.id,
                approve: false,
              ),
              onApprove: () => _resolveClosureApproval(
                sessao: sessao,
                requestId: doc.id,
                approve: true,
              ),
            ),
          for (final doc in pendingSettings)
            _buildPendingApprovalTile(
              title: _periodCloseTitle(doc.data()),
              subtitle:
                  'Solicitado por ${doc.data()['requestedByUserName'] ?? '-'} em '
                  '${_formatDateTime(_toDate(doc.data()['requestedAt']))}\n'
                  '${_settingsChangeSummary(doc.data())}\n'
                  'Obs: ${doc.data()['note'] ?? '-'}',
              isOwner: isOwner,
              rejectLabel: 'Rejeitar',
              approveLabel: 'Aprovar',
              onReject: () => _resolveSettingsChangeApproval(
                sessao: sessao,
                requestId: doc.id,
                approve: false,
              ),
              onApprove: () => _resolveSettingsChangeApproval(
                sessao: sessao,
                requestId: doc.id,
                approve: true,
              ),
            ),
          for (final doc in pendingCleanup)
            _buildPendingApprovalTile(
              title: 'Limpeza financeira geral',
              subtitle:
                  'Solicitado por ${doc.data()['requestedByUserName'] ?? '-'} em '
                  '${_formatDateTime(_toDate(doc.data()['requestedAt']))}\n'
                  'Obs: ${doc.data()['note'] ?? '-'}',
              isOwner: isOwner,
              rejectLabel: 'Rejeitar',
              approveLabel: 'Aprovar',
              onReject: () => _resolveCleanupApproval(
                sessao: sessao,
                requestId: doc.id,
                approve: false,
              ),
              onApprove: () => _resolveCleanupApproval(
                sessao: sessao,
                requestId: doc.id,
                approve: true,
              ),
            ),
          if (recentResolved.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            _buildApprovalHistoryHeader(),
            const SizedBox(height: 6),
            for (final doc in recentResolved.take(8))
              _buildResolvedApprovalTile(doc.data()),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovalHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Historico recente de solicitacoes',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DropdownButton<String>(
          value: _approvalHistoryFilter,
          items: const [
            DropdownMenuItem(
              value: 'Todos',
              child: Text('Todos'),
            ),
            DropdownMenuItem(
              value: 'Folha',
              child: Text('Folha'),
            ),
            DropdownMenuItem(
              value: 'Limpeza',
              child: Text('Limpeza'),
            ),
            DropdownMenuItem(
              value: 'Configuracoes',
              child: Text('Configuracoes'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _approvalHistoryFilter = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCompetenceClosureHistoryCard({
    required Map<String, dynamic> companySettings,
    required String competence,
  }) {
    return AppWorkspaceCard(
      title: 'Historico de fechamento',
      subtitle: 'Registro de abertura e fechamento da competencia atual.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in _closureHistory(companySettings, competence))
            _buildCompetenceClosureEventTile(event),
        ],
      ),
    );
  }

  Widget _buildCompetenceClosureEventTile(_PayrollClosureEvent event) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        event.action == 'close'
            ? Icons.lock_outline
            : Icons.lock_open_outlined,
      ),
      title: Text(
        event.action == 'close'
            ? 'Competencia fechada'
            : 'Competencia reaberta',
      ),
      subtitle: Text(
        '${event.userName} | ${_formatDateTime(event.at)}\n'
        'Obs: ${event.note.isEmpty ? '-' : event.note}',
      ),
      isThreeLine: true,
    );
  }

  Widget _buildPayrollSnapshotCard({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> lineMaps,
  }) {
    return AppWorkspaceCard(
      title: 'Snapshot do fechamento',
      subtitle: 'Fotografia salva da competencia para conferencia posterior.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status salvo: ${data['status'] == 'closed' ? 'Fechada' : 'Reaberta'} | '
            'Atualizado em ${_formatDateTime(_toDate(data['updatedAt']))}',
          ),
          Text(
            'Responsavel: ${data['updatedByUserName'] ?? '-'} | '
            'Obs: ${data['lastNote']?.toString().trim().isNotEmpty == true ? data['lastNote'] : '-'}',
          ),
          const SizedBox(height: 10),
          _buildPayrollSnapshotChips(data),
          if (lineMaps.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Conferencia congelada da competencia',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final line in lineMaps.take(8))
              _buildPayrollSnapshotLineTile(line),
          ],
        ],
      ),
    );
  }

  Widget _buildPayrollSummaryCard(_PayrollSummary payrollSummary) {
    return AppWorkspaceCard(
      title: 'Resumo da competencia',
      subtitle: 'Panorama mensal da folha com conferencia rapida por colaborador.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPayrollSummaryChips(payrollSummary),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),
          _buildPayrollLinesPanel(payrollSummary),
        ],
      ),
    );
  }

  Widget _buildMonthlyDashboardPanel({
    required List<Employee> employees,
    required String selectedCompetence,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    return AppWorkspaceCard(
      title: 'Painel RH por mes',
      subtitle:
          'Leitura consolidada das competencias recentes para conferencias e reaberturas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildMonthlyDashboardCards(
            employees: employees,
            selectedCompetence: selectedCompetence,
            payments: payments,
            workEntries: workEntries,
            tasks: tasks,
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollClosuresArchiveCard({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> ordered,
  }) {
    return AppWorkspaceCard(
      title: 'Historico de competencias fechadas',
      subtitle: 'Acesso rapido aos ultimos fechamentos salvos pela empresa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final doc in ordered.take(8))
            _buildPayrollClosureHistoryTile(
              sessao: sessao,
              companyData: companyData,
              data: doc.data(),
            ),
        ],
      ),
    );
  }

  Widget _buildCompetenceEmployeeSelectorCard(List<Employee> employees) {
    return AppWorkspaceCard(
      title: 'Competencia e colaborador',
      subtitle:
          'Escolha o funcionario e a competencia antes de lancar folha ou documentos.',
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
          const SizedBox(height: 8),
          TextField(
            controller: _competenciaController,
            decoration: const InputDecoration(
              labelText: 'Competencia (YYYY-MM)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedEmployeeCard(Employee employee) {
    return AppWorkspaceCard(
      title: employee.nomeCompleto,
      subtitle:
          'Cargo: ${employee.cargo ?? '-'}\n'
          'Remuneracao: ${_compensationLabel(employee)}\n'
          'Admissao: ${_formatDate(employee.admissionDate)}',
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildAutomaticPayrollBaseCard(_PayrollMetrics metrics) {
    return AppWorkspaceCard(
      title: 'Base automatica da competencia',
      subtitle:
          'Dias aprovados: ${metrics.approvedDays} | Horas aprovadas: ${metrics.approvedHours}\n'
          'Servicos finalizados: ${metrics.finishedServices} | Valor de servicos: ${_formatCurrency(metrics.finishedServicesValueCents)}\n'
          'Base sugerida: ${_formatCurrency(metrics.suggestedGrossCents)}',
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildCompetenceActionButtons({
    required BuildContext context,
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required List<Employee> employees,
    required Employee? selectedEmployee,
    required List<Payment> payments,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required String competence,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
    required bool canCreatePayments,
    required bool canManagePayrollDocuments,
    required bool payrollClosed,
    required bool enablePayrollClosures,
    required bool enableAdvancedDocuments,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: selectedEmployee == null ||
                  !canCreatePayments ||
                  (enablePayrollClosures && payrollClosed)
              ? null
              : () => _openPayrollDialog(
                  selectedEmployee,
                  metrics: metrics,
                ),
          icon: const Icon(Icons.add_card_outlined),
          label: const Text('Lancar pagamento'),
        ),
        ElevatedButton.icon(
          onPressed: employees.isEmpty ||
                  !canCreatePayments ||
                  (enablePayrollClosures && payrollClosed)
              ? null
              : () => _openBulkPayrollDialog(
                  employees,
                  companySettings: companySettings,
                  competence: competence,
                  payments: payments,
                  workEntries: workEntries,
                  tasks: tasks,
                ),
          icon: const Icon(Icons.playlist_add_check_circle_outlined),
          label: const Text('Lancar em massa'),
        ),
        OutlinedButton.icon(
          onPressed: canManagePayrollDocuments && selectedEmployee != null
              ? () => _generatePayrollDocument(
                  context,
                  sessao: sessao,
                  companyData: companyData,
                  companySettings: companySettings,
                  employee: selectedEmployee,
                  payment: payment,
                  metrics: metrics,
                  type: _PayrollDocumentType.payslip,
                  competence: competence,
                )
              : null,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Holerite'),
        ),
        OutlinedButton.icon(
          onPressed: canManagePayrollDocuments && selectedEmployee != null
              ? () => _generatePayrollDocument(
                  context,
                  sessao: sessao,
                  companyData: companyData,
                  companySettings: companySettings,
                  employee: selectedEmployee,
                  payment: payment,
                  metrics: metrics,
                  type: _PayrollDocumentType.receipt,
                  competence: competence,
                )
              : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Recibo'),
        ),
        if (enableAdvancedDocuments)
          OutlinedButton.icon(
            onPressed: canManagePayrollDocuments && selectedEmployee != null
                ? () => _generatePayrollDocument(
                    context,
                    sessao: sessao,
                    companyData: companyData,
                    companySettings: companySettings,
                    employee: selectedEmployee,
                    payment: payment,
                    metrics: metrics,
                    type: _PayrollDocumentType.incomeProof,
                    competence: competence,
                  )
                : null,
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Comprovante de renda'),
          ),
      ],
    );
  }

  Widget _buildOperationalStatusChips({
    required bool thirteenthEligible,
    required bool thirteenthReviewed,
    required bool vacationAttention,
    required bool vacationReviewed,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusChip(
          '13 elegivel',
          thirteenthEligible ? 'Sim' : 'Nao',
          highlighted: thirteenthEligible,
        ),
        _statusChip(
          '13 conferido',
          thirteenthReviewed ? 'Sim' : 'Nao',
          highlighted: thirteenthReviewed,
        ),
        _statusChip(
          'Ferias em atencao',
          vacationAttention ? 'Sim' : 'Nao',
          highlighted: vacationAttention,
        ),
        _statusChip(
          'Ferias conferidas',
          vacationReviewed ? 'Sim' : 'Nao',
          highlighted: vacationReviewed,
        ),
      ],
    );
  }

  Widget _buildOperationalReviewButtons({
    required Session sessao,
    required String competence,
    required _WorkforceOperationalChecks checks,
    required Employee? selectedEmployee,
    required bool thirteenthReviewed,
    required bool vacationReviewed,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: selectedEmployee == null
              ? null
              : () => _toggleOperationalEmployeeReview(
                    sessao: sessao,
                    competence: competence,
                    checks: checks,
                    employeeId: selectedEmployee.id,
                    target: _OperationalReviewTarget.thirteenth,
                    reviewed: !thirteenthReviewed,
                  ),
          icon: const Icon(Icons.task_alt_outlined),
          label: Text(
            thirteenthReviewed ? 'Desmarcar 13' : 'Marcar 13 conferido',
          ),
        ),
        OutlinedButton.icon(
          onPressed: selectedEmployee == null
              ? null
              : () => _toggleOperationalEmployeeReview(
                    sessao: sessao,
                    competence: competence,
                    checks: checks,
                    employeeId: selectedEmployee.id,
                    target: _OperationalReviewTarget.vacation,
                    reviewed: !vacationReviewed,
                  ),
          icon: const Icon(Icons.beach_access_outlined),
          label: Text(
            vacationReviewed ? 'Desmarcar ferias' : 'Marcar ferias',
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalDocumentButtons({
    required BuildContext context,
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required Employee? selectedEmployee,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required String competence,
    required bool canManagePayrollDocuments,
    required bool thirteenthEligible,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: selectedEmployee == null ||
                  !canManagePayrollDocuments ||
                  !thirteenthEligible
              ? null
              : () => _generateOperationalDocument(
                    context,
                    sessao: sessao,
                    companyData: companyData,
                    companySettings: companySettings,
                    employee: selectedEmployee,
                    payment: payment,
                    metrics: metrics,
                    type: _PayrollDocumentType.thirteenthReceipt,
                    competence: competence,
                  ),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Recibo 13 salario'),
        ),
        OutlinedButton.icon(
          onPressed: selectedEmployee == null || !canManagePayrollDocuments
              ? null
              : () => _generateOperationalDocument(
                    context,
                    sessao: sessao,
                    companyData: companyData,
                    companySettings: companySettings,
                    employee: selectedEmployee,
                    payment: payment,
                    metrics: metrics,
                    type: _PayrollDocumentType.vacationReceipt,
                    competence: competence,
                  ),
          icon: const Icon(Icons.luggage_outlined),
          label: const Text('Recibo ferias'),
        ),
        OutlinedButton.icon(
          onPressed: selectedEmployee == null || !canManagePayrollDocuments
              ? null
              : () => _generateOperationalDocument(
                    context,
                    sessao: sessao,
                    companyData: companyData,
                    companySettings: companySettings,
                    employee: selectedEmployee,
                    payment: payment,
                    metrics: metrics,
                    type: _PayrollDocumentType.terminationStatement,
                    competence: competence,
                  ),
          icon: const Icon(Icons.assignment_return_outlined),
          label: const Text('Termo rescisao'),
        ),
      ],
    );
  }

  Widget _buildWorkforceToggleTile({
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
    );
  }

  Widget _buildGeneratedDocumentTile(
    Map<String, dynamic> data, {
    required IconData icon,
    String fallbackTitle = 'Documento',
    String? primaryLabel,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(data['title']?.toString() ?? fallbackTitle),
      subtitle: Text(
        '${primaryLabel ?? data['sequenceLabel'] ?? '-'} | ${data['typeLabel'] ?? '-'} | ${_formatDateTime(_toDate(data['createdAt']))}\n'
        'Empresa: ${data['companySignerName'] ?? '-'} | '
        'Colaborador: ${data['employeeSignerName'] ?? '-'}',
      ),
      isThreeLine: true,
    );
  }

  Widget _buildWorkforceInvoiceTile({
    required Map<String, dynamic> data,
    required bool canManageServiceInvoices,
    required VoidCallback onPreviewPdf,
    required VoidCallback onOpenPortal,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        title: Text(data['clientName']?.toString() ?? 'Cliente'),
        subtitle: Text(
          'Servico: ${data['serviceDescription'] ?? '-'}\n'
          'Valor: ${_formatCurrency((data['amountCents'] as num?)?.toInt() ?? 0)} | '
          'Status: ${_invoiceStatusLabel(data['status']?.toString())}\n'
          'Numero oficial: ${data['officialNumber'] ?? '-'}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'PDF',
              onPressed: onPreviewPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: canManageServiceInvoices ? onEdit : null,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Portal oficial',
              onPressed: onOpenPortal,
              icon: const Icon(Icons.open_in_new_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
