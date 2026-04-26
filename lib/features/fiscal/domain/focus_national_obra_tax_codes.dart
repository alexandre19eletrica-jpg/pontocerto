/// O mesmo conjunto de [FOCUS_NATIONAL_OBRA_REQUIRED_TAX_CODES] no Cloud Functions
/// (NFSe Nacional — grupo obra exige CNO).
const Set<String> kFocusNationalObraRequiredTaxCodeDigits = {
  '070201',
  '070202',
  '070401',
  '070501',
  '070502',
  '070601',
  '070602',
  '070701',
  '070801',
  '071701',
  '071901',
  '141403',
  '141404',
};

/// Normaliza codigo LC 116 (4–6 digitos) para 6 digitos, alinhado ao backend.
String? focusNationalTaxCodeSixDigitsFromServiceField(String? raw) {
  final d = raw?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  if (d.isEmpty) return null;
  if (d.length >= 6) return d.substring(0, 6);
  if (d.length == 4) {
    return '00$d';
  }
  if (d.length == 5) {
    return '0$d';
  }
  return null;
}

bool focusNationalServiceCodeRequiresCno(String? serviceCode) {
  final six = focusNationalTaxCodeSixDigitsFromServiceField(serviceCode);
  return six != null && kFocusNationalObraRequiredTaxCodeDigits.contains(six);
}
