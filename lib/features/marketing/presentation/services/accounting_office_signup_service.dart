import 'package:cloud_functions/cloud_functions.dart';

class AccountingOfficeSignupService {
  AccountingOfficeSignupService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<AccountingOfficeSignupPrefill> getPrefill({
    required String token,
  }) async {
    final callable = _functions.httpsCallable(
      'publicGetAccountingOfficeSignupPrefill',
    );
    final result = await callable.call(<String, dynamic>{'token': token});
    final data = Map<String, dynamic>.from(result.data as Map);
    return AccountingOfficeSignupPrefill.fromMap(data);
  }

  Future<AccountingOfficeSignupResult> submit({
    required AccountingOfficeSignupPayload payload,
  }) async {
    final callable = _functions.httpsCallable(
      'publicSubmitAccountingOfficeSignup',
    );
    final result = await callable.call(payload.toMap());
    final data = Map<String, dynamic>.from(result.data as Map);
    return AccountingOfficeSignupResult.fromMap(data);
  }

  Future<AccountingOfficeSignupResult> createWorkspaceAccess({
    required AccountingOfficeLightweightPayload payload,
  }) async {
    final callable = _functions.httpsCallable(
      'publicCreateAccountantWorkspaceAccess',
    );
    final result = await callable.call(payload.toMap());
    final data = Map<String, dynamic>.from(result.data as Map);
    return AccountingOfficeSignupResult.fromMap(data);
  }
}

class AccountingOfficeSignupPayload {
  const AccountingOfficeSignupPayload({
    required this.token,
    required this.officeName,
    required this.cnpj,
    required this.responsibleName,
    required this.phone,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.address,
    required this.city,
    required this.state,
    required this.billingChoice,
    required this.notes,
  });

  final String token;
  final String officeName;
  final String cnpj;
  final String responsibleName;
  final String phone;
  final String email;
  final String password;
  final String confirmPassword;
  final String address;
  final String city;
  final String state;
  final String billingChoice;
  final String notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'token': token,
      'officeName': officeName,
      'cnpj': cnpj,
      'responsibleName': responsibleName,
      'phone': phone,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
      'address': address,
      'city': city,
      'state': state,
      'billingChoice': billingChoice,
      'notes': notes,
    };
  }
}

class AccountingOfficeLightweightPayload {
  const AccountingOfficeLightweightPayload({
    required this.officeName,
    required this.responsibleName,
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.leadOrigin,
  });

  final String officeName;
  final String responsibleName;
  final String email;
  final String password;
  final String confirmPassword;
  /// UF, cidade e CEP (mesmo formato do pré-cadastro empresa).
  final Map<String, String>? leadOrigin;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'officeName': officeName,
      'responsibleName': responsibleName,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
      if (leadOrigin != null && leadOrigin!.isNotEmpty) 'leadOrigin': leadOrigin,
    };
  }
}

class AccountingOfficeSignupPrefill {
  const AccountingOfficeSignupPrefill({
    required this.inviterName,
    required this.inviterEmail,
    required this.officeName,
    required this.email,
    required this.phone,
    required this.accepted,
    required this.expired,
  });

  final String inviterName;
  final String inviterEmail;
  final String officeName;
  final String email;
  final String phone;
  final bool accepted;
  final bool expired;

  factory AccountingOfficeSignupPrefill.fromMap(Map<String, dynamic> map) {
    return AccountingOfficeSignupPrefill(
      inviterName: map['inviterName']?.toString() ?? '',
      inviterEmail: map['inviterEmail']?.toString() ?? '',
      officeName: map['officeName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      accepted: map['accepted'] == true,
      expired: map['expired'] == true,
    );
  }
}

class AccountingOfficeSignupResult {
  const AccountingOfficeSignupResult({
    required this.officeId,
    required this.officeName,
    required this.email,
    required this.loginUrl,
    required this.emailDispatched,
    required this.platformLinked,
    required this.message,
  });

  final String officeId;
  final String officeName;
  final String email;
  final String loginUrl;
  final bool emailDispatched;
  final bool platformLinked;
  final String message;

  factory AccountingOfficeSignupResult.fromMap(Map<String, dynamic> map) {
    return AccountingOfficeSignupResult(
      officeId: map['officeId']?.toString() ?? '',
      officeName: map['officeName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      loginUrl: map['loginUrl']?.toString() ?? '/login-contador',
      emailDispatched: map['emailDispatched'] == true,
      platformLinked: map['platformLinked'] == true,
      message: map['message']?.toString() ?? '',
    );
  }
}
