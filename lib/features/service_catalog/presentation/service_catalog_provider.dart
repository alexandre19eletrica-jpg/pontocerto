import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/service_catalog/domain/service_catalog_item.dart';

class ServiceCatalogController extends Notifier<List<ServiceCatalogItem>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _companyIdEfetivo;

  @override
  List<ServiceCatalogItem> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return const <ServiceCatalogItem>[];
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = const <ServiceCatalogItem>[];
      return;
    }
    final companyId = (_companyIdEfetivo ?? sessao.companyId).trim();
    _sub = FirebaseFirestore.instance
        .collection('service_catalog')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .listen(
          (snap) {
            state = [
              for (final doc in snap.docs)
                ServiceCatalogItem.fromMap(doc.id, doc.data()),
            ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
          },
          onError: (e) => debugPrint('serviceCatalog stream error: $e'),
        );
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final companyId = doc.data()?['companyId']?.toString().trim();
      if (companyId != null && companyId.isNotEmpty) return companyId;
    } catch (_) {
      // fallback sessao.
    }
    return sessao.companyId.trim();
  }

  Future<void> add({
    required String nome,
    required int valorCents,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final companyId = await _resolverCompanyId(sessao);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await FirebaseFirestore.instance.collection('service_catalog').doc(id).set({
      'companyId': companyId,
      'nome': nome,
      'valorCents': valorCents,
      'pendingDelete': false,
      'pendingDeleteByName': '',
      'pendingEditNome': null,
      'pendingEditValorCents': null,
      'pendingEditByName': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addMany(List<({String nome, int valorCents})> servicos) async {
    final existentes = <String, ServiceCatalogItem>{
      for (final e in state) e.nome.trim().toLowerCase(): e,
    };
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final companyId = await _resolverCompanyId(sessao);

    for (final s in servicos) {
      final nome = s.nome.trim();
      if (nome.isEmpty || s.valorCents <= 0) continue;
      final key = nome.toLowerCase();
      final atual = existentes[key];
      if (atual != null) {
        await FirebaseFirestore.instance.collection('service_catalog').doc(atual.id).set({
          'companyId': companyId,
          'nome': nome,
          'valorCents': s.valorCents,
          'pendingDelete': false,
          'pendingDeleteByName': '',
          'pendingEditNome': null,
          'pendingEditValorCents': null,
          'pendingEditByName': '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        continue;
      }
      await add(nome: nome, valorCents: s.valorCents);
    }
  }

  Future<void> edit({
    required ServiceCatalogItem item,
    required String nome,
    required int valorCents,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final isEmpresa = sessao.role != Role.employee;

    if (isEmpresa) {
      await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).set({
        'nome': nome,
        'valorCents': valorCents,
        'pendingEditNome': null,
        'pendingEditValorCents': null,
        'pendingEditByName': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).set({
      'pendingEditNome': nome,
      'pendingEditValorCents': valorCents,
      'pendingEditByName': sessao.nome,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(ServiceCatalogItem item) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    final isEmpresa = sessao.role != Role.employee;

    if (isEmpresa) {
      await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).delete();
      return;
    }

    await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).set({
      'pendingDelete': true,
      'pendingDeleteByName': sessao.nome,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveEdit(ServiceCatalogItem item) async {
    await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).set({
      'nome': item.pendingEditNome ?? item.nome,
      'valorCents': item.pendingEditValorCents ?? item.valorCents,
      'pendingEditNome': null,
      'pendingEditValorCents': null,
      'pendingEditByName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectEdit(ServiceCatalogItem item) async {
    await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).set({
      'pendingEditNome': null,
      'pendingEditValorCents': null,
      'pendingEditByName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveDelete(ServiceCatalogItem item) async {
    await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).delete();
  }

  Future<void> rejectDelete(ServiceCatalogItem item) async {
    await FirebaseFirestore.instance.collection('service_catalog').doc(item.id).set({
      'pendingDelete': false,
      'pendingDeleteByName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final serviceCatalogProvider =
    NotifierProvider<ServiceCatalogController, List<ServiceCatalogItem>>(
      ServiceCatalogController.new,
    );
