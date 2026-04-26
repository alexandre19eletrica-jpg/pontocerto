import 'package:cloud_functions/cloud_functions.dart';

class SalesOnboardingService {
  SalesOnboardingService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<SalesOnboardingRequestSnapshot> getRequest(String token) async {
    final callable = _functions.httpsCallable('publicGetSalesOnboardingRequest');
    final result = await callable.call(<String, dynamic>{'token': token});
    final data = Map<String, dynamic>.from(result.data as Map);
    return SalesOnboardingRequestSnapshot.fromMap(data);
  }

  Future<void> submit({
    required String token,
    required Map<String, dynamic> payload,
    required List<Map<String, dynamic>> uploads,
  }) async {
    final callable = _functions.httpsCallable('publicSubmitSalesOnboardingRequest');
    await callable.call(<String, dynamic>{
      'token': token,
      'payload': payload,
      'uploads': uploads,
    });
  }
}

class SalesOnboardingRequestSnapshot {
  const SalesOnboardingRequestSnapshot({
    required this.requestId,
    required this.status,
    required this.customerName,
    required this.customerEmail,
    required this.originalBuyerName,
    required this.originalBuyerEmail,
    required this.planCode,
    required this.planTitle,
    required this.planPriceLabel,
    required this.implementationLabel,
    required this.implementationMode,
    required this.accountantName,
    required this.accountantEmail,
  });

  final String requestId;
  final String status;
  final String customerName;
  final String customerEmail;
  final String originalBuyerName;
  final String originalBuyerEmail;
  final String planCode;
  final String planTitle;
  final String planPriceLabel;
  final String implementationLabel;
  final String implementationMode;
  final String accountantName;
  final String accountantEmail;

  bool get isAccountantMode => implementationMode.trim().toLowerCase() == 'accountant';

  factory SalesOnboardingRequestSnapshot.fromMap(Map<String, dynamic> map) {
    return SalesOnboardingRequestSnapshot(
      requestId: map['requestId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerEmail: map['customerEmail']?.toString() ?? '',
      originalBuyerName: map['originalBuyerName']?.toString() ?? '',
      originalBuyerEmail: map['originalBuyerEmail']?.toString() ?? '',
      planCode: map['planCode']?.toString() ?? '',
      planTitle: map['planTitle']?.toString() ?? '',
      planPriceLabel: map['planPriceLabel']?.toString() ?? '',
      implementationLabel: map['implementationLabel']?.toString() ?? '',
      implementationMode: map['implementationMode']?.toString() ?? '',
      accountantName: map['accountantName']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
    );
  }
}
