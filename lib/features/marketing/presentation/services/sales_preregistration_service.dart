import 'package:cloud_functions/cloud_functions.dart';

class SalesPreRegistrationService {
  SalesPreRegistrationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<SalesPreRegistrationResult> create({
    required String planCode,
    required String customerName,
    required String customerEmail,
    required String implementationMode,
    String accountantName = '',
    String accountantEmail = '',
    Map<String, dynamic>? tracking,
  }) async {
    final callable = _functions.httpsCallable('publicCreateSalesPreRegistration');
    final result = await callable.call(<String, dynamic>{
      'planCode': planCode,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'implementationMode': implementationMode,
      'accountantName': accountantName,
      'accountantEmail': accountantEmail,
      'tracking': tracking,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return SalesPreRegistrationResult.fromMap(data);
  }
}

class SalesPreRegistrationResult {
  const SalesPreRegistrationResult({
    required this.leadId,
    required this.checkoutUrl,
    required this.partnerInviteUrl,
    required this.precadastroEmpresaEmailOk,
    required this.conviteParceiroEmailOk,
  });

  final String leadId;
  final String checkoutUrl;
  final String partnerInviteUrl;
  final bool precadastroEmpresaEmailOk;
  final bool conviteParceiroEmailOk;

  factory SalesPreRegistrationResult.fromMap(Map<String, dynamic> map) {
    return SalesPreRegistrationResult(
      leadId: map['leadId']?.toString() ?? '',
      checkoutUrl: map['checkoutUrl']?.toString() ?? '',
      partnerInviteUrl: map['partnerInviteUrl']?.toString() ?? '',
      precadastroEmpresaEmailOk: map['precadastroEmpresaEmailOk'] == true,
      conviteParceiroEmailOk: map['conviteParceiroEmailOk'] == true,
    );
  }
}
