class AdHelper {
  static String get bannerAdUnitId {
    // Use test ad unit ID for development
    return 'ca-app-pub-3940256099942544/6300978111'; // Test ID
    // Replace with your actual AdMob ad unit ID for production
    // return 'ca-app-pub-6638245178785483/4357399636';
  }

  static String get nativeAdUnitId {
    // return 'ca-app-pub-6638245178785483/1873146029';
    return 'ca-app-pub-3940256099942544/2247696110';
  }
  static String get interstitialAdUnitId {
    return 'ca-app-pub-6638245178785483/7985729437'; // Test ID
  }

  // static String get rewardedAdUnitId {
  //   return 'ca-app-pub-3940256099942544/5224354917'; // Test ID
  // }
}
