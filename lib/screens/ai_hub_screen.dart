import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import 'package:moviemagicbox/services/quiz_history_service.dart';
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
      backgroundColor: BentoTheme.background,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Studio', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 6),
                  Text('Your cinematic copilot', style: BentoTheme.display),
                  const SizedBox(height: 20),
                  _buildHeroTile(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: CupertinoIcons.sparkles,
                          title: 'Mood Discovery',
                          subtitle: 'Find movies that match your vibe.',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onMood();
                          },
                          tint: BentoTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionTile(
                          icon: CupertinoIcons.question_circle_fill,
                          title: 'Movie Quiz',
                          subtitle: 'Trivia generated from your picks.',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onQuiz(null);
                          },
                          tint: BentoTheme.accentSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTipTile(),
                  const SizedBox(height: 16),
                  _buildRecentQuizzes(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: BentoTheme.backgroundGradient,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeroTile() {
    return BentoCard(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2B3A5C),
          Color(0xFF141B2D),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: BentoTheme.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: BentoTheme.accent.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personalized picks', style: BentoTheme.title.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text('Let the AI assemble a watchlist tailored to your mood and favorites.', style: BentoTheme.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color tint,
  }) {
    return BentoCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      gradient: BentoTheme.surfaceGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withOpacity(0.2),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: BentoTheme.subtitle.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(subtitle, style: BentoTheme.body),
        ],
      ),
    );
  }

  Widget _buildTipTile() {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BentoTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BentoTheme.outline),
            ),
            child: const Icon(CupertinoIcons.lightbulb_fill, color: BentoTheme.highlight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: Start with Mood Discovery for instant recommendations, then challenge yourself with a quiz.',
              style: BentoTheme.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentQuizzes() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: QuizHistoryService.getQuizHistory(),
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return BentoCard(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BentoTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BentoTheme.outline),
                  ),
                  child: const Icon(CupertinoIcons.checkmark_seal, color: BentoTheme.textMuted, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Finish a quiz to see your recent scores here.',
                    style: BentoTheme.body,
                  ),
                ),
              ],
            ),
          );
        }

        final visible = results.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recently Completed', style: BentoTheme.subtitle.copyWith(color: Colors.white)),
            const SizedBox(height: 10),
            ...visible.map(_buildQuizResultTile),
          ],
        );
      },
    );
  }

  Widget _buildQuizResultTile(Map<String, dynamic> result) {
    final title = result['title']?.toString() ?? 'Quiz';
    final poster = result['poster']?.toString();
    final score = result['score']?.toString() ?? '0';
    final total = result['total']?.toString() ?? '0';
    final timestamp = result['timestamp']?.toString();
    final dateLabel = _formatTimestamp(timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 46,
                height: 64,
                child: poster != null && poster.isNotEmpty
                    ? Image.network(poster, fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
                        child: const Icon(CupertinoIcons.film, color: Colors.white54),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BentoTheme.subtitle.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Score $score / $total', style: BentoTheme.caption.copyWith(color: BentoTheme.textSecondary)),
                ],
              ),
            ),
            Text(dateLabel, style: BentoTheme.caption.copyWith(color: BentoTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    final date = DateTime.tryParse(timestamp);
    if (date == null) return '';
    return '${date.month}/${date.day}';
  }
}
