import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringBillingStatus { active, paused }
enum RecurringBillingCadence { monthly, quarterly, yearly }

class RecurringBillingProfile {
  const RecurringBillingProfile({
    required this.id,
    required this.companyId,
    required this.title,
    required this.clientId,
    required this.clientName,
    required this.amountCents,
    required this.cadence,
    required this.nextDueDate,
    required this.status,
    required this.createdByUserId,
    this.description,
    this.contractReference,
    this.autoCreateFiscalDraft = false,
    this.lastGeneratedAt,
    this.lastGeneratedMovementId,
    this.lastGeneratedPeriodKey,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String title;
  final String clientId;
  final String clientName;
  final int amountCents;
  final RecurringBillingCadence cadence;
  final DateTime nextDueDate;
  final RecurringBillingStatus status;
  final String createdByUserId;
  final String? description;
  final String? contractReference;
  final bool autoCreateFiscalDraft;
  final DateTime? lastGeneratedAt;
  final String? lastGeneratedMovementId;
  final String? lastGeneratedPeriodKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == RecurringBillingStatus.active;

  RecurringBillingProfile copyWith({
    String? title,
    String? clientId,
    String? clientName,
    int? amountCents,
    RecurringBillingCadence? cadence,
    DateTime? nextDueDate,
    RecurringBillingStatus? status,
    String? description,
    String? contractReference,
    bool? autoCreateFiscalDraft,
    DateTime? lastGeneratedAt,
    String? lastGeneratedMovementId,
    String? lastGeneratedPeriodKey,
    DateTime? updatedAt,
  }) {
    return RecurringBillingProfile(
      id: id,
      companyId: companyId,
      title: title ?? this.title,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      amountCents: amountCents ?? this.amountCents,
      cadence: cadence ?? this.cadence,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      status: status ?? this.status,
      createdByUserId: createdByUserId,
      description: description ?? this.description,
      contractReference: contractReference ?? this.contractReference,
      autoCreateFiscalDraft:
          autoCreateFiscalDraft ?? this.autoCreateFiscalDraft,
      lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
      lastGeneratedMovementId:
          lastGeneratedMovementId ?? this.lastGeneratedMovementId,
      lastGeneratedPeriodKey:
          lastGeneratedPeriodKey ?? this.lastGeneratedPeriodKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'title': title,
      'clientId': clientId,
      'clientName': clientName,
      'amountCents': amountCents,
      'cadence': cadence.name,
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'status': status.name,
      'createdByUserId': createdByUserId,
      'description': description,
      'contractReference': contractReference,
      'autoCreateFiscalDraft': autoCreateFiscalDraft,
      'lastGeneratedAt': lastGeneratedAt == null
          ? null
          : Timestamp.fromDate(lastGeneratedAt!),
      'lastGeneratedMovementId': lastGeneratedMovementId,
      'lastGeneratedPeriodKey': lastGeneratedPeriodKey,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory RecurringBillingProfile.fromMap(Map<String, dynamic> map) {
    DateTime? readDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    RecurringBillingCadence readCadence(String raw) {
      return RecurringBillingCadence.values.where((e) => e.name == raw).isEmpty
          ? RecurringBillingCadence.monthly
          : RecurringBillingCadence.values.firstWhere((e) => e.name == raw);
    }

    RecurringBillingStatus readStatus(String raw) {
      return RecurringBillingStatus.values.where((e) => e.name == raw).isEmpty
          ? RecurringBillingStatus.active
          : RecurringBillingStatus.values.firstWhere((e) => e.name == raw);
    }

    return RecurringBillingProfile(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      cadence: readCadence(map['cadence']?.toString() ?? ''),
      nextDueDate: readDate(map['nextDueDate']) ?? DateTime.now(),
      status: readStatus(map['status']?.toString() ?? ''),
      createdByUserId: map['createdByUserId']?.toString() ?? '',
      description: map['description']?.toString(),
      contractReference: map['contractReference']?.toString(),
      autoCreateFiscalDraft: map['autoCreateFiscalDraft'] == true,
      lastGeneratedAt: readDate(map['lastGeneratedAt']),
      lastGeneratedMovementId: map['lastGeneratedMovementId']?.toString(),
      lastGeneratedPeriodKey: map['lastGeneratedPeriodKey']?.toString(),
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }
}
