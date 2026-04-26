enum ServiceOrderStatus { open, inProgress, completed }

class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.companyId,
    required this.title,
    this.description = '',
    this.clientId = '',
    this.clientName = '',
    this.taskId = '',
    this.projectId = '',
    this.assignedEmployeeId = '',
    this.assignedEmployeeName = '',
    this.scheduledDate,
    this.status = ServiceOrderStatus.open,
    this.fieldNotes = '',
    this.photoUrls = const <String>[],
  });

  final String id;
  final String companyId;
  final String title;
  final String description;
  final String clientId;
  final String clientName;
  final String taskId;
  final String projectId;
  final String assignedEmployeeId;
  final String assignedEmployeeName;
  final DateTime? scheduledDate;
  final ServiceOrderStatus status;
  final String fieldNotes;
  final List<String> photoUrls;

  ServiceOrder copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    String? clientId,
    String? clientName,
    String? taskId,
    String? projectId,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    ServiceOrderStatus? status,
    String? fieldNotes,
    List<String>? photoUrls,
  }) {
    return ServiceOrder(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      scheduledDate: clearScheduledDate
          ? null
          : scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      fieldNotes: fieldNotes ?? this.fieldNotes,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'title': title,
      'description': description,
      'clientId': clientId,
      'clientName': clientName,
      'taskId': taskId,
      'projectId': projectId,
      'assignedEmployeeId': assignedEmployeeId,
      'assignedEmployeeName': assignedEmployeeName,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'status': status.name,
      'fieldNotes': fieldNotes,
      'photoUrls': photoUrls,
    };
  }

  factory ServiceOrder.fromMap(Map<String, dynamic> map) {
    final statusName = map['status']?.toString() ?? 'open';
    final status = ServiceOrderStatus.values
            .where((item) => item.name == statusName)
            .isNotEmpty
        ? ServiceOrderStatus.values.firstWhere(
            (item) => item.name == statusName,
          )
        : ServiceOrderStatus.open;
    return ServiceOrder(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      taskId: map['taskId']?.toString() ?? '',
      projectId: map['projectId']?.toString() ?? '',
      assignedEmployeeId: map['assignedEmployeeId']?.toString() ?? '',
      assignedEmployeeName: map['assignedEmployeeName']?.toString() ?? '',
      scheduledDate: DateTime.tryParse(map['scheduledDate']?.toString() ?? ''),
      status: status,
      fieldNotes: map['fieldNotes']?.toString() ?? '',
      photoUrls: (map['photoUrls'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}
