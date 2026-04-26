class FiscalServiceItem {
  const FiscalServiceItem({
    required this.id,
    required this.companyId,
    required this.name,
    required this.serviceCode,
    required this.municipalServiceCode,
    required this.cnae,
    required this.cityOfIncidence,
    this.issRateText = '5,00',
    this.taxRegime = '',
    this.operationNature = '',
    /// Texto usado na descricao da nota ao selecionar este modelo.
    this.officialDescription = '',
    this.defaultAmountCents = 0,
    this.active = true,
    this.issRateSource = '',
    this.issRateReviewedAtIso = '',
    this.inssRetainedDefault = false,
    this.inssRatePercentText = '11,00',
    this.inssRuleSource = '',
  });

  final String id;
  final String companyId;
  final String name;
  final String serviceCode;
  final String municipalServiceCode;
  final String cnae;
  final String cityOfIncidence;
  final String issRateText;
  final String taxRegime;
  final String operationNature;
  final String officialDescription;
  final int defaultAmountCents;
  final bool active;
  final String issRateSource;
  final String issRateReviewedAtIso;
  final bool inssRetainedDefault;
  final String inssRatePercentText;
  final String inssRuleSource;

  factory FiscalServiceItem.fromMap(String id, Map<String, dynamic> map) {
    return FiscalServiceItem(
      id: id,
      companyId: map['companyId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      serviceCode: map['serviceCode']?.toString() ?? '',
      municipalServiceCode: map['municipalServiceCode']?.toString() ?? '',
      cnae: map['cnae']?.toString() ?? '',
      cityOfIncidence: map['cityOfIncidence']?.toString() ?? '',
      issRateText: map['issRateText']?.toString() ?? '',
      taxRegime: map['taxRegime']?.toString() ?? '',
      operationNature: map['operationNature']?.toString() ?? '',
      officialDescription: map['officialDescription']?.toString() ?? '',
      defaultAmountCents: (map['defaultAmountCents'] as num?)?.toInt() ?? 0,
      active: map['active'] != false,
      issRateSource: map['issRateSource']?.toString() ?? '',
      issRateReviewedAtIso: map['issRateReviewedAtIso']?.toString() ?? '',
      inssRetainedDefault: map['inssRetainedDefault'] == true,
      inssRatePercentText: map['inssRatePercentText']?.toString() ?? '11,00',
      inssRuleSource: map['inssRuleSource']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'serviceCode': serviceCode,
      'municipalServiceCode': municipalServiceCode,
      'cnae': cnae,
      'cityOfIncidence': cityOfIncidence,
      'issRateText': issRateText,
      'taxRegime': taxRegime,
      'operationNature': operationNature,
      'officialDescription': officialDescription,
      'defaultAmountCents': defaultAmountCents,
      'active': active,
      'issRateSource': issRateSource,
      'issRateReviewedAtIso': issRateReviewedAtIso,
      'inssRetainedDefault': inssRetainedDefault,
      'inssRatePercentText': inssRatePercentText,
      'inssRuleSource': inssRuleSource,
    };
  }
}
