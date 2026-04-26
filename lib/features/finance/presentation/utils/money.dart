String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final reais = abs ~/ 100;
  final centavos = (abs % 100).toString().padLeft(2, '0');
  return 'R\$ $sign$reais,$centavos';
}

String competenceLabel(int year, int month) {
  return '$year-${month.toString().padLeft(2, '0')}';
}
