class DeviceConsent {
  const DeviceConsent({
    required this.employeeId,
    required this.companyId,
    required this.accepted,
    required this.acceptedStatement,
    this.acceptedAt,
    this.revokedAt,
    this.termsVersion = 'v1',
    this.appVersion,
    this.devicePlatform,
    this.timeZone,
    this.acceptedByUid,
  });

  final String employeeId;
  final String companyId;
  final bool accepted;
  final String acceptedStatement;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final String termsVersion;
  final String? appVersion;
  final String? devicePlatform;
  final String? timeZone;
  final String? acceptedByUid;
}
