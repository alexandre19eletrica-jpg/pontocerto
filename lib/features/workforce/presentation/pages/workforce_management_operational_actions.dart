part of 'workforce_management_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _WorkforceManagementOperationalActions on _WorkforceManagementPageState {
  Future<void> _openEmployeeRegistrationDialog({Employee? editingEmployee}) async {
    final isEditing = editingEmployee != null;
    final nomeController = TextEditingController(
      text: editingEmployee?.nomeCompleto ?? '',
    );
    final documentoController = TextEditingController(
      text: editingEmployee?.documento ?? '',
    );
    final pixController = TextEditingController(text: editingEmployee?.pix ?? '');
    final telefoneController = TextEditingController(
      text: editingEmployee?.telefone ?? '',
    );
    final emailController = TextEditingController(
      text: editingEmployee?.email ?? '',
    );
    final enderecoController = TextEditingController(
      text: editingEmployee?.endereco ?? '',
    );
    final cargoController = TextEditingController(
      text: editingEmployee?.cargo ?? '',
    );
    final salarioController = TextEditingController(
      text: editingEmployee?.salaryAmountCents == null
          ? ''
          : _currencyInput(editingEmployee!.salaryAmountCents!),
    );
    final comissaoController = TextEditingController(
      text: editingEmployee?.commissionPercent == null
          ? ''
          : editingEmployee!.commissionPercent!
              .toStringAsFixed(2)
              .replaceAll('.', ','),
    );
    var compensationType =
        editingEmployee?.compensationType ?? EmployeeCompensationType.monthly;
    DateTime? admissionDate = editingEmployee?.admissionDate;
    final drafts = <_EmployeeRegistrationDocumentDraft>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEditing
                ? 'Editar funcionario no Trabalhista'
                : 'Cadastrar funcionario no Trabalhista',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome completo *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: documentoController,
                    decoration: const InputDecoration(labelText: 'Documento *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pixController,
                    decoration: const InputDecoration(labelText: 'PIX *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: telefoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: enderecoController,
                    decoration: const InputDecoration(labelText: 'Endereco'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cargoController,
                    decoration: const InputDecoration(labelText: 'Cargo/funcao'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<EmployeeCompensationType>(
                    initialValue: compensationType,
                    decoration: const InputDecoration(labelText: 'Tipo de remuneracao'),
                    items: const [
                      DropdownMenuItem(
                        value: EmployeeCompensationType.monthly,
                        child: Text('Mensal'),
                      ),
                      DropdownMenuItem(
                        value: EmployeeCompensationType.weekly,
                        child: Text('Semanal'),
                      ),
                      DropdownMenuItem(
                        value: EmployeeCompensationType.daily,
                        child: Text('Diaria'),
                      ),
                      DropdownMenuItem(
                        value: EmployeeCompensationType.commission,
                        child: Text('Comissao'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => compensationType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: salarioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: compensationType == EmployeeCompensationType.commission
                          ? 'Valor base/garantia (opcional)'
                          : 'Valor da remuneracao *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: comissaoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Percentual de comissao (%)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Admissao: ${admissionDate == null ? '-' : _formatDate(admissionDate)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: admissionDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => admissionDate = picked);
                          }
                        },
                        child: const Text('Selecionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Documentos opcionais do registro',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _employeeRegistrationDocumentOptions)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickEmployeeRegistrationDocument(option);
                            if (picked == null) return;
                            setDialogState(() {
                              drafts.removeWhere((item) => item.category == option.category);
                              drafts.add(picked);
                            });
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(option.label),
                        ),
                    ],
                  ),
                  if (drafts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final item in drafts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file_outlined),
                        title: Text(item.label),
                        subtitle: Text(item.fileName),
                        trailing: IconButton(
                          onPressed: () => setDialogState(() {
                            drafts.removeWhere((draft) => draft.category == item.category);
                          }),
                          icon: const Icon(Icons.close_outlined),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                final documento = documentoController.text.trim();
                final email = emailController.text.trim();
                final pix = pixController.text.trim();
                final salaryAmountCents = _parseCurrencyToCents(salarioController.text);
                final commissionPercent = _parsePercent(comissaoController.text);
                if (nome.isEmpty || documento.isEmpty || email.isEmpty || pix.isEmpty) {
                  _msg('Preencha nome, documento, email e PIX.');
                  return;
                }
                if (compensationType != EmployeeCompensationType.commission &&
                    (salaryAmountCents == null || salaryAmountCents <= 0)) {
                  _msg('Informe um valor valido para a remuneracao.');
                  return;
                }
                if (compensationType == EmployeeCompensationType.commission &&
                    ((commissionPercent ?? 0) <= 0)) {
                  _msg('Informe o percentual de comissao.');
                  return;
                }
                try {
                  final service = EmployeeAccessService(ref);
                  final cleanTelefone = telefoneController.text.trim();
                  final cleanEndereco = enderecoController.text.trim();
                  final cleanCargo = cargoController.text.trim();
                  final notifier = ref.read(employeesProvider.notifier);
                  if (isEditing) {
                    final employeeId = editingEmployee.id;
                    if (!RegExp(r'^\d+$').hasMatch(employeeId)) {
                      await service.atualizarPerfilFuncionario(
                        employeeUid: employeeId,
                        nome: nome,
                        role: 'EMPLOYEE',
                        documento: documento,
                        pix: pix,
                        telefone: cleanTelefone,
                        email: email,
                        endereco: cleanEndereco,
                        cargo: cleanCargo,
                        admissionDate: admissionDate,
                        compensationType: _employeeCompensationApiValue(
                          compensationType,
                        ),
                        salaryAmountCents: salaryAmountCents,
                        commissionPercent: commissionPercent,
                      );
                    }
                    await notifier.update(
                      id: employeeId,
                      nomeCompleto: nome,
                      documento: documento,
                      pix: pix,
                      telefone: cleanTelefone,
                      email: email,
                      endereco: cleanEndereco,
                      cargo: cleanCargo,
                      admissionDate: admissionDate,
                      compensationType: compensationType,
                      salaryAmountCents: salaryAmountCents,
                      commissionPercent: commissionPercent,
                      role: editingEmployee.role,
                    );
                    setState(() => _employeeId = employeeId);
                  } else {
                    final status = await service.obterStatusConfiguracaoConvite();
                    if (!status.configured) {
                      _msg(
                        'Configuracao de convite incompleta: ${status.missing.join(', ')}',
                      );
                      return;
                    }
                    final access = await service.criarAcessoFuncionario(
                      nomeCompleto: nome,
                      email: email,
                      role: 'EMPLOYEE',
                    );
                    await service.atualizarPerfilFuncionario(
                      employeeUid: access.uid,
                      nome: nome,
                      role: 'EMPLOYEE',
                      documento: documento,
                      pix: pix,
                      telefone: cleanTelefone,
                      email: email,
                      endereco: cleanEndereco,
                      cargo: cleanCargo,
                      admissionDate: admissionDate,
                      compensationType: _employeeCompensationApiValue(
                        compensationType,
                      ),
                      salaryAmountCents: salaryAmountCents,
                      commissionPercent: commissionPercent,
                    );
                    await notifier.add(
                          id: access.uid,
                          nomeCompleto: nome,
                          documento: documento,
                          pix: pix,
                          telefone: cleanTelefone,
                          email: email,
                          endereco: cleanEndereco,
                          cargo: cleanCargo,
                          admissionDate: admissionDate,
                          compensationType: compensationType,
                          salaryAmountCents: salaryAmountCents,
                          commissionPercent: commissionPercent,
                          role: EmployeeRole.employee,
                        );
                    setState(() => _employeeId = access.uid);
                    for (final draft in drafts) {
                      await _saveEmployeeRegistrationDocument(
                        employeeId: access.uid,
                        employeeName: nome,
                        draft: draft,
                      );
                    }
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _msg(
                    isEditing
                        ? 'Cadastro trabalhista atualizado.'
                        : drafts.isEmpty
                            ? 'Funcionario cadastrado no Trabalhista.'
                            : 'Funcionario cadastrado e documentos salvos.',
                  );
                } catch (error) {
                  _msg(
                    isEditing
                        ? 'Nao foi possivel atualizar o cadastro trabalhista.'
                        : 'Nao foi possivel concluir o cadastro trabalhista.',
                  );
                }
              },
              child: Text(isEditing ? 'Salvar alteracoes' : 'Salvar cadastro'),
            ),
          ],
        ),
      ),
    );

    nomeController.dispose();
    documentoController.dispose();
    pixController.dispose();
    telefoneController.dispose();
    emailController.dispose();
    enderecoController.dispose();
    cargoController.dispose();
    salarioController.dispose();
    comissaoController.dispose();
  }

  Future<_EmployeeRegistrationDocumentDraft?> _pickEmployeeRegistrationDocument(
    _EmployeeRegistrationDocumentOption option,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file =
        result != null && result.files.isNotEmpty ? result.files.first : null;
    if (file == null) {
      return null;
    }
    try {
      final prepared = await MobileUploadOptimizer.preparePlatformFile(
        file: file,
        fallbackContentType: _contentTypeFromFileName(file.name),
      );
      return _EmployeeRegistrationDocumentDraft(
        category: option.category,
        label: option.label,
        fileName: prepared.fileName,
        bytes: prepared.bytes,
        contentType: prepared.contentType,
      );
    } on MobileUploadOptimizerException catch (error) {
      _msg(error.message);
      return null;
    }
  }

  Future<void> _saveEmployeeRegistrationDocument({
    required String employeeId,
    required String employeeName,
    required _EmployeeRegistrationDocumentDraft draft,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    final docId = FirebaseFirestore.instance.collection('employee_registration_documents').doc().id;
    final storagePath =
        'companies/${sessao.companyId}/employee_registration_documents/$employeeId/$docId-${draft.fileName}';
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    await storageRef.putData(
      draft.bytes,
      SettableMetadata(contentType: draft.contentType),
    );
    final downloadUrl = await storageRef.getDownloadURL();
    await FirebaseFirestore.instance
        .collection('employee_registration_documents')
        .doc(docId)
        .set({
      'companyId': sessao.companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'category': draft.category,
      'label': draft.label,
      'fileName': draft.fileName,
      'contentType': draft.contentType,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUserId': sessao.userId,
    });
  }

  Future<void> _openPayrollDialog(
    Employee employee, {
    required _PayrollMetrics? metrics,
  }) async {
    var paymentType = employee.compensationType;
    final quantityController = TextEditingController(
      text: switch (employee.compensationType) {
        EmployeeCompensationType.monthly => '1',
        EmployeeCompensationType.weekly => '1',
        EmployeeCompensationType.daily =>
          metrics?.approvedDays.toString() ?? '',
        EmployeeCompensationType.commission =>
          metrics == null || metrics.finishedServicesValueCents <= 0
              ? ''
              : _currencyInput(metrics.finishedServicesValueCents),
      },
    );
    final discountsController = TextEditingController(text: '0,00');
    final bonusController = TextEditingController(text: '0,00');
    DateTime? selectedPaymentDate;
    var markAsPaid = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Lancar pagamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Funcionario: ${employee.nomeCompleto}'),
                const SizedBox(height: 8),
                DropdownButtonFormField<EmployeeCompensationType>(
                  initialValue: paymentType,
                  decoration: const InputDecoration(labelText: 'Tipo do pagamento'),
                  items: const [
                    DropdownMenuItem(
                      value: EmployeeCompensationType.daily,
                      child: Text('Diaria'),
                    ),
                    DropdownMenuItem(
                      value: EmployeeCompensationType.weekly,
                      child: Text('Semanal'),
                    ),
                    DropdownMenuItem(
                      value: EmployeeCompensationType.monthly,
                      child: Text('Mensal'),
                    ),
                    DropdownMenuItem(
                      value: EmployeeCompensationType.commission,
                      child: Text('Comissao'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => paymentType = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: markAsPaid,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Marcar como pago ao lancar'),
                  subtitle: Text(
                    markAsPaid
                        ? 'Vai refletir hoje no financeiro da empresa como saida/despesa.'
                        : 'Se desmarcado, voce pode informar a data prevista do pagamento.',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      markAsPaid = value;
                      if (markAsPaid) {
                        selectedPaymentDate = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: switch (paymentType) {
                      EmployeeCompensationType.daily => 'Quantidade de dias',
                      EmployeeCompensationType.weekly =>
                        'Quantidade de semanas',
                      EmployeeCompensationType.monthly =>
                        'Quantidade de periodos',
                      EmployeeCompensationType.commission =>
                        'Base de servicos (R\$)',
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bonusController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Bonus/acrescimos (R\$)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: discountsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Descontos (R\$)',
                  ),
                ),
                if (!markAsPaid) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Data prevista do pagamento: ${_formatDate(selectedPaymentDate)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedPaymentDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedPaymentDate = picked);
                          }
                        },
                        child: const Text('Selecionar'),
                      ),
                      if (selectedPaymentDate != null)
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => selectedPaymentDate = null),
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                ],
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
                final competence = _competenciaController.text.trim();
                final parsedCompetence = _parseCompetence(competence);
                if (parsedCompetence == null) {
                  _msg('Competencia invalida.');
                  return;
                }
                final gross = _calculateGrossFromEmployee(
                  employee,
                  quantityController.text,
                  metrics: metrics,
                  compensationType: paymentType,
                );
                final bonus = _parseCurrencyToCents(bonusController.text) ?? 0;
                final discounts =
                    _parseCurrencyToCents(discountsController.text) ?? 0;
                if (gross <= 0 && bonus <= 0) {
                  _msg('Informe uma base valida para o pagamento.');
                  return;
                }
                try {
                  await _actions.createPayment(
                    employeeId: employee.id,
                    competenceYear: parsedCompetence.$1,
                    competenceMonth: parsedCompetence.$2,
                    grossCents: gross + bonus,
                    discountsCents: discounts,
                    dueDate: selectedPaymentDate,
                    paymentType: _employeeCompensationApiValue(paymentType),
                    markAsPaid: markAsPaid,
                  );
                } on FinanceActionException catch (e) {
                  _msg(e.message);
                  return;
                } catch (_) {
                  _msg('Nao foi possivel lancar o pagamento.');
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('Pagamento lancado com sucesso.');
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();
    discountsController.dispose();
    bonusController.dispose();
  }

  Future<void> _generatePayrollDocument(
    BuildContext context, {
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required Employee employee,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required _PayrollDocumentType type,
    required String competence,
    _OperationalDocumentData? operationalData,
  }) async {
    try {
      final sequence = await _reservePayrollDocumentSequence(sessao, type);
      final signature = await _askSimpleSignatureData(
        companyData: companyData,
        employee: employee,
        competence: competence,
        documentLabel: _documentTypeLabel(type),
      );
      if (signature == null) {
        return;
      }
      final bytes = await _buildPayrollPdf(
        sessao: sessao,
        companyData: companyData,
        companySettings: companySettings,
        employee: employee,
        payment: payment,
        metrics: metrics,
        signature: signature,
        type: type,
        competence: competence,
        sequenceLabel: _payrollDocumentSequenceLabelForType(type, sequence),
        operationalData: operationalData,
      );
      await FirebaseFirestore.instance.collection('payroll_documents').add({
        'companyId': sessao.companyId,
        'employeeId': employee.id,
        'employeeName': employee.nomeCompleto,
        'title': _documentTitle(type, employee.nomeCompleto, competence),
        'sequenceNumber': sequence,
        'sequenceLabel': _payrollDocumentSequenceLabelForType(type, sequence),
        'type': type.name,
        'typeLabel': _documentTypeLabel(type),
        'docGroup': type == _PayrollDocumentType.contract
            ? 'contract'
            : 'payroll',
        'competence': competence,
        'referenceDate': operationalData?.referenceDate.toIso8601String(),
        'notes': operationalData?.notes,
        'grossCents':
            operationalData?.amountCents ??
            payment?.valorCents ??
            metrics?.suggestedGrossCents ??
            employee.salaryAmountCents ??
            0,
        'netCents':
            operationalData?.amountCents ??
            payment?.valorCents ??
            employee.salaryAmountCents ??
            0,
        'approvedDays': metrics?.approvedDays ?? 0,
        'approvedHours': metrics?.approvedHours ?? 0,
        'finishedServices': metrics?.finishedServices ?? 0,
        'finishedServicesValueCents': metrics?.finishedServicesValueCents ?? 0,
        'companySignerName': signature.companySignerName,
        'employeeSignerName': signature.employeeSignerName,
        'signatureMethod': signature.signatureMethod,
        'signatureDeviceLabel': signature.signatureDeviceLabel,
        'signatureReference': signature.signatureReference,
        'signatureAcceptedAt': signature.acceptedAt.toIso8601String(),
        'createdByUserId': sessao.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final opened = await _tryOpenGeneratedPdf(bytes);
      if (opened) {
        _msg('${_documentTypeLabel(type)} gerado com sucesso.');
      } else {
        _msg(
          '${_documentTypeLabel(type)} gerado e salvo, mas o PDF nao abriu neste dispositivo.',
        );
      }
    } catch (e) {
      unawaited(
        RuntimeIncidentReporter.instance.capture(
          source: 'workforce_contract_generation',
          error: e,
          severity: 'warning',
          category: 'workforce',
          screenLabel: 'Trabalhista > Contratos',
          extra: {
            'documentType': type.name,
            'employeeId': employee.id,
            'employeeName': employee.nomeCompleto,
            'competence': competence,
          },
        ),
      );
      _msg(_documentGenerationErrorMessage(e));
    }
  }

  Future<bool> _tryOpenGeneratedPdf(Uint8List bytes) async {
    try {
      await openPdfBytes(
        bytes: bytes,
        filename: 'documento-trabalhista-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _documentGenerationErrorMessage(Object error) {
    if (error is FirebaseException && (error.message?.trim().isNotEmpty ?? false)) {
      return error.message!;
    }
    return 'Nao foi possivel gerar o documento.';
  }

  Future<void> _generateOperationalDocument(
    BuildContext context, {
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required Employee employee,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required _PayrollDocumentType type,
    required String competence,
  }) async {
    final operationalData = await _askOperationalDocumentData(
      employee: employee,
      payment: payment,
      metrics: metrics,
      type: type,
      competence: competence,
    );
    if (operationalData == null) {
      return;
    }
    if (!mounted || !context.mounted) {
      return;
    }
    await _generatePayrollDocument(
      context,
      sessao: sessao,
      companyData: companyData,
      companySettings: companySettings,
      employee: employee,
      payment: payment,
      metrics: metrics,
      type: type,
      competence: competence,
      operationalData: operationalData,
    );
  }

  Future<void> _openBulkPayrollDialog(
    List<Employee> employees, {
    required Map<String, dynamic> companySettings,
    required String competence,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) async {
    final selecionados = <String>{
      for (final employee in employees) employee.id,
    };
    EmployeeCompensationType? overrideType;
    DateTime? selectedPaymentDate;
    var markAsPaid = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Lancar pagamento em massa'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Competencia: $competence'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<EmployeeCompensationType?>(
                        initialValue: overrideType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo do pagamento em massa',
                        ),
                        items: const [
                          DropdownMenuItem<EmployeeCompensationType?>(
                            value: null,
                            child: Text('Usar tipo cadastrado'),
                          ),
                          DropdownMenuItem<EmployeeCompensationType?>(
                            value: EmployeeCompensationType.daily,
                            child: Text('Diaria'),
                          ),
                          DropdownMenuItem<EmployeeCompensationType?>(
                            value: EmployeeCompensationType.weekly,
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem<EmployeeCompensationType?>(
                            value: EmployeeCompensationType.monthly,
                            child: Text('Mensal'),
                          ),
                          DropdownMenuItem<EmployeeCompensationType?>(
                            value: EmployeeCompensationType.commission,
                            child: Text('Comissao'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => overrideType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: markAsPaid,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Marcar pagamentos como pagos ao lancar'),
                        subtitle: Text(
                          markAsPaid
                              ? 'Vai refletir hoje no financeiro da empresa como saida/despesa.'
                              : 'Se desmarcado, voce pode definir a data prevista do pagamento.',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            markAsPaid = value;
                            if (markAsPaid) {
                              selectedPaymentDate = null;
                            }
                          });
                        },
                      ),
                      if (!markAsPaid) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Data prevista do pagamento: ${_formatDate(selectedPaymentDate)}',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedPaymentDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedPaymentDate = picked);
                                }
                              },
                              child: const Text('Selecionar'),
                            ),
                            if (selectedPaymentDate != null)
                              TextButton(
                                onPressed: () => setDialogState(() => selectedPaymentDate = null),
                                child: const Text('Limpar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selecionados
                                  ..clear()
                                  ..addAll(employees.map((item) => item.id));
                              });
                            },
                            child: const Text('Marcar todos'),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(selecionados.clear);
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final employee in employees)
                        Builder(
                          builder: (context) {
                            final metrics = _buildPayrollMetrics(
                              employee: employee,
                              competence: competence,
                              workEntries: workEntries,
                              tasks: tasks,
                            );
                            final effectiveType = overrideType ?? employee.compensationType;
                            final suggestedCents =
                                _suggestedGrossForType(
                                  employee,
                                  effectiveType,
                                  metrics: metrics,
                                );
                            return CheckboxListTile(
                              value: selecionados.contains(employee.id),
                              contentPadding: EdgeInsets.zero,
                              title: Text(employee.nomeCompleto),
                              subtitle: Text(
                                'Tipo: ${_compensationTypeLabel(effectiveType)} | Valor previsto: ${_formatCurrency(suggestedCents)}',
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selecionados.add(employee.id);
                                  } else {
                                    selecionados.remove(employee.id);
                                  }
                                });
                              },
                            );
                          },
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
                    if (_parseCompetence(competence) == null) {
                      _msg('Competencia invalida.');
                      return;
                    }
                    if (_isPayrollClosed(companySettings, competence)) {
                      _msg('Competencia fechada. Lancamento bloqueado.');
                      return;
                    }
                    if (selecionados.isEmpty) {
                      _msg('Selecione ao menos um colaborador.');
                      return;
                    }
                    final parsedCompetence = _parseCompetence(competence);
                    if (parsedCompetence == null) {
                      _msg('Competencia invalida.');
                      return;
                    }

                    try {
                      final items = <FinanceBulkPaymentInput>[];
                      var existingCount = 0;
                      for (final employeeId in selecionados) {
                        final employee = employees.firstWhere((item) => item.id == employeeId);
                        final metrics = _buildPayrollMetrics(
                          employee: employee,
                          competence: competence,
                          workEntries: workEntries,
                          tasks: tasks,
                        );
                        final registeredGross = _registeredGrossForCompetence(
                          payments,
                          employeeId,
                          competence,
                        );
                        if (_isPayrollCovered(
                          suggestedGrossCents: metrics.suggestedGrossCents,
                          registeredGrossCents: registeredGross,
                        )) {
                          existingCount++;
                          continue;
                        }
                        final effectiveType = overrideType ?? employee.compensationType;
                        final grossCents = _suggestedGrossForType(
                          employee,
                          effectiveType,
                          metrics: metrics,
                        );
                        if (grossCents <= 0) {
                          continue;
                        }
                        items.add(FinanceBulkPaymentInput(
                          employeeId: employeeId,
                          grossCents: grossCents,
                          discountsCents: 0,
                          dueDate: selectedPaymentDate,
                          paymentType: _employeeCompensationApiValue(effectiveType),
                          markAsPaid: markAsPaid,
                        ));
                      }
                      if (items.isEmpty) {
                        _msg(
                          existingCount > 0
                              ? 'Os pagamentos selecionados ja existem ou nao possuem valor para lancamento.'
                              : 'Nenhum pagamento valido para lancar.',
                        );
                        return;
                      }
                      final result = await _actions.createPaymentsBulk(
                        competenceYear: parsedCompetence.$1,
                        competenceMonth: parsedCompetence.$2,
                        items: items,
                      );
                      final parts = <String>[];
                      if (result.createdCount > 0) {
                        parts.add(
                          result.createdCount == 1
                              ? '1 pagamento lancado'
                              : '${result.createdCount} pagamentos lancados',
                        );
                      }
                      if (existingCount + result.skippedCount > 0) {
                        final skippedTotal = existingCount + result.skippedCount;
                        parts.add(
                          skippedTotal == 1
                              ? '1 pagamento ja existente ou sem valor'
                              : '$skippedTotal pagamentos ignorados',
                        );
                      }
                      if (result.failedCount > 0) {
                        parts.add(
                          result.failedCount == 1
                              ? '1 pagamento com falha'
                              : '${result.failedCount} pagamentos com falha',
                        );
                      }
                      if (result.failed.isNotEmpty) {
                        final firstError = result.failed.first.message.trim();
                        if (firstError.isNotEmpty) {
                          parts.add(firstError);
                        }
                      }
                      if (parts.isEmpty) {
                        parts.add('Nenhum pagamento foi gerado.');
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      _msg(parts.join('. '));
                    } on FinanceActionException catch (e) {
                      _msg(e.message);
                      return;
                    } catch (_) {
                      _msg('Nao foi possivel lancar os pagamentos.');
                      return;
                    }

                    if (!context.mounted) return;
                  },
                  child: const Text('Lancar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _buildPayrollPdf({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required Employee employee,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required _SimpleSignatureData signature,
    required _PayrollDocumentType type,
    required String competence,
    required String sequenceLabel,
    _OperationalDocumentData? operationalData,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: StandardPdfDocument.pageTheme(),
        build: (_) => _buildPayrollPdfWidgets(
          sessao: sessao,
          companyData: companyData,
          companySettings: companySettings,
          employee: employee,
          payment: payment,
          metrics: metrics,
          signature: signature,
          type: type,
          competence: competence,
          sequenceLabel: sequenceLabel,
          operationalData: operationalData,
        ),
      ),
    );

    return pdf.save();
  }

  List<pw.Widget> _buildPayrollPdfWidgets({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required Employee employee,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required _SimpleSignatureData signature,
    required _PayrollDocumentType type,
    required String competence,
    required String sequenceLabel,
    _OperationalDocumentData? operationalData,
  }) {
    final empresaNome =
        companyData['nomeFantasia']?.toString().trim().isNotEmpty == true
        ? companyData['nomeFantasia'].toString()
        : companyData['razaoSocial']?.toString() ?? sessao.companyId;
    final employeeSalary =
        operationalData?.amountCents ??
        payment?.valorCents ??
        metrics?.suggestedGrossCents ??
        employee.salaryAmountCents ??
        0;
    final clauses = (companySettings['employeeClausesFullText'] ??
            companySettings['clausesFullText'])
        ?.toString()
        .trim();
    final metadata = <StandardPdfField>[
      StandardPdfField('Empresa ID', sessao.companyId),
      StandardPdfField('Funcionario', employee.nomeCompleto),
      StandardPdfField(
        'Documento',
        employee.documento.trim().isEmpty ? '-' : employee.documento,
      ),
      StandardPdfField(
        'Cargo/funcao',
        (employee.cargo ?? '').trim().isEmpty ? '-' : employee.cargo!,
      ),
      StandardPdfField('Competencia', competence),
      StandardPdfField('Numero interno', sequenceLabel),
      StandardPdfField('Remuneracao', _compensationLabel(employee)),
      if (operationalData?.referenceDate != null)
        StandardPdfField(
          'Data de referencia',
          _formatDate(operationalData!.referenceDate),
        ),
    ];

    if (type == _PayrollDocumentType.contract) {
      return [
        StandardPdfDocument.header(
          title: _documentTypeLabel(type),
          subtitle:
              'Documento trabalhista interno padronizado para formalizacao e arquivo da empresa.',
          company: StandardPdfCompanyInfo(
            name: empresaNome,
            document: companyData['cnpj']?.toString().trim() ?? '',
          ),
          metadata: metadata,
        ),
        StandardPdfDocument.section(
          title: 'Condicoes do contrato',
          children: [
            ...StandardPdfDocument.bulletList(
              _defaultContractClauses(employee, employeeSalary),
            ),
          ],
        ),
        if (clauses != null && clauses.isNotEmpty)
          StandardPdfDocument.section(
            title: 'Clausulas complementares da empresa',
            children: [
              ..._buildPdfTextParagraphs(clauses),
            ],
          ),
        StandardPdfDocument.section(
          title: 'Assinatura e aceite',
          children: [
            StandardPdfDocument.signatureBlock([
              StandardPdfSigner(
                label: 'Representante da empresa',
                name: signature.companySignerName,
                details: [
                  'Metodo: ${_signatureMethodLabel(signature.signatureMethod)}',
                ],
              ),
              StandardPdfSigner(
                label: 'Colaborador',
                name: signature.employeeSignerName,
                details: [
                  'Aceite registrado em ${_formatDateTime(signature.acceptedAt)}',
                  'Dispositivo/plataforma: ${signature.signatureDeviceLabel}',
                  if ((signature.signatureReference ?? '').isNotEmpty)
                    'Referencia digital: ${signature.signatureReference}',
                ],
              ),
            ]),
          ],
        ),
      ];
    }

    final summaryItems = <String>[
      'Valor base: ${_formatCurrency(employeeSalary)}',
      'Status do pagamento: ${_paymentStatusLabel(payment?.status)}',
      if (metrics != null) 'Dias aprovados: ${metrics.approvedDays}',
      if (metrics != null) 'Horas aprovadas: ${metrics.approvedHours}',
      if (metrics != null) 'Servicos finalizados: ${metrics.finishedServices}',
      if (metrics != null)
        'Valor dos servicos: ${_formatCurrency(metrics.finishedServicesValueCents)}',
      if (metrics != null)
        'Base sugerida do sistema: ${_formatCurrency(metrics.suggestedGrossCents)}',
    ];

    return [
      StandardPdfDocument.header(
        title: _documentTypeLabel(type),
        subtitle:
            'Documento padronizado para folha, comprovacao interna e envio organizado ao cliente ou contador.',
        company: StandardPdfCompanyInfo(
          name: empresaNome,
          document: companyData['cnpj']?.toString().trim() ?? '',
        ),
        metadata: metadata,
      ),
      StandardPdfDocument.section(
        title: 'Resumo da competencia',
        children: [
          ...StandardPdfDocument.bulletList(summaryItems),
        ],
      ),
      StandardPdfDocument.section(
        title: 'Narrativa do documento',
        children: [
          StandardPdfDocument.paragraph(
            _documentNarrative(type, employee, competence, employeeSalary),
          ),
          if (type == _PayrollDocumentType.incomeProof)
            ..._buildPdfTextParagraphs(
              'Declaramos para os devidos fins que o colaborador acima possui comprovacao interna de renda no valor indicado.',
            ),
          if (type == _PayrollDocumentType.receipt)
            ..._buildPdfTextParagraphs(
              'Recibo simples de pagamento para assinatura e arquivo interno da empresa.',
            ),
          if (type == _PayrollDocumentType.thirteenthReceipt)
            StandardPdfDocument.paragraph(
              'Recibo interno de 13 salario para conferencia, aceite e arquivo da competencia.',
            ),
          if (type == _PayrollDocumentType.vacationReceipt)
            StandardPdfDocument.paragraph(
              'Recibo simples de ferias com uso interno para conferencia da empresa e envio ao contador.',
            ),
          if (type == _PayrollDocumentType.terminationStatement)
            StandardPdfDocument.paragraph(
              'Termo simples de rescisao para organizacao interna. Exige revisao contabil e juridica antes de uso definitivo.',
            ),
        ],
      ),
      if (operationalData != null && operationalData.notes.trim().isNotEmpty)
        StandardPdfDocument.section(
          title: 'Observacoes operacionais',
          children: [
            StandardPdfDocument.paragraph(operationalData.notes),
          ],
        ),
      StandardPdfDocument.section(
        title: 'Assinatura e aceite',
        children: [
          StandardPdfDocument.signatureBlock([
            StandardPdfSigner(
              label: 'Representante da empresa',
              name: signature.companySignerName,
              details: [
                'Metodo: ${_signatureMethodLabel(signature.signatureMethod)}',
              ],
            ),
            StandardPdfSigner(
              label: 'Colaborador',
              name: signature.employeeSignerName,
              details: [
                'Aceite registrado em ${_formatDateTime(signature.acceptedAt)}',
                'Dispositivo/plataforma: ${signature.signatureDeviceLabel}',
                if ((signature.signatureReference ?? '').isNotEmpty)
                  'Referencia digital: ${signature.signatureReference}',
                'Gerado em ${_formatDateTime(DateTime.now())}',
              ],
            ),
          ]),
        ],
      ),
    ];
  }

  List<pw.Widget> _buildPdfTextParagraphs(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const <pw.Widget>[];
    }

    final blocks = normalized
        .split(RegExp(r'\n\s*\n'))
        .expand((block) => _splitPdfTextBlock(block.trim()))
        .where((block) => block.isNotEmpty)
        .toList(growable: false);

    return blocks
        .map(
          (block) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(block),
          ),
        )
        .toList(growable: false);
  }

  List<String> _splitPdfTextBlock(String text, {int maxChars = 420}) {
    if (text.length <= maxChars) {
      return <String>[text];
    }

    final parts = <String>[];
    final words = text.split(RegExp(r'\s+'));
    final buffer = StringBuffer();

    for (final word in words) {
      final candidate = buffer.isEmpty ? word : '${buffer.toString()} $word';
      if (candidate.length > maxChars && buffer.isNotEmpty) {
        parts.add(buffer.toString().trim());
        buffer
          ..clear()
          ..write(word);
      } else {
        buffer
          ..clear()
          ..write(candidate);
      }
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      parts.add(tail);
    }
    return parts;
  }

  List<String> _defaultContractClauses(Employee employee, int valueCents) {
    return [
      '1. O colaborador prestara servicos/atividades conforme orientacao da empresa e funcao registrada como ${employee.cargo ?? 'nao informada'}.',
      '2. A remuneracao cadastrada no sistema esta parametrizada como ${_compensationLabel(employee)}.',
      '3. A empresa mantera registros internos de pagamentos, recibos, holerites, apontamentos e demais comprovacoes operacionais.',
      '4. O colaborador declara receber orientacoes sobre jornada, uso de ferramentas, regras internas, seguranca e boas praticas.',
      '5. Toda alteracao de valor, funcao, rotina, descontos ou beneficios deve ser formalizada em documento complementar.',
      '6. Este modelo exige validacao juridica individual antes de uso definitivo, especialmente para prevencao de passivos trabalhistas.',
      '7. Valor de referencia atualmente registrado no app: ${_formatCurrency(valueCents)}.',
    ];
  }

  String _documentNarrative(
    _PayrollDocumentType type,
    Employee employee,
    String competence,
    int valueCents,
  ) {
    return switch (type) {
      _PayrollDocumentType.payslip =>
        'Holerite simples referente a competencia $competence, em nome de ${employee.nomeCompleto}, '
            'no valor de ${_formatCurrency(valueCents)}.',
      _PayrollDocumentType.receipt =>
        'Recibo simples referente ao pagamento do funcionario ${employee.nomeCompleto}, '
            'competencia $competence, no valor de ${_formatCurrency(valueCents)}.',
      _PayrollDocumentType.incomeProof =>
        'Comprovante interno de renda de ${employee.nomeCompleto}, referente a $competence, '
            'com valor declarado de ${_formatCurrency(valueCents)}.',
      _PayrollDocumentType.contract => '',
      _PayrollDocumentType.thirteenthReceipt =>
        'Recibo simples de 13 salario de ${employee.nomeCompleto}, referente a $competence, '
            'com valor registrado de ${_formatCurrency(valueCents)}.',
      _PayrollDocumentType.vacationReceipt =>
        'Recibo simples de ferias de ${employee.nomeCompleto}, referente a $competence, '
            'com valor registrado de ${_formatCurrency(valueCents)}.',
      _PayrollDocumentType.terminationStatement =>
        'Termo interno de rescisao de ${employee.nomeCompleto}, referente a $competence, '
            'com valor de referencia de ${_formatCurrency(valueCents)}.',
    };
  }

  Future<_OperationalDocumentData?> _askOperationalDocumentData({
    required Employee employee,
    required Payment? payment,
    required _PayrollMetrics? metrics,
    required _PayrollDocumentType type,
    required String competence,
  }) async {
    final defaultAmount =
        payment?.valorCents ??
        metrics?.suggestedGrossCents ??
        employee.salaryAmountCents ??
        0;
    final amountController = TextEditingController(
      text: _currencyInput(defaultAmount),
    );
    final notesController = TextEditingController();
    DateTime referenceDate = DateTime.now();
    _OperationalDocumentData? result;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_documentTypeLabel(type)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Funcionario: ${employee.nomeCompleto}'),
                const SizedBox(height: 8),
                Text('Competencia: $competence'),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor de referencia (R\$)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Data de referencia: ${_formatDate(referenceDate)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: referenceDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => referenceDate = picked);
                        }
                      },
                      child: const Text('Selecionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes',
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
                final amount = _parseCurrencyToCents(amountController.text);
                if (amount == null || amount <= 0) {
                  _msg('Informe um valor valido.');
                  return;
                }
                result = _OperationalDocumentData(
                  amountCents: amount,
                  referenceDate: referenceDate,
                  notes: notesController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _openInvoiceDialog({
    required Session sessao,
    QueryDocumentSnapshot<Map<String, dynamic>>? editing,
  }) async {
    final data = editing?.data() ?? <String, dynamic>{};
    final clientController = TextEditingController(
      text: data['clientName']?.toString() ?? '',
    );
    final documentController = TextEditingController(
      text: data['clientDocument']?.toString() ?? '',
    );
    final serviceController = TextEditingController(
      text: data['serviceDescription']?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: data['amountCents'] == null
          ? ''
          : _currencyInput((data['amountCents'] as num).toInt()),
    );
    final officialNumberController = TextEditingController(
      text: data['officialNumber']?.toString() ?? '',
    );
    final portalController = TextEditingController(
      text: data['officialPortalUrl']?.toString() ?? '',
    );
    var status = data['status']?.toString() ?? 'DRAFT';
    DateTime issueDate = _toDate(data['issueDate']);
    DateTime serviceDate = _toDate(data['serviceDate']);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 860),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              editing == null
                                  ? 'Nova nota de servico'
                                  : 'Editar nota de servico',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Preencha os blocos abaixo como em um emissor operacional: dados do cliente, dados fiscais e detalhes do servico.',
                              style: TextStyle(
                                color: AppBrandColors.softText,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Competencia ${_competenciaController.text.trim()}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: AppDesktopSplit(
                        breakpoint: 960,
                        sidebarFlex: 5,
                        contentFlex: 6,
                        sidebar: Column(
                          children: [
                            AppWorkspaceCard(
                              title: 'Cliente e tomador',
                              subtitle:
                                  'Dados cadastrais principais para identificar quem recebe a nota.',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: clientController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cliente / razao social',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: documentController,
                                    decoration: const InputDecoration(
                                      labelText: 'CPF/CNPJ cliente',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: portalController,
                                    decoration: const InputDecoration(
                                      labelText: 'Link portal oficial',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppWorkspaceCard(
                              title: 'Servico prestado',
                              subtitle:
                                  'Detalhes operacionais do item faturado.',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: serviceController,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      labelText: 'Descricao do servico',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Valor total (R\$)',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          children: [
                            AppWorkspaceCard(
                              title: 'Cabecalho fiscal',
                              subtitle:
                                  'Numero, status e datas de emissao da nota.',
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: status,
                                    decoration: const InputDecoration(
                                      labelText: 'Status da nota',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'DRAFT',
                                        child: Text('Rascunho'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'EMITTED',
                                        child: Text('Emitida'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'CANCELED',
                                        child: Text('Cancelada'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setStateDialog(() => status = value);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: officialNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Numero oficial da NFS-e',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _invoiceDateTile(
                                          label: 'Data de emissao',
                                          value: _formatDate(issueDate),
                                          onPressed: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: issueDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setStateDialog(
                                                () => issueDate = picked,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _invoiceDateTile(
                                          label: 'Data do servico',
                                          value: _formatDate(serviceDate),
                                          onPressed: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: serviceDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setStateDialog(
                                                () => serviceDate = picked,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppWorkspaceCard(
                              title: 'Resumo de validacao',
                              subtitle:
                                  'Checklist rapido antes de gravar a nota no sistema.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _invoiceHintLine(
                                    'Cliente preenchido',
                                    clientController.text.trim().isNotEmpty,
                                  ),
                                  _invoiceHintLine(
                                    'Servico preenchido',
                                    serviceController.text.trim().isNotEmpty,
                                  ),
                                  _invoiceHintLine(
                                    'Valor informado',
                                    (_parseCurrencyToCents(
                                              amountController.text,
                                            ) ??
                                            0) >
                                        0,
                                  ),
                                  _invoiceHintLine(
                                    'Link oficial opcional',
                                    portalController.text.trim().isNotEmpty,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                final amount = _parseCurrencyToCents(amountController.text);
                if (clientController.text.trim().isEmpty ||
                    serviceController.text.trim().isEmpty ||
                    amount == null ||
                    amount <= 0) {
                  _msg('Preencha os campos obrigatorios.');
                  return;
                }

                final payload = <String, dynamic>{
                  'companyId': sessao.companyId,
                  'clientName': clientController.text.trim(),
                  'clientDocument': documentController.text.trim(),
                  'serviceDescription': serviceController.text.trim(),
                  'amountCents': amount,
                  'status': status,
                  'officialNumber': officialNumberController.text.trim(),
                  'officialPortalUrl': portalController.text.trim(),
                  'issueDate': Timestamp.fromDate(issueDate),
                  'serviceDate': Timestamp.fromDate(serviceDate),
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (editing == null)
                    'createdAt': FieldValue.serverTimestamp(),
                };

                try {
                  if (editing == null) {
                    await FirebaseFirestore.instance
                        .collection('service_invoices')
                        .add(payload);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('service_invoices')
                        .doc(editing.id)
                        .set(payload, SetOptions(merge: true));
                  }
                } catch (_) {
                  _msg('Nao foi possivel salvar a nota.');
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('Nota de servico salva.');
              },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar nota'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    clientController.dispose();
    documentController.dispose();
    serviceController.dispose();
    amountController.dispose();
    officialNumberController.dispose();
    portalController.dispose();
  }

  Widget _invoiceDateTile({
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: onPressed, child: const Text('Alterar')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invoiceHintLine(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF2E7D32) : AppBrandColors.softText,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<_SimpleSignatureData?> _askSimpleSignatureData({
    required Map<String, dynamic> companyData,
    required Employee employee,
    required String competence,
    required String documentLabel,
  }) async {
    final companySignerController = TextEditingController(
      text: companyData['nomeFantasia']?.toString().trim().isNotEmpty == true
          ? companyData['nomeFantasia'].toString()
          : companyData['razaoSocial']?.toString() ?? '',
    );
    final employeeSignerController = TextEditingController(
      text: employee.nomeCompleto,
    );
    final referenceController = TextEditingController();
    var signatureMethod = 'manual';
    _SimpleSignatureData? result;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assinatura simples - $documentLabel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Competencia: $competence'),
                const SizedBox(height: 8),
                TextField(
                  controller: companySignerController,
                  decoration: const InputDecoration(
                    labelText: 'Responsavel da empresa',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: employeeSignerController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do colaborador para aceite',
                  ),
                ),
                const SizedBox(height: 10),
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
                    DropdownMenuItem(
                      value: 'gov_br',
                      child: Text('Gov.br'),
                    ),
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
                const SizedBox(height: 10),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia do aceite digital',
                    hintText:
                        'Protocolo, hash, id do gov.br ou observacao curta',
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
                final employeeSigner = employeeSignerController.text.trim();
                if (companySigner.isEmpty || employeeSigner.isEmpty) {
                  _msg('Informe os nomes para registrar o aceite.');
                  return;
                }
                result = _SimpleSignatureData(
                  companySignerName: companySigner,
                  employeeSignerName: employeeSigner,
                  acceptedAt: DateTime.now(),
                  signatureMethod: signatureMethod,
                  signatureDeviceLabel: _signatureDeviceLabel(),
                  signatureReference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    companySignerController.dispose();
    employeeSignerController.dispose();
    referenceController.dispose();
    return result;
  }

  Future<void> _exportBatchPayslips({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required String competence,
    required List<Employee> employees,
    required List<Payment> payments,
    required List<WorkEntry> workEntries,
    required List<TarefaItem> tasks,
  }) async {
    final signature = await _askBatchSignatureData(companyData: companyData);
    if (signature == null) {
      return;
    }

    try {
      final pdf = pw.Document();
      for (final employee in employees) {
        final sequence = await _reservePayrollDocumentSequence(
          sessao,
          _PayrollDocumentType.payslip,
        );
        final metrics = _buildPayrollMetrics(
          employee: employee,
          competence: competence,
          workEntries: workEntries,
          tasks: tasks,
        );
        final payment = _findPayment(payments, employee.id, competence);
        final employeeSignature = signature.copyWith(
          employeeSignerName: employee.nomeCompleto,
        );
        pdf.addPage(
          pw.MultiPage(
            build: (_) => _buildPayrollPdfWidgets(
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              employee: employee,
              payment: payment,
              metrics: metrics,
              signature: employeeSignature,
              type: _PayrollDocumentType.payslip,
              competence: competence,
              sequenceLabel: _payrollDocumentSequenceLabelForType(
                _PayrollDocumentType.payslip,
                sequence,
              ),
            ),
          ),
        );
        await FirebaseFirestore.instance.collection('payroll_documents').add({
          'companyId': sessao.companyId,
          'employeeId': employee.id,
          'employeeName': employee.nomeCompleto,
          'title': _documentTitle(
            _PayrollDocumentType.payslip,
            employee.nomeCompleto,
            competence,
          ),
          'sequenceNumber': sequence,
          'sequenceLabel': _payrollDocumentSequenceLabelForType(
            _PayrollDocumentType.payslip,
            sequence,
          ),
          'type': _PayrollDocumentType.payslip.name,
          'typeLabel': _documentTypeLabel(_PayrollDocumentType.payslip),
          'docGroup': 'payroll',
          'competence': competence,
          'grossCents': payment?.valorCents ?? metrics.suggestedGrossCents + 0,
          'netCents': payment?.valorCents ?? employee.salaryAmountCents ?? 0,
          'approvedDays': metrics.approvedDays,
          'approvedHours': metrics.approvedHours,
          'finishedServices': metrics.finishedServices,
          'finishedServicesValueCents': metrics.finishedServicesValueCents,
          'companySignerName': employeeSignature.companySignerName,
          'employeeSignerName': employeeSignature.employeeSignerName,
          'signatureMethod': employeeSignature.signatureMethod,
          'signatureDeviceLabel': employeeSignature.signatureDeviceLabel,
          'signatureReference': employeeSignature.signatureReference,
          'signatureAcceptedAt': employeeSignature.acceptedAt.toIso8601String(),
          'createdByUserId': sessao.userId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await openPdfBytes(
        bytes: await pdf.save(),
        filename: 'holerites-lote-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _msg('Holerites em lote gerados.');
    } catch (_) {
      _msg('Nao foi possivel exportar os holerites em lote.');
    }
  }

  Future<int> _reservePayrollDocumentSequence(
    Session sessao,
    _PayrollDocumentType type,
  ) async {
    final companySettingsRef = FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(companySettingsRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final legacyCurrent =
          (data['payrollDocumentSequence'] as num?)?.toInt() ?? 0;
      final rawMap = data['payrollDocumentSequences'];
      final sequences = rawMap is Map
          ? rawMap.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num?)?.toInt() ?? 0,
              ),
            )
          : <String, int>{};
      final key = type.name;
      final current = sequences[key] ?? legacyCurrent;
      final next = current + 1;
      sequences[key] = next;
      transaction.set(companySettingsRef, {
        'companyId': sessao.companyId,
        'payrollDocumentSequence': next,
        'payrollDocumentSequences': sequences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });
  }

  _WorkforceFeatureSettings _workforceFeatureSettings(
    Map<String, dynamic> companySettings,
  ) {
    return _WorkforceFeatureSettings.fromSettings(companySettings);
  }

  Widget _featureToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }

}
