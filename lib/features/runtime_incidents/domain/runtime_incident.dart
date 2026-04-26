import 'package:cloud_firestore/cloud_firestore.dart';

class RuntimeIncident {
  const RuntimeIncident({
    required this.id,
    required this.companyId,
    required this.reporterName,
    required this.reporterRole,
    required this.source,
    required this.category,
    required this.severity,
    required this.status,
    required this.message,
    required this.stackTrace,
    required this.screenLabel,
    required this.createdAt,
    required this.updatedAt,
    required this.resolutionNote,
    required this.assistantSummary,
    required this.recommendedAction,
    required this.recommendedActionType,
    required this.autoFixEligible,
    required this.autoFixStatus,
    required this.autoFixAttempts,
    required this.occurrenceCount,
  });

  final String id;
  final String companyId;
  final String reporterName;
  final String reporterRole;
  final String source;
  final String category;
  final String severity;
  final String status;
  final String message;
  final String stackTrace;
  final String screenLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String resolutionNote;
  final String assistantSummary;
  final String recommendedAction;
  final String recommendedActionType;
  final bool autoFixEligible;
  final String autoFixStatus;
  final int autoFixAttempts;
  final int occurrenceCount;

  factory RuntimeIncident.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RuntimeIncident(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      reporterName: data['reporterName']?.toString() ?? '-',
      reporterRole: data['reporterRole']?.toString() ?? '-',
      source: data['source']?.toString() ?? 'runtime',
      category: data['category']?.toString() ?? 'runtime',
      severity: data['severity']?.toString() ?? 'error',
      status: data['status']?.toString() ?? 'open',
      message: data['message']?.toString() ?? '',
      stackTrace: data['stackTrace']?.toString() ?? '',
      screenLabel: data['screenLabel']?.toString() ?? '',
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      resolutionNote: data['resolutionNote']?.toString() ?? '',
      assistantSummary: data['assistantSummary']?.toString() ?? '',
      recommendedAction: data['recommendedAction']?.toString() ?? '',
      recommendedActionType: data['recommendedActionType']?.toString() ?? '',
      autoFixEligible: data['autoFixEligible'] == true,
      autoFixStatus: data['autoFixStatus']?.toString() ?? '',
      autoFixAttempts: (data['autoFixAttempts'] as num?)?.toInt() ?? 0,
      occurrenceCount: (data['occurrenceCount'] as num?)?.toInt() ?? 1,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
