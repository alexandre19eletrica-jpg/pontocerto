import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/justifications/domain/justification.dart';

class JustificationsNotifier extends Notifier<List<JustificationItem>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<JustificationItem> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return <JustificationItem>[];
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <JustificationItem>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('justifications')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('justifications')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)]
          ..sort((a, b) => b.date.compareTo(a.date));
      },
      onError: (error, stackTrace) {
        debugPrint('justificationsProvider stream error: $error');
      },
    );
  }

  JustificationItem _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final rawDate = map['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final statusRaw = (map['status'] ?? 'PENDING').toString().toUpperCase();

    return JustificationItem(
      id: doc.id,
      companyId: map['companyId']?.toString() ?? '',
      employeeId: map['employeeId']?.toString() ?? '',
      date: date,
      reason: map['reason']?.toString() ?? '',
      comprovanteUrl: map['comprovanteUrl']?.toString() ?? '',
      status: switch (statusRaw) {
        'APPROVED' => JustificationStatus.approved,
        'REJECTED' => JustificationStatus.rejected,
        _ => JustificationStatus.pending,
      },
      comprovanteNomeArquivo: map['comprovanteNomeArquivo']?.toString(),
      reviewedBy: map['reviewedBy']?.toString(),
    );
  }

  Future<void> create({
    required DateTime date,
    required String reason,
    required String comprovanteUrl,
    required String comprovanteNomeArquivo,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final identidade = await _resolverIdentidade(sessao);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await FirebaseFirestore.instance.collection('justifications').doc(id).set({
      'companyId': identidade.companyId,
      'employeeId': identidade.uid,
      'date': Timestamp.fromDate(date),
      'reason': reason,
      'comprovanteUrl': comprovanteUrl,
      'comprovanteNomeArquivo': comprovanteNomeArquivo,
      'status': 'PENDING',
      'reviewedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approve(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    final identidade = await _resolverIdentidade(sessao);

    await FirebaseFirestore.instance.collection('justifications').doc(id).set({
      'companyId': identidade.companyId,
      'status': 'APPROVED',
      'reviewedBy': identidade.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reject(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    final identidade = await _resolverIdentidade(sessao);

    await FirebaseFirestore.instance.collection('justifications').doc(id).set({
      'companyId': identidade.companyId,
      'status': 'REJECTED',
      'reviewedBy': identidade.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> remove(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    if (sessao.role == Role.employee) {
      throw Exception('Somente a empresa pode excluir justificativas.');
    }

    await FirebaseFirestore.instance.collection('justifications').doc(id).delete();
  }

  Future<({String uid, String companyId})> _resolverIdentidade(Session sessao) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    var companyId = sessao.companyId;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final company = doc.data()?['companyId']?.toString().trim();
      if (company != null && company.isNotEmpty) {
        companyId = company;
      }
    } catch (_) {
      // Mantem dados da sessao como fallback em falha temporaria.
    }

    return (uid: uid, companyId: companyId);
  }
}

final justificationsProvider = NotifierProvider<JustificationsNotifier, List<JustificationItem>>(
  JustificationsNotifier.new,
);

