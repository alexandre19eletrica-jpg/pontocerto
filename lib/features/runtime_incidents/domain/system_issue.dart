import 'package:cloud_firestore/cloud_firestore.dart';

class SystemIssue {
  const SystemIssue({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.module,
    required this.source,
    required this.severity,
    required this.status,
    required this.fixStatus,
    required this.occurrenceCount,
    required this.affectedRoute,
    required this.affectedUserRole,
    required this.recommendedAction,
    required this.recommendedActionType,
    required this.assistantSummary,
    required this.latestIncidentId,
    required this.resolutionNote,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  final String id;
  final String companyId;
  final String title;
  final String description;
  final String module;
  final String source;
  final String severity;
  final String status;
  final String fixStatus;
  final int occurrenceCount;
  final String affectedRoute;
  final String affectedUserRole;
  final String recommendedAction;
  final String recommendedActionType;
  final String assistantSummary;
  final String latestIncidentId;
  final String resolutionNote;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  factory SystemIssue.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return SystemIssue(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      module: data['module']?.toString() ?? '',
      source: data['source']?.toString() ?? '',
      severity: data['severity']?.toString() ?? 'warning',
      status: data['status']?.toString() ?? 'open',
      fixStatus: data['fixStatus']?.toString() ?? 'pending',
      occurrenceCount: (data['occurrenceCount'] as num?)?.toInt() ?? 0,
      affectedRoute: data['affectedRoute']?.toString() ?? '',
      affectedUserRole: data['affectedUserRole']?.toString() ?? '',
      recommendedAction: data['recommendedAction']?.toString() ?? '',
      recommendedActionType: data['recommendedActionType']?.toString() ?? '',
      assistantSummary: data['assistantSummary']?.toString() ?? '',
      latestIncidentId: data['latestIncidentId']?.toString() ?? '',
      resolutionNote: data['resolutionNote']?.toString() ?? '',
      firstSeenAt: _toDate(data['firstSeenAt']),
      lastSeenAt: _toDate(data['lastSeenAt']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
