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

