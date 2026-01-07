import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moviemagicbox/screens/info_screen.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ambient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A20), // Deep Blue/Black for library
                  Colors.black,
                  Color(0xFF0D0D0D),
                ],
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              // Large Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.arrow_left, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        selectedType == "movie" ? "Movies" : "TV Shows",
                        style: IOSTheme.largeTitle.copyWith(
                          fontSize: 42,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        "Library",
                        style: IOSTheme.title1.copyWith(
                          color: IOSTheme.systemBlue,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Ad
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: _adsService.showBannerAd(),
                  ),
                ),
              ),

              // Content
              FutureBuilder<List<Map<String, dynamic>>>(
                future: libraryItems,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 15)),
                    );
                  } else if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text("Error loading library items", style: IOSTheme.body),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "No items available",
                          style: IOSTheme.title3.copyWith(color: Colors.white54),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.65,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final movie = items[index];
                          // Staggered animation
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
                            child: _buildMovieCard(movie, context),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  );
                },
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie, BuildContext context) {
    String truncatedTitle = _truncateTitle(movie["title"] ?? "Unknown Title");

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      movie["poster"] ?? "",
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white.withOpacity(0.1),
                        child: const Icon(CupertinoIcons.film, color: Colors.white54),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.6, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            truncatedTitle,
            style: IOSTheme.caption1.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _truncateTitle(String title) {
    List<String> words = title.split(' ');
    if (words.length > 2) {
      return '${words[0]} ${words[1]}...';
    }
    return title;
  }
}
