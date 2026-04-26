import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  static const _endpoint =
      'https://us-central1-pontocerto-e1dab.cloudfunctions.net/assistantSendMessageHttp';

  Future<AssistantReply> sendMessage({
    required String message,
    String threadId = '',
    String route = '/assistant',
    String screenLabel = 'Assistente Inteligente',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Sessao expirada. Entre novamente.');
    }

    final idToken = await user.getIdToken(true);
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'message': message,
        'threadId': threadId,
        'route': route,
        'screenLabel': screenLabel,
      }),
    );

    final rawBody = response.body.trim();
    final payload = rawBody.isNotEmpty
        ? jsonDecode(rawBody) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['message']?.toString() ??
            'Nao foi possivel consultar o assistente agora.',
      );
    }

    return AssistantReply(
      reply: payload['reply']?.toString() ?? '',
      threadId: payload['threadId']?.toString() ?? '',
      model: payload['model']?.toString() ?? '',
      rawBody: rawBody,
    );
  }
}

class AssistantReply {
  const AssistantReply({
    required this.reply,
    required this.threadId,
    required this.model,
    required this.rawBody,
  });

  final String reply;
  final String threadId;
  final String model;
  final String rawBody;
}
