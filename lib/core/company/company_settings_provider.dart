import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';

final companySettingsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
      final firebaseAvailable = ref.watch(firebaseAvailableProvider);
      final session = ref.watch(sessionProvider);
      if (!firebaseAvailable || session == null) {
        return Stream.value(const <String, dynamic>{});
      }

      return FirebaseFirestore.instance
          .collection('company_settings')
          .doc(session.companyId)
          .snapshots()
          .map((snapshot) => snapshot.data() ?? <String, dynamic>{});
    });
