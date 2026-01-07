import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  
  // Singleton pattern
  factory AdsService() => _instance;
  
  AdsService._internal() {}
  
  // Game ID from your Unity dashboard
  static const String gameId = "6005312";
  
  // Placement IDs
  static const String bannerPlacementId = "Banner_iOS";
  static const String interstitialPlacementId = "Interstitial_iOS";
  static const String rewardedPlacementId = "Rewarded_iOS";
  
  // Track initialization status
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Track if ads are enabled (user can disable via settings)
  bool _adsEnabled = true;
  bool get adsEnabled => _adsEnabled;
  
  // Background retry mechanism
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 10; // Try up to 10 times
  static const int _retryDelaySeconds = 30; // Wait 30 seconds between retries
  
  // Interstitial cooldown to prevent showing too many ads
  DateTime? _lastInterstitialTime;
  static const int interstitialCooldownSeconds = 180; // Increased from 60 to 180 seconds
  
  // Session-based ad limits
  int _interstitialAdsShownThisSession = 0;
  int _rewardedAdsShownThisSession = 0;
  static const int maxInterstitialAdsPerSession = 5; // Limit total interstitials per session
  static const int maxRewardedAdsPerSession = 8; // Higher limit for rewarded ads
  
  // Event bus for rewarded ad completion
  final StreamController<bool> _rewardStreamController = StreamController<bool>.broadcast();
  Stream<bool> get onRewardComplete => _rewardStreamController.stream;
  
  // Initialize the Unity Ads SDK
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Load ad settings from preferences
      final prefs = await SharedPreferences.getInstance();
      _adsEnabled = prefs.getBool('ads_enabled') ?? true;
      
      // Create a completer to properly handle the async initialization
      final completer = Completer<bool>();
      
      // Add timeout to prevent app from getting stuck
      Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          _isInitialized = false;
          completer.complete(false);
        }
      });
      
      try {
      await UnityAds.init(
        gameId: gameId,
          testMode: true, // Enable test mode for simulator/development
        onComplete: () {
          _isInitialized = true;
            _retryCount = 0; // Reset retry count on success
            _retryTimer?.cancel();
            _retryTimer = null;
          _preloadAds();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onFailed: (error, message) {
          _isInitialized = false;
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
      } catch (e) {
        _isInitialized = false;
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
      
      // Wait for initialization to complete
      return completer.future;
    } catch (e) {
      return false;
    }
  }
  
  // Start background retry mechanism
  void _startBackgroundRetry() {
    if (_isInitialized || _retryTimer != null || _retryCount >= _maxRetries) {
      return;
    }
    
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retryDelaySeconds), () async {
      _retryCount++;
      final success = await initialize();
      if (!success && _retryCount < _maxRetries) {
        _startBackgroundRetry(); // Continue retrying
      } else if (_retryCount >= _maxRetries) {
        _retryTimer?.cancel();
        _retryTimer = null;
      }
    });
  }
  
  // Public method to start background retry
  void startBackgroundRetry() {
    if (!_isInitialized) {
      _startBackgroundRetry();
    }
  }
  
  // Preload all ad types
  void _preloadAds() {
    if (!_isInitialized || !_adsEnabled) {
      return;
    }
    
    _loadInterstitial();
    _loadRewarded();
    // Banners are loaded when shown
  }
  
  // Load interstitial ad
  void _loadInterstitial() {
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) {},
      onFailed: (placementId, error, message) {},
    );
  }
  
  // Load rewarded ad
  void _loadRewarded() {
    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {},
      onFailed: (placementId, error, message) {},
    );
  }
  
  // Show banner ad
  Widget showBannerAd({BannerSize size = BannerSize.standard}) {
    if (!_isInitialized) {
      return Container(
        height: 50,
        color: Colors.grey.withOpacity(0.1),
        child: const Center(
          child: Text('Ad not initialized', style: TextStyle(color: Colors.grey, fontSize: 10)),
        ),
      );
    }
    
    if (!_adsEnabled) {
      return const SizedBox(height: 50);
    }
    
    return UnityBannerAd(
      placementId: bannerPlacementId,
      onLoad: (placementId) {},
      onFailed: (placementId, error, message) {},
      size: size,
    );
  }
  
  // Show interstitial ad with cooldown check
  Future<bool> showInterstitialAd() async {
    if (!_isInitialized || !_adsEnabled) {
      return false;
    }
    
    // Check session-based limit
    if (_interstitialAdsShownThisSession >= maxInterstitialAdsPerSession) {
      return false;
    }
    
    // Check cooldown to prevent showing too many ads
    final now = DateTime.now();
    if (_lastInterstitialTime != null) {
      final difference = now.difference(_lastInterstitialTime!).inSeconds;
      if (difference < interstitialCooldownSeconds) {
        return false;
      }
    }
    
    final completer = Completer<bool>();
    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onComplete: (placementId) {
        _lastInterstitialTime = now;
        _interstitialAdsShownThisSession++;
        _loadInterstitial();
        completer.complete(true);
      },
      onFailed: (placementId, error, message) {
        _loadInterstitial();
        completer.complete(false);
      },
      onStart: (placementId) {},
      onClick: (placementId) {},
      onSkipped: (placementId) {
        _lastInterstitialTime = now;
        _interstitialAdsShownThisSession++;
        completer.complete(false);
      },
    );
    
    return completer.future;
  }
  
  // Show rewarded ad
  Future<bool> showRewardedAd() async {
    if (!_isInitialized || !_adsEnabled) {
      _rewardStreamController.add(false);
      return false;
    }
    
    // Check session-based limit
    if (_rewardedAdsShownThisSession >= maxRewardedAdsPerSession) {
      _rewardStreamController.add(true);
      return true;
    }
    
    final completer = Completer<bool>();
    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {
        _rewardStreamController.add(true);
        _rewardedAdsShownThisSession++;
        _loadRewarded();
        completer.complete(true);
      },
      onFailed: (placementId, error, message) {
        _rewardStreamController.add(true);
        _loadRewarded();
        completer.complete(true);
      },
      onStart: (placementId) {},
      onClick: (placementId) {},
      onSkipped: (placementId) {
        _rewardStreamController.add(false);
        _rewardedAdsShownThisSession++;
        completer.complete(false);
      },
    );
    
    return completer.future;
  }
  
  // Reset session counters (can be called when app starts or at specific times)
  void resetSessionCounters() {
    _interstitialAdsShownThisSession = 0;
    _rewardedAdsShownThisSession = 0;
  }
  
  // Toggle ads state
  Future<void> setAdsEnabled(bool enabled) async {
    _adsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_enabled', enabled);
    
    if (enabled && _isInitialized) {
      _preloadAds();
    }
  }
  
  // Clean up resources
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _rewardStreamController.close();
  }
} 