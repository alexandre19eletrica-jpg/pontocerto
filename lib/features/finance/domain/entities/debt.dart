enum FinanceDebtType { debt, advance }

enum FinanceDebtStatus { open, settled, canceled }

class FinanceDebt {
  const FinanceDebt({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.title,
    required this.type,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.settledAt,
    this.createdByUserId,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String title;
  final FinanceDebtType type;
  final int amountCents;
  final FinanceDebtStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final DateTime? settledAt;
  final String? createdByUserId;
}
