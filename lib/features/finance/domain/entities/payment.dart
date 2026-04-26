enum FinancePaymentStatus { pending, paid, confirmed, contested, canceled }

class FinancePayment {
  const FinancePayment({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.competenceYear,
    required this.competenceMonth,
    required this.grossCents,
    required this.discountsCents,
    required this.netCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.paymentType,
    this.paidAt,
    this.confirmationAt,
    this.contestedAt,
    this.contestReason,
    this.createdByUserId,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final int competenceYear;
  final int competenceMonth;
  final int grossCents;
  final int discountsCents;
  final int netCents;
  final FinancePaymentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final String? paymentType;
  final DateTime? paidAt;
  final DateTime? confirmationAt;
  final DateTime? contestedAt;
  final String? contestReason;
  final String? createdByUserId;

  String get competenceLabel =>
      '$competenceYear-${competenceMonth.toString().padLeft(2, '0')}';
}
