import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../models/mood_recommendation.dart';
import '../services/api_service.dart';
import '../services/movie_service.dart';
import '../widgets/ai_loader.dart';
import 'info_screen.dart';

class MoodDiscoveryScreen extends StatefulWidget {
  const MoodDiscoveryScreen({super.key});

  @override
  State<MoodDiscoveryScreen> createState() => _MoodDiscoveryScreenState();
}

class _MoodDiscoveryScreenState extends State<MoodDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final List<String> _moods = const [
    'Happy',
    'Thrilling',
    'Relaxing',
    'Romantic',
    'Family',
    'Dark',
  ];

  String? _selectedMood;
  bool _isLoading = false;
  String? _error;
  List<MoodRecommendation> _recommendations = [];
  Map<String, Map<String, dynamic>> _movieIndex = {};

  Future<void> _ensureMovieIndex() async {
    if (_movieIndex.isNotEmpty) return;
    final movies = await MovieService.fetchAllByType('movie');
    final index = <String, Map<String, dynamic>>{};
    for (final movie in movies) {
      final title = movie['title']?.toString().trim().toLowerCase();
      if (title != null && title.isNotEmpty && !index.containsKey(title)) {
        index[title] = movie;
      }
    }
    if (mounted) {
      setState(() {
        _movieIndex = index;
      });
    }
  }

  Future<void> _selectMood(String mood) async {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMood = mood;
      _isLoading = true;
      _error = null;
      _recommendations = [];
    });

    try {
      await _ensureMovieIndex();
      final results = await _apiService.getMoodBasedRecommendations(mood);
      if (!mounted) return;
      setState(() {
        _recommendations = results;
        _isLoading = false;
        if (results.isEmpty) {
          _error = 'No recommendations returned. Try another mood.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to fetch recommendations. Please try again.';
      });
    }
  }

  Map<String, dynamic>? _matchMovie(MoodRecommendation recommendation) {
    final key = recommendation.title.trim().toLowerCase();
    return _movieIndex[key];
  }

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
                  Color(0xFF0A0A0A),
                  Color(0xFF111016),
                  Color(0xFF030303),
                ],
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).padding.top + 20,
                    24,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood',
                        style: IOSTheme.largeTitle.copyWith(
                          fontSize: 42,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'Discovery',
                        style: IOSTheme.title1.copyWith(
                          color: IOSTheme.systemBlue,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _moods.map((mood) {
                      final isSelected = mood == _selectedMood;
                      return GestureDetector(
                        onTap: () => _selectMood(mood),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isSelected
                                ? IOSTheme.systemBlue.withOpacity(0.2)
                                : Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: isSelected
                                  ? IOSTheme.systemBlue
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            mood,
                            style: IOSTheme.subhead.copyWith(
                              color: isSelected ? IOSTheme.systemBlue : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildResults(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_selectedMood == null) {
      return _buildEmptyState(
        icon: CupertinoIcons.sparkles,
        title: 'Pick a mood',
        message: 'We will tailor movie picks to how you feel right now.',
      );
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: AiLoader(label: 'Finding your vibe...'),
        ),
      );
    }

    if (_error != null) {
      return _buildEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Something went wrong',
        message: _error!,
        action: _selectedMood == null ? null : () => _selectMood(_selectedMood!),
        actionLabel: 'Try Again',
      );
    }

    if (_recommendations.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.film,
        title: 'No results yet',
        message: 'Try another mood for fresh picks.',
      );
    }

    return Column(
      children: _recommendations.map(_buildRecommendationCard).toList(),
    );
  }

  Widget _buildRecommendationCard(MoodRecommendation recommendation) {
    final match = _matchMovie(recommendation);
    final poster = match?['poster']?.toString();
    final hasPoster = poster != null && poster.isNotEmpty;
    final subtitleParts = <String>[];
    if (recommendation.year != null && recommendation.year!.isNotEmpty) {
      subtitleParts.add(recommendation.year!);
    }
    if (recommendation.reason != null && recommendation.reason!.isNotEmpty) {
      subtitleParts.add(recommendation.reason!);
    }
    final subtitle = subtitleParts.join(' • ');

    return GestureDetector(
      onTap: match == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsScreen(movie: match),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.08),
                image: hasPoster
                    ? DecorationImage(
                        image: NetworkImage(poster!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasPoster
                  ? null
                  : const Icon(CupertinoIcons.film, color: Colors.white54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    style: IOSTheme.title3.copyWith(color: Colors.white),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: IOSTheme.body.copyWith(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (match != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'View details',
                      style: IOSTheme.subhead.copyWith(
                        color: IOSTheme.systemBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: IOSTheme.systemBlue, size: 32),
          const SizedBox(height: 12),
          Text(title, style: IOSTheme.title3.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            message,
            style: IOSTheme.body.copyWith(color: Colors.white70),
          ),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: action,
              child: Text(
                actionLabel,
                style: IOSTheme.subhead.copyWith(color: IOSTheme.systemBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
