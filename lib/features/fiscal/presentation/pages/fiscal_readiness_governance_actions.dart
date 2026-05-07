part of 'fiscal_readiness_page.dart';

extension _FiscalReadinessGovernanceActions on _FiscalReadinessPageState {
  Future<void> _saveFiscalSettings(
    Session sessao,
    _FiscalSettings settings,
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
            'fiscalMode': settings.mode.name,
            'fiscalFeatures': settings.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'settings_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalMode': settings.mode.name,
          'fiscalFeatures': settings.toMap(),
        },
      );
      _msg('Configuracao fiscal atualizada.');
    } catch (e) {
      _msg(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel salvar a configuracao fiscal.',
        ),
      );
    }
  }

  Future<void> _openFiscalSettingsRequestDialog(
    Session sessao,
    _FiscalSettings settings,
  ) async {
    var mode = settings.mode;
    var enableOfficialInvoicePrep = settings.enableOfficialInvoicePrep;
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar ajuste fiscal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<_FiscalMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Modo'),
                  items: const [
                    DropdownMenuItem(
                      value: _FiscalMode.simple,
                      child: Text('Simples'),
                    ),
                    DropdownMenuItem(
                      value: _FiscalMode.advanced,
                      child: Text('Completo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => mode = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: enableOfficialInvoicePrep,
                  onChanged: (value) =>
                      setDialogState(() => enableOfficialInvoicePrep = value),
                  title: const Text('NFS-e oficial'),
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
                    '${sessao.companyId}_fiscal_settings_${DateTime.now().millisecondsSinceEpoch}';
                await FirebaseFirestore.instance
                    .collection('period_closes')
                    .doc(requestId)
                    .set({
                      'companyId': sessao.companyId,
                      'module': 'fiscal_settings_change',
                      'competence': 'SETTINGS',
                      'status': 'PENDING_APPROVAL',
                      'requestedByUserId': sessao.userId,
                      'requestedByUserName': sessao.nome,
                      'requestedAt': FieldValue.serverTimestamp(),
                      'note': noteController.text.trim(),
                      'proposedFiscalMode': mode.name,
                      'proposedFiscalFeatures': {
                        'enableOfficialInvoicePrep': enableOfficialInvoicePrep,
                        'enableRealInvoiceIntegration': false,
                        'enablePayrollTaxPrep': false,
                        'enableThirteenthSalary': false,
                        'enableVacation': false,
                        'enableTermination': false,
                        'enableBenefits': false,
                      },
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                await _writeAuditLog(
                  sessao: sessao,
                  action: 'settings_change_requested',
                  entityPath: 'period_closes',
                  entityId: requestId,
                  after: {
                    'module': 'fiscal_settings_change',
                    'note': noteController.text.trim(),
                  },
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('Solicitacao fiscal enviada para aprovacao do dono.');
              },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
  }

  Future<void> _resolveFiscalSettingsRequest({
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
      final resolutionComment = await _askResolutionComment(approve: approve);
      if (resolutionComment == null) return;
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
          action: 'settings_change_rejected',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {'status': 'REJECTED', 'resolutionComment': resolutionComment},
        );
        _msg('Solicitacao rejeitada.');
        return;
      }

      final settingsRef = FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId);
      final before = await settingsRef.get();
      final features =
          (data['proposedFiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      await settingsRef.set({
        'companyId': sessao.companyId,
        'fiscalMode': data['proposedFiscalMode']?.toString() ?? 'simple',
        'fiscalFeatures': features,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
        action: 'settings_change_approved',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalMode': data['proposedFiscalMode']?.toString() ?? 'simple',
          'fiscalFeatures': features,
          'resolutionComment': resolutionComment,
        },
      );
      _msg('Configuracao fiscal aprovada e aplicada.');
    } catch (_) {
      _msg('Nao foi possivel resolver a solicitacao fiscal.');
    }
  }

  Future<void> _writeAuditLog({
    required Session sessao,
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
        'module': 'fiscal',
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

  Future<String?> _askResolutionComment({required bool approve}) async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Aprovar solicitacao' : 'Rejeitar solicitacao'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Comentario da decisao'),
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
            child: Text(approve ? 'Aprovar' : 'Rejeitar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

}
