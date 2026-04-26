import 'package:cloud_firestore/cloud_firestore.dart';

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.threadId,
    required this.authorType,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String authorType;
  final String authorName;
  final String text;
  final DateTime? createdAt;

  bool get isAssistant => authorType == 'assistant';

  factory AssistantMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];
    return AssistantMessage(
      id: snapshot.id,
      threadId: data['threadId']?.toString() ?? '',
      authorType: data['authorType']?.toString() ?? 'assistant',
      authorName: data['authorName']?.toString() ?? 'Assistente Inteligente',
      text: data['text']?.toString() ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
