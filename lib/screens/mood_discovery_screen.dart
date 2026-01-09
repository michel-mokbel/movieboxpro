import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
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
      backgroundColor: BentoTheme.background,
      body: Stack(
        children: [
          _buildBackground(),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildMoodChips()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mood Discovery', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('Find your vibe', style: BentoTheme.display),
        ],
      ),
    );
  }

  Widget _buildMoodChips() {
    return Padding(
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
                borderRadius: BorderRadius.circular(18),
                color: isSelected
                    ? BentoTheme.accent.withOpacity(0.2)
                    : BentoTheme.surfaceAlt.withOpacity(0.85),
                border: Border.all(
                  color: isSelected ? BentoTheme.accent : BentoTheme.outline,
                ),
              ),
              child: Text(
                mood,
                style: BentoTheme.subtitle.copyWith(
                  color: isSelected ? BentoTheme.textPrimary : BentoTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
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

    return BentoCard(
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
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 70,
              height: 100,
              child: hasPoster
                  ? Image.network(poster, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
                      child: const Icon(CupertinoIcons.film, color: Colors.white54),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recommendation.title, style: BentoTheme.title.copyWith(color: Colors.white)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: BentoTheme.body.copyWith(color: BentoTheme.textSecondary, height: 1.4)),
                ],
                if (match != null) ...[
                  const SizedBox(height: 10),
                  Text('View details', style: BentoTheme.caption.copyWith(color: BentoTheme.accentSoft)),
                ],
              ],
            ),
          ),
        ],
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
    return BentoCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BentoTheme.accent, size: 28),
          const SizedBox(height: 12),
          Text(title, style: BentoTheme.title.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(message, style: BentoTheme.body),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: action,
              child: Text(actionLabel, style: BentoTheme.subtitle.copyWith(color: BentoTheme.accentSoft)),
            ),
          ],
        ],
      ),
    );
  }
}
