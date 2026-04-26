import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/domain/audit_log.dart';

class AuditNotifier extends Notifier<List<AuditLog>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<AuditLog> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return <AuditLog>[];
  }

  void log({
    required String modulo,
    required String acao,
    String? detalhes,
  }) {
    // Escrita de auditoria no client foi desativada por seguranca.
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <AuditLog>[];
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('audit_logs')
        .where('companyId', isEqualTo: sessao.companyId)
        .orderBy('createdAt', descending: true)
        .limit(300);

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)];
      },
      onError: (error, stackTrace) {
        // Mantem o estado atual em falha temporaria de stream.
      },
    );
  }

  AuditLog _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = map['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.tryParse(createdAtRaw?.toString() ?? '') ?? DateTime.now();

    return AuditLog(
      id: doc.id,
      companyId: map['companyId']?.toString() ?? '',
      actorUserId: map['actorUserId']?.toString() ?? '',
      actorRole: map['actorRole']?.toString() ?? '',
      module: map['module']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      entityPath: map['entityPath']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      createdAt: createdAt,
      before: (map['before'] as Map?)?.cast<String, dynamic>(),
      after: (map['after'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

final auditProvider = NotifierProvider<AuditNotifier, List<AuditLog>>(
  AuditNotifier.new,
);

