part of 'workforce_management_page.dart';

extension _WorkforceManagementGovernanceActions
    on _WorkforceManagementPageState {
  Future<void> _saveWorkforceFeatureSettings(
    Session sessao,
    _WorkforceFeatureSettings settings,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'workforceMode': settings.mode.name,
            'workforceFeatures': settings.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'workforce',
        action: 'settings_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'workforceMode': settings.mode.name,
          'workforceFeatures': settings.toMap(),
        },
      );
      _msg('Configuracao do modulo atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a configuracao do modulo.');
    }
  }

  _WorkforceManagerPermissions _workforceManagerPermissions(
    Map<String, dynamic> companySettings,
  ) {
    return _WorkforceManagerPermissions.fromSettings(companySettings);
  }

  _FinanceManagerAccess _financeManagerPermissions(
    Map<String, dynamic> companySettings,
  ) {
    return _FinanceManagerAccess.fromSettings(companySettings);
  }

  Future<void> _saveWorkforceManagerPermissions(
    Session sessao,
    _WorkforceManagerPermissions permissions,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'workforceManagerPermissions': permissions.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'workforce',
        action: 'manager_permissions_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {'workforceManagerPermissions': permissions.toMap()},
      );
      _msg('Permissoes do gerente atualizadas.');
    } catch (_) {
      _msg('Nao foi possivel salvar as permissoes do gerente.');
    }
  }

  Future<void> _openWorkforceSettingsRequestDialog(
    Session sessao,
    _WorkforceFeatureSettings featureSettings,
    _WorkforceManagerPermissions managerPermissions,
  ) async {
    var mode = featureSettings.mode;
    var enablePayrollClosures = featureSettings.enablePayrollClosures;
    var enableMonthlyDashboard = featureSettings.enableMonthlyDashboard;
    var enableContracts = featureSettings.enableContracts;
    var enableAdvancedDocuments = featureSettings.enableAdvancedDocuments;
    var requireClosureDoubleCheck = featureSettings.requireClosureDoubleCheck;
    var requireOwnerApprovalForClosure =
        featureSettings.requireOwnerApprovalForClosure;
    var allowPayrollClosures = managerPermissions.allowPayrollClosures;
    var allowPayrollDocuments = managerPermissions.allowPayrollDocuments;
    var allowContracts = managerPermissions.allowContracts;
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar ajuste trabalhista'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<_WorkforceMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Modo'),
                  items: const [
                    DropdownMenuItem(
                      value: _WorkforceMode.simple,
                      child: Text('Simples'),
                    ),
                    DropdownMenuItem(
                      value: _WorkforceMode.advanced,
                      child: Text('Completo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => mode = value);
                  },
                ),
                const SizedBox(height: 8),
                _buildWorkforceToggleTile(
                  value: enablePayrollClosures,
                  title: 'Fechamento mensal',
                  onChanged: (value) =>
                      setDialogState(() => enablePayrollClosures = value),
                ),
                _buildWorkforceToggleTile(
                  value: enableMonthlyDashboard,
                  title: 'Painel RH mensal',
                  onChanged: (value) =>
                      setDialogState(() => enableMonthlyDashboard = value),
                ),
                _buildWorkforceToggleTile(
                  value: enableAdvancedDocuments,
                  title: 'Documentos avancados',
                  onChanged: (value) =>
                      setDialogState(() => enableAdvancedDocuments = value),
                ),
                _buildWorkforceToggleTile(
                  value: enableContracts,
                  title: 'Contratos',
                  onChanged: (value) =>
                      setDialogState(() => enableContracts = value),
                ),
                _buildWorkforceToggleTile(
                  value: requireClosureDoubleCheck,
                  title: 'Confirmacao reforcada',
                  onChanged: (value) =>
                      setDialogState(() => requireClosureDoubleCheck = value),
                ),
                _buildWorkforceToggleTile(
                  value: requireOwnerApprovalForClosure,
                  title: 'Aprovacao do dono',
                  onChanged: (value) => setDialogState(
                    () => requireOwnerApprovalForClosure = value,
                  ),
                ),
                const Divider(),
                _buildWorkforceToggleTile(
                  value: allowPayrollClosures,
                  title: 'Gerente fecha/reabre folha',
                  onChanged: (value) =>
                      setDialogState(() => allowPayrollClosures = value),
                ),
                _buildWorkforceToggleTile(
                  value: allowPayrollDocuments,
                  title: 'Gerente gera documentos',
                  onChanged: (value) =>
                      setDialogState(() => allowPayrollDocuments = value),
                ),
                _buildWorkforceToggleTile(
                  value: allowContracts,
                  title: 'Gerente gere contratos',
                  onChanged: (value) =>
                      setDialogState(() => allowContracts = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da solicitacao',
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
              onPressed: () async {
                final requestId =
                    '${sessao.companyId}_workforce_settings_${DateTime.now().millisecondsSinceEpoch}';
                await FirebaseFirestore.instance
                    .collection('period_closes')
                    .doc(requestId)
                    .set({
                      'companyId': sessao.companyId,
                      'module': 'workforce_settings_change',
                      'competence': 'SETTINGS',
                      'status': 'PENDING_APPROVAL',
                      'requestedByUserId': sessao.userId,
                      'requestedByUserName': sessao.nome,
                      'requestedAt': FieldValue.serverTimestamp(),
                      'note': noteController.text.trim(),
                      'proposedWorkforceMode': mode.name,
                      'proposedWorkforceFeatures': {
                        'enablePayrollClosures': enablePayrollClosures,
                        'enableMonthlyDashboard': enableMonthlyDashboard,
                        'enableContracts': enableContracts,
                        'enableAdvancedDocuments': enableAdvancedDocuments,
                        'requireClosureDoubleCheck': requireClosureDoubleCheck,
                        'requireOwnerApprovalForClosure':
                            requireOwnerApprovalForClosure,
                      },
                      'proposedWorkforceManagerPermissions': {
                        'allowPayrollClosures': allowPayrollClosures,
                        'allowPayrollDocuments': allowPayrollDocuments,
                        'allowContracts': allowContracts,
                      },
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                await _writeAuditLog(
                  sessao: sessao,
                  module: 'workforce',
                  action: 'settings_change_requested',
                  entityPath: 'period_closes',
                  entityId: requestId,
                  after: {
                    'module': 'workforce_settings_change',
                    'note': noteController.text.trim(),
                  },
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('Solicitacao enviada para aprovacao do dono.');
              },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
  }

  Future<void> _writeAuditLog({
    required Session sessao,
    required String module,
    required String action,
    required String entityPath,
    required String entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'companyId': sessao.companyId,
        'actorUserId': sessao.userId,
        'actorRole': sessao.role.name,
        'module': module,
        'action': action,
        'entityPath': entityPath,
        'entityId': entityId,
        'before': before,
        'after': after,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Nao bloqueia o fluxo principal.
    }
  }

  Future<_SimpleSignatureData?> _askBatchSignatureData({
    required Map<String, dynamic> companyData,
  }) async {
    final companySignerController = TextEditingController(
      text: companyData['nomeFantasia']?.toString().trim().isNotEmpty == true
          ? companyData['nomeFantasia'].toString()
          : companyData['razaoSocial']?.toString() ?? '',
    );
    final referenceController = TextEditingController();
    var signatureMethod = 'manual';
    _SimpleSignatureData? result;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Exportar holerites em lote'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: companySignerController,
                  decoration: const InputDecoration(
                    labelText: 'Responsavel da empresa',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: signatureMethod,
                  decoration: const InputDecoration(
                    labelText: 'Metodo de assinatura',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Assinatura manual no sistema'),
                    ),
                    DropdownMenuItem(value: 'gov_br', child: Text('Gov.br')),
                    DropdownMenuItem(
                      value: 'digital_certificate',
                      child: Text('Certificado digital'),
                    ),
                    DropdownMenuItem(
                      value: 'other_digital',
                      child: Text('Outro meio digital'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => signatureMethod = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia do aceite digital',
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppBrandColors.border),
                  ),
                  child: Text(
                    'Registro digital: ${_signatureDeviceLabel()}\nData/hora: ${_formatDateTime(DateTime.now())}',
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
                final companySigner = companySignerController.text.trim();
                if (companySigner.isEmpty) {
                  _msg('Informe o responsavel da empresa.');
                  return;
                }
                result = _SimpleSignatureData(
                  companySignerName: companySigner,
                  employeeSignerName: 'Assinatura pendente em lote',
                  acceptedAt: DateTime.now(),
                  signatureMethod: signatureMethod,
                  signatureDeviceLabel: _signatureDeviceLabel(),
                  signatureReference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Gerar'),
            ),
          ],
        ),
      ),
    );

    companySignerController.dispose();
    referenceController.dispose();
    return result;
  }

  Future<void> _toggleOperationalEmployeeReview({
    required Session sessao,
    required String competence,
    required _WorkforceOperationalChecks checks,
    required String employeeId,
    required _OperationalReviewTarget target,
    required bool reviewed,
  }) async {
    final updatedIds = switch (target) {
      _OperationalReviewTarget.thirteenth =>
        reviewed
            ? {...checks.thirteenthReviewedEmployeeIds, employeeId}.toList()
            : checks.thirteenthReviewedEmployeeIds
                  .where((id) => id != employeeId)
                  .toList(),
      _OperationalReviewTarget.vacation =>
        reviewed
            ? {...checks.vacationReviewedEmployeeIds, employeeId}.toList()
            : checks.vacationReviewedEmployeeIds
                  .where((id) => id != employeeId)
                  .toList(),
    };
    try {
      await FirebaseFirestore.instance
          .collection('fiscal_competence_checks')
          .doc('${sessao.companyId}_$competence')
          .set({
            'companyId': sessao.companyId,
            'competence': competence,
            if (target == _OperationalReviewTarget.thirteenth)
              'thirteenthReviewedEmployeeIds': updatedIds,
            if (target == _OperationalReviewTarget.vacation)
              'vacationReviewedEmployeeIds': updatedIds,
            'updatedByUserId': sessao.userId,
            'updatedByUserName': sessao.nome,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      _msg('Nao foi possivel atualizar o acompanhamento operacional.');
    }
  }

  Future<void> _saveWorkforceCompetenceObligations({
    required Session sessao,
    required String competence,
    required _WorkforceCompetenceObligations obligations,
  }) async {
    if (_parseCompetence(competence) == null) {
      _msg('Competencia invalida para obrigacoes trabalhistas.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('workforce_competence_obligations')
          .doc('${sessao.companyId}_$competence')
          .set({
            'companyId': sessao.companyId,
            'competence': competence,
            ...obligations.toMap(),
            'updatedByUserId': sessao.userId,
            'updatedByUserName': sessao.nome,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      _msg('Nao foi possivel salvar as obrigacoes trabalhistas.');
    }
  }

  Future<void> _openWorkforceCompetenceNotesDialog({
    required Session sessao,
    required String competence,
    required _WorkforceCompetenceObligations obligations,
  }) async {
    final controller = TextEditingController(text: obligations.notes);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Observacoes da competencia'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(labelText: 'Observacoes ($competence)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveWorkforceCompetenceObligations(
                sessao: sessao,
                competence: competence,
                obligations: obligations.copyWith(
                  notes: controller.text.trim(),
                ),
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _openWorkforceEmployeeEventDialog({
    required Session sessao,
    required Employee employee,
    required String competence,
  }) async {
    var selectedType = _workforceEmployeeEventTypeOptions.first.value;
    final notesController = TextEditingController();
    DateTime effectiveDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar evento trabalhista'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de evento',
                  ),
                  items: [
                    for (final option in _workforceEmployeeEventTypeOptions)
                      DropdownMenuItem(
                        value: option.value,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data efetiva'),
                  subtitle: Text(_formatDate(effectiveDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: effectiveDate,
                    );
                    if (picked != null) {
                      setDialogState(() => effectiveDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes do evento',
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
              onPressed: () async {
                final selectedOption = _workforceEmployeeEventTypeOptions
                    .firstWhere((item) => item.value == selectedType);
                final saved = await _saveWorkforceEmployeeEvent(
                  sessao: sessao,
                  employee: employee,
                  competence: competence,
                  eventType: selectedOption.value,
                  eventLabel: selectedOption.label,
                  effectiveDate: effectiveDate,
                  notes: notesController.text.trim(),
                );
                if (!saved) {
                  _msg('Nao foi possivel registrar o evento trabalhista.');
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    notesController.dispose();
  }

  Future<void> _openPresetWorkforceEmployeeEventDialog({
    required Session sessao,
    required Employee employee,
    required String competence,
    required String eventType,
    required String eventLabel,
    String? defaultNotes,
  }) async {
    final notesController = TextEditingController(text: defaultNotes ?? '');
    DateTime effectiveDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(eventLabel),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Funcionario: ${employee.nomeCompleto}'),
                const SizedBox(height: 8),
                Text('Competencia: $competence'),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data efetiva'),
                  subtitle: Text(_formatDate(effectiveDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: effectiveDate,
                    );
                    if (picked != null) {
                      setDialogState(() => effectiveDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes do evento',
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
              onPressed: () async {
                final saved = await _saveWorkforceEmployeeEvent(
                  sessao: sessao,
                  employee: employee,
                  competence: competence,
                  eventType: eventType,
                  eventLabel: eventLabel,
                  effectiveDate: effectiveDate,
                  notes: notesController.text.trim(),
                );
                if (!saved) {
                  _msg('Nao foi possivel registrar o evento trabalhista.');
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    notesController.dispose();
  }

  Future<bool> _saveWorkforceEmployeeEvent({
    required Session sessao,
    required Employee employee,
    required String competence,
    required String eventType,
    required String eventLabel,
    required DateTime effectiveDate,
    required String notes,
  }) async {
    final docId = FirebaseFirestore.instance
        .collection('workforce_employee_events')
        .doc()
        .id;
    try {
      await FirebaseFirestore.instance
          .collection('workforce_employee_events')
          .doc(docId)
          .set({
            'companyId': sessao.companyId,
            'employeeId': employee.id,
            'employeeName': employee.nomeCompleto,
            'competence': competence,
            'eventType': eventType,
            'eventLabel': eventLabel,
            'effectiveDate': Timestamp.fromDate(effectiveDate),
            'notes': notes,
            'createdByUserId': sessao.userId,
            'createdByUserName': sessao.nome,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveWorkforceEmployeeCompetenceSnapshot({
    required Session sessao,
    required Employee employee,
    required String competence,
    required int grossReferenceCents,
    required int thirteenthProjectedCents,
    required int vacationProjectedCents,
    required int vacationBonusCents,
    required int terminationProjectedCents,
    required int thirteenthAvos,
    required int vacationMonthsAccrued,
    required bool terminationSignaled,
    required Map<String, dynamic> thirteenthMemory,
    required Map<String, dynamic> vacationMemory,
    required Map<String, dynamic> terminationMemory,
  }) async {
    if (_parseCompetence(competence) == null) {
      _msg('Competencia invalida para snapshot trabalhista.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('workforce_employee_competence_snapshots')
          .doc('${sessao.companyId}_${employee.id}_$competence')
          .set({
            'companyId': sessao.companyId,
            'employeeId': employee.id,
            'employeeName': employee.nomeCompleto,
            'competence': competence,
            'grossReferenceCents': grossReferenceCents,
            'thirteenthProjectedCents': thirteenthProjectedCents,
            'vacationProjectedCents': vacationProjectedCents,
            'vacationBonusCents': vacationBonusCents,
            'terminationProjectedCents': terminationProjectedCents,
            'thirteenthAvos': thirteenthAvos,
            'vacationMonthsAccrued': vacationMonthsAccrued,
            'terminationSignaled': terminationSignaled,
            'thirteenthMemory': thirteenthMemory,
            'vacationMemory': vacationMemory,
            'terminationMemory': terminationMemory,
            'updatedByUserId': sessao.userId,
            'updatedByUserName': sessao.nome,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _msg('Snapshot trabalhista salvo para a competencia.');
    } catch (_) {
      _msg('Nao foi possivel salvar o snapshot trabalhista.');
    }
  }

  Future<void> _saveWorkforceLaborCompetenceClosure({
    required Session sessao,
    required String competence,
    required String status,
    required _WorkforceCompetenceObligations obligations,
    required int totalEmployees,
    required int employeesWithSnapshot,
    required int missingSnapshotEmployees,
    required int thirteenthEmployees,
    required int vacationAttentionEmployees,
    required int terminationEmployees,
    required int thirteenthProjectedCents,
    required int vacationProjectedCents,
    required int vacationBonusCents,
    required int terminationProjectedCents,
    required List<Map<String, dynamic>> lines,
  }) async {
    if (_parseCompetence(competence) == null) {
      _msg('Competencia invalida para fechamento trabalhista.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('payroll_closures')
          .doc('${sessao.companyId}_$competence')
          .set({
            'companyId': sessao.companyId,
            'competence': competence,
            'laborClosure': {
              'status': status,
              'totalEmployees': totalEmployees,
              'employeesWithSnapshot': employeesWithSnapshot,
              'missingSnapshotEmployees': missingSnapshotEmployees,
              'thirteenthEmployees': thirteenthEmployees,
              'vacationAttentionEmployees': vacationAttentionEmployees,
              'terminationEmployees': terminationEmployees,
              'thirteenthProjectedCents': thirteenthProjectedCents,
              'vacationProjectedCents': vacationProjectedCents,
              'vacationBonusCents': vacationBonusCents,
              'terminationProjectedCents': terminationProjectedCents,
              'obligationsCompletedCount': obligations.completedCount,
              'obligationsTotalCount': obligations.totalCount,
              'notes': obligations.notes,
              'updatedByUserId': sessao.userId,
              'updatedByUserName': sessao.nome,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'laborLines': lines,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'workforce',
        action: 'labor_competence_closure_save',
        entityPath: 'payroll_closures',
        entityId: '${sessao.companyId}_$competence',
        after: {
          'competence': competence,
          'status': status,
          'totalEmployees': totalEmployees,
          'employeesWithSnapshot': employeesWithSnapshot,
          'missingSnapshotEmployees': missingSnapshotEmployees,
          'thirteenthEmployees': thirteenthEmployees,
          'vacationAttentionEmployees': vacationAttentionEmployees,
          'terminationEmployees': terminationEmployees,
        },
      );
      _msg('Fechamento trabalhista salvo para a competencia.');
    } catch (_) {
      _msg('Nao foi possivel salvar o fechamento trabalhista.');
    }
  }

  bool _isEligibleForThirteenth(Employee? employee, String competence) {
    if (employee == null || employee.admissionDate == null) {
      return false;
    }
    final parsed = _parseCompetence(competence);
    if (parsed == null) {
      return false;
    }
    final endOfMonth = DateTime(parsed.$1, parsed.$2 + 1, 0);
    return employee.admissionDate!.isBefore(endOfMonth) ||
        employee.admissionDate!.isAtSameMomentAs(endOfMonth);
  }

  bool _isVacationAttention(Employee? employee) {
    if (employee?.admissionDate == null) {
      return false;
    }
    return DateTime.now().difference(employee!.admissionDate!).inDays >= 330;
  }

  Widget _statusChip(String label, String value, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF64B5F6)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: highlighted ? const Color(0xFF0D47A1) : null,
        ),
      ),
    );
  }

  bool _isPayrollClosed(Map<String, dynamic> settings, String competence) {
    final raw = settings['closedPayrollCompetences'];
    if (raw is! List) {
      return false;
    }
    return raw.map((e) => e.toString()).contains(competence);
  }

  List<_PayrollClosureEvent> _closureHistory(
    Map<String, dynamic> settings,
    String competence,
  ) {
    final raw = settings['payrollClosureHistory'];
    if (raw is! List) {
      return const <_PayrollClosureEvent>[];
    }
    final events = <_PayrollClosureEvent>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      if ((map['competence']?.toString() ?? '') != competence) {
        continue;
      }
      events.add(
        _PayrollClosureEvent(
          competence: map['competence']?.toString() ?? '',
          action: map['action']?.toString() ?? 'close',
          userId: map['userId']?.toString() ?? '',
          userName: map['userName']?.toString() ?? '-',
          note: map['note']?.toString() ?? '',
          at: _toDate(map['at']),
        ),
      );
    }
    return events;
  }

  List<_PayrollMonthDashboardLine> _buildMonthlyPayrollDashboard({
    required List<Employee> employees,
    required String selectedCompetence,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    final selected = _parseCompetence(selectedCompetence);
    if (selected == null) {
      return const <_PayrollMonthDashboardLine>[];
    }

    final lines = <_PayrollMonthDashboardLine>[];
    for (var offset = 0; offset < 6; offset++) {
      final monthDate = DateTime(selected.$1, selected.$2 - offset, 1);
      final competence =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
      final summary = _buildPayrollSummary(
        employees: employees,
        competence: competence,
        payments: payments,
        workEntries: workEntries,
        tasks: tasks,
      );
      lines.add(
        _PayrollMonthDashboardLine(
          competence: competence,
          summary: summary,
          pendingEmployees: summary.lines
              .where((line) => !line.hasRegisteredPayment)
              .length,
          divergentEmployees: summary.lines
              .where((line) => line.hasDivergence)
              .length,
          isSelected: competence == selectedCompetence,
        ),
      );
    }
    return lines;
  }

  Future<void> _togglePayrollClose({
    required Session sessao,
    required String competence,
    required bool close,
    required _PayrollSummary summary,
    required bool requireDoubleCheck,
    required bool requireOwnerApproval,
    String? predefinedNote,
  }) async {
    if (_parseCompetence(competence) == null) {
      _msg('Competencia invalida.');
      return;
    }
    final pendingEmployees = summary.lines
        .where((line) => !line.hasRegisteredPayment)
        .length;
    final divergentEmployees = summary.lines
        .where((line) => line.hasDivergence)
        .length;
    if (close && (pendingEmployees > 0 || divergentEmployees > 0)) {
      _msg(
        'A competencia so pode ser fechada quando os pagamentos estiverem completos para todos os funcionarios.',
      );
      return;
    }
    if (close) {
      try {
        final laborClosureSnapshot = await FirebaseFirestore.instance
            .collection('payroll_closures')
            .doc('${sessao.companyId}_$competence')
            .get();
        final laborData = laborClosureSnapshot.data();
        final laborClosureRaw = laborData?['laborClosure'];
        final laborStatus = laborClosureRaw is Map
            ? laborClosureRaw['status']?.toString() ?? 'pending_review'
            : 'pending_review';
        if (laborStatus != 'ready_for_close' && laborStatus != 'closed') {
          _msg(
            'Feche primeiro o trabalhista da competencia: snapshots, checklists e workflows de ferias/13o/rescisao ainda nao estao prontos.',
          );
          return;
        }
      } catch (_) {
        _msg(
          'Nao foi possivel validar o fechamento trabalhista da competencia.',
        );
        return;
      }
    }
    try {
      final note =
          predefinedNote ??
          await _askClosureNote(
            close: close,
            competence: competence,
            requireDoubleCheck: requireDoubleCheck,
          );
      if (note == null) {
        return;
      }
      if (requireOwnerApproval && sessao.role != Role.owner) {
        final requestId =
            '${sessao.companyId}_workforce_${close ? 'close' : 'open'}_$competence';
        await FirebaseFirestore.instance
            .collection('period_closes')
            .doc(requestId)
            .set({
              'companyId': sessao.companyId,
              'module': 'workforce',
              'competence': competence,
              'closeAction': close,
              'status': 'PENDING_APPROVAL',
              'requestedByUserId': sessao.userId,
              'requestedByUserName': sessao.nome,
              'requestedAt': FieldValue.serverTimestamp(),
              'note': note,
              'suggestedGrossCents': summary.suggestedGrossCents,
              'registeredGrossCents': summary.registeredGrossCents,
              'registeredPayments': summary.registeredPayments,
              'totalEmployees': summary.totalEmployees,
              'approvedDays': summary.approvedDays,
              'finishedServices': summary.finishedServices,
              'pendingEmployees': summary.lines
                  .where((line) => !line.hasRegisteredPayment)
                  .length,
              'divergentEmployees': summary.lines
                  .where((line) => line.hasDivergence)
                  .length,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        await _writeAuditLog(
          sessao: sessao,
          module: 'workforce',
          action: close
              ? 'payroll_close_requested'
              : 'payroll_reopen_requested',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {
            'competence': competence,
            'note': note,
            'closeAction': close,
            'status': 'PENDING_APPROVAL',
          },
        );
        _msg(
          close
              ? 'Solicitacao de fechamento enviada para aprovacao do dono.'
              : 'Solicitacao de reabertura enviada para aprovacao do dono.',
        );
        return;
      }
      final docRef = FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId);
      final snapshot = await docRef.get();
      final currentData = snapshot.data() ?? <String, dynamic>{};
      final historyRaw = currentData['payrollClosureHistory'];
      final history = <Map<String, dynamic>>[
        if (historyRaw is List)
          for (final item in historyRaw)
            if (item is Map)
              item.map((key, value) => MapEntry(key.toString(), value)),
      ];
      history.insert(0, {
        'competence': competence,
        'action': close ? 'close' : 'open',
        'userId': sessao.userId,
        'userName': sessao.nome,
        'note': note,
        'at': DateTime.now().toIso8601String(),
      });
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'closedPayrollCompetences': close
                ? FieldValue.arrayUnion([competence])
                : FieldValue.arrayRemove([competence]),
            'payrollClosureHistory': history.take(50).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'workforce',
        action: close ? 'payroll_close' : 'payroll_reopen',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        after: {
          'competence': competence,
          'note': note,
          'status': close ? 'closed' : 'open',
          'suggestedGrossCents': summary.suggestedGrossCents,
          'registeredGrossCents': summary.registeredGrossCents,
        },
      );
      await FirebaseFirestore.instance
          .collection('payroll_closures')
          .doc('${sessao.companyId}_$competence')
          .set({
            'companyId': sessao.companyId,
            'competence': competence,
            'status': close ? 'closed' : 'open',
            'suggestedGrossCents': summary.suggestedGrossCents,
            'registeredGrossCents': summary.registeredGrossCents,
            'registeredPayments': summary.registeredPayments,
            'totalEmployees': summary.totalEmployees,
            'approvedDays': summary.approvedDays,
            'finishedServices': summary.finishedServices,
            'pendingEmployees': summary.lines
                .where((line) => !line.hasRegisteredPayment)
                .length,
            'divergentEmployees': summary.lines
                .where((line) => line.hasDivergence)
                .length,
            'lines': [
              for (final line in summary.lines)
                {
                  'employeeId': line.employeeId,
                  'employeeName': line.employeeName,
                  'approvedDays': line.approvedDays,
                  'approvedHours': line.approvedHours,
                  'finishedServices': line.finishedServices,
                  'suggestedGrossCents': line.suggestedGrossCents,
                  'registeredGrossCents': line.registeredGrossCents,
                  'hasRegisteredPayment': line.hasRegisteredPayment,
                  'hasDivergence': line.hasDivergence,
                },
            ],
            'updatedByUserId': sessao.userId,
            'updatedByUserName': sessao.nome,
            'lastNote': note,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _msg(close ? 'Competencia fechada.' : 'Competencia reaberta.');
    } catch (_) {
      _msg('Nao foi possivel atualizar o fechamento mensal.');
    }
  }

  Future<void> _resolveClosureApproval({
    required Session sessao,
    required String requestId,
    required bool approve,
  }) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('period_closes')
          .doc(requestId);
      final snapshot = await requestRef.get();
      final data = snapshot.data();
      if (data == null) {
        _msg('Solicitacao nao encontrada.');
        return;
      }
      final resolutionComment = await _askResolutionComment(
        approve: approve,
        subject: 'solicitacao de folha',
      );
      if (resolutionComment == null) {
        return;
      }
      final closeAction = data['closeAction'] as bool? ?? true;
      if (!approve) {
        await requestRef.set({
          'status': 'REJECTED',
          'resolvedByUserId': sessao.userId,
          'resolvedByUserName': sessao.nome,
          'resolutionComment': resolutionComment,
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _writeAuditLog(
          sessao: sessao,
          module: 'workforce',
          action: closeAction
              ? 'payroll_close_rejected'
              : 'payroll_reopen_rejected',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {'status': 'REJECTED', 'resolutionComment': resolutionComment},
        );
        _msg('Solicitacao rejeitada.');
        return;
      }

      final competence = data['competence']?.toString() ?? '';
      final summary = _PayrollSummary(
        totalEmployees: (data['totalEmployees'] as num?)?.toInt() ?? 0,
        registeredPayments: (data['registeredPayments'] as num?)?.toInt() ?? 0,
        suggestedGrossCents:
            (data['suggestedGrossCents'] as num?)?.toInt() ?? 0,
        registeredGrossCents:
            (data['registeredGrossCents'] as num?)?.toInt() ?? 0,
        approvedDays: (data['approvedDays'] as num?)?.toInt() ?? 0,
        finishedServices: (data['finishedServices'] as num?)?.toInt() ?? 0,
        lines: const <_PayrollSummaryLine>[],
      );
      await _togglePayrollClose(
        sessao: sessao,
        competence: competence,
        close: closeAction,
        summary: summary,
        requireDoubleCheck: false,
        requireOwnerApproval: false,
        predefinedNote: data['note']?.toString() ?? '',
      );
      await requestRef.set({
        'status': 'APPROVED',
        'resolvedByUserId': sessao.userId,
        'resolvedByUserName': sessao.nome,
        'resolutionComment': resolutionComment,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'workforce',
        action: closeAction
            ? 'payroll_close_approved'
            : 'payroll_reopen_approved',
        entityPath: 'period_closes',
        entityId: requestId,
        after: {
          'status': 'APPROVED',
          'competence': competence,
          'closeAction': closeAction,
          'resolutionComment': resolutionComment,
        },
      );
    } catch (_) {
      _msg('Nao foi possivel resolver a aprovacao.');
    }
  }

  Future<void> _resolveCleanupApproval({
    required Session sessao,
    required String requestId,
    required bool approve,
  }) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('period_closes')
          .doc(requestId);
      final snapshot = await requestRef.get();
      final data = snapshot.data();
      if (data == null) {
        _msg('Solicitacao nao encontrada.');
        return;
      }
      final resolutionComment = await _askResolutionComment(
        approve: approve,
        subject: 'solicitacao de limpeza',
      );
      if (resolutionComment == null) {
        return;
      }
      if (!approve) {
        await requestRef.set({
          'status': 'REJECTED',
          'resolvedByUserId': sessao.userId,
          'resolvedByUserName': sessao.nome,
          'resolutionComment': resolutionComment,
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _writeAuditLog(
          sessao: sessao,
          module: 'finance',
          action: 'cleanup_rejected',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {'status': 'REJECTED', 'resolutionComment': resolutionComment},
        );
        _msg('Solicitacao de limpeza rejeitada.');
        return;
      }
      await _cleanup.clearCompanyOperationalData();
      await requestRef.set({
        'status': 'APPROVED',
        'resolvedByUserId': sessao.userId,
        'resolvedByUserName': sessao.nome,
        'resolutionComment': resolutionComment,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'finance',
        action: 'cleanup_approved',
        entityPath: 'period_closes',
        entityId: requestId,
        after: {'status': 'APPROVED', 'resolutionComment': resolutionComment},
      );
      _msg('Limpeza financeira aprovada e executada.');
    } on FinanceCleanupException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('Nao foi possivel resolver a limpeza.');
    }
  }

  Future<void> _resolveSettingsChangeApproval({
    required Session sessao,
    required String requestId,
    required bool approve,
  }) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('period_closes')
          .doc(requestId);
      final snapshot = await requestRef.get();
      final data = snapshot.data();
      if (data == null) {
        _msg('Solicitacao nao encontrada.');
        return;
      }
      final resolutionComment = await _askResolutionComment(
        approve: approve,
        subject: 'ajuste sensivel de configuracao',
      );
      if (resolutionComment == null) {
        return;
      }
      final module = data['module']?.toString() ?? '';
      if (!approve) {
        await requestRef.set({
          'status': 'REJECTED',
          'resolvedByUserId': sessao.userId,
          'resolvedByUserName': sessao.nome,
          'resolutionComment': resolutionComment,
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _writeAuditLog(
          sessao: sessao,
          module: module == 'finance_settings_change' ? 'finance' : 'workforce',
          action: 'settings_change_rejected',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {'status': 'REJECTED', 'resolutionComment': resolutionComment},
        );
        _msg('Solicitacao rejeitada.');
        return;
      }

      await _applySettingsChangeRequest(sessao: sessao, data: data);
      await requestRef.set({
        'status': 'APPROVED',
        'resolvedByUserId': sessao.userId,
        'resolvedByUserName': sessao.nome,
        'resolutionComment': resolutionComment,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: module == 'finance_settings_change' ? 'finance' : 'workforce',
        action: 'settings_change_approved',
        entityPath: 'period_closes',
        entityId: requestId,
        after: {
          'status': 'APPROVED',
          'resolutionComment': resolutionComment,
          'module': module,
        },
      );
      _msg('Solicitacao aprovada e aplicada.');
    } catch (_) {
      _msg('Nao foi possivel resolver a solicitacao.');
    }
  }

  Future<void> _applySettingsChangeRequest({
    required Session sessao,
    required Map<String, dynamic> data,
  }) async {
    final module = data['module']?.toString() ?? '';
    final settingsRef = FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId);
    final before = await settingsRef.get();
    if (module == 'finance_settings_change') {
      final financeFeatures =
          (data['proposedFinanceFeatures'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final financePermissions =
          (data['proposedFinanceManagerPermissions'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      await settingsRef.set({
        'companyId': sessao.companyId,
        'financeMode': data['proposedFinanceMode']?.toString() ?? 'simple',
        'financeFeatures': financeFeatures,
        'financeManagerPermissions': financePermissions,
        'financeRequireOwnerApprovalForCleanup':
            data['proposedFinanceRequireOwnerApprovalForCleanup'] == true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        module: 'finance',
        action: 'settings_change_applied',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'financeMode': data['proposedFinanceMode']?.toString() ?? 'simple',
          'financeFeatures': financeFeatures,
          'financeManagerPermissions': financePermissions,
          'financeRequireOwnerApprovalForCleanup':
              data['proposedFinanceRequireOwnerApprovalForCleanup'] == true,
        },
      );
      return;
    }

    final workforceFeatures =
        (data['proposedWorkforceFeatures'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final workforcePermissions =
        (data['proposedWorkforceManagerPermissions'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    await settingsRef.set({
      'companyId': sessao.companyId,
      'workforceMode': data['proposedWorkforceMode']?.toString() ?? 'simple',
      'workforceFeatures': workforceFeatures,
      'workforceManagerPermissions': workforcePermissions,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAuditLog(
      sessao: sessao,
      module: 'workforce',
      action: 'settings_change_applied',
      entityPath: 'company_settings',
      entityId: sessao.companyId,
      before: before.data(),
      after: {
        'workforceMode': data['proposedWorkforceMode']?.toString() ?? 'simple',
        'workforceFeatures': workforceFeatures,
        'workforceManagerPermissions': workforcePermissions,
      },
    );
  }

  Future<String?> _askClosureNote({
    required bool close,
    required String competence,
    required bool requireDoubleCheck,
  }) async {
    final controller = TextEditingController();
    final confirmationController = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(close ? 'Fechar competencia' : 'Reabrir competencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Observacao ($competence)',
              ),
            ),
            if (close && requireDoubleCheck) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                decoration: InputDecoration(
                  labelText: 'Digite $competence para confirmar',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (close &&
                  requireDoubleCheck &&
                  confirmationController.text.trim() != competence) {
                _msg('Confirme digitando a competencia exatamente.');
                return;
              }
              result = controller.text.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    confirmationController.dispose();
    return result;
  }

  Future<String?> _askResolutionComment({
    required bool approve,
    required String subject,
  }) async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Aprovar solicitacao' : 'Rejeitar solicitacao'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Comentario sobre $subject'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        border: Border.all(color: const Color(0xFFD8E4F7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B85)),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  List<_PayrollSummaryLine> _filteredPayrollLines(
    List<_PayrollSummaryLine> lines,
  ) {
    if (!_showOnlyPendingPayroll) {
      return lines;
    }
    return lines
        .where((line) => !line.hasRegisteredPayment || line.hasDivergence)
        .toList();
  }

  Future<void> _previewInvoicePdf({
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> data,
  }) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Documento auxiliar de NFS-e / Nota de servico',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Empresa: ${companyData['nomeFantasia'] ?? companyData['razaoSocial'] ?? '-'}',
            ),
            pw.Text('CNPJ: ${companyData['cnpj'] ?? '-'}'),
            pw.Text('Cliente: ${data['clientName'] ?? '-'}'),
            pw.Text('CPF/CNPJ cliente: ${data['clientDocument'] ?? '-'}'),
            pw.Text(
              'Descricao do servico: ${data['serviceDescription'] ?? '-'}',
            ),
            pw.Text(
              'Valor: ${_formatCurrency((data['amountCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Text(
              'Data do servico: ${_formatDate(_toDate(data['serviceDate']))}',
            ),
            pw.Text(
              'Data de emissao: ${_formatDate(_toDate(data['issueDate']))}',
            ),
            pw.Text(
              'Status: ${_invoiceStatusLabel(data['status']?.toString())}',
            ),
            pw.Text('Numero oficial: ${data['officialNumber'] ?? '-'}'),
            pw.Text('Portal oficial: ${data['officialPortalUrl'] ?? '-'}'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Observacao: este documento serve como espelho operacional interno. '
              'A emissao fiscal oficial depende do ambiente oficial da prefeitura/NFS-e.',
            ),
          ],
        ),
      );
      await openPdfBytes(
        bytes: await pdf.save(),
        filename:
            'nota-trabalhista-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (_) {
      _msg('Nao foi possivel gerar o PDF da nota.');
    }
  }

  Future<void> _openUrl(String? url) async {
    final parsed = Uri.tryParse(url ?? '');
    if (parsed == null) {
      _msg('Link do portal invalido.');
      return;
    }
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  Employee? _findEmployee(List<Employee> employees, String? id) {
    if (id == null) return null;
    for (final employee in employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  Payment? _findPayment(
    List<Payment> payments,
    String employeeId,
    String competence,
  ) {
    final matches = _paymentsForCompetence(payments, employeeId, competence);
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.dataRegistro.compareTo(a.dataRegistro));
    return matches.first;
  }

  List<Payment> _paymentsForCompetence(
    List<Payment> payments,
    String employeeId,
    String competence,
  ) {
    return payments
        .where(
          (payment) =>
              payment.employeeId == employeeId &&
              payment.competencia == competence &&
              payment.status != PaymentStatus.cancelado,
        )
        .toList();
  }

  int _registeredGrossForCompetence(
    List<Payment> payments,
    String employeeId,
    String competence,
  ) {
    return _paymentsForCompetence(
      payments,
      employeeId,
      competence,
    ).fold<int>(0, (total, payment) => total + payment.valorCents);
  }

  bool _isPayrollCovered({
    required int suggestedGrossCents,
    required int registeredGrossCents,
  }) {
    if (suggestedGrossCents <= 0) {
      return registeredGrossCents > 0;
    }
    return registeredGrossCents >= suggestedGrossCents;
  }

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final dayOffset = firstDay.weekday - DateTime.monday;
    final normalizedOffset = dayOffset < 0 ? 6 : dayOffset;
    final dayOfYear = date.difference(firstDay).inDays;
    return ((dayOfYear + normalizedOffset) ~/ 7) + 1;
  }

  String _signatureDeviceLabel() {
    final platform = defaultTargetPlatform.toString().split('.').last;
    return '${kIsWeb ? 'web' : 'app'} | $platform';
  }

  String _signatureMethodLabel(String method) {
    return switch (method) {
      'gov_br' => 'Gov.br',
      'digital_certificate' => 'Certificado digital',
      'other_digital' => 'Outro meio digital',
      _ => 'Assinatura manual no sistema',
    };
  }

  _PayrollMetrics _buildPayrollMetrics({
    required Employee employee,
    required String competence,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    final ym = _parseCompetence(competence);
    if (ym == null) {
      return const _PayrollMetrics(
        approvedDays: 0,
        approvedWeeks: 0,
        approvedHours: 0,
        finishedServices: 0,
        finishedServicesValueCents: 0,
        suggestedGrossCents: 0,
      );
    }

    final filteredEntries = workEntries.where(
      (entry) =>
          entry.employeeId == employee.id &&
          entry.status == WorkEntryStatus.aprovado &&
          entry.data.year == ym.$1 &&
          entry.data.month == ym.$2,
    );

    final approvedDays = {
      for (final entry in filteredEntries)
        '${entry.data.year}-${entry.data.month}-${entry.data.day}',
    }.length;
    final approvedWeeks = {
      for (final entry in filteredEntries)
        '${entry.data.year}-${_weekOfYear(entry.data)}',
    }.length;
    final approvedHours = filteredEntries.fold<int>(
      0,
      (total, entry) => total + entry.horas,
    );

    final finishedTasks = tasks.where(
      (task) =>
          task.autorId == employee.id &&
          task.status == StatusTarefa.finalizado &&
          task.dataExecucao != null &&
          task.dataExecucao!.year == ym.$1 &&
          task.dataExecucao!.month == ym.$2,
    );
    final finishedServices = finishedTasks.length;
    final finishedServicesValueCents = finishedTasks.fold<int>(
      0,
      (total, task) => total + (task.valorTotalCents ?? 0),
    );

    final suggestedGrossCents = switch (employee.compensationType) {
      EmployeeCompensationType.monthly => employee.salaryAmountCents ?? 0,
      EmployeeCompensationType.weekly =>
        (employee.salaryAmountCents ?? 0) * approvedWeeks,
      EmployeeCompensationType.daily =>
        (employee.salaryAmountCents ?? 0) * approvedDays,
      EmployeeCompensationType.commission =>
        ((finishedServicesValueCents * (employee.commissionPercent ?? 0)) / 100)
            .round(),
    };

    return _PayrollMetrics(
      approvedDays: approvedDays,
      approvedWeeks: approvedWeeks,
      approvedHours: approvedHours,
      finishedServices: finishedServices,
      finishedServicesValueCents: finishedServicesValueCents,
      suggestedGrossCents: suggestedGrossCents,
    );
  }

  _PayrollSummary _buildPayrollSummary({
    required List<Employee> employees,
    required String competence,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) {
    final lines = <_PayrollSummaryLine>[];
    var suggestedGrossCents = 0;
    var registeredGrossCents = 0;
    var registeredPayments = 0;
    var approvedDays = 0;
    var finishedServices = 0;

    for (final employee in employees) {
      final metrics = _buildPayrollMetrics(
        employee: employee,
        competence: competence,
        workEntries: workEntries,
        tasks: tasks,
      );
      final registered = _registeredGrossForCompetence(
        payments,
        employee.id,
        competence,
      );
      final hasRegisteredPayment = registered > 0;
      final isCovered = _isPayrollCovered(
        suggestedGrossCents: metrics.suggestedGrossCents,
        registeredGrossCents: registered,
      );

      suggestedGrossCents += metrics.suggestedGrossCents;
      registeredGrossCents += registered;
      approvedDays += metrics.approvedDays;
      finishedServices += metrics.finishedServices;
      if (isCovered) {
        registeredPayments++;
      }

      lines.add(
        _PayrollSummaryLine(
          employeeId: employee.id,
          employeeName: employee.nomeCompleto,
          approvedDays: metrics.approvedDays,
          approvedHours: metrics.approvedHours,
          finishedServices: metrics.finishedServices,
          suggestedGrossCents: metrics.suggestedGrossCents,
          registeredGrossCents: registered,
          hasRegisteredPayment: isCovered,
          hasDivergence: hasRegisteredPayment && !isCovered,
        ),
      );
    }

    lines.sort((a, b) => a.employeeName.compareTo(b.employeeName));

    return _PayrollSummary(
      totalEmployees: employees.length,
      registeredPayments: registeredPayments,
      suggestedGrossCents: suggestedGrossCents,
      registeredGrossCents: registeredGrossCents,
      approvedDays: approvedDays,
      finishedServices: finishedServices,
      lines: lines,
    );
  }

  Future<void> _generateMissingPayments({
    required String competence,
    required List<Employee> employees,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) async {
    final ym = _parseCompetence(competence);
    if (ym == null) {
      _msg('Competencia invalida.');
      return;
    }

    var created = 0;
    for (final employee in employees) {
      final metrics = _buildPayrollMetrics(
        employee: employee,
        competence: competence,
        workEntries: workEntries,
        tasks: tasks,
      );
      final registeredGross = _registeredGrossForCompetence(
        payments,
        employee.id,
        competence,
      );
      if (_isPayrollCovered(
        suggestedGrossCents: metrics.suggestedGrossCents,
        registeredGrossCents: registeredGross,
      )) {
        continue;
      }
      if (metrics.suggestedGrossCents <= 0) {
        continue;
      }
      try {
        await _actions.createPayment(
          employeeId: employee.id,
          competenceYear: ym.$1,
          competenceMonth: ym.$2,
          grossCents: metrics.suggestedGrossCents,
          discountsCents: 0,
          paymentType: _employeeCompensationApiValue(employee.compensationType),
        );
        created++;
      } on FinanceActionException {
        // Segue para os demais para nao bloquear o lote inteiro.
      } catch (_) {
        // Segue para os demais para nao bloquear o lote inteiro.
      }
    }

    _msg(
      created > 0
          ? '$created pagamento(s) gerado(s) automaticamente.'
          : 'Nenhum pagamento faltante para gerar.',
    );
  }

  Future<void> _exportPayrollSummaryPdf({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required String competence,
    required _PayrollSummary summary,
  }) async {
    try {
      final pdf = pw.Document();
      final empresaNome =
          companyData['nomeFantasia']?.toString().trim().isNotEmpty == true
          ? companyData['nomeFantasia'].toString()
          : companyData['razaoSocial']?.toString() ?? sessao.companyId;

      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Resumo mensal da folha',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Empresa: $empresaNome'),
            pw.Text('Competencia: $competence'),
            pw.Text('Gerado em: ${_formatDateTime(DateTime.now())}'),
            pw.SizedBox(height: 14),
            pw.Text(
              'Totais',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Bullet(text: 'Funcionarios: ${summary.totalEmployees}'),
            pw.Bullet(
              text: 'Pagamentos lancados: ${summary.registeredPayments}',
            ),
            pw.Bullet(
              text:
                  'Base sugerida: ${_formatCurrency(summary.suggestedGrossCents)}',
            ),
            pw.Bullet(
              text:
                  'Total lancado: ${_formatCurrency(summary.registeredGrossCents)}',
            ),
            pw.Bullet(text: 'Dias aprovados: ${summary.approvedDays}'),
            pw.Bullet(
              text: 'Servicos finalizados: ${summary.finishedServices}',
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Conferencia por funcionario',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...summary.lines.map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: line.hasDivergence
                          ? PdfColors.orange300
                          : PdfColors.grey300,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        line.employeeName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Sugerido: ${_formatCurrency(line.suggestedGrossCents)} | '
                        'Lancado: ${_formatCurrency(line.registeredGrossCents)}',
                      ),
                      pw.Text(
                        'Dias: ${line.approvedDays} | Horas: ${line.approvedHours} | '
                        'Servicos: ${line.finishedServices}',
                      ),
                      pw.Text(
                        line.hasDivergence
                            ? 'Status: Divergente'
                            : line.hasRegisteredPayment
                            ? 'Status: OK'
                            : 'Status: Pendente',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      await openPdfBytes(
        bytes: await pdf.save(),
        filename: 'resumo-mensal-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _msg('Resumo mensal gerado em PDF.');
    } catch (_) {
      _msg('Nao foi possivel gerar o resumo mensal.');
    }
  }

  Future<void> _exportPayrollClosurePdf({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required String competence,
  }) async {
    if (competence.trim().isEmpty) {
      _msg('Competencia invalida.');
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payroll_closures')
          .doc('${sessao.companyId}_$competence')
          .get();
      final data = snapshot.data();
      if (data == null) {
        _msg('Nao existe snapshot de fechamento para esta competencia.');
        return;
      }
      final pdf = pw.Document();
      final empresaNome =
          companyData['nomeFantasia']?.toString().trim().isNotEmpty == true
          ? companyData['nomeFantasia'].toString()
          : companyData['razaoSocial']?.toString() ?? sessao.companyId;
      final linesRaw = data['lines'];
      final lines = <Map<String, dynamic>>[
        if (linesRaw is List)
          for (final item in linesRaw)
            if (item is Map)
              item.map((key, value) => MapEntry(key.toString(), value)),
      ];
      final laborClosureRaw = data['laborClosure'];
      final laborClosure = laborClosureRaw is Map
          ? _WorkforceLaborCompetenceClosure.fromMap(
              laborClosureRaw.cast<String, dynamic>(),
            )
          : null;
      final laborLinesRaw = data['laborLines'];
      final laborLines = <Map<String, dynamic>>[
        if (laborLinesRaw is List)
          for (final item in laborLinesRaw)
            if (item is Map)
              item.map((key, value) => MapEntry(key.toString(), value)),
      ];

      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Relatorio de fechamento mensal',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Empresa: $empresaNome'),
            pw.Text('Empresa ID: ${sessao.companyId}'),
            pw.Text('Competencia: ${data['competence'] ?? competence}'),
            pw.Text(
              'Status: ${data['status'] == 'closed' ? 'Fechada' : 'Reaberta'}',
            ),
            pw.Text(
              'Responsavel: ${data['updatedByUserName'] ?? '-'} | '
              'Atualizado em: ${_formatDateTime(_toDate(data['updatedAt']))}',
            ),
            pw.Text('Observacao: ${data['lastNote'] ?? '-'}'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Totais consolidados',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Bullet(
              text:
                  'Base sugerida: ${_formatCurrency((data['suggestedGrossCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Bullet(
              text:
                  'Total lancado: ${_formatCurrency((data['registeredGrossCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Bullet(
              text:
                  'Pagamentos lancados: ${(data['registeredPayments'] as num?)?.toInt() ?? 0}',
            ),
            pw.Bullet(
              text:
                  'Funcionarios: ${(data['totalEmployees'] as num?)?.toInt() ?? 0}',
            ),
            pw.Bullet(
              text:
                  'Dias aprovados: ${(data['approvedDays'] as num?)?.toInt() ?? 0}',
            ),
            pw.Bullet(
              text:
                  'Servicos finalizados: ${(data['finishedServices'] as num?)?.toInt() ?? 0}',
            ),
            pw.Bullet(
              text:
                  'Pendencias: ${(data['pendingEmployees'] as num?)?.toInt() ?? 0}',
            ),
            pw.Bullet(
              text:
                  'Divergencias: ${(data['divergentEmployees'] as num?)?.toInt() ?? 0}',
            ),
            if (laborClosure != null) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Fechamento trabalhista consolidado',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Bullet(
                text:
                    'Status: ${laborClosure.status == 'closed'
                        ? 'Fechado'
                        : laborClosure.status == 'ready_for_close'
                        ? 'Pronto para fechar'
                        : 'Pendente de conferencia'}',
              ),
              pw.Bullet(
                text:
                    'Snapshots salvos: ${laborClosure.employeesWithSnapshot}/${laborClosure.totalEmployees}',
              ),
              pw.Bullet(
                text:
                    'Checklist: ${laborClosure.obligationsCompletedCount}/${laborClosure.obligationsTotalCount}',
              ),
              pw.Bullet(
                text:
                    '13o projetado: ${_formatCurrency(laborClosure.thirteenthProjectedCents)}',
              ),
              pw.Bullet(
                text:
                    'Ferias + 1/3 projetados: ${_formatCurrency(laborClosure.vacationProjectedCents + laborClosure.vacationBonusCents)}',
              ),
              pw.Bullet(
                text:
                    'Rescisao projetada: ${_formatCurrency(laborClosure.terminationProjectedCents)}',
              ),
              pw.Bullet(
                text:
                    'Observacao: ${laborClosure.notes.trim().isEmpty ? '-' : laborClosure.notes}',
              ),
            ],
            pw.SizedBox(height: 14),
            pw.Text(
              'Conferencia por funcionario',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...lines.map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: (line['hasDivergence'] as bool? ?? false)
                          ? PdfColors.orange300
                          : PdfColors.grey300,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        line['employeeName']?.toString() ?? '-',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Sugerido: ${_formatCurrency((line['suggestedGrossCents'] as num?)?.toInt() ?? 0)} | '
                        'Lancado: ${_formatCurrency((line['registeredGrossCents'] as num?)?.toInt() ?? 0)}',
                      ),
                      pw.Text(
                        'Dias: ${(line['approvedDays'] as num?)?.toInt() ?? 0} | '
                        'Horas: ${(line['approvedHours'] as num?)?.toInt() ?? 0} | '
                        'Servicos: ${(line['finishedServices'] as num?)?.toInt() ?? 0}',
                      ),
                      pw.Text(
                        (line['hasDivergence'] as bool? ?? false)
                            ? 'Status: Divergente'
                            : (line['hasRegisteredPayment'] as bool? ?? false)
                            ? 'Status: OK'
                            : 'Status: Pendente',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (laborLines.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Conferencia trabalhista por colaborador',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ...laborLines
                  .take(12)
                  .map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: (line['hasSavedSnapshot'] as bool? ?? false)
                                ? PdfColors.green300
                                : PdfColors.orange300,
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              line['employeeName']?.toString() ?? '-',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Base: ${_formatCurrency((line['grossReferenceCents'] as num?)?.toInt() ?? 0)} | '
                              '13o: ${_formatCurrency((line['thirteenthProjectedCents'] as num?)?.toInt() ?? 0)}',
                            ),
                            pw.Text(
                              'Ferias + 1/3: ${_formatCurrency(((line['vacationProjectedCents'] as num?)?.toInt() ?? 0) + ((line['vacationBonusCents'] as num?)?.toInt() ?? 0))} | '
                              'Rescisao: ${_formatCurrency((line['terminationProjectedCents'] as num?)?.toInt() ?? 0)}',
                            ),
                            pw.Text(
                              (line['hasSavedSnapshot'] as bool? ?? false)
                                  ? 'Snapshot: salvo'
                                  : 'Snapshot: pendente',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      );

      await openPdfBytes(
        bytes: await pdf.save(),
        filename:
            'fechamento-trabalhista-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _msg('Relatorio de fechamento gerado em PDF.');
    } catch (_) {
      _msg('Nao foi possivel gerar o PDF do fechamento.');
    }
  }
}
