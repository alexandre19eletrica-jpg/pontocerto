import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/material_catalog/domain/material_catalog_item.dart';

class MaterialCatalogController extends Notifier<List<MaterialCatalogItem>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _companyIdEfetivo;

  @override
  List<MaterialCatalogItem> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return const <MaterialCatalogItem>[];
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = const <MaterialCatalogItem>[];
      return;
    }
    final companyId = (_companyIdEfetivo ?? sessao.companyId).trim();
    _sub = FirebaseFirestore.instance
        .collection('material_catalog')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .listen((snap) {
          state =
              [
                for (final doc in snap.docs)
                  MaterialCatalogItem.fromMap(doc.id, doc.data()),
              ]..sort(
                (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
              );
        }, onError: (e) => debugPrint('materialCatalog stream error: $e'));
    _syncCompanyIdEfetivo(sessao);
  }

  Future<void> _syncCompanyIdEfetivo(Session sessao) async {
    final resolved = await _resolverCompanyId(sessao);
    if (resolved.isEmpty || resolved == _companyIdEfetivo) return;
    _companyIdEfetivo = resolved;
    final firebaseDisponivel = ref.read(firebaseAvailableProvider);
    final sessaoAtual = ref.read(sessionProvider);
    _bind(firebaseDisponivel, sessaoAtual);
  }

  Future<String> _resolverCompanyId(Session sessao) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final companyId = doc.data()?['companyId']?.toString().trim();
      if (companyId != null && companyId.isNotEmpty) return companyId;
    } catch (_) {
      // fallback para sessao.
    }
    return sessao.companyId.trim();
  }

  Future<void> save({
    String? id,
    required String nome,
    required int quantidade,
    required String unidade,
    required String observacao,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final companyId = await _resolverCompanyId(sessao);
    final isEmpresa = sessao.role != Role.employee;
    final docId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final normalizedQuantidade = quantidade < 1 ? 1 : quantidade;
    final normalizedUnidade = unidade.trim().isEmpty ? 'un' : unidade.trim();
    final normalizedObservacao = observacao.trim();

    if (id == null) {
      await FirebaseFirestore.instance.collection('material_catalog').doc(docId).set({
        'companyId': companyId,
        'nome': nome,
        'quantidade': normalizedQuantidade,
        'unidade': normalizedUnidade,
        'observacao': normalizedObservacao,
        'pendingCreate': !isEmpresa,
        'pendingCreateByName': isEmpresa ? '' : sessao.nome,
        'pendingEditNome': null,
        'pendingEditQuantidade': null,
        'pendingEditUnidade': null,
        'pendingEditObservacao': null,
        'pendingEditByName': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    if (isEmpresa) {
      await FirebaseFirestore.instance.collection('material_catalog').doc(docId).set({
        'companyId': companyId,
        'nome': nome,
        'quantidade': normalizedQuantidade,
        'unidade': normalizedUnidade,
        'observacao': normalizedObservacao,
        'pendingEditNome': null,
        'pendingEditQuantidade': null,
        'pendingEditUnidade': null,
        'pendingEditObservacao': null,
        'pendingEditByName': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await FirebaseFirestore.instance.collection('material_catalog').doc(docId).set({
      'pendingEditNome': nome,
      'pendingEditQuantidade': normalizedQuantidade,
      'pendingEditUnidade': normalizedUnidade,
      'pendingEditObservacao': normalizedObservacao,
      'pendingEditByName': sessao.nome,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertMany(
    List<({String nome, int quantidade, String unidade, String observacao})>
    materiais,
  ) async {
    final existentes = <String, MaterialCatalogItem>{
      for (final e in state) e.nome.trim().toLowerCase(): e,
    };
    for (final material in materiais) {
      final nome = material.nome.trim();
      if (nome.isEmpty) continue;
      final atual = existentes[nome.toLowerCase()];
      await save(
        id: atual?.id,
        nome: nome,
        quantidade: material.quantidade,
        unidade: material.unidade,
        observacao: material.observacao,
      );
    }
  }

  Future<void> delete(String id) async {
    await FirebaseFirestore.instance
        .collection('material_catalog')
        .doc(id)
        .delete();
  }

  Future<void> approveCreate(MaterialCatalogItem item) async {
    await FirebaseFirestore.instance.collection('material_catalog').doc(item.id).set({
      'pendingCreate': false,
      'pendingCreateByName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectCreate(MaterialCatalogItem item) async {
    await FirebaseFirestore.instance.collection('material_catalog').doc(item.id).delete();
  }

  Future<void> approveEdit(MaterialCatalogItem item) async {
    await FirebaseFirestore.instance.collection('material_catalog').doc(item.id).set({
      'nome': item.pendingEditNome ?? item.nome,
      'quantidade': item.pendingEditQuantidade ?? item.quantidadeNormalizada,
      'unidade': item.pendingEditUnidade ?? item.unidadeNormalizada,
      'observacao': item.pendingEditObservacao ?? item.observacaoNormalizada,
      'pendingEditNome': null,
      'pendingEditQuantidade': null,
      'pendingEditUnidade': null,
      'pendingEditObservacao': null,
      'pendingEditByName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectEdit(MaterialCatalogItem item) async {
    await FirebaseFirestore.instance.collection('material_catalog').doc(item.id).set({
      'pendingEditNome': null,
      'pendingEditQuantidade': null,
      'pendingEditUnidade': null,
      'pendingEditObservacao': null,
      'pendingEditByName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final materialCatalogProvider =
    NotifierProvider<MaterialCatalogController, List<MaterialCatalogItem>>(
      MaterialCatalogController.new,
    );
