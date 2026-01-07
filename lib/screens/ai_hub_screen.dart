import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import 'mood_discovery_screen.dart';
import 'movie_quiz_screen.dart';

class AIHubScreen extends StatefulWidget {
  const AIHubScreen({super.key});

  @override
  State<AIHubScreen> createState() => AIHubScreenState();
}

class AIHubScreenState extends State<AIHubScreen> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void openMood() {
    _navigatorKey.currentState?.push(
      CupertinoPageRoute(
        builder: (context) => const MoodDiscoveryScreen(),
      ),
    );
  }

  void openQuiz({Map<String, dynamic>? movie}) {
    _navigatorKey.currentState?.push(
      CupertinoPageRoute(
        builder: (context) => MovieQuizScreen(movie: movie),
      ),
    );
  }

  void popToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => AIHubHome(
            onMood: openMood,
            onQuiz: (movie) => openQuiz(movie: movie),
          ),
        );
      },
    );
  }
}

class AIHubHome extends StatelessWidget {
  final VoidCallback onMood;
  final ValueChanged<Map<String, dynamic>?> onQuiz;

  const AIHubHome({
    super.key,
    required this.onMood,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0B10),
                  Color(0xFF0F1116),
                  Color(0xFF050505),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI',
                    style: IOSTheme.largeTitle.copyWith(
                      fontSize: 42,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'Studio',
                    style: IOSTheme.title1.copyWith(
                      color: IOSTheme.systemBlue,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildHubCard(
                    icon: CupertinoIcons.sparkles,
                    title: 'Mood Discovery',
                    subtitle: 'Match movies to your mood with one tap.',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onMood();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildHubCard(
                    icon: CupertinoIcons.question_circle_fill,
                    title: 'Movie Quiz',
                    subtitle: 'Generate trivia quizzes from favorites or trending.',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onQuiz(null);
                    },
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: IOSTheme.systemBlue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: IOSTheme.systemBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: IOSTheme.title3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: IOSTheme.subhead.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}
