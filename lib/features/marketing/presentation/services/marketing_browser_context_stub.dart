class MarketingBrowserContext {
  const MarketingBrowserContext({
    required this.referrer,
    required this.userAgent,
    required this.language,
    required this.screenWidth,
    required this.screenHeight,
  });

  final String referrer;
  final String userAgent;
  final String language;
  final double screenWidth;
  final double screenHeight;
}

MarketingBrowserContext readMarketingBrowserContext() {
  return const MarketingBrowserContext(
    referrer: '',
    userAgent: '',
    language: '',
    screenWidth: 0,
    screenHeight: 0,
  );
}
