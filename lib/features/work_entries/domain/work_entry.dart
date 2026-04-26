enum WorkEntryStatus { pendente, aprovado }

class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.employeeId,
    required this.data,
    required this.horas,
    required this.status,
    this.projectId = '',
    this.projectName = '',
    this.clientId = '',
    this.clientName = '',
    this.taskId = '',
    this.serviceOrderId = '',
    this.notes = '',
  });

  final String id;
  final String employeeId;
  final DateTime data;
  final int horas;
  final WorkEntryStatus status;
  final String projectId;
  final String projectName;
  final String clientId;
  final String clientName;
  final String taskId;
  final String serviceOrderId;
  final String notes;

  WorkEntry copyWith({
    String? id,
    String? employeeId,
    DateTime? data,
    int? horas,
    WorkEntryStatus? status,
    String? projectId,
    String? projectName,
    String? clientId,
    String? clientName,
    String? taskId,
    String? serviceOrderId,
    String? notes,
  }) {
    return WorkEntry(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      data: data ?? this.data,
      horas: horas ?? this.horas,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      taskId: taskId ?? this.taskId,
      serviceOrderId: serviceOrderId ?? this.serviceOrderId,
      notes: notes ?? this.notes,
    );
  }
}
