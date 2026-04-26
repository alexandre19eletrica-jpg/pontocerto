import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pontocerto/features/finance/domain/entities/payment.dart';

class FinancePaymentDto {
  const FinancePaymentDto._();

  static FinancePayment fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};

    final statusRaw = (map['status'] ?? 'PENDING').toString().toUpperCase();
    final year = (map['competenceYear'] as num?)?.toInt() ??
        _parseYearFromLegacyCompetencia(map['competencia']?.toString()) ??
        DateTime.now().year;
    final month = (map['competenceMonth'] as num?)?.toInt() ??
        _parseMonthFromLegacyCompetencia(map['competencia']?.toString()) ??
        DateTime.now().month;
    final grossCents = (map['grossCents'] as num?)?.toInt() ??
        (map['valorCents'] as num?)?.toInt() ??
        0;
    final discountsCents = (map['discountsCents'] as num?)?.toInt() ?? 0;
    final netCents = (map['netCents'] as num?)?.toInt() ?? (grossCents - discountsCents);

    return FinancePayment(
      id: doc.id,
      companyId: map['companyId']?.toString() ?? '',
      employeeId: map['employeeId']?.toString() ?? '',
      competenceYear: year,
      competenceMonth: month,
      grossCents: grossCents,
      discountsCents: discountsCents,
      netCents: netCents,
      paymentType: map['paymentType']?.toString(),
      status: switch (statusRaw) {
        'PAID' || 'PAGO' => FinancePaymentStatus.paid,
        'CONFIRMED' || 'CONFIRMADO' => FinancePaymentStatus.confirmed,
        'CONTESTED' || 'CONTESTADO' => FinancePaymentStatus.contested,
        'CANCELED' => FinancePaymentStatus.canceled,
        _ => FinancePaymentStatus.pending,
      },
      dueDate: _toDate(map['dueDate'] ?? map['vencimento']),
      paidAt: _toDate(map['paidAt']),
      confirmationAt: _toDate(map['confirmationAt']),
      contestedAt: _toDate(map['contestedAt']),
      contestReason: (map['contestReason'] ?? map['motivoContestacao'])?.toString(),
      createdAt: _toDate(map['createdAt']) ?? _toDate(map['dataRegistro']) ?? DateTime.now(),
      updatedAt: _toDate(map['updatedAt']) ?? _toDate(map['dataRegistro']) ?? DateTime.now(),
      createdByUserId: map['createdByUserId']?.toString(),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseYearFromLegacyCompetencia(String? competencia) {
    if (competencia == null) return null;
    final parts = competencia.split('-');
    if (parts.length != 2) return null;
    return int.tryParse(parts[0]);
  }

  static int? _parseMonthFromLegacyCompetencia(String? competencia) {
    if (competencia == null) return null;
    final parts = competencia.split('-');
    if (parts.length != 2) return null;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return null;
    return month;
  }
}
