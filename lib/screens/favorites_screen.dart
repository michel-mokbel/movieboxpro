import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviemagicbox/screens/info_screen.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import '../services/favorites_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _favoritesFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = FavoritesService.getFavorites();
    });
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
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _favoritesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(child: _buildMessage('Unable to load favorites'));
                  }

                  final favorites = snapshot.data ?? [];

                  if (favorites.isEmpty) {
                    return SliverFillRemaining(child: _buildEmptyState());
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.74,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final movie = favorites[index];
                          final animation = CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index / favorites.length).clamp(0.0, 1.0) * 0.5,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, 26 * (1 - animation.value)),
                                child: Opacity(
                                  opacity: animation.value,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildFavoriteCard(movie),
                          );
                        },
                        childCount: favorites.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
          Text('Your List', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('Favorites', style: BentoTheme.display),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: BentoCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BentoTheme.surfaceAlt.withOpacity(0.8),
                border: Border.all(color: BentoTheme.outline),
              ),
              child: const Icon(CupertinoIcons.bookmark, color: BentoTheme.textMuted, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Nothing saved yet', style: BentoTheme.title.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Save movies to build your list.', style: BentoTheme.body),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String text) {
    return Center(
      child: BentoCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
        child: Text(text, style: BentoTheme.body.copyWith(color: Colors.white70)),
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> movie) {
    final title = movie['title']?.toString() ?? 'Unknown';
    final rating = movie['imdbRating']?.toString() ?? 'N/A';

    return BentoCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        ).then((_) => _loadFavorites());
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildPosterImage(movie['poster']?.toString()),
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
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _buildRatingBadge(rating),
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
                const SizedBox(height: 6),
                Text('Watch again', style: BentoTheme.caption.copyWith(color: BentoTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(String rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BentoTheme.outline),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.star_fill, size: 10, color: BentoTheme.highlight),
          const SizedBox(width: 4),
          Text(rating, style: BentoTheme.caption.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildPosterImage(String? url) {
    final safeUrl = url ?? '';
    if (safeUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
        child: Container(
          decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
          child: const Icon(CupertinoIcons.film, color: Colors.white54),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      child: Image.network(
        safeUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
            child: const Icon(CupertinoIcons.film, color: Colors.white54),
          );
        },
      ),
    );
  }
}
