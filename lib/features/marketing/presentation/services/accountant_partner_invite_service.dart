import 'package:cloud_functions/cloud_functions.dart';

class AccountantPartnerInviteService {
  AccountantPartnerInviteService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<AccountantPartnerInviteSnapshot> getInvite(String token) async {
    final callable = _functions.httpsCallable('publicGetAccountantPartnerInvite');
    final result = await callable.call(<String, dynamic>{'token': token});
    final data = Map<String, dynamic>.from(result.data as Map);
    return AccountantPartnerInviteSnapshot.fromMap(data);
  }

  Future<AccountantPartnerInviteSnapshot> accept(String token) async {
    final callable = _functions.httpsCallable('publicAcceptAccountantPartnerInvite');
    final result = await callable.call(<String, dynamic>{'token': token});
    final data = Map<String, dynamic>.from(result.data as Map);
    return AccountantPartnerInviteSnapshot.fromMap(data);
  }
}

class AccountantPartnerInviteSnapshot {
  const AccountantPartnerInviteSnapshot({
    required this.leadId,
    required this.status,
    required this.customerName,
    required this.customerEmail,
    required this.accountantName,
    required this.accountantEmail,
    required this.planTitle,
    required this.implementationMode,
    required this.partnerStatus,
  });

  final String leadId;
  final String status;
  final String customerName;
  final String customerEmail;
  final String accountantName;
  final String accountantEmail;
  final String planTitle;
  final String implementationMode;
  final String partnerStatus;

  bool get accepted => partnerStatus.toLowerCase() == 'accepted';

  factory AccountantPartnerInviteSnapshot.fromMap(Map<String, dynamic> map) {
    return AccountantPartnerInviteSnapshot(
      leadId: map['leadId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerEmail: map['customerEmail']?.toString() ?? '',
      accountantName: map['accountantName']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
      planTitle: map['planTitle']?.toString() ?? '',
      implementationMode: map['implementationMode']?.toString() ?? '',
      partnerStatus: map['partnerStatus']?.toString() ?? '',
    );
  }
}
