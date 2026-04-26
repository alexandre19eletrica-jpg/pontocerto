import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/debts/domain/debt.dart';

class DebtsNotifier extends Notifier<List<Debt>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<Debt> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bindStream(firebaseDisponivel, sessao);
    return <Debt>[];
  }

  void _bindStream(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <Debt>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('debts')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('debts')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromFirestoreDoc(doc)]
          ..sort((a, b) => b.data.compareTo(a.data));
      },
      onError: (error, stackTrace) {
        debugPrint('debtsProvider stream error: $error');
      },
    );
  }

  Debt _fromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final tipoTexto = (map['tipo'] ?? map['type'] ?? 'divida').toString().toLowerCase();
    final statusTexto = map['status']?.toString().toLowerCase() ?? 'aberto';

    final timestamp = map['data'] ?? map['createdAt'];
    final data = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now();

    final status = switch (statusTexto) {
      'baixado' || 'settled' => DebtStatus.baixado,
      'cancelado' || 'canceled' => DebtStatus.cancelado,
      _ => DebtStatus.aberto,
    };

    return Debt(
      id: doc.id,
      employeeId: map['employeeId']?.toString() ?? '',
      createdByUserId: map['createdByUserId']?.toString() ?? map['createdBy']?.toString() ?? '',
      tipo: (tipoTexto == 'adiantamento' || tipoTexto == 'advance')
          ? DebtType.adiantamento
          : DebtType.divida,
      valorCents: (map['valorCents'] as num?)?.toInt() ??
          (map['amountCents'] as num?)?.toInt() ??
          0,
      descricao: (map['descricao'] ?? map['title'])?.toString() ?? '',
      data: data,
      status: status,
      editRequestPending: map['editRequestPending'] == true,
      allowEmployeeEdit: map['allowEmployeeEdit'] == true,
      allowEmployeeSettle: map['allowEmployeeSettle'] == true,
    );
  }

  Future<void> add(
    String employeeId,
    DebtType tipo,
    int valorCents,
    String descricao,
    DateTime data,
  ) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    await FirebaseFirestore.instance.collection('debts').doc(id).set({
      'companyId': sessao.companyId,
      'employeeId': employeeId,
      'tipo': tipo.name,
      'type': tipo == DebtType.divida ? 'DEBT' : 'ADVANCE',
      'valorCents': valorCents,
      'amountCents': valorCents,
      'descricao': descricao,
      'title': descricao,
      'data': Timestamp.fromDate(data),
      'status': DebtStatus.aberto.name,
      'createdBy': sessao.userId,
      'createdByUserId': sessao.userId,
      'allowEmployeeEdit': sessao.role == Role.employee,
      'allowEmployeeSettle': sessao.role == Role.employee,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _registrarAuditoria('add');
  }

  Future<void> update(
    String id,
    String employeeId,
    DebtType tipo,
    int valorCents,
    String descricao,
    DateTime data,
  ) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    if (sessao.role == Role.employee) {
      throw Exception('Somente a empresa pode editar dividas.');
    }

    await FirebaseFirestore.instance.collection('debts').doc(id).set({
      'companyId': sessao.companyId,
      'employeeId': employeeId,
      'tipo': tipo.name,
      'type': tipo == DebtType.divida ? 'DEBT' : 'ADVANCE',
      'valorCents': valorCents,
      'amountCents': valorCents,
      'descricao': descricao,
      'title': descricao,
      'data': Timestamp.fromDate(data),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('update');
  }

  Future<void> requestEdit({
    required String debtId,
    required String employeeId,
    required DebtType tipo,
    required int valorCents,
    required String descricao,
    required DateTime data,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final docRef = FirebaseFirestore.instance.collection('debts').doc(debtId);
    final snap = await docRef.get();
    final atual = snap.data();
    if (atual == null) {
      throw Exception('Divida nao encontrada.');
    }
    final debtEmployeeId = atual['employeeId']?.toString() ?? '';
    if (sessao.role == Role.employee && debtEmployeeId != uid) {
      throw Exception('Sem permissao para solicitar edicao desta divida.');
    }
    final status = (atual['status']?.toString() ?? '').toLowerCase();
    if (status == 'baixado' || status == 'settled' || status == 'cancelado' || status == 'canceled') {
      throw Exception('Esta divida nao esta aberta para edicao.');
    }
    if (sessao.role == Role.employee && atual['allowEmployeeEdit'] != true) {
      throw Exception('A empresa ainda nao permitiu edicao desta divida.');
    }
    if (atual['editRequestPending'] == true) {
      throw Exception('Ja existe uma solicitacao pendente para esta divida.');
    }

    await docRef.set({
      'companyId': sessao.companyId,
      'employeeId': employeeId,
      'editRequestPending': true,
      'editRequestBy': uid,
      'editRequestAt': FieldValue.serverTimestamp(),
      'editRequestPayload': {
        'tipo': tipo.name,
        'valorCents': valorCents,
        'amountCents': valorCents,
        'descricao': descricao,
        'title': descricao,
        'data': Timestamp.fromDate(data),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('request_edit');
  }

  Future<void> approveEditRequest(String debtId) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final docRef = FirebaseFirestore.instance.collection('debts').doc(debtId);
    final snap = await docRef.get();
    final map = snap.data() ?? <String, dynamic>{};
    final payload = map['editRequestPayload'];
    if (payload is! Map<String, dynamic>) {
      throw Exception('Sem solicitacao pendente para aprovar.');
    }

    await docRef.set({
      'companyId': sessao.companyId,
      'tipo': payload['tipo']?.toString() ?? map['tipo'],
      'type': payload['tipo']?.toString() == DebtType.adiantamento.name ? 'ADVANCE' : 'DEBT',
      'valorCents': (payload['valorCents'] as num?)?.toInt() ?? map['valorCents'],
      'amountCents': (payload['amountCents'] as num?)?.toInt() ??
          (payload['valorCents'] as num?)?.toInt() ??
          map['amountCents'],
      'descricao': payload['descricao']?.toString() ?? map['descricao'],
      'title': payload['title']?.toString() ?? payload['descricao']?.toString() ?? map['title'],
      'data': payload['data'] is Timestamp ? payload['data'] : map['data'],
      'editRequestPending': false,
      'editRequestApprovedBy': sessao.userId,
      'editRequestApprovedAt': FieldValue.serverTimestamp(),
      'editRequestPayload': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('approve_edit');
  }

  Future<void> setEmployeePermissions({
    required String debtId,
    required bool allowEmployeeEdit,
    required bool allowEmployeeSettle,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    if (sessao.role == Role.employee) {
      throw Exception('Somente a empresa pode alterar permissoes.');
    }

    await FirebaseFirestore.instance.collection('debts').doc(debtId).set({
      'companyId': sessao.companyId,
      'allowEmployeeEdit': allowEmployeeEdit,
      'allowEmployeeSettle': allowEmployeeSettle,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('set_permissions');
  }

  Future<void> payByEmployee(String debtId) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final docRef = FirebaseFirestore.instance.collection('debts').doc(debtId);
    final snap = await docRef.get();
    final map = snap.data();
    if (map == null) {
      throw Exception('Divida nao encontrada.');
    }
    final employeeId = map['employeeId']?.toString() ?? '';
    if (employeeId != uid) {
      throw Exception('Sem permissao para pagar esta divida.');
    }
    final allowEmployeeSettle = map['allowEmployeeSettle'] == true;
    if (!allowEmployeeSettle) {
      throw Exception('A empresa ainda nao permitiu pagamento pelo funcionario.');
    }
    final status = (map['status']?.toString() ?? '').toLowerCase();
    if (status == 'baixado' || status == 'settled' || status == 'cancelado' || status == 'canceled') {
      throw Exception('Esta divida nao esta aberta para pagamento.');
    }

    await docRef.set({
      'companyId': sessao.companyId,
      'status': 'SETTLED',
      'settledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('pay_by_employee');
  }

  Future<void> rejectEditRequest(String debtId) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('debts').doc(debtId).set({
      'companyId': sessao.companyId,
      'editRequestPending': false,
      'editRequestRejectedBy': sessao.userId,
      'editRequestRejectedAt': FieldValue.serverTimestamp(),
      'editRequestPayload': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('reject_edit');
  }

  Future<void> baixar(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('debts').doc(id).set({
      'companyId': sessao.companyId,
      'status': DebtStatus.baixado.name,
      'settledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _registrarAuditoria('baixar');
  }

  Future<void> remove(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    await FirebaseFirestore.instance.collection('debts').doc(id).set({
      'companyId': sessao.companyId,
      'status': 'CANCELED',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _registrarAuditoria('remove');
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'debts', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }
}

final debtsProvider = NotifierProvider<DebtsNotifier, List<Debt>>(
  DebtsNotifier.new,
);

