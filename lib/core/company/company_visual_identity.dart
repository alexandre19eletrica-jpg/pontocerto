String buildCompanyDisplayCode({
  required String cnpj,
  required String companyName,
}) {
  final digits = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
  final firstDigits = digits.padRight(5, '0').substring(0, 5);
  final firstWord = _firstCompanyWord(companyName);
  return 'comp_${firstDigits}_$firstWord';
}

String _firstCompanyWord(String value) {
  final sanitized = value
      .trim()
      .split(RegExp(r'\s+'))
      .firstWhere((item) => item.trim().isNotEmpty, orElse: () => 'empresa')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  return sanitized.isEmpty ? 'empresa' : sanitized;
}
