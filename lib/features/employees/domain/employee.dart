enum EmployeeRole { manager, accountant, employee }

enum EmployeeCompensationType { daily, weekly, monthly, commission }

class Employee {
  const Employee({
    required this.id,
    required this.nomeCompleto,
    required this.documento,
    required this.pix,
    this.telefone,
    this.email,
    this.endereco,
    this.apelido,
    this.fotoUrl,
    this.cargo,
    this.admissionDate,
    required this.compensationType,
    this.salaryAmountCents,
    this.commissionPercent,
    required this.role,
    required this.ativo,
  });

  final String id;
  final String nomeCompleto;
  final String documento;
  final String pix;
  final String? telefone;
  final String? email;
  final String? endereco;
  final String? apelido;
  final String? fotoUrl;
  final String? cargo;
  final DateTime? admissionDate;
  final EmployeeCompensationType compensationType;
  final int? salaryAmountCents;
  final double? commissionPercent;
  final EmployeeRole role;
  final bool ativo;

  String get nome => nomeCompleto;
  bool get isAccountant => role == EmployeeRole.accountant;
  bool get isOperationalTeam => role != EmployeeRole.accountant;
  bool get isManager => role == EmployeeRole.manager;

  Employee copyWith({
    String? id,
    String? nomeCompleto,
    String? documento,
    String? pix,
    String? telefone,
    String? email,
    String? endereco,
    String? apelido,
    String? fotoUrl,
    String? cargo,
    DateTime? admissionDate,
    EmployeeCompensationType? compensationType,
    int? salaryAmountCents,
    double? commissionPercent,
    EmployeeRole? role,
    bool? ativo,
  }) {
    return Employee(
      id: id ?? this.id,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      documento: documento ?? this.documento,
      pix: pix ?? this.pix,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      endereco: endereco ?? this.endereco,
      apelido: apelido ?? this.apelido,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      cargo: cargo ?? this.cargo,
      admissionDate: admissionDate ?? this.admissionDate,
      compensationType: compensationType ?? this.compensationType,
      salaryAmountCents: salaryAmountCents ?? this.salaryAmountCents,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      role: role ?? this.role,
      ativo: ativo ?? this.ativo,
    );
  }
}
