import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/accountant_links/domain/accountant_link.dart';

final accountantCompanyLinksProvider = StreamProvider<List<AccountantLink>>((
  ref,
) {
  final session = ref.watch(sessionProvider);
  if (session == null || session.role != Role.accountant) {
    return Stream.value(const <AccountantLink>[]);
  }

  return FirebaseFirestore.instance
      .collection('accountant_links')
      .where('accountantUserId', isEqualTo: session.userId)
      .snapshots()
      .map((snapshot) {
        final rawLinks = [
          for (final doc in snapshot.docs)
            AccountantLink.fromMap({...doc.data(), 'id': doc.id}),
        ];

        final hasRichLinks = rawLinks.any(_isRichAccountantLink);
        final normalizedLinks = hasRichLinks
            ? rawLinks.where((item) => _isRichAccountantLink(item)).toList()
            : rawLinks;

        final dedupedLinks = <String, AccountantLink>{};
        for (final item in normalizedLinks) {
          final key = _dedupeKey(item);
          final current = dedupedLinks[key];
          if (current == null) {
            dedupedLinks[key] = item;
            continue;
          }

          final currentScore = _linkScore(current);
          final nextScore = _linkScore(item);
          if (nextScore >= currentScore) {
            dedupedLinks[key] = item;
          }
        }

        final links = dedupedLinks.values.toList()
          ..sort((a, b) {
            final aAct = a.isActive ? 0 : 1;
            final bAct = b.isActive ? 0 : 1;
            if (aAct != bAct) return aAct.compareTo(bAct);
            return a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
          });
        return links;
      });
});

int _linkScore(AccountantLink item) {
  var score = item.isActive ? 500000 : 0;
  if (item.companyDisplayCode.trim().isNotEmpty) score += 10;
  if (item.companyDocument.trim().isNotEmpty) score += 5;
  if (item.companyName.trim().isNotEmpty) score += 5;
  if (item.updatedAt != null) score += item.updatedAt!.millisecondsSinceEpoch;
  return score;
}

bool _isRichAccountantLink(AccountantLink item) {
  return item.companyName.trim().isNotEmpty ||
      item.companyDocument.trim().isNotEmpty ||
      item.companyDisplayCode.trim().isNotEmpty;
}

String _dedupeKey(AccountantLink item) {
  final document = item.companyDocument.replaceAll(RegExp(r'[^0-9]'), '');
  if (document.isNotEmpty) {
    return 'doc:$document';
  }

  final companyId = item.companyId.trim().toLowerCase();
  if (companyId.isNotEmpty) {
    return 'company:$companyId';
  }

  final companyName = item.companyName.trim().toLowerCase();
  return 'name:$companyName';
}
