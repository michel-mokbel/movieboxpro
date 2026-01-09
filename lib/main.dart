import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:moviemagicbox/screens/welcome_screen.dart';
import 'package:moviemagicbox/services/movie_service.dart';
import 'package:moviemagicbox/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:app_set_id/app_set_id.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:moviemagicbox/services/ads_service.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';

// ============================================================================
// GLOBAL STATE
// ============================================================================

/// AppsFlyer SDK initialization state flags
bool _afInitDone = false;
bool _afStartDone = false;

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

Future<void> main() async {
  try {
    await _initializeApp();
  } catch (e) {
    print('Fatal error during initialization: $e');
    _launchSplashScreen();
  }
}

// ============================================================================
// APP INITIALIZATION
// ============================================================================

/// Main app initialization flow
Future<void> _initializeApp() async {
  print('DEBUG: main() function started');
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: Flutter binding initialized');

  // Initialize core services
  await _initializeFirebase();
  _initializeAdsService();
  final remoteConfig = await _initializeRemoteConfig();

  // Get configuration values
  final url = remoteConfig.getValue('url');
  final showAtt = remoteConfig.getBool('show_att');
  final openRouterApiKey = remoteConfig.getString('openrouter_api_key');
  ApiService.setOpenRouterApiKey(openRouterApiKey);
  _logRemoteConfigValues(url, showAtt, remoteConfig);

  // Request ATT (always, regardless of URL)
  final trackingAllowed = await _requestTrackingPermission(showAtt);

  // Route based on remote config URL
  if (url.asString().isNotEmpty) {
    await _handleWebViewFlow(url.asString(), trackingAllowed);
  } else {
    await _handleNormalAppFlow(trackingAllowed);
  }
}

/// Initialize Firebase Core
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    print('DEBUG: Firebase initialized successfully');
  } catch (e) {
    print('DEBUG: Failed to initialize Firebase: $e');
  }
}

/// Initialize Remote Config
Future<FirebaseRemoteConfig> _initializeRemoteConfig() async {
  print('DEBUG: About to initialize Remote Config');
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(minutes: 1),
  ));
  await remoteConfig.fetchAndActivate();
  print('DEBUG: Remote Config initialized and fetched');
  return remoteConfig;
}

/// Log remote config values for debugging
void _logRemoteConfigValues(
  RemoteConfigValue url,
  bool showAtt,
  FirebaseRemoteConfig remoteConfig,
) {
  print('Remote config URL: ${url.asString()}');
  print('Remote config show_att: $showAtt');
  print('Remote config source: ${url.source}');
  print('Remote config last fetch status: ${remoteConfig.lastFetchStatus}');
  print('Remote config last fetch time: ${remoteConfig.lastFetchTime}');
}

/// Initialize AdsService in background (non-blocking)
void _initializeAdsService() {
  print('Initializing ads service...');
  final adsService = AdsService();
  adsService.resetSessionCounters();

  Future(() async {
    bool adsInitialized = false;
    try {
      adsInitialized = await Future.any([
        adsService.initialize(),
        Future.delayed(const Duration(seconds: 20), () => false)
      ]);
    } catch (e) {
      adsInitialized = false;
    }

    if (adsInitialized) {
      print('Ads service initialized successfully');
    } else {
      print('Ads service initialization failed, will retry in background');
      adsService.startBackgroundRetry();
    }
  });
}

// ============================================================================
// TRACKING PERMISSION
// ============================================================================

/// Request App Tracking Transparency permission
Future<bool> _requestTrackingPermission(bool showAtt) async {
  if (Platform.isIOS && showAtt) {
    try {
      await Future.delayed(const Duration(seconds: 1));
      final status = await AppTrackingTransparency.requestTrackingAuthorization();
      print('Tracking authorization status: $status');
      return status == TrackingStatus.authorized;
    } catch (e) {
      print('Failed to request tracking authorization: $e');
      return false;
    }
  } else if (!Platform.isIOS) {
    // Android - tracking allowed
    return true;
  } else {
    // iOS but not showing ATT - limited mode
    return false;
  }
}

// ============================================================================
// APP FLOW ROUTING
// ============================================================================

/// Handle WebView flow when URL exists in remote config
Future<void> _handleWebViewFlow(String url, bool trackingAllowed) async {
  print('URL found in remote config, showing webview after ATT');

  // Get device information and build final URL
  final deviceInfo = await getDeviceInfo();
  final finalUrl = _buildUrlWithParameters(url, deviceInfo);
  print('Final URL with parameters: $finalUrl');

  // Launch WebView
  _launchWebView(finalUrl);

  // Initialize AppsFlyer in background (non-blocking)
  initializeAppsFlyerSdk(trackingAllowed, inBackground: true);
}

/// Handle normal app flow when no URL in remote config
Future<void> _handleNormalAppFlow(bool trackingAllowed) async {
  print('No URL from remote config, initializing AppsFlyer normally');

  // Initialize AppsFlyer (blocking - wait for completion)
  await initializeAppsFlyerSdk(trackingAllowed, inBackground: false);

  // Preload cache
  await _preloadCache();

  // Launch splash screen
  _launchSplashScreen();
}

/// Build final URL by replacing placeholders with device info
String _buildUrlWithParameters(String url, Map<String, String> deviceInfo) {
  return url
      .replaceAll('{bundle_id}', deviceInfo['bundle_id']!)
      .replaceAll('{uuid}', deviceInfo['uuid']!)
      .replaceAll('{idfa}', deviceInfo['idfa']!)
      .replaceAll('{idfv}', deviceInfo['idfv']!)
      .replaceAll('{appsflyer_id}', deviceInfo['appsflyer_id'] ?? '');
}

/// Launch WebView screen
void _launchWebView(String url) {
  runApp(MaterialApp(
    home: WebViewScreen(url: url),
    debugShowCheckedModeBanner: false,
  ));
}

/// Launch splash screen
void _launchSplashScreen() {
  runApp(const MaterialApp(
    home: SplashWithAdScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// ============================================================================
// CACHE MANAGEMENT
// ============================================================================

/// Preload movie and TV show cache
Future<void> _preloadCache() async {
  try {
    await preloadCache();
  } catch (e) {
    print('Failed to preload cache: $e');
  }
}

// ============================================================================
// DEVICE INFORMATION
// ============================================================================

/// Get or create persistent device UUID
Future<String> getOrCreateUUID() async {
  final prefs = await SharedPreferences.getInstance();
  String? uuid = prefs.getString('device_uuid');

  if (uuid == null) {
    uuid = const Uuid().v4();
    await prefs.setString('device_uuid', uuid);
  }

  return uuid;
}

/// Get basic device information (without AppsFlyer ID)
Future<Map<String, String>> getDeviceInfo() async {
  return await getDeviceInfoWithSdk(null);
}

/// Get device information with optional AppsFlyer SDK instance
Future<Map<String, String>> getDeviceInfoWithSdk(AppsflyerSdk? appsflyerSdk) async {
  final deviceInfo = <String, String>{};

  // Get or create persistent UUID
  final uuid = await getOrCreateUUID();
  deviceInfo['uuid'] = uuid;

  // Get IDFA (Advertising Identifier)
  deviceInfo['idfa'] = await _getIDFA();

  // Get IDFV (Vendor Identifier)
  deviceInfo['idfv'] = await _getIDFV();

  // Bundle ID
  deviceInfo['bundle_id'] = 'com.saleem.movie';

  // Get AppsFlyer ID using existing SDK instance if available
  final appsFlyerId = await getAppsFlyerId(appsflyerSdk);
  deviceInfo['appsflyer_id'] = appsFlyerId ?? '';

  print('Device info collected: $deviceInfo');
  return deviceInfo;
}

/// Get IDFA (iOS Advertising Identifier)
Future<String> _getIDFA() async {
  try {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.authorized) {
        final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
        return idfa;
      } else {
        print('Tracking not authorized, status: $status');
        return '';
      }
    } else {
      return '';
    }
  } catch (e) {
    print('Error getting IDFA: $e');
    return '';
  }
}

/// Get IDFV (Vendor Identifier)
Future<String> _getIDFV() async {
  try {
    final appSetId = AppSetId();
    final idfv = await appSetId.getIdentifier();
    return idfv ?? '';
  } catch (e) {
    print('Error getting IDFV: $e');
    return '';
  }
}

/// Get AppsFlyer ID from SDK instance
Future<String?> getAppsFlyerId(AppsflyerSdk? appsflyerSdk) async {
  if (appsflyerSdk == null) return null;
  try {
    final result = await appsflyerSdk.getAppsFlyerUID();
    return result;
  } catch (e) {
    print('AppsFlyer: getAppsFlyerUID failed: $e');
    return null;
  }
}

// ============================================================================
// REMOTE CONFIG HELPERS
// ============================================================================

/// Ensure Remote Config is initialized before use
Future<void> ensureRemoteConfigInitialized() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    // Check if already initialized by trying to get a value
    try {
      remoteConfig.getValue('dev_key');
    } catch (e) {
      // Not initialized, initialize it now
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(minutes: 1),
      ));
      await remoteConfig.fetchAndActivate();
      print('Remote Config initialized for dev key fetch');
    }
  } catch (e) {
    print('Failed to initialize Remote Config: $e');
  }
}

/// Fetch AppsFlyer dev key from Remote Config
Future<String> fetchDevKeyFromRemoteConfig() async {
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  try {
    // Set default value
    await remoteConfig.setDefaults(<String, dynamic>{
      'dev_key': 'TVuiYiPd4Bu5wzUuZwTymX',
    });

    // Always attempt to fetch and activate from Remote Config
    await remoteConfig.fetchAndActivate();

    // Get the dev key (will use remote value if available, otherwise default)
    String devKey = remoteConfig.getString('dev_key');
    devKey = devKey.trim();

    // Validate that we got a value
    if (devKey.isEmpty) {
      devKey = 'TVuiYiPd4Bu5wzUuZwTymX';
      print('Dev key was empty, using default');
    } else {
      print('Fetched dev_key from Remote Config: $devKey (length: ${devKey.length})');
    }

    return devKey;
  } catch (e) {
    print('Error fetching dev_key from Remote Config: $e');
    // Return default only as last resort
    return 'TVuiYiPd4Bu5wzUuZwTymX';
  }
}

// ============================================================================
// APPSFLYER SDK INTEGRATION
// ============================================================================

/// Initialize AppsFlyer SDK
Future<void> initializeAppsFlyerSdk(bool trackingAllowed, {bool inBackground = false}) async {
  try {
    // Ensure Remote Config is initialized before fetching dev key
    await ensureRemoteConfigInitialized();

    // Fetch dev key from Remote Config
    final devKey = await fetchDevKeyFromRemoteConfig().catchError((e) {
      print('Error fetching dev key from Remote Config: $e');
      return 'TVuiYiPd4Bu5wzUuZwTymX';
    });

    print('Using AppsFlyer dev key from Remote Config: ${devKey.substring(0, devKey.length > 10 ? 10 : devKey.length)}...');

    // Create AppsFlyer instance
    final appsflyerSdk = initAppsFlyerInstance(
      devKey,
      useAttWait: false, // Already got ATT, don't wait again
      attWaitSeconds: 60,
    );

    // Start AppsFlyer tracking
    if (inBackground) {
      _startAppsFlyerInBackground(appsflyerSdk, trackingAllowed);
    } else {
      await startAppsFlyerTracking(appsflyerSdk, trackingAllowed);
      print('AppsFlyer initialized successfully');
    }
  } catch (e) {
    print('Error initializing AppsFlyer SDK: $e');
  }
}

/// Start AppsFlyer in background (non-blocking)
void _startAppsFlyerInBackground(AppsflyerSdk appsflyerSdk, bool trackingAllowed) {
  Future(() async {
    try {
      await startAppsFlyerTracking(appsflyerSdk, trackingAllowed);
      print('AppsFlyer initialized in background');
    } catch (e) {
      print('Error initializing AppsFlyer in background: $e');
    }
  }).catchError((e) {
    print('AppsFlyer background init error: $e');
  });
}

/// Create AppsFlyer SDK instance
AppsflyerSdk initAppsFlyerInstance(
  String devKey, {
  required bool useAttWait,
  int attWaitSeconds = 60,
}) {
  devKey = devKey.trim();
  if (devKey.isEmpty) {
    devKey = 'TVuiYiPd4Bu5wzUuZwTymX';
  }

  const String appId = "6757599133";

  print('AppsFlyer: Creating SDK instance');

  final AppsFlyerOptions options = AppsFlyerOptions(
    afDevKey: devKey,
    appId: appId,
    showDebug: true,
    manualStart: true,
    timeToWaitForATTUserAuthorization: useAttWait ? attWaitSeconds.toDouble() : 0,
  );

  return AppsflyerSdk(options);
}

/// Start AppsFlyer tracking
Future<void> startAppsFlyerTracking(AppsflyerSdk appsflyerSdk, bool isTrackingAllowed) async {
  if (_afStartDone) {
    print('AppsFlyer: startAppsFlyerTracking skipped (already started)');
    return;
  }

  // Register callbacks
  _registerAppsFlyerCallbacks(appsflyerSdk);

  try {
    // Set CUID before starting
    await _setAppsFlyerCUID(appsflyerSdk);

    // Initialize SDK
    await _initAppsFlyerSdk(appsflyerSdk);

    // Start SDK
    _startAppsFlyerSdk(appsflyerSdk, isTrackingAllowed);
  } catch (e) {
    print('AppsFlyer: Exception during initialization: $e');
    _afStartDone = true;
  }
}

/// Register AppsFlyer callbacks
void _registerAppsFlyerCallbacks(AppsflyerSdk appsflyerSdk) {
  appsflyerSdk.onInstallConversionData((res) {
    try {
      print("AppsFlyer Install Conversion Data: $res");
    } catch (_) {}
  });

  appsflyerSdk.onAppOpenAttribution((res) {
    try {
      print("AppsFlyer App Open Attribution: $res");
    } catch (_) {}
  });
}

/// Set AppsFlyer Customer User ID
Future<void> _setAppsFlyerCUID(AppsflyerSdk appsflyerSdk) async {
  try {
    final cuid = await getOrCreateUUID();
    appsflyerSdk.setCustomerUserId(cuid);
    print('AppsFlyer: CUID set');
  } catch (e) {
    print('AppsFlyer: failed to set CUID: $e');
  }
}

/// Initialize AppsFlyer SDK
Future<void> _initAppsFlyerSdk(AppsflyerSdk appsflyerSdk) async {
  if (!_afInitDone) {
    print('AppsFlyer: initSdk()...');
    await appsflyerSdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    _afInitDone = true;
    print('AppsFlyer: initSdk() done');
  }
}

/// Start AppsFlyer SDK
void _startAppsFlyerSdk(AppsflyerSdk appsflyerSdk, bool isTrackingAllowed) {
  print('AppsFlyer: startSDK()...');
  appsflyerSdk.startSDK(
    onSuccess: () async {
      print('AppsFlyer: startSDK success');
      _afStartDone = true;

      if (isTrackingAllowed) {
        await _logUserSessionEvent(appsflyerSdk);
      }

      await _logInstallationEvent(appsflyerSdk, isTrackingAllowed);
    },
    onError: (int errorCode, String errorMessage) {
      print('AppsFlyer: startSDK error - Code: $errorCode, Message: $errorMessage');
      _afStartDone = true; // avoid repeated start attempts
    },
  );
}

/// Log user session started event
Future<void> _logUserSessionEvent(AppsflyerSdk appsflyerSdk) async {
  try {
    final userType = await _getUserType();
    await appsflyerSdk.logEvent("user_session_started", {
      "session_start_time": DateTime.now().toIso8601String(),
      "tracking_permission_granted": true,
      "user_type": userType,
    });
  } catch (_) {}
}

/// Log app installation completed event
Future<void> _logInstallationEvent(AppsflyerSdk appsflyerSdk, bool isTrackingAllowed) async {
  try {
    await appsflyerSdk.logEvent("app_installation_completed", {
      "installation_time": DateTime.now().toIso8601String(),
      "tracking_enabled": isTrackingAllowed,
    });
  } catch (_) {}
}

/// Get user type (new_user or returning_user)
Future<String> _getUserType() async {
  try {
    final prefInstance = await SharedPreferences.getInstance();
    final firstOpen = prefInstance.getBool('first_open') ?? true;
    if (firstOpen) {
      await prefInstance.setBool('first_open', false);
      return "new_user";
    } else {
      return "returning_user";
    }
  } catch (e) {
    return "unknown";
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

/// WebView screen for displaying remote config URL
class WebViewScreen extends StatefulWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final AdsService _adsService = AdsService();
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    final controller = _createWebViewController();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(child: WebViewWidget(controller: controller)),
          _buildCloseButton(),
        ],
      ),
    );
  }

  /// Create and configure WebView controller
  WebViewController _createWebViewController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) async {
            print('WebView error: ${error.description}');
            await _showAdAndNavigate();
          },
          onNavigationRequest: (NavigationRequest request) async {
            print('Navigation request to: ${request.url}');

            if (request.url.startsWith('error://')) {
              print('Error scheme detected, showing ad');
              await _showAdAndNavigate();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Build close button widget
  Widget _buildCloseButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: SafeArea(
        child: CupertinoButton(
          padding: const EdgeInsets.all(8),
          minSize: 0,
          color: BentoTheme.surfaceAlt.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          child: const Icon(
            CupertinoIcons.xmark,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            _showAdAndNavigate();
          },
        ),
      ),
    );
  }

  /// Show rewarded ad and navigate to welcome screen
  Future<void> _showAdAndNavigate() async {
    if (_isExiting) return;
    _isExiting = true;

    _showLoadingDialog();

    if (_adsService.isInitialized && _adsService.adsEnabled) {
      await _showRewardedAd();
    } else {
      print('Ads not available, skipping ad display');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _dismissLoadingDialog();
    _navigateToWelcome();
  }

  /// Show loading dialog
  void _showLoadingDialog() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(color: BentoTheme.accent),
          );
        },
      );
    }
  }

  /// Dismiss loading dialog
  void _dismissLoadingDialog() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Show rewarded ad with timeout
  Future<void> _showRewardedAd() async {
    print('Showing rewarded ad before navigating from WebView');
    try {
      await Future.any([
        _adsService.showRewardedAd(),
        Future.delayed(const Duration(seconds: 5), () {
          print('WebView: Ad display timed out');
          return false;
        })
      ]);
    } catch (e) {
      print('WebView: Error showing ad: $e');
    }
  }

  /// Navigate to welcome screen
  void _navigateToWelcome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }
}

/// Splash screen with ad display
class SplashWithAdScreen extends StatefulWidget {
  const SplashWithAdScreen({super.key});

  @override
  State<SplashWithAdScreen> createState() => _SplashWithAdScreenState();
}

class _SplashWithAdScreenState extends State<SplashWithAdScreen> {
  final AdsService _adsService = AdsService();

  @override
  void initState() {
    super.initState();
    _showAdAndNavigate();
  }

  Future<void> _showAdAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (_adsService.isInitialized && _adsService.adsEnabled) {
      try {
        await Future.any([
          _adsService.showRewardedAd(),
          Future.delayed(const Duration(seconds: 5), () => false)
        ]);
      } catch (e) {
        // Silently handle ad errors
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/images/First.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: BentoTheme.accent),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main app widget (currently unused but kept for potential future use)
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    final _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    // Initialize AdsService without blocking app startup
    AdsService().initialize().then((success) {
      if (!success) {
        AdsService().startBackgroundRetry();
      }
    });
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Box Pro +',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BentoTheme.background,
        primaryColor: BentoTheme.accent,
        colorScheme: const ColorScheme.dark(
          primary: BentoTheme.accent,
          secondary: BentoTheme.accentSoft,
          surface: BentoTheme.surface,
          background: BentoTheme.background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      locale: _locale ?? ui.window.locale,
      supportedLocales: const [Locale('en', '')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('en', '');
      },
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
    );
  }
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/// Preload movie and TV show cache
Future<void> preloadCache() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey("preloaded")) {
    await MovieService.fetchAllByType("movie");
    await MovieService.fetchAllByType("tv_show");
    prefs.setBool("preloaded", true);
  }
}
