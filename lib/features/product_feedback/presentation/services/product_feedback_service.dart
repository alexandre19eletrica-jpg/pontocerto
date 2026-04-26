import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pontocerto/core/auth/session.dart';

class ProductFeedbackService {
  ProductFeedbackService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> submit({
    required Session session,
    required String module,
    required String priority,
    required String title,
    required String contextText,
    required String ideaText,
    required String userInfo,
  }) async {
    final feedbackRef = _firestore.collection('product_feedback').doc();
    final incidentRef = _firestore
        .collection('runtime_incidents')
        .doc('feedback_${feedbackRef.id}');
    final now = FieldValue.serverTimestamp();
    final severity = switch (priority.trim().toLowerCase()) {
      'critica' => 'critical',
      'alta' => 'warning',
      'baixa' => 'info',
      _ => 'warning',
    };

    final batch = _firestore.batch();
    batch.set(feedbackRef, {
      'companyId': session.companyId,
      'userId': session.userId,
      'userName': session.nome,
      'userRole': _roleLabel(session),
      'module': module,
      'priority': priority,
      'title': title,
      'context': contextText,
      'idea': ideaText,
      'userInfo': userInfo,
      'status': 'novo',
      'assistantStatus': 'pendente',
      'assistantActionStatus': 'pendente',
      'observabilityIncidentId': incidentRef.id,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(incidentRef, {
      'companyId': session.companyId,
      'reporterUserId': session.userId,
      'reporterName': session.nome,
      'reporterRole': session.role.name,
      'source': 'product_feedback',
      'category': 'product_feedback',
      'severity': severity,
      'status': 'open',
      'message': 'Ideia registrada: $title',
      'stackTrace': '',
      'screenLabel': 'Ideias',
      'assistantSummary': '',
      'recommendedAction': '',
      'recommendedActionType': '',
      'autoFixEligible': false,
      'autoFixStatus': 'pending_review',
      'autoFixAttempts': 0,
      'occurrenceCount': 1,
      'fingerprint': 'feedback_${feedbackRef.id}',
      'firstSeenAt': now,
      'lastSeenAt': now,
      'capturedAtClient': DateTime.now().toIso8601String(),
      'createdAt': now,
      'updatedAt': now,
      'extra': {
        'origin': 'product_feedback',
        'feedbackId': feedbackRef.id,
        'module': module,
        'priority': priority,
        'title': title,
        'context': contextText,
        'idea': ideaText,
        'userInfo': userInfo,
      },
    });
    await batch.commit();
  }

  Future<void> updateStatus({
    required Session session,
    required String feedbackId,
    required String status,
    String incidentId = '',
  }) async {
    final feedbackRef = _firestore.collection('product_feedback').doc(feedbackId);
    final batch = _firestore.batch();
    batch.set(feedbackRef, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'assistantActionStatus': status == 'entregue' ? 'concluido' : 'em_analise',
      'updatedByUserId': session.userId,
      'updatedByName': session.nome,
    }, SetOptions(merge: true));

    if (incidentId.trim().isNotEmpty) {
      batch.set(_firestore.collection('runtime_incidents').doc(incidentId), {
        'status': status == 'entregue' ? 'resolved' : 'open',
        'resolutionNote': status == 'entregue'
            ? 'Ideia marcada como entregue no modulo de melhorias.'
            : 'Ideia marcada como planejada no modulo de melhorias.',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  String _roleLabel(Session session) {
    return switch (session.role) {
      Role.owner => 'Owner',
      Role.manager => 'Manager',
      Role.accountant => 'Contador',
      Role.employee => 'Funcionario',
    };
  }
}
