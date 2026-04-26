import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/recurring_billing/domain/recurring_billing_profile.dart';

class RecurringBillingController
    extends Notifier<List<RecurringBillingProfile>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<RecurringBillingProfile> build() {
    ref.onDispose(() => _sub?.cancel());
    final session = ref.watch(sessionProvider);
    _bind(session);
    return const <RecurringBillingProfile>[];
  }

  void _bind(Session? session) {
    _sub?.cancel();
    if (session == null) {
      state = const <RecurringBillingProfile>[];
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('recurring_billings')
        .where('companyId', isEqualTo: session.companyId)
        .snapshots()
        .listen(
          (snapshot) {
            state = [
              for (final doc in snapshot.docs)
                RecurringBillingProfile.fromMap({...doc.data(), 'id': doc.id}),
            ]..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
          },
          onError: (error) =>
              debugPrint('recurringBillingProvider stream error: $error'),
        );
  }

  Future<void> add(RecurringBillingProfile profile) async {
    final previous = state;
    state = [profile, ...state.where((item) => item.id != profile.id)];
    try {
      await FirebaseFirestore.instance
          .collection('recurring_billings')
          .doc(profile.id)
          .set({
            ...profile.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  Future<void> update(RecurringBillingProfile profile) async {
    final previous = state;
    state = [
      for (final item in state) if (item.id == profile.id) profile else item,
    ];
    try {
      await FirebaseFirestore.instance
          .collection('recurring_billings')
          .doc(profile.id)
          .set({
            ...profile.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  Future<void> remove(RecurringBillingProfile profile) async {
    final previous = state;
    state = [
      for (final item in state)
        if (item.id != profile.id) item,
    ];
    try {
      await FirebaseFirestore.instance
          .collection('recurring_billings')
          .doc(profile.id)
          .delete();
    } catch (error) {
      state = previous;
      rethrow;
    }
  }
}

final recurringBillingProvider = NotifierProvider<
  RecurringBillingController,
  List<RecurringBillingProfile>
>(RecurringBillingController.new);
