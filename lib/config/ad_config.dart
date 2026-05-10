class AdConfig {
  static const String appId = 'ca-app-pub-4610957825938255~8289810329';

  // ID de test Google (toujours actif, affiche une vraie bannière de test)
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  // ID de production (ton vrai ID AdMob)
  static const String prodBannerAdUnitId = 'ca-app-pub-4610957825938255/4079102575';

  static const bool isProduction = false;

  // Retourne automatiquement le bon ID selon le mode
  static String get bannerAdUnitId =>
      isProduction ? prodBannerAdUnitId : testBannerAdUnitId;
}
