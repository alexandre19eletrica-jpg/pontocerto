import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountantLinkStatus { active, inactive }

class AccountantLink {
  const AccountantLink({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.companyDocument,
    required this.companyDisplayCode,
    required this.accountantUserId,
    required this.accountantName,
    required this.accountantEmail,
    required this.linkedByUserId,
    required this.linkedByName,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String companyName;
  final String companyDocument;
  final String companyDisplayCode;
  final String accountantUserId;
  final String accountantName;
  final String accountantEmail;
  final String linkedByUserId;
  final String linkedByName;
  final AccountantLinkStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == AccountantLinkStatus.active;

  factory AccountantLink.fromMap(Map<String, dynamic> map) {
    DateTime? readDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    final rawStatus = map['status']?.toString().toLowerCase() ?? '';
    final status = rawStatus == 'inactive'
        ? AccountantLinkStatus.inactive
        : AccountantLinkStatus.active;

    return AccountantLink(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      companyDocument: map['companyDocument']?.toString() ?? '',
      companyDisplayCode: map['companyDisplayCode']?.toString() ?? '',
      accountantUserId: map['accountantUserId']?.toString() ?? '',
      accountantName: map['accountantName']?.toString() ?? '',
      accountantEmail: map['accountantEmail']?.toString() ?? '',
      linkedByUserId: map['linkedByUserId']?.toString() ?? '',
      linkedByName: map['linkedByName']?.toString() ?? '',
      status: status,
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }
}
