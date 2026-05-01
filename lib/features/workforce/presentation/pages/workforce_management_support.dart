part of 'workforce_management_page.dart';

enum _PayrollDocumentType {
  payslip,
  receipt,
  incomeProof,
  contract,
  thirteenthReceipt,
  vacationReceipt,
  terminationStatement,
}

class _EmployeeRegistrationDocumentOption {
  const _EmployeeRegistrationDocumentOption({
    required this.category,
    required this.label,
  });

  final String category;
  final String label;
}

class _EmployeeRegistrationDocumentDraft {
  const _EmployeeRegistrationDocumentDraft({
    required this.category,
    required this.label,
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String category;
  final String label;
  final String fileName;
  final Uint8List bytes;
  final String contentType;
}

const _employeeRegistrationDocumentOptions = [
  _EmployeeRegistrationDocumentOption(
    category: 'rg_cpf',
    label: 'RG/CPF',
  ),
  _EmployeeRegistrationDocumentOption(
    category: 'ctps',
    label: 'CTPS',
  ),
  _EmployeeRegistrationDocumentOption(
    category: 'comprovante_residencia',
    label: 'Comprovante de residencia',
  ),
  _EmployeeRegistrationDocumentOption(
    category: 'bancario',
    label: 'Documento bancario',
  ),
];

enum _OperationalReviewTarget { thirteenth, vacation }

class _OperationalDocumentData {
  const _OperationalDocumentData({
    required this.amountCents,
    required this.referenceDate,
    required this.notes,
  });

  final int amountCents;
  final DateTime referenceDate;
  final String notes;
}

class _WorkforceOperationalChecks {
  const _WorkforceOperationalChecks({
    required this.thirteenthReviewedEmployeeIds,
    required this.vacationReviewedEmployeeIds,
    required this.terminationNotes,
  });

  factory _WorkforceOperationalChecks.fromMap(Map<String, dynamic> map) {
    return _WorkforceOperationalChecks(
      thirteenthReviewedEmployeeIds: _stringListFromDynamic(
        map['thirteenthReviewedEmployeeIds'],
      ),
      vacationReviewedEmployeeIds: _stringListFromDynamic(
        map['vacationReviewedEmployeeIds'],
      ),
      terminationNotes: map['terminationNotes']?.toString() ?? '',
    );
  }

  final List<String> thirteenthReviewedEmployeeIds;
  final List<String> vacationReviewedEmployeeIds;
  final String terminationNotes;
}

class _WorkforceCompetenceObligations {
  const _WorkforceCompetenceObligations({
    required this.admissionChecklistDone,
    required this.payrollConferenceDone,
    required this.vacationConferenceDone,
    required this.thirteenthConferenceDone,
    required this.terminationConferenceDone,
    required this.fgtsGuideChecked,
    required this.esocialPendingResolved,
    required this.notes,
  });

  factory _WorkforceCompetenceObligations.fromMap(Map<String, dynamic> map) {
    return _WorkforceCompetenceObligations(
      admissionChecklistDone:
          map['admissionChecklistDone'] as bool? ?? false,
      payrollConferenceDone:
          map['payrollConferenceDone'] as bool? ?? false,
      vacationConferenceDone:
          map['vacationConferenceDone'] as bool? ?? false,
      thirteenthConferenceDone:
          map['thirteenthConferenceDone'] as bool? ?? false,
      terminationConferenceDone:
          map['terminationConferenceDone'] as bool? ?? false,
      fgtsGuideChecked: map['fgtsGuideChecked'] as bool? ?? false,
      esocialPendingResolved:
          map['esocialPendingResolved'] as bool? ?? false,
      notes: map['notes']?.toString() ?? '',
    );
  }

  final bool admissionChecklistDone;
  final bool payrollConferenceDone;
  final bool vacationConferenceDone;
  final bool thirteenthConferenceDone;
  final bool terminationConferenceDone;
  final bool fgtsGuideChecked;
  final bool esocialPendingResolved;
  final String notes;

  int get completedCount => [
        admissionChecklistDone,
        payrollConferenceDone,
        vacationConferenceDone,
        thirteenthConferenceDone,
        terminationConferenceDone,
        fgtsGuideChecked,
        esocialPendingResolved,
      ].where((item) => item).length;

  int get totalCount => 7;

  _WorkforceCompetenceObligations copyWith({
    bool? admissionChecklistDone,
    bool? payrollConferenceDone,
    bool? vacationConferenceDone,
    bool? thirteenthConferenceDone,
    bool? terminationConferenceDone,
    bool? fgtsGuideChecked,
    bool? esocialPendingResolved,
    String? notes,
  }) {
    return _WorkforceCompetenceObligations(
      admissionChecklistDone:
          admissionChecklistDone ?? this.admissionChecklistDone,
      payrollConferenceDone:
          payrollConferenceDone ?? this.payrollConferenceDone,
      vacationConferenceDone:
          vacationConferenceDone ?? this.vacationConferenceDone,
      thirteenthConferenceDone:
          thirteenthConferenceDone ?? this.thirteenthConferenceDone,
      terminationConferenceDone:
          terminationConferenceDone ?? this.terminationConferenceDone,
      fgtsGuideChecked: fgtsGuideChecked ?? this.fgtsGuideChecked,
      esocialPendingResolved:
          esocialPendingResolved ?? this.esocialPendingResolved,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'admissionChecklistDone': admissionChecklistDone,
      'payrollConferenceDone': payrollConferenceDone,
      'vacationConferenceDone': vacationConferenceDone,
      'thirteenthConferenceDone': thirteenthConferenceDone,
      'terminationConferenceDone': terminationConferenceDone,
      'fgtsGuideChecked': fgtsGuideChecked,
      'esocialPendingResolved': esocialPendingResolved,
      'notes': notes,
    };
  }
}

List<String> _stringListFromDynamic(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

enum _WorkforceMode { simple, advanced }

class _PayrollMetrics {
  const _PayrollMetrics({
    required this.approvedDays,
    required this.approvedWeeks,
    required this.approvedHours,
    required this.finishedServices,
    required this.finishedServicesValueCents,
    required this.suggestedGrossCents,
  });

  final int approvedDays;
  final int approvedWeeks;
  final int approvedHours;
  final int finishedServices;
  final int finishedServicesValueCents;
  final int suggestedGrossCents;
}

class _PayrollSummary {
  const _PayrollSummary({
    required this.totalEmployees,
    required this.registeredPayments,
    required this.suggestedGrossCents,
    required this.registeredGrossCents,
    required this.approvedDays,
    required this.finishedServices,
    required this.lines,
  });

  final int totalEmployees;
  final int registeredPayments;
  final int suggestedGrossCents;
  final int registeredGrossCents;
  final int approvedDays;
  final int finishedServices;
  final List<_PayrollSummaryLine> lines;
}

class _PayrollSummaryLine {
  const _PayrollSummaryLine({
    required this.employeeId,
    required this.employeeName,
    required this.approvedDays,
    required this.approvedHours,
    required this.finishedServices,
    required this.suggestedGrossCents,
    required this.registeredGrossCents,
    required this.hasRegisteredPayment,
    required this.hasDivergence,
  });

  final String employeeId;
  final String employeeName;
  final int approvedDays;
  final int approvedHours;
  final int finishedServices;
  final int suggestedGrossCents;
  final int registeredGrossCents;
  final bool hasRegisteredPayment;
  final bool hasDivergence;
}

class _PayrollClosureEvent {
  const _PayrollClosureEvent({
    required this.competence,
    required this.action,
    required this.userId,
    required this.userName,
    required this.note,
    required this.at,
  });

  final String competence;
  final String action;
  final String userId;
  final String userName;
  final String note;
  final DateTime at;
}

class _PayrollMonthDashboardLine {
  const _PayrollMonthDashboardLine({
    required this.competence,
    required this.summary,
    required this.pendingEmployees,
    required this.divergentEmployees,
    required this.isSelected,
  });

  final String competence;
  final _PayrollSummary summary;
  final int pendingEmployees;
  final int divergentEmployees;
  final bool isSelected;
}

class _LaborRealSnapshot {
  const _LaborRealSnapshot({
    required this.thirteenthAvos,
    required this.vacationMonthsAccrued,
    required this.vacationDaysLabel,
    required this.acquisitionPeriodLabel,
    required this.terminationStatusLabel,
    required this.summaryLabel,
    required this.alerts,
  });

  final int thirteenthAvos;
  final int vacationMonthsAccrued;
  final String vacationDaysLabel;
  final String acquisitionPeriodLabel;
  final String terminationStatusLabel;
  final String summaryLabel;
  final List<String> alerts;
}

class _WorkforceEmployeeEventTypeOption {
  const _WorkforceEmployeeEventTypeOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

const _workforceEmployeeEventTypeOptions = [
  _WorkforceEmployeeEventTypeOption(
    value: 'admission_review',
    label: 'Revisao de admissao',
  ),
  _WorkforceEmployeeEventTypeOption(
    value: 'vacation_notice',
    label: 'Aviso de ferias',
  ),
  _WorkforceEmployeeEventTypeOption(
    value: 'vacation_start',
    label: 'Inicio de ferias',
  ),
  _WorkforceEmployeeEventTypeOption(
    value: 'thirteenth_advance',
    label: 'Adiantamento de 13o',
  ),
  _WorkforceEmployeeEventTypeOption(
    value: 'thirteenth_final',
    label: 'Fechamento de 13o',
  ),
  _WorkforceEmployeeEventTypeOption(
    value: 'termination_notice',
    label: 'Aviso de rescisao',
  ),
  _WorkforceEmployeeEventTypeOption(
    value: 'termination_effective',
    label: 'Rescisao efetivada',
  ),
];

class _WorkforceEmployeeEvent {
  const _WorkforceEmployeeEvent({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.competence,
    required this.eventType,
    required this.eventLabel,
    required this.effectiveDate,
    required this.notes,
    required this.createdByUserName,
    required this.createdAt,
  });

  factory _WorkforceEmployeeEvent.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return _WorkforceEmployeeEvent(
      id: id,
      companyId: map['companyId']?.toString() ?? '',
      employeeId: map['employeeId']?.toString() ?? '',
      employeeName: map['employeeName']?.toString() ?? '',
      competence: map['competence']?.toString() ?? '',
      eventType: map['eventType']?.toString() ?? '',
      eventLabel: map['eventLabel']?.toString() ?? '',
      effectiveDate: map['effectiveDate'],
      notes: map['notes']?.toString() ?? '',
      createdByUserName: map['createdByUserName']?.toString() ?? '',
      createdAt: map['createdAt'],
    );
  }

  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String competence;
  final String eventType;
  final String eventLabel;
  final dynamic effectiveDate;
  final String notes;
  final String createdByUserName;
  final dynamic createdAt;
}

class _WorkforceEmployeeCompetenceSnapshot {
  const _WorkforceEmployeeCompetenceSnapshot({
    required this.employeeId,
    required this.competence,
    required this.grossReferenceCents,
    required this.thirteenthProjectedCents,
    required this.vacationProjectedCents,
    required this.vacationBonusCents,
    required this.terminationProjectedCents,
    required this.thirteenthAvos,
    required this.vacationMonthsAccrued,
    required this.terminationSignaled,
    required this.thirteenthMemory,
    required this.vacationMemory,
    required this.terminationMemory,
    required this.updatedAt,
    required this.updatedByUserName,
  });

  factory _WorkforceEmployeeCompetenceSnapshot.fromMap(
    Map<String, dynamic> map,
  ) {
    return _WorkforceEmployeeCompetenceSnapshot(
      employeeId: map['employeeId']?.toString() ?? '',
      competence: map['competence']?.toString() ?? '',
      grossReferenceCents: (map['grossReferenceCents'] as num?)?.toInt() ?? 0,
      thirteenthProjectedCents:
          (map['thirteenthProjectedCents'] as num?)?.toInt() ?? 0,
      vacationProjectedCents:
          (map['vacationProjectedCents'] as num?)?.toInt() ?? 0,
      vacationBonusCents: (map['vacationBonusCents'] as num?)?.toInt() ?? 0,
      terminationProjectedCents:
          (map['terminationProjectedCents'] as num?)?.toInt() ?? 0,
      thirteenthAvos: (map['thirteenthAvos'] as num?)?.toInt() ?? 0,
      vacationMonthsAccrued:
          (map['vacationMonthsAccrued'] as num?)?.toInt() ?? 0,
      terminationSignaled: map['terminationSignaled'] as bool? ?? false,
      thirteenthMemory:
          (map['thirteenthMemory'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      vacationMemory:
          (map['vacationMemory'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      terminationMemory:
          (map['terminationMemory'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      updatedAt: map['updatedAt'],
      updatedByUserName: map['updatedByUserName']?.toString() ?? '',
    );
  }

  final String employeeId;
  final String competence;
  final int grossReferenceCents;
  final int thirteenthProjectedCents;
  final int vacationProjectedCents;
  final int vacationBonusCents;
  final int terminationProjectedCents;
  final int thirteenthAvos;
  final int vacationMonthsAccrued;
  final bool terminationSignaled;
  final Map<String, dynamic> thirteenthMemory;
  final Map<String, dynamic> vacationMemory;
  final Map<String, dynamic> terminationMemory;
  final dynamic updatedAt;
  final String updatedByUserName;
}

class _WorkforceFeatureSettings {
  const _WorkforceFeatureSettings({
    required this.mode,
    required this.enablePayrollClosures,
    required this.enableMonthlyDashboard,
    required this.enableServiceInvoices,
    required this.enableContracts,
    required this.enableAdvancedDocuments,
    required this.requireClosureDoubleCheck,
    required this.requireOwnerApprovalForClosure,
  });

  factory _WorkforceFeatureSettings.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final mode =
        (companySettings['workforceMode']?.toString() ?? 'advanced') == 'simple'
        ? _WorkforceMode.simple
        : _WorkforceMode.advanced;
    final raw = companySettings['workforceFeatures'];
    final features = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final fallback = mode == _WorkforceMode.simple
        ? const _WorkforceFeatureSettings(
            mode: _WorkforceMode.simple,
            enablePayrollClosures: false,
            enableMonthlyDashboard: false,
            enableServiceInvoices: false,
            enableContracts: false,
            enableAdvancedDocuments: false,
            requireClosureDoubleCheck: false,
            requireOwnerApprovalForClosure: false,
          )
        : const _WorkforceFeatureSettings(
            mode: _WorkforceMode.advanced,
            enablePayrollClosures: true,
            enableMonthlyDashboard: true,
            enableServiceInvoices: true,
            enableContracts: true,
            enableAdvancedDocuments: true,
            requireClosureDoubleCheck: true,
            requireOwnerApprovalForClosure: false,
          );
    return fallback.copyWith(
      enablePayrollClosures:
          features['enablePayrollClosures'] as bool? ??
          fallback.enablePayrollClosures,
      enableMonthlyDashboard:
          features['enableMonthlyDashboard'] as bool? ??
          fallback.enableMonthlyDashboard,
      enableServiceInvoices:
          features['enableServiceInvoices'] as bool? ??
          fallback.enableServiceInvoices,
      enableContracts:
          features['enableContracts'] as bool? ?? fallback.enableContracts,
      enableAdvancedDocuments:
          features['enableAdvancedDocuments'] as bool? ??
          fallback.enableAdvancedDocuments,
      requireClosureDoubleCheck:
          features['requireClosureDoubleCheck'] as bool? ??
          fallback.requireClosureDoubleCheck,
      requireOwnerApprovalForClosure:
          features['requireOwnerApprovalForClosure'] as bool? ??
          fallback.requireOwnerApprovalForClosure,
    );
  }

  final _WorkforceMode mode;
  final bool enablePayrollClosures;
  final bool enableMonthlyDashboard;
  final bool enableServiceInvoices;
  final bool enableContracts;
  final bool enableAdvancedDocuments;
  final bool requireClosureDoubleCheck;
  final bool requireOwnerApprovalForClosure;

  _WorkforceFeatureSettings copyWith({
    _WorkforceMode? mode,
    bool? enablePayrollClosures,
    bool? enableMonthlyDashboard,
    bool? enableServiceInvoices,
    bool? enableContracts,
    bool? enableAdvancedDocuments,
    bool? requireClosureDoubleCheck,
    bool? requireOwnerApprovalForClosure,
  }) {
    return _WorkforceFeatureSettings(
      mode: mode ?? this.mode,
      enablePayrollClosures:
          enablePayrollClosures ?? this.enablePayrollClosures,
      enableMonthlyDashboard:
          enableMonthlyDashboard ?? this.enableMonthlyDashboard,
      enableServiceInvoices:
          enableServiceInvoices ?? this.enableServiceInvoices,
      enableContracts: enableContracts ?? this.enableContracts,
      enableAdvancedDocuments:
          enableAdvancedDocuments ?? this.enableAdvancedDocuments,
      requireClosureDoubleCheck:
          requireClosureDoubleCheck ?? this.requireClosureDoubleCheck,
      requireOwnerApprovalForClosure:
          requireOwnerApprovalForClosure ?? this.requireOwnerApprovalForClosure,
    );
  }

  _WorkforceFeatureSettings simplePreset() {
    return const _WorkforceFeatureSettings(
      mode: _WorkforceMode.simple,
      enablePayrollClosures: false,
      enableMonthlyDashboard: false,
      enableServiceInvoices: false,
      enableContracts: false,
      enableAdvancedDocuments: false,
      requireClosureDoubleCheck: false,
      requireOwnerApprovalForClosure: false,
    );
  }

  _WorkforceFeatureSettings advancedPreset() {
    return const _WorkforceFeatureSettings(
      mode: _WorkforceMode.advanced,
      enablePayrollClosures: true,
      enableMonthlyDashboard: true,
      enableServiceInvoices: true,
      enableContracts: true,
      enableAdvancedDocuments: true,
      requireClosureDoubleCheck: true,
      requireOwnerApprovalForClosure: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enablePayrollClosures': enablePayrollClosures,
      'enableMonthlyDashboard': enableMonthlyDashboard,
      'enableServiceInvoices': enableServiceInvoices,
      'enableContracts': enableContracts,
      'enableAdvancedDocuments': enableAdvancedDocuments,
      'requireClosureDoubleCheck': requireClosureDoubleCheck,
      'requireOwnerApprovalForClosure': requireOwnerApprovalForClosure,
    };
  }
}

class _WorkforceManagerPermissions {
  const _WorkforceManagerPermissions({
    required this.allowPayrollClosures,
    required this.allowPayrollDocuments,
    required this.allowServiceInvoices,
    required this.allowContracts,
  });

  factory _WorkforceManagerPermissions.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final raw = companySettings['workforceManagerPermissions'];
    final settings = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return _WorkforceManagerPermissions(
      allowPayrollClosures: settings['allowPayrollClosures'] as bool? ?? true,
      allowPayrollDocuments: settings['allowPayrollDocuments'] as bool? ?? true,
      allowServiceInvoices: settings['allowServiceInvoices'] as bool? ?? true,
      allowContracts: settings['allowContracts'] as bool? ?? true,
    );
  }

  final bool allowPayrollClosures;
  final bool allowPayrollDocuments;
  final bool allowServiceInvoices;
  final bool allowContracts;

  _WorkforceManagerPermissions copyWith({
    bool? allowPayrollClosures,
    bool? allowPayrollDocuments,
    bool? allowServiceInvoices,
    bool? allowContracts,
  }) {
    return _WorkforceManagerPermissions(
      allowPayrollClosures: allowPayrollClosures ?? this.allowPayrollClosures,
      allowPayrollDocuments:
          allowPayrollDocuments ?? this.allowPayrollDocuments,
      allowServiceInvoices: allowServiceInvoices ?? this.allowServiceInvoices,
      allowContracts: allowContracts ?? this.allowContracts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowPayrollClosures': allowPayrollClosures,
      'allowPayrollDocuments': allowPayrollDocuments,
      'allowServiceInvoices': allowServiceInvoices,
      'allowContracts': allowContracts,
    };
  }
}

class _FinanceManagerAccess {
  const _FinanceManagerAccess({required this.allowCreatePayments});

  factory _FinanceManagerAccess.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final raw = companySettings['financeManagerPermissions'];
    final settings = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return _FinanceManagerAccess(
      allowCreatePayments: settings['allowCreatePayments'] as bool? ?? true,
    );
  }

  final bool allowCreatePayments;
}

class _SimpleSignatureData {
  const _SimpleSignatureData({
    required this.companySignerName,
    required this.employeeSignerName,
    required this.acceptedAt,
    required this.signatureMethod,
    required this.signatureDeviceLabel,
    this.signatureReference,
  });

  final String companySignerName;
  final String employeeSignerName;
  final DateTime acceptedAt;
  final String signatureMethod;
  final String signatureDeviceLabel;
  final String? signatureReference;

  _SimpleSignatureData copyWith({
    String? companySignerName,
    String? employeeSignerName,
    DateTime? acceptedAt,
    String? signatureMethod,
    String? signatureDeviceLabel,
    String? signatureReference,
  }) {
    return _SimpleSignatureData(
      companySignerName: companySignerName ?? this.companySignerName,
      employeeSignerName: employeeSignerName ?? this.employeeSignerName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      signatureMethod: signatureMethod ?? this.signatureMethod,
      signatureDeviceLabel: signatureDeviceLabel ?? this.signatureDeviceLabel,
      signatureReference: signatureReference ?? this.signatureReference,
    );
  }
}

