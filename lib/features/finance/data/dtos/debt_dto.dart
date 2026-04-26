import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pontocerto/features/finance/domain/entities/debt.dart';

class FinanceDebtDto {
  const FinanceDebtDto._();

  static FinanceDebt fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};

    final typeRaw = (map['type'] ?? map['tipo'] ?? 'DEBT').toString().toUpperCase();
    final statusRaw = (map['status'] ?? 'OPEN').toString().toUpperCase();

    return FinanceDebt(
      id: doc.id,
      companyId: map['companyId']?.toString() ?? '',
      employeeId: map['employeeId']?.toString() ?? '',
      title: (map['title'] ?? map['descricao'] ?? '').toString(),
      type: typeRaw == 'ADVANCE' || typeRaw == 'ADIANTAMENTO'
          ? FinanceDebtType.advance
          : FinanceDebtType.debt,
      amountCents: (map['amountCents'] as num?)?.toInt() ??
          (map['valorCents'] as num?)?.toInt() ??
          0,
      status: switch (statusRaw) {
        'SETTLED' || 'BAIXADO' => FinanceDebtStatus.settled,
        'CANCELED' => FinanceDebtStatus.canceled,
        _ => FinanceDebtStatus.open,
      },
      dueDate: _toDate(map['dueDate'] ?? map['vencimento']),
      createdAt: _toDate(map['createdAt']) ?? _toDate(map['data']) ?? DateTime.now(),
      updatedAt: _toDate(map['updatedAt']) ?? _toDate(map['data']) ?? DateTime.now(),
      settledAt: _toDate(map['settledAt']),
      createdByUserId: map['createdByUserId']?.toString(),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
