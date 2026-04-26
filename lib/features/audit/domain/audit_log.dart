class AuditLog {
  const AuditLog({
    required this.id,
    required this.companyId,
    required this.actorUserId,
    required this.actorRole,
    required this.module,
    required this.action,
    required this.entityPath,
    required this.entityId,
    required this.createdAt,
    this.before,
    this.after,
  });

  final String id;
  final String companyId;
  final String actorUserId;
  final String actorRole;
  final String module;
  final String action;
  final String entityPath;
  final String entityId;
  final DateTime createdAt;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
}
