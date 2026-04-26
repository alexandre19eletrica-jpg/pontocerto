import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';

class TasksController extends Notifier<List<TarefaItem>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<TarefaItem> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bindStream(firebaseDisponivel, sessao);
    return <TarefaItem>[];
  }

  void _bindStream(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <TarefaItem>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('tasks')
          .where('autorId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('tasks')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromFirestoreDoc(doc)]
          ..sort(
            (a, b) => (b.dataExecucao ?? DateTime(1900)).compareTo(
              a.dataExecucao ?? DateTime(1900),
            ),
          );
      },
      onError: (error, stackTrace) {
        debugPrint('tasksProvider stream error: $error');
      },
    );
  }

  TarefaItem _fromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    return TarefaItem.fromMap({...map, 'id': doc.id});
  }

  Future<void> add(TarefaItem tarefa) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }
    final identidade = await _resolverIdentidade(sessao);

    final snapshotAnterior = state;
    state = [
      tarefa,
      for (final item in state)
        if (item.id != tarefa.id) item,
    ];
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(tarefa.id).set({
        'companyId': identidade.companyId,
        'autorId': tarefa.autorId,
        'autorNome': tarefa.autorNome,
        'createdByUserId': identidade.uid,
        'createdByUserName': sessao.nome,
        'nome': tarefa.nome,
        'descricao': tarefa.descricao,
        'clienteId': tarefa.clienteId,
        'clienteNome': tarefa.clienteNome,
        'clienteDocumento': tarefa.clienteDocumento,
        'dataExecucao': tarefa.dataExecucao?.toIso8601String(),
        'itens': tarefa.itens.map((e) => e.toMap()).toList(),
        'materiaisNecessarios': tarefa.materiaisNecessarios
            .map((e) => e.toMap())
            .toList(),
        'materiaisUtilizados': tarefa.materiaisUtilizados
            .map((e) => e.toMap())
            .toList(),
        'anexos': tarefa.anexos.map((e) => e.toMap()).toList(),
        'status': tarefa.status.name,
        'valorTotalCents': tarefa.valorTotalCents,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('add');
  }

  Future<void> updateById(String id, TarefaItem tarefa) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }
    final identidade = await _resolverIdentidade(sessao);

    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id == id) tarefa else item,
    ];
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(id).set({
        'companyId': identidade.companyId,
        'autorId': tarefa.autorId,
        'autorNome': tarefa.autorNome,
        'updatedByUserId': identidade.uid,
        'updatedByUserName': sessao.nome,
        'nome': tarefa.nome,
        'descricao': tarefa.descricao,
        'clienteId': tarefa.clienteId,
        'clienteNome': tarefa.clienteNome,
        'clienteDocumento': tarefa.clienteDocumento,
        'dataExecucao': tarefa.dataExecucao?.toIso8601String(),
        'itens': tarefa.itens.map((e) => e.toMap()).toList(),
        'materiaisNecessarios': tarefa.materiaisNecessarios
            .map((e) => e.toMap())
            .toList(),
        'materiaisUtilizados': tarefa.materiaisUtilizados
            .map((e) => e.toMap())
            .toList(),
        'anexos': tarefa.anexos.map((e) => e.toMap()).toList(),
        'status': tarefa.status.name,
        'valorTotalCents': tarefa.valorTotalCents,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('update');
  }

  Future<void> removeById(String id) async {
    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id != id) item,
    ];
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(id).delete();
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }
    _registrarAuditoria('remove');
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'tasks', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }

  Future<({String uid, String companyId})> _resolverIdentidade(
    Session sessao,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    var companyId = sessao.companyId;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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

final tasksProvider = NotifierProvider<TasksController, List<TarefaItem>>(
  TasksController.new,
);
