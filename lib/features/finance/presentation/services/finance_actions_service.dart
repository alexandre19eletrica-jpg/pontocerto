import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FinanceActionsService {
  FinanceActionsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<void> createPayment({
    required String employeeId,
    required int competenceYear,
    required int competenceMonth,
    required int grossCents,
    required int discountsCents,
    DateTime? dueDate,
    String? paymentType,
    bool markAsPaid = false,
  }) async {
    try {
      await _call('paymentsCreate', {
        'employeeId': employeeId,
        'competenceYear': competenceYear,
        'competenceMonth': competenceMonth,
        'grossCents': grossCents,
        'discountsCents': discountsCents,
        if (paymentType != null) 'paymentType': paymentType,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        'markAsPaid': markAsPaid,
      });
    } on FinanceActionNotFoundException {
      final sessao = await _session();
      final net = grossCents - discountsCents;
      if (net < 0) {
        throw FinanceActionException('Descontos nao podem superar o valor bruto.');
      }
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      await _firestore.collection('payments').doc(id).set({
        'companyId': sessao.companyId,
        'employeeId': employeeId,
        'competenceYear': competenceYear,
        'competenceMonth': competenceMonth,
        'grossCents': grossCents,
        'discountsCents': discountsCents,
        'netCents': net,
        'paymentType': paymentType,
        'competencia': '$competenceYear-${competenceMonth.toString().padLeft(2, '0')}',
        'valorCents': net,
        'status': markAsPaid ? 'PAID' : 'PENDING',
        'paidAt': markAsPaid ? FieldValue.serverTimestamp() : null,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'createdByUserId': sessao.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updatePayment({
    required String paymentId,
    required String employeeId,
    required int competenceYear,
    required int competenceMonth,
    required int grossCents,
    required int discountsCents,
  }) async {
    try {
      await _call('paymentsUpdate', {
        'paymentId': paymentId,
        'employeeId': employeeId,
        'competenceYear': competenceYear,
        'competenceMonth': competenceMonth,
        'grossCents': grossCents,
        'discountsCents': discountsCents,
      });
    } on FinanceActionNotFoundException {
      final net = grossCents - discountsCents;
      if (net < 0) {
        throw FinanceActionException('Descontos nao podem superar o valor bruto.');
      }
      await _firestore.collection('payments').doc(paymentId).set({
        'employeeId': employeeId,
        'competenceYear': competenceYear,
        'competenceMonth': competenceMonth,
        'competencia': '$competenceYear-${competenceMonth.toString().padLeft(2, '0')}',
        'grossCents': grossCents,
        'discountsCents': discountsCents,
        'netCents': net,
        'valorCents': net,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<FinanceBulkPaymentResult> createPaymentsBulk({
    required int competenceYear,
    required int competenceMonth,
    required List<FinanceBulkPaymentInput> items,
  }) async {
    try {
      final response = await _functions.httpsCallable('paymentsCreateBulk').call({
        'competenceYear': competenceYear,
        'competenceMonth': competenceMonth,
        'items': [
          for (final item in items)
            {
              'employeeId': item.employeeId,
              'grossCents': item.grossCents,
              'discountsCents': item.discountsCents,
              if (item.paymentType != null) 'paymentType': item.paymentType,
              if (item.dueDate != null) 'dueDate': item.dueDate!.toIso8601String(),
              'markAsPaid': item.markAsPaid,
            },
        ],
      });
      return FinanceBulkPaymentResult.fromMap(
        (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      );
    } on FinanceActionNotFoundException {
      var createdCount = 0;
      final failed = <FinanceBulkPaymentIssue>[];
      for (final item in items) {
        try {
          await createPayment(
            employeeId: item.employeeId,
            competenceYear: competenceYear,
            competenceMonth: competenceMonth,
            grossCents: item.grossCents,
            discountsCents: item.discountsCents,
            dueDate: item.dueDate,
            paymentType: item.paymentType,
            markAsPaid: item.markAsPaid,
          );
          createdCount++;
        } on FinanceActionException catch (e) {
          failed.add(
            FinanceBulkPaymentIssue(
              employeeId: item.employeeId,
              message: e.message,
            ),
          );
        } catch (_) {
          failed.add(
            FinanceBulkPaymentIssue(
              employeeId: item.employeeId,
              message: 'Falha ao lancar pagamento.',
            ),
          );
        }
      }
      return FinanceBulkPaymentResult(
        createdCount: createdCount,
        skipped: const <FinanceBulkPaymentIssue>[],
        failed: failed,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw FinanceActionNotFoundException();
      }
      throw FinanceActionException(_mapFunctionError(e, 'paymentsCreateBulk'));
    } catch (_) {
      throw FinanceActionException('Falha ao executar paymentsCreateBulk.');
    }
  }

  Future<void> markPaid(String paymentId) async {
    try {
      await _call('paymentsMarkPaid', {'paymentId': paymentId});
    } on FinanceActionNotFoundException {
      await _firestore.collection('payments').doc(paymentId).set({
        'status': 'PAID',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> confirm(String paymentId) async {
    try {
      await _call('paymentsConfirm', {'paymentId': paymentId});
    } on FinanceActionNotFoundException {
      await _firestore.collection('payments').doc(paymentId).set({
        'status': 'CONFIRMED',
        'confirmationAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> contest({required String paymentId, required String reason}) async {
    try {
      await _call('paymentsContest', {'paymentId': paymentId, 'reason': reason});
    } on FinanceActionNotFoundException {
      await _firestore.collection('payments').doc(paymentId).set({
        'status': 'CONTESTED',
        'contestReason': reason,
        'motivoContestacao': reason,
        'contestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> cancelPayment(String paymentId) async {
    try {
      await _call('paymentsCancel', {'paymentId': paymentId});
    } on FinanceActionNotFoundException {
      await _firestore.collection('payments').doc(paymentId).set({
        'status': 'CANCELED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deletePayment(String paymentId) async {
    await _firestore.collection('payments').doc(paymentId).delete();
  }

  Future<void> createDebt({
    required String employeeId,
    required String title,
    required String type,
    required int amountCents,
    DateTime? dueDate,
  }) async {
    try {
      await _call('debtsCreate', {
        'employeeId': employeeId,
        'title': title,
        'type': type,
        'amountCents': amountCents,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      });
    } on FinanceActionNotFoundException {
      final sessao = await _session();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      await _firestore.collection('debts').doc(id).set({
        'companyId': sessao.companyId,
        'employeeId': employeeId,
        'title': title,
        'descricao': title,
        'type': type,
        'tipo': type == 'ADVANCE' ? 'adiantamento' : 'divida',
        'amountCents': amountCents,
        'valorCents': amountCents,
        'status': 'OPEN',
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'createdByUserId': sessao.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> settleDebt(String debtId) async {
    try {
      await _call('debtsSettle', {'debtId': debtId});
    } on FinanceActionNotFoundException {
      await _firestore.collection('debts').doc(debtId).set({
        'status': 'SETTLED',
        'settledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> cancelDebt(String debtId) async {
    try {
      await _call('debtsCancel', {'debtId': debtId});
    } on FinanceActionNotFoundException {
      await _firestore.collection('debts').doc(debtId).set({
        'status': 'CANCELED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteDebt(String debtId) async {
    await _firestore.collection('debts').doc(debtId).delete();
  }

  Future<void> createPersonalMovement({
    required String title,
    required String type,
    required int amountCents,
    required DateTime date,
    DateTime? dueDate,
    required String paymentStatus,
    String? notes,
  }) async {
    final sessao = await _session();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _firestore.collection('finance_movements').doc(id).set({
      'companyId': sessao.companyId,
      'ownerUserId': sessao.userId,
      'title': title,
      'type': type.toUpperCase() == 'INCOME' ? 'INCOME' : 'EXPENSE',
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'paymentStatus': paymentStatus.toUpperCase() == 'PAID' ? 'PAID' : 'PENDING',
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePersonalMovement({
    required String movementId,
    required String title,
    required String type,
    required int amountCents,
    required DateTime date,
    DateTime? dueDate,
    required String paymentStatus,
    String? notes,
  }) async {
    await _firestore.collection('finance_movements').doc(movementId).set({
      'title': title,
      'type': type.toUpperCase() == 'INCOME' ? 'INCOME' : 'EXPENSE',
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'paymentStatus': paymentStatus.toUpperCase() == 'PAID' ? 'PAID' : 'PENDING',
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletePersonalMovement(String movementId) async {
    await _firestore.collection('finance_movements').doc(movementId).delete();
  }

  Future<void> createCompanyMovement({
    required String title,
    required String type,
    required String category,
    required int amountCents,
    required DateTime date,
    DateTime? dueDate,
    required String paymentStatus,
    String? notes,
  }) async {
    final sessao = await _session();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _firestore.collection('finance_movements').doc(id).set({
      'companyId': sessao.companyId,
      'ownerUserId': '__COMPANY__',
      'title': title,
      'category': category,
      'type': type.toUpperCase() == 'INCOME' ? 'INCOME' : 'EXPENSE',
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'paymentStatus': paymentStatus.toUpperCase() == 'PAID' ? 'PAID' : 'PENDING',
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCompanyMovement({
    required String movementId,
    required String title,
    required String type,
    required String category,
    required int amountCents,
    required DateTime date,
    DateTime? dueDate,
    required String paymentStatus,
    String? notes,
  }) async {
    await _firestore.collection('finance_movements').doc(movementId).set({
      'title': title,
      'category': category,
      'type': type.toUpperCase() == 'INCOME' ? 'INCOME' : 'EXPENSE',
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'paymentStatus': paymentStatus.toUpperCase() == 'PAID' ? 'PAID' : 'PENDING',
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCompanyMovement(String movementId) async {
    await _firestore.collection('finance_movements').doc(movementId).delete();
  }

  Future<void> _call(String callable, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(callable).call(data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw FinanceActionNotFoundException();
      }
      throw FinanceActionException(_mapFunctionError(e, callable));
    } catch (_) {
      throw FinanceActionException('Falha ao executar $callable.');
    }
  }

  String _mapFunctionError(FirebaseFunctionsException e, String callable) {
    final message = e.message?.trim();
    return switch (e.code) {
      'unauthenticated' => 'Sessao expirada. Entre novamente no app.',
      'permission-denied' => 'Seu perfil nao tem permissao para esta acao.',
      'invalid-argument' => message ?? 'Dados invalidos para $callable.',
      'failed-precondition' => message ?? 'Precondicoes da operacao nao atendidas.',
      'unavailable' => 'Servico temporariamente indisponivel. Tente novamente.',
      'deadline-exceeded' => 'Tempo de resposta excedido. Tente novamente.',
      _ => message ?? 'Falha ao executar $callable.',
    };
  }

  Future<_SessionData> _session() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw FinanceActionException('Sessao nao encontrada.');
    final doc = await _firestore.collection('users').doc(uid).get();
    final map = doc.data();
    if (map == null) throw FinanceActionException('Perfil nao encontrado.');
    final companyId = map['companyId']?.toString();
    if (companyId == null || companyId.isEmpty) {
      throw FinanceActionException('CompanyId nao encontrado.');
    }
    return _SessionData(userId: uid, companyId: companyId);
  }
}

class FinanceActionException implements Exception {
  FinanceActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FinanceBulkPaymentInput {
  const FinanceBulkPaymentInput({
    required this.employeeId,
    required this.grossCents,
    this.discountsCents = 0,
    this.dueDate,
    this.paymentType,
    this.markAsPaid = false,
  });

  final String employeeId;
  final int grossCents;
  final int discountsCents;
  final DateTime? dueDate;
  final String? paymentType;
  final bool markAsPaid;
}

class FinanceBulkPaymentIssue {
  const FinanceBulkPaymentIssue({
    required this.employeeId,
    required this.message,
  });

  factory FinanceBulkPaymentIssue.fromMap(Map<String, dynamic> map) {
    return FinanceBulkPaymentIssue(
      employeeId: map['employeeId']?.toString() ?? '',
      message: map['message']?.toString() ?? 'Falha ao lancar pagamento.',
    );
  }

  final String employeeId;
  final String message;
}

class FinanceBulkPaymentResult {
  const FinanceBulkPaymentResult({
    required this.createdCount,
    required this.skipped,
    required this.failed,
  });

  factory FinanceBulkPaymentResult.fromMap(Map<String, dynamic> map) {
    return FinanceBulkPaymentResult(
      createdCount: (map['createdCount'] as num?)?.toInt() ?? 0,
      skipped: ((map['skipped'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => FinanceBulkPaymentIssue.fromMap(item.cast<String, dynamic>()))
          .toList(),
      failed: ((map['failed'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => FinanceBulkPaymentIssue.fromMap(item.cast<String, dynamic>()))
          .toList(),
    );
  }

  final int createdCount;
  final List<FinanceBulkPaymentIssue> skipped;
  final List<FinanceBulkPaymentIssue> failed;

  int get skippedCount => skipped.length;
  int get failedCount => failed.length;
}

class FinanceActionNotFoundException implements Exception {}

class _SessionData {
  const _SessionData({
    required this.userId,
    required this.companyId,
  });

  final String userId;
  final String companyId;
}
