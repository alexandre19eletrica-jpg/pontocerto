enum JustificationStatus { pending, approved, rejected }

class JustificationItem {
  const JustificationItem({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.date,
    required this.reason,
    required this.comprovanteUrl,
    required this.status,
    this.comprovanteNomeArquivo,
    this.reviewedBy,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final DateTime date;
  final String reason;
  final String comprovanteUrl;
  final JustificationStatus status;
  final String? comprovanteNomeArquivo;
  final String? reviewedBy;

  JustificationItem copyWith({
    JustificationStatus? status,
    String? comprovanteUrl,
    String? comprovanteNomeArquivo,
    String? reviewedBy,
  }) {
    return JustificationItem(
      id: id,
      companyId: companyId,
      employeeId: employeeId,
      date: date,
      reason: reason,
      comprovanteUrl: comprovanteUrl ?? this.comprovanteUrl,
      status: status ?? this.status,
      comprovanteNomeArquivo: comprovanteNomeArquivo ?? this.comprovanteNomeArquivo,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}
