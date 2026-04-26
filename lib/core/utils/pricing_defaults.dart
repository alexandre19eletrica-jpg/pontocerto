int planDefaultPriceCents(String plan) {
  final normalized = plan.trim().toLowerCase();
  return normalized == 'equipe' || normalized == 'empresa' ? 19700 : 9700;
}

int licenseDefaultPriceCents([int? reported]) {
  if (reported != null && reported > 0) {
    return reported;
  }
  return 1990;
}
