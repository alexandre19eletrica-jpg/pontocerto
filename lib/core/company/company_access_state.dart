import 'package:pontocerto/core/platform/platform_access.dart';

class CompanyAccessState {
  const CompanyAccessState({
    required this.allowLogin,
    required this.lifecycleStatus,
    required this.approvalStatus,
    required this.plan,
    required this.message,
  });

  final bool allowLogin;
  final String lifecycleStatus;
  final String approvalStatus;
  final String plan;
  final String message;

  factory CompanyAccessState.fromSettings(
    Map<String, dynamic> settings, {
    String companyId = '',
  }) {
    // Unica empresa suprema: nunca bloquear por cobranca, ativacao ou flags comerciais.
    if (isSupremePlatformCompanyId(companyId)) {
      return const CompanyAccessState(
        allowLogin: true,
        lifecycleStatus: 'released',
        approvalStatus: 'approved',
        plan: 'supreme',
        message: '',
      );
    }
    final raw = settings['commercialSettings'];
    final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    final lifecycleStatus = map['lifecycleStatus']?.toString() ?? 'trial';
    final approvalStatus = map['approvalStatus']?.toString() ?? 'auto_approved';
    final requiresApproval = map['requiresApproval'] == true;
    final allowLoginFlag = map['allowLogin'] as bool? ?? true;
    final billingRaw = map['billingIntegration'];
    final billing = billingRaw is Map
        ? billingRaw.cast<String, dynamic>()
        : <String, dynamic>{};
    final billingManaged =
        billing['accessManagedByGateway'] == true &&
        (billing['provider']?.toString().trim().isNotEmpty ?? false) &&
        billing['provider']?.toString().trim().toLowerCase() != 'manual';
    final billingStatus = billing['status']?.toString().trim().toLowerCase() ??
        'pending_setup';
    final graceUntil = DateTime.tryParse(
      billing['graceUntil']?.toString() ?? '',
    );
    final billingAllowsAccess =
        !billingManaged ||
        billingStatus == 'active' ||
        billingStatus == 'paid' ||
        billingStatus == 'received' ||
        billingStatus == 'confirmed' ||
        billingStatus == 'trialing' ||
        (graceUntil != null && !graceUntil.isBefore(DateTime.now()));
    final allowLogin =
        allowLoginFlag &&
        lifecycleStatus != 'suspended' &&
        lifecycleStatus != 'inactive' &&
        lifecycleStatus != 'blocked' &&
        !(requiresApproval && approvalStatus != 'approved') &&
        billingAllowsAccess;

    String message = '';
    if (!allowLoginFlag) {
      message = 'A empresa esta temporariamente desativada para acesso.';
    } else if (billingStatus == 'trial_expired') {
      message =
          'Teste encerrado. Gere o boleto pre-pago para continuar e o acesso volta apos a confirmacao do pagamento.';
    } else if (lifecycleStatus == 'suspended') {
      message = 'A empresa esta suspensa temporariamente.';
    } else if (lifecycleStatus == 'inactive' || lifecycleStatus == 'blocked') {
      message = 'A empresa esta inativa no momento.';
    } else if (requiresApproval && approvalStatus != 'approved') {
      message = 'A empresa ainda aguarda aprovacao da plataforma.';
    } else if (!billingAllowsAccess) {
      message = billing['blockReason']?.toString().trim().isNotEmpty == true
          ? billing['blockReason'].toString().trim()
          : 'Pagamento pre-pago pendente. O acesso sera liberado apos a confirmacao do boleto.';
    } else if (billingManaged && graceUntil != null && !graceUntil.isBefore(DateTime.now())) {
      message = 'Pagamento em regularizacao dentro do prazo de carencia.';
    }

    return CompanyAccessState(
      allowLogin: allowLogin,
      lifecycleStatus: lifecycleStatus,
      approvalStatus: approvalStatus,
      plan: map['plan']?.toString() ?? 'solo',
      message: message,
    );
  }
}
