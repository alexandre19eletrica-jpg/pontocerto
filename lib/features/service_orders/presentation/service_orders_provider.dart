import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/service_orders/domain/service_order.dart';

class ServiceOrdersController extends Notifier<List<ServiceOrder>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<ServiceOrder> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseAvailable = ref.watch(firebaseAvailableProvider);
    final session = ref.watch(sessionProvider);
    _bindStream(firebaseAvailable, session);
    return <ServiceOrder>[];
  }

  void _bindStream(bool firebaseAvailable, Session? session) {
    _sub?.cancel();
    if (!firebaseAvailable || session == null) {
      state = <ServiceOrder>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? session.userId;
    Query<Map<String, dynamic>> query;
    if (session.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('service_orders')
          .where('assignedEmployeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('service_orders')
          .where('companyId', isEqualTo: session.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [
          for (final doc in snapshot.docs)
            ServiceOrder.fromMap({...doc.data(), 'id': doc.id}),
        ]..sort(
            (a, b) => (b.scheduledDate ?? DateTime(1900)).compareTo(
              a.scheduledDate ?? DateTime(1900),
            ),
          );
      },
      onError: (error) => debugPrint('serviceOrdersProvider stream error: $error'),
    );
  }

  Future<void> add(ServiceOrder order) async {
    final previous = state;
    state = [order, ...state.where((item) => item.id != order.id)];
    try {
      await FirebaseFirestore.instance
          .collection('service_orders')
          .doc(order.id)
          .set({
            ...order.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _audit('add');
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  Future<void> update(ServiceOrder order) async {
    final previous = state;
    state = [
      for (final item in state)
        if (item.id == order.id) order else item,
    ];
    try {
      await FirebaseFirestore.instance
          .collection('service_orders')
          .doc(order.id)
          .set({
            ...order.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _audit('update');
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  Future<void> remove(ServiceOrder order) async {
    final previous = state;
    state = [
      for (final item in state)
        if (item.id != order.id) item,
    ];
    try {
      await FirebaseFirestore.instance
          .collection('service_orders')
          .doc(order.id)
          .delete();
      _audit('delete');
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  void _audit(String action) {
    try {
      ref.read(auditProvider.notifier).log(
            modulo: 'service_orders',
            acao: action,
          );
    } catch (_) {}
  }
}

final serviceOrdersProvider =
    NotifierProvider<ServiceOrdersController, List<ServiceOrder>>(
  ServiceOrdersController.new,
);
