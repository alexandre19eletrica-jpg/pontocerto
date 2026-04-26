import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/finance/data/dtos/debt_dto.dart';
import 'package:pontocerto/features/finance/data/dtos/payment_dto.dart';
import 'package:pontocerto/features/finance/domain/entities/debt.dart';
import 'package:pontocerto/features/finance/domain/entities/movement.dart';
import 'package:pontocerto/features/finance/domain/entities/payment.dart';
import 'package:pontocerto/features/finance/presentation/providers/finance_filters_provider.dart';

final financeSelectedEmployeeProvider = StateProvider<String?>((ref) => null);

final financePaymentsStreamProvider = StreamProvider<List<FinancePayment>>((ref) {
  final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
  final sessao = ref.watch(sessionProvider);
  final competencia = ref.watch(financeFiltersProvider);
  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao?.userId;

  if (!firebaseDisponivel || sessao == null) {
    return Stream.value(const <FinancePayment>[]);
  }

  Query<Map<String, dynamic>> query;
  if (sessao.role == Role.employee) {
    query = FirebaseFirestore.instance
        .collection('payments')
        .where('employeeId', isEqualTo: currentUid)
        .where('competenceYear', isEqualTo: competencia.year)
        .where('competenceMonth', isEqualTo: competencia.month);
  } else {
    query = FirebaseFirestore.instance
        .collection('payments')
        .where('companyId', isEqualTo: sessao.companyId)
        .where('competenceYear', isEqualTo: competencia.year)
        .where('competenceMonth', isEqualTo: competencia.month);
  }

  return query.snapshots().map(
        (snapshot) {
          final list = [
          for (final doc in snapshot.docs) FinancePaymentDto.fromDoc(doc),
          ];
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        },
      );
});

final financeDebtsStreamProvider = StreamProvider<List<FinanceDebt>>((ref) {
  final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
  final sessao = ref.watch(sessionProvider);
  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao?.userId;

  if (!firebaseDisponivel || sessao == null) {
    return Stream.value(const <FinanceDebt>[]);
  }

  Query<Map<String, dynamic>> query;
  if (sessao.role == Role.employee) {
    query = FirebaseFirestore.instance
        .collection('debts')
        .where('employeeId', isEqualTo: currentUid);
  } else {
    query = FirebaseFirestore.instance
        .collection('debts')
        .where('companyId', isEqualTo: sessao.companyId);
  }

  return query.snapshots().map(
        (snapshot) {
          final list = [for (final doc in snapshot.docs) FinanceDebtDto.fromDoc(doc)];
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        },
      );
});

final financeVisiblePaymentsProvider = Provider<List<FinancePayment>>((ref) {
  final sessao = ref.watch(sessionProvider);
  final selecionado = ref.watch(financeSelectedEmployeeProvider);
  final all = ref.watch(financePaymentsStreamProvider).valueOrNull ?? const <FinancePayment>[];

  if (sessao == null || sessao.role == Role.employee || selecionado == null) {
    return all;
  }

  return all.where((item) => item.employeeId == selecionado).toList();
});

final financeVisibleDebtsProvider = Provider<List<FinanceDebt>>((ref) {
  final sessao = ref.watch(sessionProvider);
  final selecionado = ref.watch(financeSelectedEmployeeProvider);
  final all = ref.watch(financeDebtsStreamProvider).valueOrNull ?? const <FinanceDebt>[];

  if (sessao == null || sessao.role == Role.employee || selecionado == null) {
    return all;
  }

  return all.where((item) => item.employeeId == selecionado).toList();
});

final financePersonalMovementsProvider = StreamProvider<List<FinanceMovement>>((ref) {
  final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
  final sessao = ref.watch(sessionProvider);
  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao?.userId;

  if (!firebaseDisponivel || sessao == null) {
    return Stream.value(const <FinanceMovement>[]);
  }

  final query = FirebaseFirestore.instance
      .collection('finance_movements')
      .where('companyId', isEqualTo: sessao.companyId)
      .where('ownerUserId', isEqualTo: currentUid);

  return query.snapshots().map(
        (snapshot) {
          final list = [
            for (final doc in snapshot.docs) _movementFromDoc(doc),
          ];
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        },
      );
});

final financeCompanyMovementsProvider = StreamProvider<List<FinanceMovement>>((ref) {
  final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
  final sessao = ref.watch(sessionProvider);

  if (!firebaseDisponivel || sessao == null) {
    return Stream.value(const <FinanceMovement>[]);
  }

  if (sessao.role == Role.employee) {
    return Stream.value(const <FinanceMovement>[]);
  }

  final query = FirebaseFirestore.instance
      .collection('finance_movements')
      .where('companyId', isEqualTo: sessao.companyId)
      .where('ownerUserId', isEqualTo: '__COMPANY__');

  return query.snapshots().map(
        (snapshot) {
          final list = [
            for (final doc in snapshot.docs) _movementFromDoc(doc),
          ];
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        },
      );
});

FinanceMovement _movementFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final map = doc.data() ?? <String, dynamic>{};
  final typeRaw = (map['type'] ?? 'EXPENSE').toString().toUpperCase();
  final dateRaw = map['date'];
  final dueDateRaw = map['dueDate'];
  final createdRaw = map['createdAt'];
  final updatedRaw = map['updatedAt'];
  final paymentStatusRaw = (map['paymentStatus'] ?? 'PENDING').toString().toUpperCase();

  DateTime toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  return FinanceMovement(
    id: doc.id,
    companyId: map['companyId']?.toString() ?? '',
    ownerUserId: map['ownerUserId']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    category: map['category']?.toString() ?? '',
    type: typeRaw == 'INCOME' ? FinanceMovementType.income : FinanceMovementType.expense,
    amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
    date: toDate(dateRaw),
    dueDate: dueDateRaw == null ? null : toDate(dueDateRaw),
    paymentStatus: paymentStatusRaw == 'PAID'
        ? FinanceMovementPaymentStatus.paid
        : FinanceMovementPaymentStatus.pending,
    notes: map['notes']?.toString(),
    sourceModule: map['sourceModule']?.toString(),
    sourceInvoiceId: map['sourceInvoiceId']?.toString(),
    sourceTaskId: map['sourceTaskId']?.toString(),
    sourceCustomerId: map['sourceCustomerId']?.toString(),
    sourceCustomerName: map['sourceCustomerName']?.toString(),
    createdAt: toDate(createdRaw),
    updatedAt: toDate(updatedRaw),
  );
}
