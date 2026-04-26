enum DebtType { divida, adiantamento }

enum DebtStatus { aberto, baixado, cancelado }

class Debt {
  const Debt({
    required this.id,
    required this.employeeId,
    required this.createdByUserId,
    required this.tipo,
    required this.valorCents,
    required this.descricao,
    required this.data,
    required this.status,
    required this.editRequestPending,
    required this.allowEmployeeEdit,
    required this.allowEmployeeSettle,
  });

  final String id;
  final String employeeId;
  final String createdByUserId;
  final DebtType tipo;
  final int valorCents;
  final String descricao;
  final DateTime data;
  final DebtStatus status;
  final bool editRequestPending;
  final bool allowEmployeeEdit;
  final bool allowEmployeeSettle;

  Debt copyWith({
    String? id,
    String? employeeId,
    String? createdByUserId,
    DebtType? tipo,
    int? valorCents,
    String? descricao,
    DateTime? data,
    DebtStatus? status,
    bool? editRequestPending,
    bool? allowEmployeeEdit,
    bool? allowEmployeeSettle,
  }) {
    return Debt(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      tipo: tipo ?? this.tipo,
      valorCents: valorCents ?? this.valorCents,
      descricao: descricao ?? this.descricao,
      data: data ?? this.data,
      status: status ?? this.status,
      editRequestPending: editRequestPending ?? this.editRequestPending,
      allowEmployeeEdit: allowEmployeeEdit ?? this.allowEmployeeEdit,
      allowEmployeeSettle: allowEmployeeSettle ?? this.allowEmployeeSettle,
    );
  }
}
