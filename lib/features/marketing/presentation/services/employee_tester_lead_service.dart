import 'package:cloud_functions/cloud_functions.dart';

class EmployeeTesterLeadService {
  EmployeeTesterLeadService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<EmployeeTesterLeadResult> create({
    required String fullName,
    required String email,
    String phone = '',
    String city = '',
    String state = '',
    String occupation = '',
    Map<String, dynamic>? tracking,
  }) async {
    final callable = _functions.httpsCallable('publicCreateEmployeeTesterLead');
    final result = await callable.call(<String, dynamic>{
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'city': city,
      'state': state,
      'occupation': occupation,
      'tracking': tracking,
    });
    return EmployeeTesterLeadResult.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}

class EmployeeTesterLeadResult {
  const EmployeeTesterLeadResult({
    required this.leadId,
    required this.status,
  });

  final String leadId;
  final String status;

  factory EmployeeTesterLeadResult.fromMap(Map<String, dynamic> map) {
    return EmployeeTesterLeadResult(
      leadId: map['leadId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }
}
