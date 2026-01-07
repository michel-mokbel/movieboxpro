import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/screens/search_screen.dart';
import 'package:moviemagicbox/screens/settings_screen.dart';
import 'package:moviemagicbox/screens/favorites_screen.dart';
import 'package:moviemagicbox/screens/ai_hub_screen.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../services/api_service.dart';
import '../services/ads_service.dart';
import 'dashboard_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  bool _isChatOpen = false;
  late AnimationController _animationController;
  late final List<Widget> screens;
  final GlobalKey<AIHubScreenState> _aiHubKey = GlobalKey<AIHubScreenState>();
  
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ApiService _apiService = ApiService();
  final AdsService _adsService = AdsService();
  bool _isLoading = false;
  int _previousIndex = 0;
  DateTime? _lastFeatureModalShown;
  bool _isFeatureModalVisible = false;
  static const int _aiTabIndex = 2;

  @override
  void initState() {
    super.initState();
    screens = [
      DashboardScreen(
        onMoodRequested: _openMoodFromDashboard,
        onQuizRequested: _openQuizFromDashboard,
      ),
      const SearchScreen(),
      AIHubScreen(key: _aiHubKey),
      const FavoritesScreen(),
      const Settings(),
    ];
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Slightly slower for iOS feel
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentIndex == 0) {
        _maybeShowFeatureModal();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Show interstitial ad when changing tabs (with some logic to not show too frequently)
  Future<void> _maybeShowInterstitial(int newIndex) async {
    // Only show interstitial when navigating from dashboard to another tab,
    // and only one in every three times to reduce frequency
    if (_previousIndex == 0 && newIndex != 0 && DateTime.now().second % 3 == 0) {
      await _adsService.showInterstitialAd();
    }
    _previousIndex = currentIndex;
    setState(() {
      currentIndex = newIndex;
    });
    if (newIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _maybeShowFeatureModal();
        }
      });
    }
  }

  Future<void> _openMoodFromDashboard() async {
    await _maybeShowInterstitial(_aiTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _aiHubKey.currentState?.openMood();
      }
    });
  }

  Future<void> _openQuizFromDashboard(Map<String, dynamic>? movie) async {
    await _maybeShowInterstitial(_aiTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _aiHubKey.currentState?.openQuiz(movie: movie);
      }
    });
  }

  void _maybeShowFeatureModal() {
    if (_isFeatureModalVisible) return;
    final now = DateTime.now();
    if (_lastFeatureModalShown != null &&
        now.difference(_lastFeatureModalShown!) < const Duration(minutes: 5)) {
      return;
    }
    _lastFeatureModalShown = now;
    _isFeatureModalVisible = true;
    showGeneralDialog(
      context: context,
      barrierLabel: 'Feature Highlights',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildFeatureModal();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ).whenComplete(() {
      _isFeatureModalVisible = false;
    });
  }

  Widget _buildFeatureModal() {
    final size = MediaQuery.of(context).size;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: size.width * 0.86,
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: size.height * 0.7,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    IOSTheme.systemBlue.withOpacity(0.15),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: IOSTheme.body.copyWith(
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New AI Features',
                            style: IOSTheme.title2.copyWith(
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () => Navigator.pop(context),
                            child: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Discover what is new in Movie Magic Box.',
                        style: IOSTheme.body.copyWith(
                          color: Colors.white70,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildFeatureRow(
                        CupertinoIcons.sparkles,
                        'Mood Discovery',
                        'Match movies to your mood with one tap.',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureRow(
                        CupertinoIcons.question_circle_fill,
                        'Movie Quiz',
                        'Generate trivia quizzes for any movie.',
                      ),
                      const SizedBox(height: 20),
                      CupertinoButton(
                        color: IOSTheme.systemBlue,
                        borderRadius: BorderRadius.circular(24),
                        onPressed: () {
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _openMoodFromDashboard();
                            }
                          });
                        },
                        child: Text(
                          'Open Mood Discovery',
                          style: IOSTheme.headline.copyWith(
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CupertinoButton(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(24),
                        onPressed: () {
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _openQuizFromDashboard(null);
                            }
                          });
                        },
                        child: Text(
                          'Take a Movie Quiz',
                          style: IOSTheme.headline.copyWith(
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: IOSTheme.systemBlue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: IOSTheme.systemBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: IOSTheme.headline.copyWith(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: IOSTheme.subhead.copyWith(
                    color: Colors.white70,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleChat() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
        // Clear focus when closing chat
        FocusScope.of(context).unfocus();
      }
    });
  }

  Future<void> _sendMessage(String userMessage) async {
    if (userMessage.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _messages.add({'sender': 'user', 'text': userMessage});
      _messageController.clear();
      _isLoading = true;
    });

    try {
      final response = await _apiService.getChatbotResponse(userMessage);
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': _formatBotResponse(response),
        });
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Error: Unable to get response. Please try again.',
        });
      });
      HapticFeedback.heavyImpact();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBotResponse(String response) {
    response = response.replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*'), (match) => '<b>${match.group(1)}</b>');
    response = response.replaceAllMapped(
        RegExp(r'\*\s(.*)'), (match) => '<li>${match.group(1)}</li>');
    response = response.replaceAllMapped(
        RegExp(r'(<li>.*?</li>)'), (match) => '<ul>${match.group(0)}</ul>');
    response = response.replaceAll('\n', '<br>');
    return response;
  }

  Widget _buildChatOverlay() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut, // iOS-like spring effect
      )),
      child: Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 60, // Below header space
            bottom: 90, // Above tab bar
            left: 16,
            right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: IOSTheme.secondarySystemBackground.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Movie Assistant',
                          style: IOSTheme.headline,
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          child: const Icon(CupertinoIcons.xmark_circle_fill, color: IOSTheme.secondaryLabel),
                          onPressed: _toggleChat,
                        ),
                      ],
                    ),
                  ),
                  
                  // Messages
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.chat_bubble_2_fill, size: 48, color: IOSTheme.systemBlue),
                                  const SizedBox(height: 16),
                                  Text(
                                    'How can I help you today?',
                                    style: IOSTheme.title3.copyWith(color: IOSTheme.secondaryLabel),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isUser = message['sender'] == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                  decoration: BoxDecoration(
                                    color: isUser ? IOSTheme.systemBlue : IOSTheme.tertiarySystemBackground,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: isUser
                                      ? Text(message['text'] ?? '', style: const TextStyle(color: Colors.white))
                                      : Html(
                                          data: message['text'] ?? '',
                                          style: {
                                            "body": Style(color: Colors.white, margin: Margins.zero),
                                            "p": Style(margin: Margins.zero),
                                          },
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Input Area
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CupertinoActivityIndicator(),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _messageController,
                            placeholder: 'Ask something...',
                            placeholderStyle: const TextStyle(color: IOSTheme.tertiaryLabel),
                            style: const TextStyle(color: Colors.white),
                            decoration: BoxDecoration(
                              color: IOSTheme.tertiarySystemBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 44,
                          color: IOSTheme.systemBlue,
                          borderRadius: BorderRadius.circular(22),
                          onPressed: () => _sendMessage(_messageController.text),
                          child: const Icon(CupertinoIcons.arrow_up, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOSTheme.systemBackground,
      extendBody: true, // Allow content to flow behind navigation bar
      body: Stack(
        children: [
          // Main Content
          screens[currentIndex],
          
          // Chat Overlay
          if (_isChatOpen) _buildChatOverlay(),
          
          // Floating Chat Button
          Positioned(
            bottom: 100, // Above tab bar
            right: 16,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
                reverseCurve: Curves.easeIn,
              ).drive(Tween<double>(begin: 1.0, end: 0.0)), // Hide when chat is open
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: IOSTheme.systemBlue.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: IOSTheme.systemBlue.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleChat,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Icon(
                            CupertinoIcons.chat_bubble_2_fill,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0x1AFFFFFF), // Subtle white border at top
                  width: 0.5,
                ),
              ),
            ),
            child: CupertinoTabBar(
              backgroundColor: const Color(0xCC000000), // Translucent black
              activeColor: IOSTheme.systemBlue,
              inactiveColor: IOSTheme.secondaryLabel,
              currentIndex: currentIndex,
              onTap: (index) {
                HapticFeedback.selectionClick();
                if (index == currentIndex) {
                  if (index == _aiTabIndex) {
                    _aiHubKey.currentState?.popToRoot();
                  }
                  return;
                }
                _maybeShowInterstitial(index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.home),
                  activeIcon: Icon(CupertinoIcons.house_fill),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.search),
                  activeIcon: Icon(CupertinoIcons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.sparkles),
                  activeIcon: Icon(CupertinoIcons.sparkles),
                  label: 'AI',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.bookmark),
                  activeIcon: Icon(CupertinoIcons.bookmark_fill),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.settings),
                  activeIcon: Icon(CupertinoIcons.settings_solid),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
