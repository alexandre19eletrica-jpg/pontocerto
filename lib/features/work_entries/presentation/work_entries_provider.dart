import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/work_entries/domain/work_entry.dart';

class WorkEntriesNotifier extends Notifier<List<WorkEntry>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<WorkEntry> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bindStream(firebaseDisponivel, sessao);
    return <WorkEntry>[];
  }

  void _bindStream(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <WorkEntry>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('work_entries')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('work_entries')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)]
          ..sort((a, b) => b.data.compareTo(a.data));
      },
      onError: (error, stackTrace) {
        debugPrint('workEntriesProvider stream error: $error');
      },
    );
  }

  WorkEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final timestamp = map['data'];
    final data = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now();

    final statusTexto = map['status']?.toString() ?? WorkEntryStatus.pendente.name;

    return WorkEntry(
      id: doc.id,
      employeeId: map['employeeId']?.toString() ?? '',
      data: data,
      horas: (map['horas'] as num?)?.toInt() ?? 0,
      status: statusTexto == WorkEntryStatus.aprovado.name
          ? WorkEntryStatus.aprovado
          : WorkEntryStatus.pendente,
      projectId: map['projectId']?.toString() ?? '',
      projectName: map['projectName']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      taskId: map['taskId']?.toString() ?? '',
      serviceOrderId: map['serviceOrderId']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
    );
  }

  Future<void> add(
    String employeeId,
    DateTime data,
    int horas, {
    String projectId = '',
    String projectName = '',
    String clientId = '',
    String clientName = '',
    String taskId = '',
    String serviceOrderId = '',
    String notes = '',
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final snapshotAnterior = state;
    final novo = WorkEntry(
      id: id,
      employeeId: employeeId,
      data: data,
      horas: horas,
      status: WorkEntryStatus.pendente,
      projectId: projectId,
      projectName: projectName,
      clientId: clientId,
      clientName: clientName,
      taskId: taskId,
      serviceOrderId: serviceOrderId,
      notes: notes,
    );
    state = [novo, ...state];

    try {
      await FirebaseFirestore.instance.collection('work_entries').doc(id).set({
        'companyId': sessao.companyId,
        'employeeId': employeeId,
        'data': Timestamp.fromDate(data),
        'horas': horas,
        'status': WorkEntryStatus.pendente.name,
        'projectId': projectId,
        'projectName': projectName,
        'clientId': clientId,
        'clientName': clientName,
        'taskId': taskId,
        'serviceOrderId': serviceOrderId,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('add');
  }

  Future<void> update(
    String id,
    String employeeId,
    DateTime data,
    int horas, {
    String? projectId,
    String? projectName,
    String? clientId,
    String? clientName,
    String? taskId,
    String? serviceOrderId,
    String? notes,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            employeeId: employeeId,
            data: data,
            horas: horas,
            projectId: projectId,
            projectName: projectName,
            clientId: clientId,
            clientName: clientName,
            taskId: taskId,
            serviceOrderId: serviceOrderId,
            notes: notes,
          )
        else
          item,
    ];
    try {
      await FirebaseFirestore.instance.collection('work_entries').doc(id).set({
        'companyId': sessao.companyId,
        'employeeId': employeeId,
        'data': Timestamp.fromDate(data),
        'horas': horas,
        'projectId': projectId,
        'projectName': projectName,
        'clientId': clientId,
        'clientName': clientName,
        'taskId': taskId,
        'serviceOrderId': serviceOrderId,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('update');
  }

  Future<void> approve(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(status: WorkEntryStatus.aprovado) else item,
    ];
    try {
      await FirebaseFirestore.instance.collection('work_entries').doc(id).set({
        'companyId': sessao.companyId,
        'status': WorkEntryStatus.aprovado.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('approve');
  }

  Future<void> remove(String id) async {
    final snapshotAnterior = state;
    state = [for (final item in state) if (item.id != id) item];
    try {
      await FirebaseFirestore.instance.collection('work_entries').doc(id).delete();
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }
    _registrarAuditoria('remove');
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'work_entries', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }
}

final workEntriesProvider =
    NotifierProvider<WorkEntriesNotifier, List<WorkEntry>>(
  WorkEntriesNotifier.new,
);

