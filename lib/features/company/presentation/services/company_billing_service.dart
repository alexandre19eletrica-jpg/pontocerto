import 'package:cloud_functions/cloud_functions.dart';

class CompanyBillingService {
  CompanyBillingService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<CompanyBillingSnapshot> getManagementSnapshot() async {
    final callable = _functions.httpsCallable('companyGetBillingManagementSnapshot');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return CompanyBillingSnapshot.fromMap(data);
  }

  Future<CompanyBillingSeatUpdateResult> updateAdditionalAppAccess({
    required int contractedAppUsers,
  }) async {
    final callable = _functions.httpsCallable('companyUpdateAdditionalAppAccess');
    final result = await callable.call(<String, dynamic>{
      'contractedAppUsers': contractedAppUsers,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return CompanyBillingSeatUpdateResult.fromMap(data);
  }

  Future<CompanyBillingCancellationResult> cancelSubscription({
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('companyCancelBillingSubscription');
    final result = await callable.call(<String, dynamic>{
      'reason': reason,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return CompanyBillingCancellationResult.fromMap(data);
  }

  Future<CompanyTrialConversionResult> startPrepaidPlanFromTrial() async {
    final callable = _functions.httpsCallable('companyStartPrepaidPlanFromTrial');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return CompanyTrialConversionResult.fromMap(data);
  }
}

class CompanyBillingSnapshot {
  const CompanyBillingSnapshot({
    required this.companyId,
    required this.renewalUrl,
    required this.paymentId,
    required this.paymentStatus,
    required this.dueDate,
    required this.canCancel,
    required this.contractedAppUsers,
    required this.seatsIncluded,
    required this.monthlyPriceCents,
  });

  final String companyId;
  final String renewalUrl;
  final String paymentId;
  final String paymentStatus;
  final String dueDate;
  final bool canCancel;
  final int contractedAppUsers;
  final int seatsIncluded;
  final int monthlyPriceCents;

  factory CompanyBillingSnapshot.fromMap(Map<String, dynamic> map) {
    return CompanyBillingSnapshot(
      companyId: map['companyId']?.toString() ?? '',
      renewalUrl: map['renewalUrl']?.toString() ?? '',
      paymentId: map['paymentId']?.toString() ?? '',
      paymentStatus: map['paymentStatus']?.toString() ?? '',
      dueDate: map['dueDate']?.toString() ?? '',
      canCancel: map['canCancel'] == true,
      contractedAppUsers: (map['contractedAppUsers'] as num?)?.toInt() ?? 0,
      seatsIncluded: (map['seatsIncluded'] as num?)?.toInt() ?? 0,
      monthlyPriceCents: (map['monthlyPriceCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class CompanyBillingSeatUpdateResult {
  const CompanyBillingSeatUpdateResult({
    required this.companyId,
    required this.contractedAppUsers,
    required this.additionalAppUsers,
    required this.monthlyPriceCents,
    required this.paymentLinkUrl,
  });

  final String companyId;
  final int contractedAppUsers;
  final int additionalAppUsers;
  final int monthlyPriceCents;
  final String paymentLinkUrl;

  factory CompanyBillingSeatUpdateResult.fromMap(Map<String, dynamic> map) {
    return CompanyBillingSeatUpdateResult(
      companyId: map['companyId']?.toString() ?? '',
      contractedAppUsers: (map['contractedAppUsers'] as num?)?.toInt() ?? 0,
      additionalAppUsers: (map['additionalAppUsers'] as num?)?.toInt() ?? 0,
      monthlyPriceCents: (map['monthlyPriceCents'] as num?)?.toInt() ?? 0,
      paymentLinkUrl: map['paymentLinkUrl']?.toString() ?? '',
    );
  }
}

class CompanyBillingCancellationResult {
  const CompanyBillingCancellationResult({
    required this.companyId,
    required this.subscriptionId,
    required this.accessUntil,
    required this.status,
  });

  final String companyId;
  final String subscriptionId;
  final String accessUntil;
  final String status;

  factory CompanyBillingCancellationResult.fromMap(Map<String, dynamic> map) {
    return CompanyBillingCancellationResult(
      companyId: map['companyId']?.toString() ?? '',
      subscriptionId: map['subscriptionId']?.toString() ?? '',
      accessUntil: map['accessUntil']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }
}

class CompanyTrialConversionResult {
  const CompanyTrialConversionResult({
    required this.companyId,
    required this.paymentLinkUrl,
    required this.dueDate,
    required this.monthlyPriceCents,
    required this.planTitle,
    required this.reusedExistingCharge,
  });

  final String companyId;
  final String paymentLinkUrl;
  final String dueDate;
  final int monthlyPriceCents;
  final String planTitle;
  final bool reusedExistingCharge;

  factory CompanyTrialConversionResult.fromMap(Map<String, dynamic> map) {
    return CompanyTrialConversionResult(
      companyId: map['companyId']?.toString() ?? '',
      paymentLinkUrl: map['paymentLinkUrl']?.toString() ?? '',
      dueDate: map['dueDate']?.toString() ?? '',
      monthlyPriceCents: (map['monthlyPriceCents'] as num?)?.toInt() ?? 0,
      planTitle: map['planTitle']?.toString() ?? '',
      reusedExistingCharge: map['reusedExistingCharge'] == true,
    );
  }
}
