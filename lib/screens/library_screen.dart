import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/screens/info_screen.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import '../services/movie_service.dart';
import '../services/ads_service.dart';

class LibraryScreen extends StatefulWidget {
  final String type; // Accept 'movie' or 'tv_show'
  const LibraryScreen({super.key, required this.type});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> libraryItems;
  late String selectedType;
  final AdsService _adsService = AdsService();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    selectedType = widget.type;
    libraryItems = MovieService.fetchAllByType(selectedType);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    if (type == selectedType) return;
    HapticFeedback.selectionClick();
    setState(() {
      selectedType = type;
      libraryItems = MovieService.fetchAllByType(selectedType);
    });
    _animationController.forward(from: 0.0);
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
              SliverToBoxAdapter(child: _buildTypeSwitch()),
              SliverToBoxAdapter(child: _buildAdTile()),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: libraryItems,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return SliverFillRemaining(child: _buildMessage('Error loading library items'));
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return SliverFillRemaining(child: _buildMessage('No titles available yet'));
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final movie = items[index];
                          final animation = CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index / items.length).clamp(0.0, 1.0) * 0.5,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - animation.value)),
                                child: Opacity(
                                  opacity: animation.value,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildMovieCard(movie),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
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
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Navigator.of(context).canPop())
            _buildBackButton(),
          if (Navigator.of(context).canPop())
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Library', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 6),
                Text(
                  selectedType == 'movie' ? 'All Movies' : 'TV Collections',
                  style: BentoTheme.display,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return BentoCard(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(context),
      child: const Icon(CupertinoIcons.arrow_left, color: Colors.white, size: 18),
    );
  }

  Widget _buildTypeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeChip('movie', 'Movies', CupertinoIcons.film),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTypeChip('tv_show', 'TV Shows', CupertinoIcons.tv),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () => _selectType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? BentoTheme.accent.withOpacity(0.25) : BentoTheme.surfaceAlt.withOpacity(0.85),
          border: Border.all(color: isSelected ? BentoTheme.accent : BentoTheme.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: BentoTheme.subtitle.copyWith(
                color: isSelected ? BentoTheme.textPrimary : BentoTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: BentoCard(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _adsService.showBannerAd(),
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

  Widget _buildMovieCard(Map<String, dynamic> movie) {
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
        );
      },
      child: Stack(
        children: [
          Positioned.fill(child: _buildPosterImage(movie['poster']?.toString())),
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
            top: 8,
            right: 8,
            child: _buildRatingBadge(rating),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 10,
            child: Text(
              title,
              style: BentoTheme.caption.copyWith(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(String rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
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
