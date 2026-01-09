import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import '../services/movie_service.dart';
import 'info_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;

  const SearchScreen({super.key, this.initialCategory});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;

  final List<_QuickFilter> _filters = const [
    _QuickFilter('Trending', CupertinoIcons.flame),
    _QuickFilter('New', CupertinoIcons.sparkles),
    _QuickFilter('Top Rated', CupertinoIcons.star_fill),
    _QuickFilter('Family', CupertinoIcons.person_2_fill),
  ];

  final List<String> _categories = const [
    'All',
    'Action',
    'Comedy',
    'Drama',
    'Sci-Fi',
    'Horror',
    'Family',
  ];

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _baseSuggestions = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  String _selectedFilter = 'Trending';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void applyCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _searchController.clear();
      _searchFocusNode.unfocus();
    });
    refreshSuggestions();
  }

  void refreshSuggestions() {
    if (_allItems.isEmpty) {
      _loadItems();
      return;
    }
    _baseSuggestions = _pickRandomItems(_allItems, 24);
    _applyFilters();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final movies = await MovieService.fetchAllByType('movie');
      final tvShows = await MovieService.fetchAllByType('tv_show');
      _allItems = [...movies, ...tvShows];

      _baseSuggestions = _pickRandomItems(_allItems, 24);
      _applyFilters();
    } catch (_) {
      _allItems = [];
      _baseSuggestions = [];
      _searchResults = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim();
    List<Map<String, dynamic>> source = query.isEmpty ? _baseSuggestions : _allItems;

    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      source = source.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final plot = item['plot']?.toString().toLowerCase() ?? '';
        final cast = (item['cast'] as List<String>?)?.join(' ').toLowerCase() ?? '';
        return title.contains(lowerQuery) || plot.contains(lowerQuery) || cast.contains(lowerQuery);
      }).toList();
    }

    _searchResults = source.where((item) => _matchesCategory(item, _selectedCategory)).toList();

    if (_searchResults.isNotEmpty) {
      _animationController.forward(from: 0.0);
    }
    if (mounted) {
      setState(() {});
    }
  }

  bool _matchesCategory(Map<String, dynamic> item, String category) {
    if (category == 'All') return true;
    final genre = item['genre']?.toString().toLowerCase() ?? '';
    final normalized = category.toLowerCase();
    if (normalized == 'sci-fi') {
      return genre.contains('sci-fi') || genre.contains('sci fi') || genre.contains('science fiction');
    }
    return genre.contains(normalized);
  }

  List<Map<String, dynamic>> _pickRandomItems(List<Map<String, dynamic>> items, int count) {
    if (items.isEmpty) return [];
    final random = Random();
    final shuffled = List<Map<String, dynamic>>.from(items)..shuffle(random);
    return shuffled.take(count).toList();
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
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildQuickFilters()),
              SliverToBoxAdapter(child: _buildCategoryFilters()),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                  ),
                )
              else if (_searchResults.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  sliver: _buildResultsGrid(),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
          Text('Search', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('Find your next watch', style: BentoTheme.display),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gradient: BentoTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
        child: CupertinoSearchTextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (_) => _applyFilters(),
          style: const TextStyle(color: BentoTheme.textPrimary),
          placeholder: 'Search movies, series, cast... ',
          placeholderStyle: TextStyle(color: BentoTheme.textMuted),
          backgroundColor: Colors.transparent,
          prefixIcon: const Icon(CupertinoIcons.search, color: BentoTheme.textPrimary),
          suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill, color: BentoTheme.textMuted),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = filter.label == _selectedFilter;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedFilter = filter.label;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? BentoTheme.accent.withOpacity(0.2)
                      : BentoTheme.surfaceAlt.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? BentoTheme.accent : BentoTheme.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(filter.icon, size: 16, color: isSelected ? BentoTheme.accent : BentoTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      filter.label,
                      style: BentoTheme.subtitle.copyWith(
                        color: isSelected ? BentoTheme.textPrimary : BentoTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = category == _selectedCategory;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategory = category;
                });
                _applyFilters();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? BentoTheme.surfaceAlt : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? BentoTheme.accent : BentoTheme.outline),
                ),
                child: Text(
                  category,
                  style: BentoTheme.caption.copyWith(
                    color: isSelected ? BentoTheme.textPrimary : BentoTheme.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _searchController.text.isEmpty
        ? 'We will surface recent picks once you start exploring.'
        : 'Try another title or actor name.';

    return Center(
      child: BentoCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.search, color: BentoTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text('No results found', style: BentoTheme.title.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text(message, style: BentoTheme.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final movie = _searchResults[index];
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index / _searchResults.length).clamp(0.0, 1.0) * 0.5,
              1.0,
              curve: Curves.easeOutCubic,
            ),
          );

          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - animation.value)),
                child: Opacity(
                  opacity: animation.value,
                  child: child,
                ),
              );
            },
            child: _buildResultCard(movie),
          );
        },
        childCount: _searchResults.length,
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> movie) {
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
          Positioned.fill(
            child: _buildPosterImage(movie['poster']?.toString(), BentoTheme.radiusMedium),
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
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.55, 1.0],
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
            child: Text(
              title,
              style: BentoTheme.subtitle.copyWith(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildPosterImage(String? url, double radius) {
    final safeUrl = url ?? '';
    if (safeUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
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
            decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
            child: const Icon(CupertinoIcons.film, color: Colors.white54),
          );
        },
      ),
    );
  }
}

class _QuickFilter {
  final String label;
  final IconData icon;

  const _QuickFilter(this.label, this.icon);
}
