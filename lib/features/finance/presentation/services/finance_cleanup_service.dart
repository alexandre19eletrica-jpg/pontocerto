import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FinanceCleanupService {
  FinanceCleanupService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const _batchSize = 350;

  Future<void> clearCompanyOperationalData() async {
    final sessao = await _session();

    // Preserva a base mestre da empresa para evitar perda estrutural ao escalar:
    // nao apaga users, company_settings, cadastros principais ou configuracoes.
    final collections = <String>[
      'finance_movements',
      'payments',
      'debts',
      'tasks',
      'work_entries',
      'punches',
      'worked_days',
      'justifications',
      'audit_logs',
      'employees',
      'device_consents',
      'notifications',
      'reports',
      'period_closes',
      'app_updates',
    ];

    for (final collection in collections) {
      await _deleteByCompanyId(collection, sessao.companyId);
    }

    await _deleteStorageFolder('companies/${sessao.companyId}');
  }

  Future<void> _deleteByCompanyId(String collection, String companyId) async {
    while (true) {
      final snap = await _firestore
          .collection(collection)
          .where('companyId', isEqualTo: companyId)
          .limit(_batchSize)
          .get();
      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteStorageFolder(String folderPath) async {
    try {
      final ref = _storage.ref(folderPath);
      await _deleteStorageRefRecursively(ref);
    } catch (_) {
      // Nao bloqueia limpeza do Firestore caso o storage falhe.
    }
  }

  Future<void> _deleteStorageRefRecursively(Reference ref) async {
    final listed = await ref.listAll();
    for (final item in listed.items) {
      await item.delete();
    }
    for (final prefix in listed.prefixes) {
      await _deleteStorageRefRecursively(prefix);
    }
  }

  Future<_SessionData> _session() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw FinanceCleanupException('Sessao nao encontrada.');
    final doc = await _firestore.collection('users').doc(uid).get();
    final map = doc.data();
    if (map == null) throw FinanceCleanupException('Perfil nao encontrado.');

    final role = map['role']?.toString().toUpperCase() ?? '';
    if (role != 'OWNER' && role != 'MANAGER') {
      throw FinanceCleanupException('Sem permissao para limpar registros.');
    }

    final companyId = map['companyId']?.toString().trim();
    if (companyId == null || companyId.isEmpty) {
      throw FinanceCleanupException('CompanyId nao encontrado.');
    }
    return _SessionData(companyId: companyId);
  }
}

class FinanceCleanupException implements Exception {
  FinanceCleanupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _SessionData {
  const _SessionData({
    required this.companyId,
  });

  final String companyId;
}
