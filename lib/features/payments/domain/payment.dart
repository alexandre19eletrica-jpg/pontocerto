enum PaymentStatus { pendente, pago, confirmado, contestado, cancelado }

class Payment {
  const Payment({
    required this.id,
    required this.employeeId,
    required this.competencia,
    required this.valorCents,
    required this.dataRegistro,
    required this.status,
    this.motivoContestacao,
  });

  final String id;
  final String employeeId;
  final String competencia;
  final int valorCents;
  final DateTime dataRegistro;
  final PaymentStatus status;
  final String? motivoContestacao;

  Payment copyWith({
    String? id,
    String? employeeId,
    String? competencia,
    int? valorCents,
    DateTime? dataRegistro,
    PaymentStatus? status,
    String? motivoContestacao,
  }) {
    return Payment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      competencia: competencia ?? this.competencia,
      valorCents: valorCents ?? this.valorCents,
      dataRegistro: dataRegistro ?? this.dataRegistro,
      status: status ?? this.status,
      motivoContestacao: motivoContestacao ?? this.motivoContestacao,
    );
  }
}
