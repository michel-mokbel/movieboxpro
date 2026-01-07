import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/screens/info_screen.dart';
import 'package:moviemagicbox/screens/library_screen.dart';
import 'package:moviemagicbox/screens/mood_discovery_screen.dart';
import 'package:moviemagicbox/screens/movie_quiz_screen.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../repositories/dashboard_repository.dart';
import '../services/ads_service.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMoodRequested;
  final ValueChanged<Map<String, dynamic>?>? onQuizRequested;

  const DashboardScreen({
    super.key,
    this.onMoodRequested,
    this.onQuizRequested,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, List<Map<String, dynamic>>>> dashboardData;
  int _activeIndex = 0;
  late AnimationController _animationController;
  final AdsService _adsService = AdsService();
  final PageController _pageController = PageController(viewportFraction: 0.75);
  
  // Track current background image for transitions
  String? _currentBackgroundPoster;

  @override
  void initState() {
    super.initState();
    dashboardData = DashboardRepository.fetchDashboardData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 15, color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle, color: IOSTheme.systemBlue, size: 40),
                  const SizedBox(height: 16),
                  Text('Error loading data', style: IOSTheme.body),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final topRated = data["topRatedMovies"]!;
          
          // Update background if needed
          if (_currentBackgroundPoster == null && topRated.isNotEmpty) {
            _currentBackgroundPoster = topRated[0]["poster"];
          }

          return Stack(
            children: [
              // 1. Dynamic Background
              _buildDynamicBackground(topRated),

              // 2. Content Scroll View
              CustomScrollView(
                slivers: [
                  // Large Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Discover",
                            style: IOSTheme.largeTitle.copyWith(
                              fontSize: 42,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            "Movies",
                            style: IOSTheme.title1.copyWith(
                              color: IOSTheme.systemBlue,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3D Cover Flow Carousel
                  SliverToBoxAdapter(
                    child: _build3DCarousel(topRated),
                  ),

                  // Mood Discovery CTA
                  SliverToBoxAdapter(
                    child: _buildMoodDiscoveryCta(),
                  ),

                  // Movie Quiz CTA
                  SliverToBoxAdapter(
                    child: _buildQuizCta(data),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),

                  // Trending Section (Glass List)
                  SliverToBoxAdapter(
                    child: _buildGlassList("Trending Now", data["trendingMovies"] ?? []),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  
                  // Ad
                  SliverToBoxAdapter(
                    child: _buildBannerAd(),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // TV Shows (Ticket Stubs)
                  SliverToBoxAdapter(
                    child: _buildTicketList("TV Series", data["topRatedTvShows"] ?? []),
                  ),

                  // Bottom Padding
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDynamicBackground(List<Map<String, dynamic>> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: Container(
        key: ValueKey<String>(_currentBackgroundPoster ?? ""),
        decoration: BoxDecoration(
          color: Colors.black,
          image: _currentBackgroundPoster != null ? DecorationImage(
            image: NetworkImage(_currentBackgroundPoster!),
            fit: BoxFit.cover,
            opacity: 0.4,
          ) : null,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DCarousel(List<Map<String, dynamic>> movies) {
    return SizedBox(
      height: 450,
      child: PageView.builder(
        controller: _pageController,
        itemCount: movies.length,
        onPageChanged: (index) {
          setState(() {
            _activeIndex = index;
            _currentBackgroundPoster = movies[index]["poster"];
          });
          HapticFeedback.selectionClick();
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 0.0;
              if (_pageController.position.haveDimensions) {
                value = index.toDouble() - (_pageController.page ?? 0);
              } else {
                value = index.toDouble() - _activeIndex.toDouble();
              }
              
              // 3D Rotation calculation
              final rotation = (value * 45).clamp(-45, 45) * (math.pi / 180);
              final scale = 1.0 - (value.abs() * 0.2);
              final opacity = 1.0 - (value.abs() * 0.5).clamp(0.0, 0.6);

              return Center(
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
                    ..rotateY(rotation)
                    ..scale(scale),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: opacity,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieDetailsScreen(movie: movies[index]),
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'poster_3d_${movies[index]["imdbID"] ?? index}',
                        child: Container(
                          width: 280,
                          height: 420,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _buildPosterImage(
                              movies[index]["poster"]?.toString(),
                              width: 280,
                              height: 420,
                              radius: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMoodDiscoveryCta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (widget.onMoodRequested != null) {
            widget.onMoodRequested!();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MoodDiscoveryScreen(),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                IOSTheme.systemBlue.withOpacity(0.2),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IOSTheme.systemBlue.withOpacity(0.2),
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: IOSTheme.systemBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood Discovery',
                      style: IOSTheme.title3.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Match movies to how you feel right now.',
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
      ),
    );
  }

  Widget _buildQuizCta(Map<String, List<Map<String, dynamic>>> data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final quizItem = _pickRandomQuizItem(data);
          if (quizItem == null) {
            _showQuizUnavailableDialog();
            return;
          }
          if (widget.onQuizRequested != null) {
            widget.onQuizRequested!(quizItem);
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieQuizScreen(movie: quizItem),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.05),
                IOSTheme.systemBlue.withOpacity(0.2),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IOSTheme.systemBlue.withOpacity(0.2),
                ),
                child: const Icon(
                  CupertinoIcons.question_circle_fill,
                  color: IOSTheme.systemBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Movie Quiz',
                      style: IOSTheme.title3.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Random quiz from a movie or series.',
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
      ),
    );
  }

  Map<String, dynamic>? _pickRandomQuizItem(
      Map<String, List<Map<String, dynamic>>> data) {
    final items = <Map<String, dynamic>>[];
    items.addAll(data['trendingMovies'] ?? []);
    items.addAll(data['trendingTvShows'] ?? []);
    items.addAll(data['topRatedMovies'] ?? []);
    items.addAll(data['topRatedTvShows'] ?? []);
    if (items.isEmpty) return null;
    items.shuffle(math.Random());
    return items.first;
  }

  void _showQuizUnavailableDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Quiz Unavailable'),
        content: const Text('No movies or series are available right now.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassList(String title, List<Map<String, dynamic>> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: IOSTheme.title2),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibraryScreen(
                        type: title.contains("TV") ? "tv_show" : "movie",
                      ),
                    ),
                  );
                },
                child: Text("View All", style: IOSTheme.body.copyWith(color: IOSTheme.systemBlue)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailsScreen(movie: movie),
                    ),
                  );
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    children: [
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          // Glassmorphism Border
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                              _buildPosterImage(
                                movie["poster"]?.toString(),
                                width: 160,
                                height: 200,
                                radius: 15,
                              ),
                              // Reflection effect
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie["title"] ?? "Unknown",
                        style: IOSTheme.caption1.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketList(String title, List<Map<String, dynamic>> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(title, style: IOSTheme.title2),
        ),
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: movies.take(5).length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailsScreen(movie: movie),
                  ),
                );
              },
              child: Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    // Left stub
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      child: SizedBox(
                        width: 80,
                        height: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPosterImage(
                              movie["poster"]?.toString(),
                              width: 80,
                              height: 100,
                              radius: 12,
                            ),
                            Container(color: Colors.black.withOpacity(0.3)),
                            const Center(
                              child: Icon(CupertinoIcons.play_circle, color: Colors.white, size: 30),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Perforation
                    SizedBox(
                      width: 1,
                      child: Column(
                        children: List.generate(10, (index) => Expanded(
                          child: Container(color: index % 2 == 0 ? Colors.transparent : Colors.grey),
                        )),
                      ),
                    ),
                    // Right details
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              movie["title"] ?? "Unknown",
                              style: IOSTheme.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(movie["imdbRating"] ?? "N/A", style: IOSTheme.caption1),
                                const SizedBox(width: 12),
                                const Icon(CupertinoIcons.calendar, color: Colors.grey, size: 12),
                                const SizedBox(width: 4),
                                Text(movie["year"] ?? "N/A", style: IOSTheme.caption1),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPosterImage(
    String? url, {
    required double width,
    required double height,
    double radius = 12,
  }) {
    final safeUrl = url ?? '';
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (width * dpr).round();
    final cacheHeight = (height * dpr).round();

    if (safeUrl.isEmpty) {
      return _buildPosterPlaceholder(radius);
    }

    return Image.network(
      safeUrl,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildPosterPlaceholder(radius, isLoading: true),
            Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IOSTheme.systemBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildPosterPlaceholder(radius),
    );
  }

  Widget _buildPosterPlaceholder(double radius, {bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
      ),
      child: Icon(
        CupertinoIcons.film,
        color: Colors.white.withOpacity(isLoading ? 0.4 : 0.6),
        size: 28,
      ),
    );
  }

  Widget _buildBannerAd() {
    return Center(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withOpacity(0.1))),
          color: Colors.black.withOpacity(0.3),
        ),
        child: Builder(
          builder: (context) {
            return _adsService.showBannerAd();
          },
        ),
      ),
    );
  }
}
