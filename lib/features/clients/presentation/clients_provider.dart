import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/fiscal/domain/invoice_customer.dart';

class ClientsController extends Notifier<List<InvoiceCustomer>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<InvoiceCustomer> build() {
    ref.onDispose(() => _sub?.cancel());
    final session = ref.watch(sessionProvider);
    _bind(session);
    return const <InvoiceCustomer>[];
  }

  void _bind(Session? session) {
    _sub?.cancel();
    if (session == null) {
      state = const <InvoiceCustomer>[];
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('invoice_customers')
        .where('companyId', isEqualTo: session.companyId)
        .snapshots()
        .listen(
          (snapshot) {
            state = [
              for (final doc in snapshot.docs)
                InvoiceCustomer.fromMap(doc.id, doc.data()),
            ]..sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
          },
          onError: (error) => debugPrint('clientsProvider stream error: $error'),
        );
  }
}

final clientsProvider = NotifierProvider<ClientsController, List<InvoiceCustomer>>(
  ClientsController.new,
);
