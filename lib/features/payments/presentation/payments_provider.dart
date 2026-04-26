import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';

class PaymentsNotifier extends Notifier<List<Payment>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<Payment> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bindStream(firebaseDisponivel, sessao);
    return <Payment>[];
  }

  void _bindStream(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <Payment>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('payments')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('payments')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)]
          ..sort((a, b) => b.dataRegistro.compareTo(a.dataRegistro));
      },
      onError: (error, stackTrace) {
        debugPrint('paymentsProvider stream error: $error');
      },
    );
  }

  Payment _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final timestamp = map['dataRegistro'] ?? map['createdAt'];
    final dataRegistro = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now();

    final statusTexto =
        map['status']?.toString().toLowerCase() ?? PaymentStatus.pendente.name;
    final status = PaymentStatus.values.firstWhere(
      (e) => e.name == statusTexto,
      orElse: () {
        if (statusTexto == 'paid' || statusTexto == 'pago') return PaymentStatus.pago;
        if (statusTexto == 'confirmed' || statusTexto == 'confirmado') {
          return PaymentStatus.confirmado;
        }
        if (statusTexto == 'contested' || statusTexto == 'contestado') {
          return PaymentStatus.contestado;
        }
        if (statusTexto == 'canceled' || statusTexto == 'cancelado') {
          return PaymentStatus.cancelado;
        }
        return PaymentStatus.pendente;
      },
    );

    final competenceYear = (map['competenceYear'] as num?)?.toInt();
    final competenceMonth = (map['competenceMonth'] as num?)?.toInt();
    final competencia = competenceYear != null && competenceMonth != null
        ? '$competenceYear-${competenceMonth.toString().padLeft(2, '0')}'
        : (map['competencia']?.toString() ?? '');

    final valorCents = (map['valorCents'] as num?)?.toInt() ??
        (map['netCents'] as num?)?.toInt() ??
        (map['grossCents'] as num?)?.toInt() ??
        0;

    return Payment(
      id: doc.id,
      employeeId: map['employeeId']?.toString() ?? '',
      competencia: competencia,
      valorCents: valorCents,
      dataRegistro: dataRegistro,
      status: status,
      motivoContestacao: (map['motivoContestacao'] ?? map['contestReason'])?.toString(),
    );
  }

  Future<void> add(String employeeId, String competencia, int valorCents) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final yearMonth = _parseCompetencia(competencia);
    if (yearMonth == null) throw Exception('Competencia invalida.');

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await FirebaseFirestore.instance.collection('payments').doc(id).set({
      'companyId': sessao.companyId,
      'employeeId': employeeId,
      'competencia': competencia,
      'competenceYear': yearMonth.$1,
      'competenceMonth': yearMonth.$2,
      'valorCents': valorCents,
      'grossCents': valorCents,
      'discountsCents': 0,
      'netCents': valorCents,
      'dataRegistro': FieldValue.serverTimestamp(),
      'status': PaymentStatus.pendente.name,
      'motivoContestacao': null,
      'createdByUserId': sessao.userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _registrarAuditoria('add');
  }

  Future<void> update(String id, String employeeId, String competencia, int valorCents) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final yearMonth = _parseCompetencia(competencia);
    if (yearMonth == null) throw Exception('Competencia invalida.');

    await FirebaseFirestore.instance.collection('payments').doc(id).set({
      'companyId': sessao.companyId,
      'employeeId': employeeId,
      'competencia': competencia,
      'competenceYear': yearMonth.$1,
      'competenceMonth': yearMonth.$2,
      'valorCents': valorCents,
      'grossCents': valorCents,
      'netCents': valorCents,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _registrarAuditoria('update');
  }

  Future<void> marcarPago(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('payments').doc(id).set({
      'companyId': sessao.companyId,
      'status': PaymentStatus.pago.name,
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('marcarPago');
  }

  Future<void> confirmar(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('payments').doc(id).set({
      'companyId': sessao.companyId,
      'status': PaymentStatus.confirmado.name,
      'confirmationAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('confirmar');
  }

  Future<void> contestar(String id, String motivo) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('payments').doc(id).set({
      'companyId': sessao.companyId,
      'status': PaymentStatus.contestado.name,
      'motivoContestacao': motivo,
      'contestReason': motivo,
      'contestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('contestar');
  }

  Future<void> remove(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('payments').doc(id).set({
      'companyId': sessao.companyId,
      'status': 'CANCELED',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _registrarAuditoria('remove');
  }

  (int, int)? _parseCompetencia(String competencia) {
    final partes = competencia.split('-');
    if (partes.length != 2) return null;
    final year = int.tryParse(partes[0]);
    final month = int.tryParse(partes[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return null;
    }
    return (year, month);
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'payments', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }
}

final paymentsProvider = NotifierProvider<PaymentsNotifier, List<Payment>>(
  PaymentsNotifier.new,
);

