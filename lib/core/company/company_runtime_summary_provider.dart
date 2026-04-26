import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';

final companyRuntimeSummaryProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
      final session = ref.watch(sessionProvider);
      if (session == null) {
        return const Stream<Map<String, dynamic>?>.empty();
      }

      return FirebaseFirestore.instance
          .collection('company_runtime_summary')
          .doc(session.companyId)
          .snapshots()
          .map((snapshot) => snapshot.data());
    });
