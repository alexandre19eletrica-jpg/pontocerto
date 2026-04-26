import 'package:cloud_firestore/cloud_firestore.dart';

class AssistantThread {
  const AssistantThread({
    required this.id,
    required this.companyId,
    required this.createdByUid,
    required this.title,
    required this.lastMessagePreview,
    required this.lastRoute,
    required this.updatedAt,
    required this.archived,
  });

  final String id;
  final String companyId;
  final String createdByUid;
  final String title;
  final String lastMessagePreview;
  final String lastRoute;
  final DateTime? updatedAt;
  final bool archived;

  factory AssistantThread.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final updatedAt = data['updatedAt'];
    return AssistantThread(
      id: snapshot.id,
      companyId: data['companyId']?.toString() ?? '',
      createdByUid: data['createdByUid']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Nova conversa',
      lastMessagePreview: data['lastMessagePreview']?.toString() ?? '',
      lastRoute: data['lastRoute']?.toString() ?? '/assistant',
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      archived: data['archived'] == true,
    );
  }
}
