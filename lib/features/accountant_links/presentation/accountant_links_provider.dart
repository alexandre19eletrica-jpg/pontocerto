import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/accountant_links/domain/accountant_link.dart';

final accountantLinksProvider = StreamProvider<List<AccountantLink>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return Stream.value(const <AccountantLink>[]);
  }

  return FirebaseFirestore.instance
      .collection('accountant_links')
      .where('companyId', isEqualTo: session.companyId)
      .snapshots()
      .map((snapshot) {
        final list = [
          for (final doc in snapshot.docs)
            AccountantLink.fromMap({...doc.data(), 'id': doc.id}),
        ]..sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
        return list;
      });
});
