enum FinanceMovementType { income, expense }
enum FinanceMovementPaymentStatus { pending, paid }

class FinanceMovement {
  const FinanceMovement({
    required this.id,
    required this.companyId,
    required this.ownerUserId,
    required this.title,
    required this.category,
    required this.type,
    required this.amountCents,
    required this.date,
    this.dueDate,
    required this.paymentStatus,
    this.notes,
    this.sourceModule,
    this.sourceInvoiceId,
    this.sourceTaskId,
    this.sourceCustomerId,
    this.sourceCustomerName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String ownerUserId;
  final String title;
  final String category;
  final FinanceMovementType type;
  final int amountCents;
  final DateTime date;
  final DateTime? dueDate;
  final FinanceMovementPaymentStatus paymentStatus;
  final String? notes;
  final String? sourceModule;
  final String? sourceInvoiceId;
  final String? sourceTaskId;
  final String? sourceCustomerId;
  final String? sourceCustomerName;
  final DateTime createdAt;
  final DateTime updatedAt;
}
