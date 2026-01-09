import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/screens/info_screen.dart';
import 'package:moviemagicbox/screens/library_screen.dart';
import 'package:moviemagicbox/screens/mood_discovery_screen.dart';
import 'package:moviemagicbox/screens/movie_quiz_screen.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import '../repositories/dashboard_repository.dart';
import '../services/ads_service.dart';
import '../services/recently_viewed_service.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMoodRequested;
  final ValueChanged<Map<String, dynamic>?>? onQuizRequested;
  final ValueChanged<String>? onCategorySelected;

  const DashboardScreen({
    super.key,
    this.onMoodRequested,
    this.onQuizRequested,
    this.onCategorySelected,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, List<Map<String, dynamic>>>> dashboardData;
  final AdsService _adsService = AdsService();

  final List<_CategoryItem> _categories = const [
    _CategoryItem('Action', CupertinoIcons.bolt),
    _CategoryItem('Comedy', CupertinoIcons.smiley),
    _CategoryItem('Drama', CupertinoIcons.eye),
    _CategoryItem('Sci-Fi', CupertinoIcons.antenna_radiowaves_left_right),
    _CategoryItem('Horror', CupertinoIcons.eye),
  ];

  @override
  void initState() {
    super.initState();
    dashboardData = DashboardRepository.fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text('Unable to load dashboard', style: BentoTheme.body),
            );
          }

          final data = snapshot.data!;
          final topRated = data['topRatedMovies'] ?? [];
          final trending = data['trendingMovies'] ?? [];
          final featured = _pickFeatured(topRated, trending);

          return Stack(
            children: [
              _buildBackground(featured?['poster']?.toString()),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildFeaturedCard(featured)),
                  SliverToBoxAdapter(child: _buildCategoryRow()),
                  SliverToBoxAdapter(child: _buildRecentlyViewedSection()),
                  SliverToBoxAdapter(child: _buildAiTiles(featured)),
                  SliverToBoxAdapter(child: _buildTopPicksSection(topRated, trending)),
                  SliverToBoxAdapter(child: _buildBannerAd()),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground(String? poster) {
    return Container(
      decoration: BoxDecoration(
        gradient: BentoTheme.backgroundGradient,
        image: poster != null && poster.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(poster),
                fit: BoxFit.cover,
                opacity: 0.22,
              )
            : null,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BentoTheme.background.withOpacity(0.2),
                BentoTheme.background,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Featured Movie', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('Tonight\'s Spotlight', style: BentoTheme.display),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic>? movie) {
    if (movie == null) {
      return const SizedBox.shrink();
    }

    final title = movie['title']?.toString() ?? 'Unknown';
    final genre = _formatGenres(movie['genre']?.toString());
    final rating = movie['imdbRating']?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: BentoCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
        height: 230,
        onTap: () => _openDetails(movie),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildPosterImage(movie['poster']?.toString(), radius: BentoTheme.radiusLarge),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.2, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BentoTheme.title.copyWith(fontSize: 24, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(genre, style: BentoTheme.body.copyWith(color: BentoTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.star_fill, color: BentoTheme.highlight, size: 14),
                      const SizedBox(width: 6),
                      Text(rating, style: BentoTheme.body.copyWith(color: BentoTheme.textPrimary)),
                      const SizedBox(width: 8),
                      Text('IMDb', style: BentoTheme.caption),
                      const Spacer(),
                      _buildWatchButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: BentoTheme.accentGradient,
        boxShadow: [
          BoxShadow(
            color: BentoTheme.accent.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text('View Now', style: BentoTheme.caption.copyWith(color: Colors.white)),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.play_arrow_solid, size: 12, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = _categories[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (widget.onCategorySelected != null) {
                  widget.onCategorySelected!(item.label);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: BentoTheme.surfaceAlt.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BentoTheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: BentoTheme.textPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(item.label, style: BentoTheme.subtitle.copyWith(color: BentoTheme.textPrimary)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: RecentlyViewedService.getRecentlyViewed(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: BentoCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BentoTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BentoTheme.outline),
                    ),
                    child: const Icon(
                      CupertinoIcons.clock,
                      color: BentoTheme.textMuted,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recently viewed titles will show up here.',
                      style: BentoTheme.body.copyWith(color: BentoTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final visibleItems = items.take(6).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Recently Viewed'),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return _buildRecentCard(visibleItems[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Unknown';
    final year = item['year']?.toString();
    final type = _resolveTypeLabel(item);

    return BentoCard(
      width: 150,
      height: 210,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      onTap: () => _openDetails(item),
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildPosterImage(item['poster']?.toString(), radius: BentoTheme.radiusMedium),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: _buildTypeChip(type),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: BentoTheme.subtitle.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (year != null) ...[
                  const SizedBox(height: 6),
                  Text(year, style: BentoTheme.caption.copyWith(color: BentoTheme.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTiles(Map<String, dynamic>? featured) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('AI Studio'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BentoCard(
                  gradient: BentoTheme.surfaceGradient,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (widget.onMoodRequested != null) {
                      widget.onMoodRequested!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MoodDiscoveryScreen()),
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BentoTheme.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.sparkles, color: BentoTheme.accent, size: 18),
                      ),
                      const SizedBox(height: 12),
                      Text('Mood Discovery', style: BentoTheme.subtitle.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('Match movies to your vibe.', style: BentoTheme.body),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: BentoCard(
                  gradient: BentoTheme.surfaceGradient,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (widget.onQuizRequested != null) {
                      widget.onQuizRequested!(featured);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MovieQuizScreen(movie: featured)),
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BentoTheme.accentSoft.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.question_circle_fill, color: BentoTheme.accentSoft, size: 18),
                      ),
                      const SizedBox(height: 12),
                      Text('Movie Quiz', style: BentoTheme.subtitle.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('Test your trivia knowledge.', style: BentoTheme.body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPicksSection(
    List<Map<String, dynamic>> topRated,
    List<Map<String, dynamic>> trending,
  ) {
    final picks = [...topRated, ...trending];
    if (picks.isEmpty) return const SizedBox.shrink();

    final hero = picks.first;
    final list = picks.skip(1).take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Top Picks for You', onViewAll: () => _openLibrary(type: 'movie')),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: list
                      .map(
                        (movie) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildMiniPickTile(movie),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildHeroPickTile(hero)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPickTile(Map<String, dynamic> movie) {
    final title = movie['title']?.toString() ?? 'Unknown';

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => _openDetails(movie),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 54,
              child: _buildPosterImage(movie['poster']?.toString(), radius: 10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: BentoTheme.subtitle.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, color: BentoTheme.textMuted, size: 16),
        ],
      ),
    );
  }

  Widget _buildHeroPickTile(Map<String, dynamic> movie) {
    final title = movie['title']?.toString() ?? 'Unknown';
    final rating = movie['imdbRating']?.toString() ?? 'N/A';

    return BentoCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      onTap: () => _openDetails(movie),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildPosterImage(movie['poster']?.toString(), radius: BentoTheme.radiusMedium),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _buildRatingBadge(rating),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                title,
                style: BentoTheme.subtitle.copyWith(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBadge(String rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BentoTheme.outline),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.star_fill, size: 12, color: BentoTheme.highlight),
          const SizedBox(width: 4),
          Text(rating, style: BentoTheme.caption.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: BentoCard(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _adsService.showBannerAd(),
      ),
    );
  }

  String _formatGenres(String? raw) {
    if (raw == null || raw.isEmpty) return 'Adventure';
    final parts = raw.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (parts.isEmpty) return 'Adventure';
    return parts.take(2).join(' • ');
  }

  String _resolveTypeLabel(Map<String, dynamic> item) {
    final rawType = (item['type'] ?? item['Type'] ?? '').toString().toLowerCase();
    if (rawType.contains('tv')) return 'TV';
    if (rawType.contains('series')) return 'TV';
    return 'Movie';
  }

  Widget _buildTypeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BentoTheme.outline),
      ),
      child: Text(
        label,
        style: BentoTheme.caption.copyWith(color: Colors.white),
      ),
    );
  }

  Map<String, dynamic>? _pickFeatured(
    List<Map<String, dynamic>> topRated,
    List<Map<String, dynamic>> trending,
  ) {
    if (topRated.isNotEmpty) return topRated.first;
    if (trending.isNotEmpty) return trending.first;
    return null;
  }

  void _openDetails(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: movie),
      ),
    );
  }

  void _openLibrary({required String type}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LibraryScreen(type: type),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: BentoTheme.title),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text('View All', style: BentoTheme.body.copyWith(color: BentoTheme.accentSoft)),
          ),
      ],
    );
  }

  Widget _buildPosterImage(String? url, {required double radius}) {
    final safeUrl = url ?? '';
    if (safeUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: const BoxDecoration(
            gradient: BentoTheme.surfaceGradient,
          ),
          child: const Icon(CupertinoIcons.film, color: Colors.white54),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        safeUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: const BoxDecoration(
              gradient: BentoTheme.surfaceGradient,
            ),
            child: const Icon(CupertinoIcons.film, color: Colors.white54),
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  final String label;
  final IconData icon;

  const _CategoryItem(this.label, this.icon);
}
