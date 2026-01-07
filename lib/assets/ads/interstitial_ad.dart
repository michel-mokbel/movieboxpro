// ignore_for_file: avoid_print

import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdManager {
  InterstitialAd? _interstitialAd;
  bool isLoaded = false;

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-6638245178785483/6901386708', // Replace with your own AdUnitId
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          isLoaded = true;
        },
        onAdFailedToLoad: (error) {
          print('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null; // Reset the ad after showing
    } else {
      print('Interstitial Ad is not ready yet.');
    }
  }

  bool isAdLoaded() {
    return isLoaded;
  }

  InterstitialAd? get interstitialAd => _interstitialAd;

  void disposeAd() {
    _interstitialAd?.dispose();
  }
}
