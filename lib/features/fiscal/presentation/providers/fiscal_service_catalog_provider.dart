import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/fiscal/domain/fiscal_service_item.dart';

class FiscalServiceCatalogController extends Notifier<List<FiscalServiceItem>> {
  Session? _session;

  @override
  List<FiscalServiceItem> build() {
    final session = ref.watch(sessionProvider);
    _session = session;
    if (session == null) {
      return const <FiscalServiceItem>[];
    }
    unawaited(refresh(companyId: session.companyId));
    return const <FiscalServiceItem>[];
  }

  Future<void> refresh({String? companyId}) async {
    final effectiveCompanyId = companyId ?? _session?.companyId;
    if (effectiveCompanyId == null || effectiveCompanyId.isEmpty) {
      state = const <FiscalServiceItem>[];
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fiscal_service_catalog')
          .where('companyId', isEqualTo: effectiveCompanyId)
          .get();
      state = [
        for (final doc in snapshot.docs)
          FiscalServiceItem.fromMap(doc.id, doc.data()),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (error) {
      debugPrint('fiscalServiceCatalog refresh error: $error');
    }
  }

  Future<void> save(FiscalServiceItem item, {bool isNew = false}) async {
    final refDoc = FirebaseFirestore.instance
        .collection('fiscal_service_catalog')
        .doc(item.id);
    await refDoc.set({
      ...item.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await refresh(companyId: item.companyId);
  }

  Future<void> remove(String id) async {
    await FirebaseFirestore.instance
        .collection('fiscal_service_catalog')
        .doc(id)
        .delete();
    await refresh();
  }
}

final fiscalServiceCatalogProvider =
    NotifierProvider<FiscalServiceCatalogController, List<FiscalServiceItem>>(
      FiscalServiceCatalogController.new,
    );
