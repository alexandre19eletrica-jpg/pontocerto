import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentRequestStatus { requested, awaitingCompany, completed }

enum DocumentRequestTargetScope { company, employees }

extension DocumentRequestStatusX on DocumentRequestStatus {
  String get label {
    switch (this) {
      case DocumentRequestStatus.requested:
        return 'Solicitado';
      case DocumentRequestStatus.awaitingCompany:
        return 'Aguardando';
      case DocumentRequestStatus.completed:
        return 'Concluido';
    }
  }
}

class DocumentRequestAttachment {
  const DocumentRequestAttachment({
    required this.id,
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
    required this.contentType,
    required this.uploadedByUserId,
    required this.uploadedByName,
    required this.uploadedByRole,
    this.uploadedAt,
  });

  final String id;
  final String fileName;
  final String downloadUrl;
  final String storagePath;
  final String contentType;
  final String uploadedByUserId;
  final String uploadedByName;
  final String uploadedByRole;
  final DateTime? uploadedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'contentType': contentType,
      'uploadedByUserId': uploadedByUserId,
      'uploadedByName': uploadedByName,
      'uploadedByRole': uploadedByRole,
      'uploadedAt': uploadedAt == null ? null : Timestamp.fromDate(uploadedAt!),
    };
  }

  factory DocumentRequestAttachment.fromMap(Map<String, dynamic> map) {
    return DocumentRequestAttachment(
      id: map['id']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      downloadUrl: map['downloadUrl']?.toString() ?? '',
      storagePath: map['storagePath']?.toString() ?? '',
      contentType: map['contentType']?.toString() ?? 'application/octet-stream',
      uploadedByUserId: map['uploadedByUserId']?.toString() ?? '',
      uploadedByName: map['uploadedByName']?.toString() ?? '',
      uploadedByRole: map['uploadedByRole']?.toString() ?? '',
      uploadedAt: _readDate(map['uploadedAt']),
    );
  }
}

class CompanyDocumentRequest {
  const CompanyDocumentRequest({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.requestedDocuments,
    required this.status,
    required this.targetScope,
    required this.createdByUserId,
    required this.createdByName,
    this.requestedEmployeeIds = const <String>[],
    this.requestedEmployeeNames = const <String>[],
    this.currentResponsibleEmployeeIds = const <String>[],
    this.currentResponsibleEmployeeNames = const <String>[],
    this.forwardedByUserId = '',
    this.forwardedByName = '',
    this.forwardedAt,
    this.attachments = const <DocumentRequestAttachment>[],
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.completedByName = '',
  });

  final String id;
  final String companyId;
  final String title;
  final String description;
  final List<String> requestedDocuments;
  final DocumentRequestStatus status;
  final DocumentRequestTargetScope targetScope;
  final String createdByUserId;
  final String createdByName;
  final List<String> requestedEmployeeIds;
  final List<String> requestedEmployeeNames;
  final List<String> currentResponsibleEmployeeIds;
  final List<String> currentResponsibleEmployeeNames;
  final String forwardedByUserId;
  final String forwardedByName;
  final DateTime? forwardedAt;
  final List<DocumentRequestAttachment> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String completedByName;

  bool get isDirectedToCompany =>
      targetScope == DocumentRequestTargetScope.company;
  bool get hasEmployeeRouting => currentResponsibleEmployeeIds.isNotEmpty;

  CompanyDocumentRequest copyWith({
    String? title,
    String? description,
    List<String>? requestedDocuments,
    DocumentRequestStatus? status,
    DocumentRequestTargetScope? targetScope,
    List<String>? requestedEmployeeIds,
    List<String>? requestedEmployeeNames,
    List<String>? currentResponsibleEmployeeIds,
    List<String>? currentResponsibleEmployeeNames,
    String? forwardedByUserId,
    String? forwardedByName,
    DateTime? forwardedAt,
    List<DocumentRequestAttachment>? attachments,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? completedByName,
  }) {
    return CompanyDocumentRequest(
      id: id,
      companyId: companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      requestedDocuments: requestedDocuments ?? this.requestedDocuments,
      status: status ?? this.status,
      targetScope: targetScope ?? this.targetScope,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      requestedEmployeeIds: requestedEmployeeIds ?? this.requestedEmployeeIds,
      requestedEmployeeNames:
          requestedEmployeeNames ?? this.requestedEmployeeNames,
      currentResponsibleEmployeeIds:
          currentResponsibleEmployeeIds ?? this.currentResponsibleEmployeeIds,
      currentResponsibleEmployeeNames:
          currentResponsibleEmployeeNames ??
          this.currentResponsibleEmployeeNames,
      forwardedByUserId: forwardedByUserId ?? this.forwardedByUserId,
      forwardedByName: forwardedByName ?? this.forwardedByName,
      forwardedAt: forwardedAt ?? this.forwardedAt,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt,
      completedByName: completedByName ?? this.completedByName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'title': title,
      'description': description,
      'requestedDocuments': requestedDocuments,
      'status': status.name,
      'targetScope': targetScope.name,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'requestedEmployeeIds': requestedEmployeeIds,
      'requestedEmployeeNames': requestedEmployeeNames,
      'currentResponsibleEmployeeIds': currentResponsibleEmployeeIds,
      'currentResponsibleEmployeeNames': currentResponsibleEmployeeNames,
      'forwardedByUserId': forwardedByUserId,
      'forwardedByName': forwardedByName,
      'forwardedAt': forwardedAt == null
          ? null
          : Timestamp.fromDate(forwardedAt!),
      'attachments': attachments.map((item) => item.toMap()).toList(),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'completedByName': completedByName,
    };
  }

  factory CompanyDocumentRequest.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status']?.toString() ?? '';
    final status =
        DocumentRequestStatus.values.any((item) => item.name == rawStatus)
        ? DocumentRequestStatus.values.firstWhere(
            (item) => item.name == rawStatus,
          )
        : DocumentRequestStatus.requested;
    final rawTargetScope = map['targetScope']?.toString() ?? '';
    final targetScope =
        DocumentRequestTargetScope.values.any(
          (item) => item.name == rawTargetScope,
        )
        ? DocumentRequestTargetScope.values.firstWhere(
            (item) => item.name == rawTargetScope,
          )
        : DocumentRequestTargetScope.company;
    final rawAttachments = map['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .whereType<Map>()
              .map(
                (item) => DocumentRequestAttachment.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <DocumentRequestAttachment>[];
    final rawRequested = map['requestedDocuments'];
    final requestedDocuments = rawRequested is List
        ? rawRequested
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];
    List<String> readList(String key) {
      final raw = map[key];
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return CompanyDocumentRequest(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      requestedDocuments: requestedDocuments,
      status: status,
      targetScope: targetScope,
      createdByUserId: map['createdByUserId']?.toString() ?? '',
      createdByName: map['createdByName']?.toString() ?? '',
      requestedEmployeeIds: readList('requestedEmployeeIds'),
      requestedEmployeeNames: readList('requestedEmployeeNames'),
      currentResponsibleEmployeeIds: readList('currentResponsibleEmployeeIds'),
      currentResponsibleEmployeeNames: readList(
        'currentResponsibleEmployeeNames',
      ),
      forwardedByUserId: map['forwardedByUserId']?.toString() ?? '',
      forwardedByName: map['forwardedByName']?.toString() ?? '',
      forwardedAt: _readDate(map['forwardedAt']),
      attachments: attachments,
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
      completedAt: _readDate(map['completedAt']),
      completedByName: map['completedByName']?.toString() ?? '',
    );
  }
}

DateTime? _readDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
