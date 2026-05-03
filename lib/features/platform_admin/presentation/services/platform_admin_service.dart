import 'package:cloud_functions/cloud_functions.dart';

class PlatformAdminService {
  PlatformAdminService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<PlatformCompanySummary>> listCompanies() async {
    final callable = _functions.httpsCallable('platformListCompanies');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PlatformCompanySummary.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    return items;
  }

  Future<List<StandaloneLightweightCompanyRow>> listStandaloneLightweightCompanies() async {
    final callable = _functions.httpsCallable('platformListStandaloneLightweightCompanies');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              StandaloneLightweightCompanyRow.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    return items;
  }

  Future<List<PublicDemoAccessLedgerRow>> listPublicDemoAccessLedger({int limit = 120}) async {
    final callable = _functions.httpsCallable('platformListPublicDemoAccessLedger');
    final result = await callable.call(<String, dynamic>{'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PublicDemoAccessLedgerRow.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<StandaloneLightweightOfficeRow>> listLightweightTestOffices() async {
    final callable = _functions.httpsCallable('platformListLightweightTestOffices');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => StandaloneLightweightOfficeRow.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> deleteLightweightTestCompany({required String companyId}) async {
    final callable = _functions.httpsCallable('platformDeleteLightweightTestCompany');
    await callable.call(<String, dynamic>{'companyId': companyId});
  }

  Future<void> deleteLightweightTestOffice({required String officeId}) async {
    final callable = _functions.httpsCallable('platformDeleteLightweightTestOffice');
    await callable.call(<String, dynamic>{'officeId': officeId});
  }

  Future<GovernanceRealRegistrationsResult> listGovernanceRealRegistrations() async {
    final callable = _functions.httpsCallable('platformListGovernanceRealRegistrations');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final companies = (data['companies'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GraduatedPublicCompanyRow.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final offices = (data['offices'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => GraduatedPublicOfficeRow.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return GovernanceRealRegistrationsResult(companies: companies, offices: offices);
  }

  Future<IssuedTrialInvite> issueTrialInvite90Days({
    String? companyEmail,
    required String accountantEmail,
    String? companyName,
    String? accountantName,
    String? notes,
    String? companyCnpj,
    String? companyOpenedAt,
  }) async {
    final callable = _functions.httpsCallable('platformIssueTrial90DayInvite');
    final result = await callable.call(<String, dynamic>{
      'companyEmail': companyEmail,
      'accountantEmail': accountantEmail,
      'companyName': companyName,
      'accountantName': accountantName,
      'notes': notes,
      'companyCnpj': companyCnpj,
      'companyOpenedAt': companyOpenedAt,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return IssuedTrialInvite.fromMap(data);
  }

  Future<ExtendedTrialResult> extendCompanyTrial({
    required String companyId,
    required int extraDays,
  }) async {
    final callable = _functions.httpsCallable('platformExtendCompanyTrial');
    final result = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'extraDays': extraDays,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return ExtendedTrialResult.fromMap(data);
  }

  Future<PlatformCommercialUpdateResult> updateCommercialSettings({
    required String companyId,
    required String plan,
    required String businessTier,
    required String lifecycleStatus,
    required String billingStatus,
    required String approvalStatus,
    required bool allowLogin,
    required bool requiresApproval,
    required int seatsIncluded,
    required int contractedAppUsers,
    required int baseSystemPriceCents,
    required int extraAppUserPriceCents,
    required int monthlyPriceCents,
    String? billingProvider,
    bool? billingAccessManagedByGateway,
    String? billingCustomerId,
    String? billingSubscriptionId,
    String? billingPaymentLinkUrl,
    String? billingCheckoutUrl,
    String? billingExternalReference,
    String? billingGatewayStatus,
    int? billingGraceDays,
    String? billingCurrentPeriodEnd,
    String? billingGraceUntil,
    String? billingLastPaymentAt,
    String? billingLastPaymentId,
    String? billingLastPaymentStatus,
    String? billingLastWebhookEventId,
    String? billingLastWebhookEvent,
    String? billingLastWebhookAt,
    String? billingDelinquencyStartedAt,
    String? billingBlockReason,
    bool? billingWebhookReady,
    String? platformNote,
    bool acknowledgePlanUpgradeCharge = false,
  }) async {
    final callable = _functions.httpsCallable(
      'platformUpdateCompanyCommercialSettings',
    );
    final result = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plan': plan,
      'businessTier': businessTier,
      'lifecycleStatus': lifecycleStatus,
      'billingStatus': billingStatus,
      'approvalStatus': approvalStatus,
      'allowLogin': allowLogin,
      'requiresApproval': requiresApproval,
      'seatsIncluded': seatsIncluded,
      'contractedAppUsers': contractedAppUsers,
      'baseSystemPriceCents': baseSystemPriceCents,
      'extraAppUserPriceCents': extraAppUserPriceCents,
      'monthlyPriceCents': monthlyPriceCents,
      'billingProvider': billingProvider,
      'billingAccessManagedByGateway': billingAccessManagedByGateway,
      'billingCustomerId': billingCustomerId,
      'billingSubscriptionId': billingSubscriptionId,
      'billingPaymentLinkUrl': billingPaymentLinkUrl,
      'billingCheckoutUrl': billingCheckoutUrl,
      'billingExternalReference': billingExternalReference,
      'billingGatewayStatus': billingGatewayStatus,
      'billingGraceDays': billingGraceDays,
      'billingCurrentPeriodEnd': billingCurrentPeriodEnd,
      'billingGraceUntil': billingGraceUntil,
      'billingLastPaymentAt': billingLastPaymentAt,
      'billingLastPaymentId': billingLastPaymentId,
      'billingLastPaymentStatus': billingLastPaymentStatus,
      'billingLastWebhookEventId': billingLastWebhookEventId,
      'billingLastWebhookEvent': billingLastWebhookEvent,
      'billingLastWebhookAt': billingLastWebhookAt,
      'billingDelinquencyStartedAt': billingDelinquencyStartedAt,
      'billingBlockReason': billingBlockReason,
      'billingWebhookReady': billingWebhookReady,
      'platformNote': platformNote,
      'acknowledgePlanUpgradeCharge': acknowledgePlanUpgradeCharge,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformCommercialUpdateResult.fromMap(data);
  }

  Future<IssuedActivationCode> issueActivationCode({
    required String companyId,
    int expiresInDays = 30,
  }) async {
    final callable = _functions.httpsCallable('platformIssueCompanyActivationCode');
    final result = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'expiresInDays': expiresInDays,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return IssuedActivationCode.fromMap(data);
  }

  Future<ProvisionedAsaasBilling> provisionAsaasBilling({
    required String companyId,
    required String billingType,
    required String cycle,
    required String nextDueDate,
    int graceDays = 3,
    String? description,
    String? externalReference,
  }) async {
    final callable = _functions.httpsCallable('platformProvisionCompanyBillingAsaas');
    final result = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'billingType': billingType,
      'cycle': cycle,
      'nextDueDate': nextDueDate,
      'graceDays': graceDays,
      'description': description,
      'externalReference': externalReference,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return ProvisionedAsaasBilling.fromMap(data);
  }

  Future<PlatformSalesPipelineSnapshot> listSalesPipeline() async {
    final callable = _functions.httpsCallable('platformListSalesPipeline');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final leads = (data['leads'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PlatformSalesLeadSummary.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final onboardings = (data['onboardings'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PlatformSalesOnboardingSummary.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final employeeTesterLeads = (data['employeeTesterLeads'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => PlatformEmployeeTesterLeadSummary.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    final productIdeas = (data['productIdeas'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => PlatformProductIdeaSummary.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    final governanceIssues = (data['governanceIssues'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => PlatformGovernanceIssueSummary.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    return PlatformSalesPipelineSnapshot(
      leads: leads,
      onboardings: onboardings,
      employeeTesterLeads: employeeTesterLeads,
      productIdeas: productIdeas,
      governanceIssues: governanceIssues,
    );
  }

  Future<void> releaseEmployeeTesterAccess({
    required String leadId,
  }) async {
    final callable = _functions.httpsCallable('platformReleaseEmployeeTesterAccess');
    await callable.call(<String, dynamic>{'leadId': leadId});
  }

  Future<void> markEmployeeTesterPlayStoreIncluded({
    required String leadId,
  }) async {
    final callable = _functions.httpsCallable(
      'platformMarkEmployeeTesterPlayStoreIncluded',
    );
    await callable.call(<String, dynamic>{'leadId': leadId});
  }

  Future<void> releaseEmployeeTesterRealAccess({
    required String leadId,
    String? realAccessUrl,
    String? realAccessLabel,
  }) async {
    final callable = _functions.httpsCallable(
      'platformReleaseEmployeeTesterRealAccess',
    );
    await callable.call(<String, dynamic>{
      'leadId': leadId,
      'realAccessUrl': realAccessUrl,
      'realAccessLabel': realAccessLabel,
    });
  }

  Future<PlatformEmployeeTesterUsageSummary> getEmployeeTesterUsageSummary({
    required String leadId,
  }) async {
    final callable = _functions.httpsCallable('platformGetEmployeeTesterUsageSummary');
    final result = await callable.call(<String, dynamic>{'leadId': leadId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformEmployeeTesterUsageSummary.fromMap(
      Map<String, dynamic>.from(data['summary'] as Map),
    );
  }

  Future<PlatformMarketingDashboard> getMarketingDashboard({
    int days = 30,
  }) async {
    final callable = _functions.httpsCallable('platformGetMarketingDashboard');
    final result = await callable.call(<String, dynamic>{'days': days});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformMarketingDashboard.fromMap(data);
  }

  Future<List<TrialInviteSummary>> listTrialInvites({int limit = 50}) async {
    final callable = _functions.httpsCallable('platformListTrialInvites');
    final result = await callable.call(<String, dynamic>{'limit': limit});
    final data = Map<String, dynamic>.from(result.data as Map);
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => TrialInviteSummary.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return items;
  }

  Future<void> deleteTrialInvites({
    required List<String> inviteIds,
  }) async {
    final ids = inviteIds.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    final callable = _functions.httpsCallable('platformDeleteTrialInvites');
    await callable.call(<String, dynamic>{'inviteIds': ids});
  }

  Future<void> purgeDeletedTrialInvites({
    required List<String> inviteIds,
  }) async {
    final ids = inviteIds.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    final callable = _functions.httpsCallable('platformPurgeDeletedTrialInvites');
    await callable.call(<String, dynamic>{'inviteIds': ids});
  }

  Future<PlatformFiscalCompanyStatus> getCompanyFiscalStatus({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('platformGetCompanyFiscalStatus');
    final result = await callable.call(<String, dynamic>{'companyId': companyId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformFiscalCompanyStatus.fromMap(
      Map<String, dynamic>.from(data['snapshot'] as Map),
    );
  }

  Future<PlatformFiscalCompanyStatus> updateCompanyFiscalStatus({
    required String companyId,
    Map<String, dynamic>? companyDataPatch,
    Map<String, dynamic>? integrationPatch,
    Map<String, dynamic>? checklistPatch,
    Map<String, dynamic>? securePatch,
    List<Map<String, dynamic>>? pendingItems,
    bool sendPendingEmail = false,
    String? customMessage,
  }) async {
    final callable = _functions.httpsCallable('platformUpdateCompanyFiscalStatus');
    final result = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'companyDataPatch': companyDataPatch,
      'integrationPatch': integrationPatch,
      'checklistPatch': checklistPatch,
      'securePatch': securePatch,
      'pendingItems': pendingItems,
      'sendPendingEmail': sendPendingEmail,
      'customMessage': customMessage,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformFiscalCompanyStatus.fromMap(
      Map<String, dynamic>.from(data['snapshot'] as Map),
    );
  }

  Future<PlatformFiscalCompanyStatus> syncCompanyFocus({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('platformSyncCompanyFocus');
    final result = await callable.call(<String, dynamic>{'companyId': companyId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformFiscalCompanyStatus.fromMap(
      Map<String, dynamic>.from(data['snapshot'] as Map),
    );
  }

  Future<PlatformImplementationCharge> generateImplementationCharge({
    required String requestId,
    int? implementationFeeCents,
    int dueInDays = 30,
  }) async {
    final callable = _functions.httpsCallable('platformGenerateImplementationCharge');
    final result = await callable.call(<String, dynamic>{
      'requestId': requestId,
      'implementationFeeCents': implementationFeeCents,
      'dueInDays': dueInDays,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformImplementationCharge.fromMap(data);
  }

  Future<PlatformFinalizedOnboarding> finalizeSalesOnboarding({
    required String requestId,
  }) async {
    final callable = _functions.httpsCallable('platformFinalizeSalesOnboarding');
    final result = await callable.call(<String, dynamic>{'requestId': requestId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformFinalizedOnboarding.fromMap(data);
  }

  /// Escritorios contabeis (somente leitura administrativa + vinculo com empresas).
  /// [searchEmail] inclui o escritorio com esse email mesmo fora do top [limit] por data.
  Future<List<PlatformAccountingOfficeSummary>> listAccountingOffices({
    int limit = 200,
    String? searchEmail,
  }) async {
    final callable = _functions.httpsCallable('platformListAccountingOffices');
    final result = await callable.call(<String, dynamic>{
      'limit': limit,
      if (searchEmail != null && searchEmail.trim().isNotEmpty)
        'searchEmail': searchEmail.trim().toLowerCase(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => PlatformAccountingOfficeSummary.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList();
    return items;
  }

  Future<PlatformReconcileOfficeInviteResult> reconcileAccountingOfficeTrialInvite({
    required String officeId,
  }) async {
    final callable = _functions.httpsCallable('platformReconcileAccountingOfficeTrialInvite');
    final result = await callable.call(<String, dynamic>{'officeId': officeId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PlatformReconcileOfficeInviteResult.fromMap(data);
  }

  Future<void> setAccountingOfficeAccess({
    required String officeId,
    required bool allowAccess,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('platformSetAccountingOfficeAccess');
    await callable.call(<String, dynamic>{
      'officeId': officeId,
      'allowAccess': allowAccess,
      'reason': reason,
    });
  }
}

class PlatformCommercialUpdateResult {
  const PlatformCommercialUpdateResult({
    required this.ok,
    required this.companyId,
    required this.upgradeChargeRequired,
    required this.paymentLinkUrl,
    required this.amountCents,
    required this.message,
  });

  final bool ok;
  final String companyId;
  final bool upgradeChargeRequired;
  final String paymentLinkUrl;
  final int amountCents;
  final String message;

  factory PlatformCommercialUpdateResult.fromMap(Map<String, dynamic> map) {
    return PlatformCommercialUpdateResult(
      ok: map['ok'] != false,
      companyId: map['companyId']?.toString() ?? '',
      upgradeChargeRequired: map['upgradeChargeRequired'] == true,
      paymentLinkUrl: map['paymentLinkUrl']?.toString() ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      message: map['message']?.toString() ?? '',
    );
  }
}

class IssuedActivationCode {
  const IssuedActivationCode({
    required this.companyId,
    required this.codeId,
    required this.code,
    required this.codeLast4,
    required this.expiresAtIso,
  });

  final String companyId;
  final String codeId;
  final String code;
  final String codeLast4;
  final String expiresAtIso;

  factory IssuedActivationCode.fromMap(Map<String, dynamic> map) {
    return IssuedActivationCode(
      companyId: map['companyId']?.toString() ?? '',
      codeId: map['codeId']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      codeLast4: map['codeLast4']?.toString() ?? '',
      expiresAtIso: map['expiresAt']?.toString() ?? '',
    );
  }
}

class IssuedTrialInvite {
  const IssuedTrialInvite({
    required this.inviteId,
    required this.companyEmail,
    required this.accountantEmail,
    required this.inviteUrl,
    required this.expiresAtIso,
    this.inviteUrlCompany = '',
    this.inviteUrlAccountant = '',
  });

  final String inviteId;
  final String companyEmail;
  final String accountantEmail;
  final String inviteUrl;
  final String expiresAtIso;
  final String inviteUrlCompany;
  final String inviteUrlAccountant;

  factory IssuedTrialInvite.fromMap(Map<String, dynamic> map) {
    return IssuedTrialInvite(
      inviteId: map['inviteId']?.toString() ?? '',
      companyEmail: map['companyEmail']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
      inviteUrl: map['inviteUrl']?.toString() ?? '',
      expiresAtIso: map['expiresAtIso']?.toString() ?? '',
      inviteUrlCompany: map['inviteUrlCompany']?.toString() ?? '',
      inviteUrlAccountant: map['inviteUrlAccountant']?.toString() ?? '',
    );
  }
}

class ExtendedTrialResult {
  const ExtendedTrialResult({
    required this.companyId,
    required this.graceUntil,
    required this.extraDays,
  });

  final String companyId;
  final String graceUntil;
  final int extraDays;

  factory ExtendedTrialResult.fromMap(Map<String, dynamic> map) {
    return ExtendedTrialResult(
      companyId: map['companyId']?.toString() ?? '',
      graceUntil: map['graceUntil']?.toString() ?? '',
      extraDays: int.tryParse(map['extraDays']?.toString() ?? '') ?? 0,
    );
  }
}

class PlatformReconcileOfficeInviteResult {
  const PlatformReconcileOfficeInviteResult({
    required this.ok,
    required this.updated,
    this.message = '',
  });

  final bool ok;
  final int updated;
  final String message;

  factory PlatformReconcileOfficeInviteResult.fromMap(Map<String, dynamic> map) {
    return PlatformReconcileOfficeInviteResult(
      ok: map['ok'] != false,
      updated: (map['updated'] as num?)?.toInt() ?? 0,
      message: map['message']?.toString() ?? '',
    );
  }
}

class PlatformOfficeLinkedCompany {
  const PlatformOfficeLinkedCompany({
    required this.companyId,
    required this.companyName,
    required this.lifecycleStatus,
    required this.allowLogin,
    required this.billingStatus,
    required this.billingGraceUntil,
    required this.accountantOnboardingStatus,
    required this.companyDocument,
    required this.city,
    required this.state,
  });

  final String companyId;
  final String companyName;
  final String lifecycleStatus;
  final bool allowLogin;
  final String billingStatus;
  final String billingGraceUntil;
  final String accountantOnboardingStatus;
  final String companyDocument;
  final String city;
  final String state;

  factory PlatformOfficeLinkedCompany.fromMap(Map<String, dynamic> map) {
    return PlatformOfficeLinkedCompany(
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      lifecycleStatus: map['lifecycleStatus']?.toString() ?? '',
      allowLogin: map['allowLogin'] != false,
      billingStatus: map['billingStatus']?.toString() ?? '',
      billingGraceUntil: map['billingGraceUntil']?.toString() ?? '',
      accountantOnboardingStatus: map['accountantOnboardingStatus']?.toString() ?? '',
      companyDocument: map['companyDocument']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
    );
  }
}

class PlatformAccountingOfficeSummary {
  const PlatformAccountingOfficeSummary({
    required this.officeId,
    required this.officeName,
    required this.officeDisplayCode,
    required this.email,
    required this.cnpj,
    required this.responsibleName,
    required this.phone,
    required this.city,
    required this.state,
    required this.platformStatus,
    required this.officeBillingStatus,
    required this.active,
    required this.accessSuspended,
    required this.source,
    required this.linkedCompaniesCount,
    required this.companies,
    required this.updatedAt,
    required this.createdAt,
  });

  final String officeId;
  final String officeName;
  final String officeDisplayCode;
  final String email;
  final String cnpj;
  final String responsibleName;
  final String phone;
  final String city;
  final String state;
  final String platformStatus;
  final String officeBillingStatus;
  final bool active;
  final bool accessSuspended;
  final String source;
  final int linkedCompaniesCount;
  final List<PlatformOfficeLinkedCompany> companies;
  final String updatedAt;
  final String createdAt;

  factory PlatformAccountingOfficeSummary.fromMap(Map<String, dynamic> map) {
    final rawCompanies = (map['companies'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => PlatformOfficeLinkedCompany.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return PlatformAccountingOfficeSummary(
      officeId: map['officeId']?.toString() ?? '',
      officeName: map['officeName']?.toString() ?? '',
      officeDisplayCode: map['officeDisplayCode']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      cnpj: map['cnpj']?.toString() ?? '',
      responsibleName: map['responsibleName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      platformStatus: map['platformStatus']?.toString() ?? '',
      officeBillingStatus: map['officeBillingStatus']?.toString() ?? '',
      active: map['active'] != false,
      accessSuspended: map['accessSuspended'] == true,
      source: map['source']?.toString() ?? '',
      linkedCompaniesCount: (map['linkedCompaniesCount'] as num?)?.toInt() ?? 0,
      companies: rawCompanies,
      updatedAt: map['updatedAt']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }
}

/// Empresa owner com cadastro leve pendente (entrada publica sem escritorio).
class StandaloneLightweightCompanyRow {
  const StandaloneLightweightCompanyRow({
    required this.companyId,
    required this.ownerUid,
    required this.ownerName,
    required this.ownerEmail,
    required this.companyName,
    required this.lightweightSource,
    required this.directSignupPending,
    required this.accountantPendingStatus,
    required this.updatedAtIso,
  });

  final String companyId;
  final String ownerUid;
  final String ownerName;
  final String ownerEmail;
  final String companyName;
  final String lightweightSource;
  final bool directSignupPending;
  final String accountantPendingStatus;
  final String updatedAtIso;

  factory StandaloneLightweightCompanyRow.fromMap(Map<String, dynamic> map) {
    return StandaloneLightweightCompanyRow(
      companyId: map['companyId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      ownerName: map['ownerName']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      lightweightSource: map['lightweightSource']?.toString() ?? '',
      directSignupPending: map['directSignupPending'] == true,
      accountantPendingStatus: map['accountantPendingStatus']?.toString() ?? '',
      updatedAtIso: map['updatedAtIso']?.toString() ?? '',
    );
  }
}

/// Linha anonimizada do livro de demo (IP apenas hash, UA truncado).
class PublicDemoAccessLedgerRow {
  const PublicDemoAccessLedgerRow({
    required this.docId,
    required this.clientVisitorId,
    required this.marketingVisitorId,
    required this.ipHashShort,
    required this.deviceType,
    required this.language,
    required this.screen,
    required this.accessCount,
    required this.rolesCompany,
    required this.rolesAccountant,
    required this.lastSeenAtIso,
    required this.firstSeenAtIso,
    required this.dedupeVersion,
    required this.userAgentSnippet,
  });

  final String docId;
  final String clientVisitorId;
  final String marketingVisitorId;
  final String ipHashShort;
  final String deviceType;
  final String language;
  final String screen;
  final int accessCount;
  final bool rolesCompany;
  final bool rolesAccountant;
  final String lastSeenAtIso;
  final String firstSeenAtIso;
  final int dedupeVersion;
  final String userAgentSnippet;

  factory PublicDemoAccessLedgerRow.fromMap(Map<String, dynamic> map) {
    return PublicDemoAccessLedgerRow(
      docId: map['docId']?.toString() ?? '',
      clientVisitorId: map['clientVisitorId']?.toString() ?? '',
      marketingVisitorId: map['marketingVisitorId']?.toString() ?? '',
      ipHashShort: map['ipHashShort']?.toString() ?? '',
      deviceType: map['deviceType']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      screen: map['screen']?.toString() ?? '',
      accessCount: (map['accessCount'] as num?)?.toInt() ?? 0,
      rolesCompany: map['rolesCompany'] == true,
      rolesAccountant: map['rolesAccountant'] == true,
      lastSeenAtIso: map['lastSeenAtIso']?.toString() ?? '',
      firstSeenAtIso: map['firstSeenAtIso']?.toString() ?? '',
      dedupeVersion: (map['dedupeVersion'] as num?)?.toInt() ?? 0,
      userAgentSnippet: map['userAgentSnippet']?.toString() ?? '',
    );
  }
}

/// Escritorio contabil apenas com cadastro leve incompleto.
class StandaloneLightweightOfficeRow {
  const StandaloneLightweightOfficeRow({
    required this.officeId,
    required this.officeName,
    required this.email,
    required this.responsibleName,
    required this.platformStatus,
    required this.source,
    required this.linkedCompaniesCount,
    required this.linkedCompaniesInIndex,
  });

  final String officeId;
  final String officeName;
  final String email;
  final String responsibleName;
  final String platformStatus;
  final String source;
  final int linkedCompaniesCount;
  final int linkedCompaniesInIndex;

  factory StandaloneLightweightOfficeRow.fromMap(Map<String, dynamic> map) {
    return StandaloneLightweightOfficeRow(
      officeId: map['officeId']?.toString() ?? '',
      officeName: map['officeName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      responsibleName: map['responsibleName']?.toString() ?? '',
      platformStatus: map['platformStatus']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      linkedCompaniesCount: (map['linkedCompaniesCount'] as num?)?.toInt() ?? 0,
      linkedCompaniesInIndex: (map['linkedCompaniesInIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class GovernanceRealRegistrationsResult {
  const GovernanceRealRegistrationsResult({
    required this.companies,
    required this.offices,
  });

  final List<GraduatedPublicCompanyRow> companies;
  final List<GraduatedPublicOfficeRow> offices;
}

/// Empresa que iniciou pela entrada publica leve e concluiu perfil (`directSignup` nao pendente).
class GraduatedPublicCompanyRow {
  const GraduatedPublicCompanyRow({
    required this.companyId,
    required this.companyName,
    required this.directSignupSource,
    required this.ownerUid,
    required this.ownerEmail,
    required this.ownerName,
    required this.ownerLightweightResolved,
    required this.accountantPendingStatus,
    required this.updatedAtIso,
  });

  final String companyId;
  final String companyName;
  final String directSignupSource;
  final String ownerUid;
  final String ownerEmail;
  final String ownerName;
  final bool ownerLightweightResolved;
  final String accountantPendingStatus;
  final String updatedAtIso;

  factory GraduatedPublicCompanyRow.fromMap(Map<String, dynamic> map) {
    return GraduatedPublicCompanyRow(
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      directSignupSource: map['directSignupSource']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      ownerName: map['ownerName']?.toString() ?? '',
      ownerLightweightResolved: map['ownerLightweightResolved'] == true,
      accountantPendingStatus: map['accountantPendingStatus']?.toString() ?? '',
      updatedAtIso: map['updatedAtIso']?.toString() ?? '',
    );
  }
}

/// Escritorio que iniciou pelo pre-cadastro leve publico e concluiu perfil.
class GraduatedPublicOfficeRow {
  const GraduatedPublicOfficeRow({
    required this.officeId,
    required this.officeName,
    required this.email,
    required this.responsibleName,
    required this.platformStatus,
    required this.cnpj,
    required this.linkedCompaniesCount,
    required this.linkedCompaniesInIndex,
    required this.updatedAtIso,
  });

  final String officeId;
  final String officeName;
  final String email;
  final String responsibleName;
  final String platformStatus;
  final String cnpj;
  final int linkedCompaniesCount;
  final int linkedCompaniesInIndex;
  final String updatedAtIso;

  factory GraduatedPublicOfficeRow.fromMap(Map<String, dynamic> map) {
    return GraduatedPublicOfficeRow(
      officeId: map['officeId']?.toString() ?? '',
      officeName: map['officeName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      responsibleName: map['responsibleName']?.toString() ?? '',
      platformStatus: map['platformStatus']?.toString() ?? '',
      cnpj: map['cnpj']?.toString() ?? '',
      linkedCompaniesCount: (map['linkedCompaniesCount'] as num?)?.toInt() ?? 0,
      linkedCompaniesInIndex: (map['linkedCompaniesInIndex'] as num?)?.toInt() ?? 0,
      updatedAtIso: map['updatedAtIso']?.toString() ?? '',
    );
  }
}

class TrialInviteSummary {
  const TrialInviteSummary({
    required this.id,
    required this.status,
    required this.companyEmail,
    required this.accountantEmail,
    required this.usedCompanyId,
    required this.usedOfficeId,
    required this.issuedByUid,
    required this.issuedByName,
    required this.issuedAtIso,
    required this.expiresAtIso,
    required this.usedAtIso,
    required this.notes,
    required this.deletedAtIso,
    required this.deletedByName,
  });

  final String id;
  final String status;
  final String companyEmail;
  final String accountantEmail;
  final String usedCompanyId;
  final String usedOfficeId;
  final String issuedByUid;
  final String issuedByName;
  final String issuedAtIso;
  final String expiresAtIso;
  final String usedAtIso;
  final String notes;
  final String deletedAtIso;
  final String deletedByName;

  factory TrialInviteSummary.fromMap(Map<String, dynamic> map) {
    return TrialInviteSummary(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      companyEmail: map['companyEmail']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
      usedCompanyId: map['usedCompanyId']?.toString() ?? '',
      usedOfficeId: map['usedOfficeId']?.toString() ?? '',
      issuedByUid: map['issuedByUid']?.toString() ?? '',
      issuedByName: map['issuedByName']?.toString() ?? '',
      issuedAtIso: map['issuedAtIso']?.toString() ?? '',
      expiresAtIso: map['expiresAtIso']?.toString() ?? '',
      usedAtIso: map['usedAtIso']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      deletedAtIso: map['deletedAtIso']?.toString() ?? '',
      deletedByName: map['deletedByName']?.toString() ?? '',
    );
  }
}

class ProvisionedAsaasBilling {
  const ProvisionedAsaasBilling({
    required this.companyId,
    required this.provider,
    required this.customerId,
    required this.subscriptionId,
    required this.paymentLinkUrl,
    required this.billingType,
    required this.cycle,
    required this.nextDueDate,
  });

  final String companyId;
  final String provider;
  final String customerId;
  final String subscriptionId;
  final String paymentLinkUrl;
  final String billingType;
  final String cycle;
  final String nextDueDate;

  factory ProvisionedAsaasBilling.fromMap(Map<String, dynamic> map) {
    return ProvisionedAsaasBilling(
      companyId: map['companyId']?.toString() ?? '',
      provider: map['provider']?.toString() ?? 'asaas',
      customerId: map['customerId']?.toString() ?? '',
      subscriptionId: map['subscriptionId']?.toString() ?? '',
      paymentLinkUrl: map['paymentLinkUrl']?.toString() ?? '',
      billingType: map['billingType']?.toString() ?? 'BOLETO',
      cycle: map['cycle']?.toString() ?? 'MONTHLY',
      nextDueDate: map['nextDueDate']?.toString() ?? '',
    );
  }
}

class PlatformCompanySummary {
  const PlatformCompanySummary({
    required this.ownerUid,
    required this.companyId,
    required this.companyName,
    required this.ownerName,
    required this.ownerEmail,
    required this.lifecycleStatus,
    required this.plan,
    required this.businessTier,
    required this.allowLogin,
    required this.approvalStatus,
    required this.accessControlMode,
    required this.activationRequired,
    required this.activationStatus,
    required this.activationCodeLast4,
    required this.activationCodeIssuedAt,
    required this.activationCodeExpiresAt,
    required this.activationReleasedAt,
    required this.billingStatus,
    required this.billingProvider,
    required this.billingGatewayStatus,
    required this.billingAccessManagedByGateway,
    required this.billingCustomerId,
    required this.billingSubscriptionId,
    required this.billingPaymentLinkUrl,
    required this.billingExternalReference,
    required this.billingGraceDays,
    required this.billingCurrentPeriodEnd,
    required this.billingGraceUntil,
    required this.billingLastPaymentAt,
    required this.billingLastPaymentStatus,
    required this.billingLastWebhookEvent,
    required this.billingLastWebhookAt,
    required this.accountantOnboardingStatus,
    required this.accountantOnboardingName,
    required this.accountantOnboardingEmail,
    required this.companyDocument,
    required this.city,
    required this.state,
    required this.phone,
    required this.seatsIncluded,
    required this.contractedAppUsers,
    required this.baseSystemPriceCents,
    required this.extraAppUserPriceCents,
    required this.monthlyPriceCents,
    required this.calculatedMonthlyPriceCents,
    required this.platformNote,
    required this.fiscalOverallStatus,
    required this.fiscalPendingCount,
    required this.fiscalCriticalPendingCount,
    required this.focusProvisioningStatus,
  });

  final String ownerUid;
  final String companyId;
  final String companyName;
  final String ownerName;
  final String ownerEmail;
  final String lifecycleStatus;
  final String plan;
  final String businessTier;
  final bool allowLogin;
  final String approvalStatus;
  final String accessControlMode;
  final bool activationRequired;
  final String activationStatus;
  final String activationCodeLast4;
  final String activationCodeIssuedAt;
  final String activationCodeExpiresAt;
  final String activationReleasedAt;
  final String billingStatus;
  final String billingProvider;
  final String billingGatewayStatus;
  final bool billingAccessManagedByGateway;
  final String billingCustomerId;
  final String billingSubscriptionId;
  final String billingPaymentLinkUrl;
  final String billingExternalReference;
  final int billingGraceDays;
  final String billingCurrentPeriodEnd;
  final String billingGraceUntil;
  final String billingLastPaymentAt;
  final String billingLastPaymentStatus;
  final String billingLastWebhookEvent;
  final String billingLastWebhookAt;
  final String accountantOnboardingStatus;
  final String accountantOnboardingName;
  final String accountantOnboardingEmail;
  final String companyDocument;
  final String city;
  final String state;
  final String phone;
  final int seatsIncluded;
  final int contractedAppUsers;
  final int baseSystemPriceCents;
  final int extraAppUserPriceCents;
  final int monthlyPriceCents;
  final int calculatedMonthlyPriceCents;
  final String platformNote;
  final String fiscalOverallStatus;
  final int fiscalPendingCount;
  final int fiscalCriticalPendingCount;
  final String focusProvisioningStatus;

  factory PlatformCompanySummary.fromMap(Map<String, dynamic> map) {
    return PlatformCompanySummary(
      ownerUid: map['ownerUid']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      ownerName: map['ownerName']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      lifecycleStatus: map['lifecycleStatus']?.toString() ?? 'trial',
      plan: map['plan']?.toString() ?? 'solo',
      businessTier: map['businessTier']?.toString() ?? 'mei',
      allowLogin: map['allowLogin'] == true,
      approvalStatus: map['approvalStatus']?.toString() ?? 'auto_approved',
      accessControlMode: map['accessControlMode']?.toString() ?? 'standard',
      activationRequired: map['activationRequired'] == true,
      activationStatus: map['activationStatus']?.toString() ?? 'not_required',
      activationCodeLast4: map['activationCodeLast4']?.toString() ?? '',
      activationCodeIssuedAt: map['activationCodeIssuedAt']?.toString() ?? '',
      activationCodeExpiresAt: map['activationCodeExpiresAt']?.toString() ?? '',
      activationReleasedAt: map['activationReleasedAt']?.toString() ?? '',
      billingStatus: map['billingStatus']?.toString() ?? 'trialing',
      billingProvider: map['billingProvider']?.toString() ?? 'manual',
      billingGatewayStatus: map['billingGatewayStatus']?.toString() ?? 'pending_setup',
      billingAccessManagedByGateway: map['billingAccessManagedByGateway'] == true,
      billingCustomerId: map['billingCustomerId']?.toString() ?? '',
      billingSubscriptionId: map['billingSubscriptionId']?.toString() ?? '',
      billingPaymentLinkUrl: map['billingPaymentLinkUrl']?.toString() ?? '',
      billingExternalReference: map['billingExternalReference']?.toString() ?? '',
      billingGraceDays: (map['billingGraceDays'] as num?)?.toInt() ?? 3,
      billingCurrentPeriodEnd: map['billingCurrentPeriodEnd']?.toString() ?? '',
      billingGraceUntil: map['billingGraceUntil']?.toString() ?? '',
      billingLastPaymentAt: map['billingLastPaymentAt']?.toString() ?? '',
      billingLastPaymentStatus: map['billingLastPaymentStatus']?.toString() ?? '',
      billingLastWebhookEvent: map['billingLastWebhookEvent']?.toString() ?? '',
      billingLastWebhookAt: map['billingLastWebhookAt']?.toString() ?? '',
      accountantOnboardingStatus:
          map['accountantOnboardingStatus']?.toString() ?? '',
      accountantOnboardingName:
          map['accountantOnboardingName']?.toString() ?? '',
      accountantOnboardingEmail:
          map['accountantOnboardingEmail']?.toString() ?? '',
      companyDocument: map['companyDocument']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      seatsIncluded: (map['seatsIncluded'] as num?)?.toInt() ?? 3,
      contractedAppUsers: (map['contractedAppUsers'] as num?)?.toInt() ?? 3,
      baseSystemPriceCents: (map['baseSystemPriceCents'] as num?)?.toInt() ?? 0,
      extraAppUserPriceCents:
          (map['extraAppUserPriceCents'] as num?)?.toInt() ?? 0,
      monthlyPriceCents: (map['monthlyPriceCents'] as num?)?.toInt() ?? 0,
      calculatedMonthlyPriceCents:
          (map['calculatedMonthlyPriceCents'] as num?)?.toInt() ?? 0,
      platformNote: map['platformNote']?.toString() ?? '',
      fiscalOverallStatus: map['fiscalOverallStatus']?.toString() ?? '',
      fiscalPendingCount: (map['fiscalPendingCount'] as num?)?.toInt() ?? 0,
      fiscalCriticalPendingCount:
          (map['fiscalCriticalPendingCount'] as num?)?.toInt() ?? 0,
      focusProvisioningStatus: map['focusProvisioningStatus']?.toString() ?? '',
    );
  }
}

class PlatformFiscalCompanyStatus {
  const PlatformFiscalCompanyStatus({
    required this.companyId,
    required this.ownerUid,
    required this.ownerName,
    required this.ownerEmail,
    required this.companyName,
    required this.companyDocument,
    required this.city,
    required this.state,
    required this.focusProvisioningStatus,
    required this.focusProvisioningError,
    required this.focusProvisioningMissing,
    required this.focusCompanyId,
    required this.fiscalEnvironment,
    required this.fiscalProvider,
    required this.focusNfseApi,
    required this.municipalCode,
    required this.certificateRef,
    required this.lastHomologationNote,
    required this.certificateFileName,
    required this.certificateValidUntil,
    required this.checklistCompleted,
    required this.checklistTotal,
    required this.pendingCount,
    required this.criticalPendingCount,
    required this.documentPendingCount,
    required this.overallStatus,
    required this.pendingItems,
    required this.lastPendingEmailAt,
    required this.lastPendingEmailTo,
    required this.lastPendingEmailSummary,
  });

  final String companyId;
  final String ownerUid;
  final String ownerName;
  final String ownerEmail;
  final String companyName;
  final String companyDocument;
  final String city;
  final String state;
  final String focusProvisioningStatus;
  final String focusProvisioningError;
  final List<String> focusProvisioningMissing;
  final String focusCompanyId;
  final String fiscalEnvironment;
  final String fiscalProvider;
  final String focusNfseApi;
  final String municipalCode;
  final String certificateRef;
  final String lastHomologationNote;
  final String certificateFileName;
  final String certificateValidUntil;
  final int checklistCompleted;
  final int checklistTotal;
  final int pendingCount;
  final int criticalPendingCount;
  final int documentPendingCount;
  final String overallStatus;
  final List<PlatformFiscalPendingItem> pendingItems;
  final String lastPendingEmailAt;
  final String lastPendingEmailTo;
  final String lastPendingEmailSummary;

  factory PlatformFiscalCompanyStatus.fromMap(Map<String, dynamic> map) {
    return PlatformFiscalCompanyStatus(
      companyId: map['companyId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      ownerName: map['ownerName']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      companyDocument: map['companyDocument']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      focusProvisioningStatus: map['focusProvisioningStatus']?.toString() ?? '',
      focusProvisioningError: map['focusProvisioningError']?.toString() ?? '',
      focusProvisioningMissing: (map['focusProvisioningMissing'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      focusCompanyId: map['focusCompanyId']?.toString() ?? '',
      fiscalEnvironment: map['fiscalEnvironment']?.toString() ?? '',
      fiscalProvider: map['fiscalProvider']?.toString() ?? '',
      focusNfseApi: map['focusNfseApi']?.toString() ?? '',
      municipalCode: map['municipalCode']?.toString() ?? '',
      certificateRef: map['certificateRef']?.toString() ?? '',
      lastHomologationNote: map['lastHomologationNote']?.toString() ?? '',
      certificateFileName: map['certificateFileName']?.toString() ?? '',
      certificateValidUntil: map['certificateValidUntil']?.toString() ?? '',
      checklistCompleted: (map['checklistCompleted'] as num?)?.toInt() ?? 0,
      checklistTotal: (map['checklistTotal'] as num?)?.toInt() ?? 6,
      pendingCount: (map['pendingCount'] as num?)?.toInt() ?? 0,
      criticalPendingCount: (map['criticalPendingCount'] as num?)?.toInt() ?? 0,
      documentPendingCount: (map['documentPendingCount'] as num?)?.toInt() ?? 0,
      overallStatus: map['overallStatus']?.toString() ?? 'PENDING',
      pendingItems: (map['pendingItems'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => PlatformFiscalPendingItem.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      lastPendingEmailAt: map['lastPendingEmailAt']?.toString() ?? '',
      lastPendingEmailTo: map['lastPendingEmailTo']?.toString() ?? '',
      lastPendingEmailSummary: map['lastPendingEmailSummary']?.toString() ?? '',
    );
  }
}

class PlatformFiscalPendingItem {
  const PlatformFiscalPendingItem({
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.documentRequired,
    required this.owner,
    required this.status,
    required this.note,
    required this.updatedAt,
  });

  final String code;
  final String title;
  final String description;
  final String category;
  final String severity;
  final bool documentRequired;
  final String owner;
  final String status;
  final String note;
  final String updatedAt;

  factory PlatformFiscalPendingItem.fromMap(Map<String, dynamic> map) {
    return PlatformFiscalPendingItem(
      code: map['code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'high',
      documentRequired: map['documentRequired'] == true,
      owner: map['owner']?.toString() ?? 'company',
      status: map['status']?.toString() ?? 'pending',
      note: map['note']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap({
    String? owner,
    String? status,
    String? note,
  }) {
    return {
      'code': code,
      'owner': owner ?? this.owner,
      'status': status ?? this.status,
      'note': note ?? this.note,
    };
  }
}

class PlatformMarketingDashboard {
  const PlatformMarketingDashboard({
    required this.days,
    required this.metrics,
    required this.topSources,
    required this.topCampaigns,
    required this.topPlans,
    required this.recentLeads,
  });

  final int days;
  final PlatformMarketingMetrics metrics;
  final List<PlatformMarketingCount> topSources;
  final List<PlatformMarketingCount> topCampaigns;
  final List<PlatformMarketingCount> topPlans;
  final List<PlatformMarketingLead> recentLeads;

  factory PlatformMarketingDashboard.fromMap(Map<String, dynamic> map) {
    return PlatformMarketingDashboard(
      days: (map['days'] as num?)?.toInt() ?? 30,
      metrics: PlatformMarketingMetrics.fromMap(
        Map<String, dynamic>.from(map['metrics'] as Map? ?? const {}),
      ),
      topSources: (map['topSources'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PlatformMarketingCount.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      topCampaigns: (map['topCampaigns'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PlatformMarketingCount.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      topPlans: (map['topPlans'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PlatformMarketingCount.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      recentLeads: (map['recentLeads'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PlatformMarketingLead.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class PlatformMarketingMetrics {
  const PlatformMarketingMetrics({
    required this.visitors,
    required this.sessions,
    required this.salesViews,
    required this.preregViews,
    required this.planSelects,
    required this.preregSubmits,
    required this.hotVisitors,
    required this.recurringVisitors,
    required this.demoVisitors,
    required this.demoCompanyUnique,
    required this.demoAccountantUnique,
    required this.demoOpenCount,
    required this.preregConversionRate,
    required this.planSelectRate,
  });

  final int visitors;
  final int sessions;
  final int salesViews;
  final int preregViews;
  final int planSelects;
  final int preregSubmits;
  final int hotVisitors;
  final int recurringVisitors;
  final int demoVisitors;
  final int demoCompanyUnique;
  final int demoAccountantUnique;
  final int demoOpenCount;
  final double preregConversionRate;
  final double planSelectRate;

  factory PlatformMarketingMetrics.fromMap(Map<String, dynamic> map) {
    return PlatformMarketingMetrics(
      visitors: (map['visitors'] as num?)?.toInt() ?? 0,
      sessions: (map['sessions'] as num?)?.toInt() ?? 0,
      salesViews: (map['salesViews'] as num?)?.toInt() ?? 0,
      preregViews: (map['preregViews'] as num?)?.toInt() ?? 0,
      planSelects: (map['planSelects'] as num?)?.toInt() ?? 0,
      preregSubmits: (map['preregSubmits'] as num?)?.toInt() ?? 0,
      hotVisitors: (map['hotVisitors'] as num?)?.toInt() ?? 0,
      recurringVisitors: (map['recurringVisitors'] as num?)?.toInt() ?? 0,
      demoVisitors: (map['demoVisitors'] as num?)?.toInt() ?? 0,
      demoCompanyUnique: (map['demoCompanyUnique'] as num?)?.toInt() ?? 0,
      demoAccountantUnique:
          (map['demoAccountantUnique'] as num?)?.toInt() ?? 0,
      demoOpenCount: (map['demoOpenCount'] as num?)?.toInt() ?? 0,
      preregConversionRate:
          (map['preregConversionRate'] as num?)?.toDouble() ?? 0,
      planSelectRate: (map['planSelectRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PlatformMarketingCount {
  const PlatformMarketingCount({
    required this.key,
    required this.count,
  });

  final String key;
  final int count;

  factory PlatformMarketingCount.fromMap(Map<String, dynamic> map) {
    return PlatformMarketingCount(
      key: map['key']?.toString() ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformMarketingLead {
  const PlatformMarketingLead({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.status,
    required this.planCode,
    required this.implementationMode,
    required this.sourceBucket,
    required this.utmSource,
    required this.utmCampaign,
    required this.updatedAt,
  });

  final String id;
  final String customerName;
  final String customerEmail;
  final String status;
  final String planCode;
  final String implementationMode;
  final String sourceBucket;
  final String utmSource;
  final String utmCampaign;
  final String updatedAt;

  factory PlatformMarketingLead.fromMap(Map<String, dynamic> map) {
    return PlatformMarketingLead(
      id: map['id']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerEmail: map['customerEmail']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      planCode: map['planCode']?.toString() ?? '',
      implementationMode: map['implementationMode']?.toString() ?? '',
      sourceBucket: map['sourceBucket']?.toString() ?? '',
      utmSource: map['utmSource']?.toString() ?? '',
      utmCampaign: map['utmCampaign']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }
}

class PlatformSalesPipelineSnapshot {
  const PlatformSalesPipelineSnapshot({
    required this.leads,
    required this.onboardings,
    required this.employeeTesterLeads,
    required this.productIdeas,
    required this.governanceIssues,
  });

  final List<PlatformSalesLeadSummary> leads;
  final List<PlatformSalesOnboardingSummary> onboardings;
  final List<PlatformEmployeeTesterLeadSummary> employeeTesterLeads;
  final List<PlatformProductIdeaSummary> productIdeas;
  final List<PlatformGovernanceIssueSummary> governanceIssues;
}

class PlatformGovernanceIssueSummary {
  const PlatformGovernanceIssueSummary({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.entityId,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String severity;
  final String title;
  final String description;
  final String entityId;
  final String updatedAt;

  factory PlatformGovernanceIssueSummary.fromMap(Map<String, dynamic> map) {
    return PlatformGovernanceIssueSummary(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      severity: map['severity']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }
}

class PlatformEmployeeTesterLeadSummary {
  const PlatformEmployeeTesterLeadSummary({
    required this.id,
    required this.status,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.occupation,
    required this.sourceBucket,
    required this.utmSource,
    required this.utmCampaign,
    required this.testerUid,
    required this.playStoreTesterIncludedAt,
    required this.playStoreReleasedAt,
    required this.inviteSentAt,
    required this.realAccessReleasedAt,
    required this.realAccessUrl,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String state;
  final String occupation;
  final String sourceBucket;
  final String utmSource;
  final String utmCampaign;
  final String testerUid;
  final String playStoreTesterIncludedAt;
  final String playStoreReleasedAt;
  final String inviteSentAt;
  final String realAccessReleasedAt;
  final String realAccessUrl;
  final String updatedAt;
  final String createdAt;

  factory PlatformEmployeeTesterLeadSummary.fromMap(Map<String, dynamic> map) {
    return PlatformEmployeeTesterLeadSummary(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      occupation: map['occupation']?.toString() ?? '',
      sourceBucket: map['sourceBucket']?.toString() ?? '',
      utmSource: map['utmSource']?.toString() ?? '',
      utmCampaign: map['utmCampaign']?.toString() ?? '',
      testerUid: map['testerUid']?.toString() ?? '',
      playStoreTesterIncludedAt:
          map['playStoreTesterIncludedAt']?.toString() ?? '',
      playStoreReleasedAt: map['playStoreReleasedAt']?.toString() ?? '',
      inviteSentAt: map['inviteSentAt']?.toString() ?? '',
      realAccessReleasedAt: map['realAccessReleasedAt']?.toString() ?? '',
      realAccessUrl: map['realAccessUrl']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }
}

class PlatformEmployeeTesterUsageSummary {
  const PlatformEmployeeTesterUsageSummary({
    required this.fullName,
    required this.email,
    required this.status,
    required this.testerUid,
    required this.tasksCount,
    required this.serviceOrdersCount,
    required this.punchesCount,
    required this.justificationsCount,
    required this.paymentsCount,
    required this.debtsCount,
    required this.personalMovementsCount,
    required this.hasDeviceConsent,
    required this.authCreatedAt,
    required this.authLastSignInAt,
    required this.lastActivityAt,
  });

  final String fullName;
  final String email;
  final String status;
  final String testerUid;
  final int tasksCount;
  final int serviceOrdersCount;
  final int punchesCount;
  final int justificationsCount;
  final int paymentsCount;
  final int debtsCount;
  final int personalMovementsCount;
  final bool hasDeviceConsent;
  final String authCreatedAt;
  final String authLastSignInAt;
  final String lastActivityAt;

  factory PlatformEmployeeTesterUsageSummary.fromMap(
    Map<String, dynamic> map,
  ) {
    return PlatformEmployeeTesterUsageSummary(
      fullName: map['fullName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      testerUid: map['testerUid']?.toString() ?? '',
      tasksCount: (map['tasksCount'] as num?)?.toInt() ?? 0,
      serviceOrdersCount: (map['serviceOrdersCount'] as num?)?.toInt() ?? 0,
      punchesCount: (map['punchesCount'] as num?)?.toInt() ?? 0,
      justificationsCount:
          (map['justificationsCount'] as num?)?.toInt() ?? 0,
      paymentsCount: (map['paymentsCount'] as num?)?.toInt() ?? 0,
      debtsCount: (map['debtsCount'] as num?)?.toInt() ?? 0,
      personalMovementsCount:
          (map['personalMovementsCount'] as num?)?.toInt() ?? 0,
      hasDeviceConsent: map['hasDeviceConsent'] == true,
      authCreatedAt: map['authCreatedAt']?.toString() ?? '',
      authLastSignInAt: map['authLastSignInAt']?.toString() ?? '',
      lastActivityAt: map['lastActivityAt']?.toString() ?? '',
    );
  }
}

class PlatformProductIdeaSummary {
  const PlatformProductIdeaSummary({
    required this.id,
    required this.title,
    required this.module,
    required this.priority,
    required this.status,
    required this.companyId,
    required this.companyName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.context,
    required this.idea,
    required this.userInfo,
    required this.incidentId,
    required this.incidentStatus,
    required this.issueId,
    required this.issueStatus,
    required this.assistantSummary,
    required this.recommendedAction,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String module;
  final String priority;
  final String status;
  final String companyId;
  final String companyName;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String context;
  final String idea;
  final String userInfo;
  final String incidentId;
  final String incidentStatus;
  final String issueId;
  final String issueStatus;
  final String assistantSummary;
  final String recommendedAction;
  final String createdAt;
  final String updatedAt;

  factory PlatformProductIdeaSummary.fromMap(Map<String, dynamic> map) {
    return PlatformProductIdeaSummary(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      module: map['module']?.toString() ?? '',
      priority: map['priority']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      userEmail: map['userEmail']?.toString() ?? '',
      userRole: map['userRole']?.toString() ?? '',
      context: map['context']?.toString() ?? '',
      idea: map['idea']?.toString() ?? '',
      userInfo: map['userInfo']?.toString() ?? '',
      incidentId: map['incidentId']?.toString() ?? '',
      incidentStatus: map['incidentStatus']?.toString() ?? '',
      issueId: map['issueId']?.toString() ?? '',
      issueStatus: map['issueStatus']?.toString() ?? '',
      assistantSummary: map['assistantSummary']?.toString() ?? '',
      recommendedAction: map['recommendedAction']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }
}

class PlatformSalesLeadSummary {
  const PlatformSalesLeadSummary({
    required this.id,
    required this.status,
    required this.customerName,
    required this.customerEmail,
    required this.accountantName,
    required this.accountantEmail,
    required this.planCode,
    required this.planTitle,
    required this.implementationMode,
    required this.onboardingRequestId,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String customerName;
  final String customerEmail;
  final String accountantName;
  final String accountantEmail;
  final String planCode;
  final String planTitle;
  final String implementationMode;
  final String onboardingRequestId;
  final String updatedAt;
  final String createdAt;

  factory PlatformSalesLeadSummary.fromMap(Map<String, dynamic> map) {
    return PlatformSalesLeadSummary(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerEmail: map['customerEmail']?.toString() ?? '',
      accountantName: map['accountantName']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
      planCode: map['planCode']?.toString() ?? '',
      planTitle: map['planTitle']?.toString() ?? '',
      implementationMode: map['implementationMode']?.toString() ?? '',
      onboardingRequestId: map['onboardingRequestId']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }
}

class PlatformSalesOnboardingSummary {
  const PlatformSalesOnboardingSummary({
    required this.id,
    required this.status,
    required this.customerName,
    required this.customerEmail,
    required this.originalBuyerName,
    required this.originalBuyerEmail,
    required this.planCode,
    required this.planTitle,
    required this.implementationMode,
    required this.implementationFeeCents,
    required this.implementationChargePaymentId,
    required this.implementationChargeStatus,
    required this.implementationChargeInvoiceUrl,
    required this.implementationChargeAutomationError,
    required this.companyId,
    required this.companyName,
    required this.ownerEmail,
    required this.archivedCompanyPath,
    required this.accountantName,
    required this.accountantEmail,
    required this.legalName,
    required this.document,
    required this.city,
    required this.state,
    required this.uploadedCount,
    required this.submittedAt,
    required this.updatedAt,
  });

  final String id;
  final String status;
  final String customerName;
  final String customerEmail;
  final String originalBuyerName;
  final String originalBuyerEmail;
  final String planCode;
  final String planTitle;
  final String implementationMode;
  final int implementationFeeCents;
  final String implementationChargePaymentId;
  final String implementationChargeStatus;
  final String implementationChargeInvoiceUrl;
  final String implementationChargeAutomationError;
  final String companyId;
  final String companyName;
  final String ownerEmail;
  final String archivedCompanyPath;
  final String accountantName;
  final String accountantEmail;
  final String legalName;
  final String document;
  final String city;
  final String state;
  final int uploadedCount;
  final String submittedAt;
  final String updatedAt;

  factory PlatformSalesOnboardingSummary.fromMap(Map<String, dynamic> map) {
    return PlatformSalesOnboardingSummary(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerEmail: map['customerEmail']?.toString() ?? '',
      originalBuyerName: map['originalBuyerName']?.toString() ?? '',
      originalBuyerEmail: map['originalBuyerEmail']?.toString() ?? '',
      planCode: map['planCode']?.toString() ?? '',
      planTitle: map['planTitle']?.toString() ?? '',
      implementationMode: map['implementationMode']?.toString() ?? '',
      implementationFeeCents: (map['implementationFeeCents'] as num?)?.toInt() ?? 0,
      implementationChargePaymentId:
          map['implementationChargePaymentId']?.toString() ?? '',
      implementationChargeStatus:
          map['implementationChargeStatus']?.toString() ?? '',
      implementationChargeInvoiceUrl:
          map['implementationChargeInvoiceUrl']?.toString() ?? '',
      implementationChargeAutomationError:
          map['implementationChargeAutomationError']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      archivedCompanyPath: map['archivedCompanyPath']?.toString() ?? '',
      accountantName: map['accountantName']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
      legalName: map['legalName']?.toString() ?? '',
      document: map['document']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      uploadedCount: (map['uploadedCount'] as num?)?.toInt() ?? 0,
      submittedAt: map['submittedAt']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }
}

class PlatformImplementationCharge {
  const PlatformImplementationCharge({
    required this.requestId,
    required this.paymentId,
    required this.valueCents,
    required this.dueDate,
    required this.invoiceUrl,
    required this.status,
  });

  final String requestId;
  final String paymentId;
  final int valueCents;
  final String dueDate;
  final String invoiceUrl;
  final String status;

  factory PlatformImplementationCharge.fromMap(Map<String, dynamic> map) {
    return PlatformImplementationCharge(
      requestId: map['requestId']?.toString() ?? '',
      paymentId: map['paymentId']?.toString() ?? '',
      valueCents: (map['valueCents'] as num?)?.toInt() ?? 0,
      dueDate: map['dueDate']?.toString() ?? '',
      invoiceUrl: map['invoiceUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }
}

class PlatformFinalizedOnboarding {
  const PlatformFinalizedOnboarding({
    required this.requestId,
    required this.companyId,
    required this.ownerUid,
    required this.ownerEmail,
    required this.companyName,
    required this.implementationCharge,
    required this.implementationChargeError,
  });

  final String requestId;
  final String companyId;
  final String ownerUid;
  final String ownerEmail;
  final String companyName;
  final PlatformImplementationCharge? implementationCharge;
  final String implementationChargeError;

  factory PlatformFinalizedOnboarding.fromMap(Map<String, dynamic> map) {
    final rawCharge = map['implementationCharge'];
    return PlatformFinalizedOnboarding(
      requestId: map['requestId']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      ownerEmail: map['ownerEmail']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      implementationCharge: rawCharge is Map
          ? PlatformImplementationCharge.fromMap(Map<String, dynamic>.from(rawCharge))
          : null,
      implementationChargeError: map['implementationChargeError']?.toString() ?? '',
    );
  }
}
