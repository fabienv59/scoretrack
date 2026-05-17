import 'package:flutter/foundation.dart';

class AdConfig {
  static const String appId = 'ca-app-pub-4610957825938255~8289810329';

  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String prodBannerAdUnitId = 'ca-app-pub-4610957825938255/4079102575';

  static bool get isProduction => kReleaseMode;

  static String get bannerAdUnitId =>
      isProduction ? prodBannerAdUnitId : testBannerAdUnitId;
}
