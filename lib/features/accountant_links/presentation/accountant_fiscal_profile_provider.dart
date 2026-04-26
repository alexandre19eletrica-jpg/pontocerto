import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';

class AccountantFiscalProfile {
  const AccountantFiscalProfile({
    required this.officeName,
    required this.officeDocument,
    required this.officeEmail,
    required this.officePhone,
    required this.integraContadorActive,
    required this.apiCredentialsConfigured,
    required this.ecnpjCertificateReady,
    required this.serviceScopesReady,
    required this.contractReference,
    required this.apiCredentialLabel,
    required this.certificateLabel,
    required this.serviceScopesSummary,
    required this.notes,
    required this.appliesToLinkedCompanies,
    required this.updatedAt,
  });

  factory AccountantFiscalProfile.empty() {
    return const AccountantFiscalProfile(
      officeName: '',
      officeDocument: '',
      officeEmail: '',
      officePhone: '',
      integraContadorActive: false,
      apiCredentialsConfigured: false,
      ecnpjCertificateReady: false,
      serviceScopesReady: false,
      contractReference: '',
      apiCredentialLabel: '',
      certificateLabel: '',
      serviceScopesSummary: '',
      notes: '',
      appliesToLinkedCompanies: true,
      updatedAt: null,
    );
  }

  factory AccountantFiscalProfile.fromMap(Map<String, dynamic> map) {
    final timestamp = map['updatedAt'];
    return AccountantFiscalProfile(
      officeName: map['officeName']?.toString() ?? '',
      officeDocument: map['officeDocument']?.toString() ?? '',
      officeEmail: map['officeEmail']?.toString() ?? '',
      officePhone: map['officePhone']?.toString() ?? '',
      integraContadorActive: map['integraContadorActive'] == true,
      apiCredentialsConfigured: map['apiCredentialsConfigured'] == true,
      ecnpjCertificateReady: map['ecnpjCertificateReady'] == true,
      serviceScopesReady: map['serviceScopesReady'] == true,
      contractReference: map['contractReference']?.toString() ?? '',
      apiCredentialLabel: map['apiCredentialLabel']?.toString() ?? '',
      certificateLabel: map['certificateLabel']?.toString() ?? '',
      serviceScopesSummary: map['serviceScopesSummary']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      appliesToLinkedCompanies: map['appliesToLinkedCompanies'] != false,
      updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  final String officeName;
  final String officeDocument;
  final String officeEmail;
  final String officePhone;
  final bool integraContadorActive;
  final bool apiCredentialsConfigured;
  final bool ecnpjCertificateReady;
  final bool serviceScopesReady;
  final String contractReference;
  final String apiCredentialLabel;
  final String certificateLabel;
  final String serviceScopesSummary;
  final String notes;
  final bool appliesToLinkedCompanies;
  final DateTime? updatedAt;

  bool get isReady =>
      integraContadorActive &&
      apiCredentialsConfigured &&
      ecnpjCertificateReady &&
      serviceScopesReady;
}

final accountantFiscalProfileProvider =
    StreamProvider<AccountantFiscalProfile>((ref) {
      final session = ref.watch(sessionProvider);
      if (session == null || session.role != Role.accountant) {
        return Stream.value(AccountantFiscalProfile.empty());
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(session.userId)
          .snapshots()
          .map((doc) {
            final data = doc.data() ?? <String, dynamic>{};
            final profile = data['accountantFiscalProfile'];
            if (profile is! Map) {
              return AccountantFiscalProfile.empty();
            }
            return AccountantFiscalProfile.fromMap(
              profile.cast<String, dynamic>(),
            );
          });
    });
