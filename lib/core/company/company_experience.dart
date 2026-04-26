enum CompanyExperienceType { mei, empresa }

enum CompanyExperiencePlan { solo, equipe }

class CompanyExperience {
  const CompanyExperience({
    required this.type,
    required this.plan,
  });

  final CompanyExperienceType type;
  final CompanyExperiencePlan plan;

  bool get isMei => type == CompanyExperienceType.mei;
  bool get isEmpresa => type == CompanyExperienceType.empresa;

  factory CompanyExperience.fromSettings(Map<String, dynamic> settings) {
    final raw = settings['companyExperience'];
    final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    final rawType = map['type']?.toString().trim().toUpperCase();
    final rawPlan = map['plan']?.toString().trim().toUpperCase();

    final fallbackProfile =
        settings['companyOperationalProfile']?.toString().trim().toLowerCase() ??
        'small_business';

    final type = switch (rawType) {
      'MEI' => CompanyExperienceType.mei,
      'EMPRESA' => CompanyExperienceType.empresa,
      _ => fallbackProfile == 'mei'
          ? CompanyExperienceType.mei
          : CompanyExperienceType.empresa,
    };

    final plan = switch (rawPlan) {
      'SOLO' => CompanyExperiencePlan.solo,
      'EQUIPE' => CompanyExperiencePlan.equipe,
      _ => type == CompanyExperienceType.mei
          ? CompanyExperiencePlan.solo
          : CompanyExperiencePlan.equipe,
    };

    return CompanyExperience(type: type, plan: plan);
  }
}
