import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/screens/info_screen.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
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

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = FavoritesService.getFavorites();
    });
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A0505), // Dark Red tint
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
                        "Watch",
                        style: IOSTheme.largeTitle.copyWith(
                          fontSize: 42,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        "Later",
                        style: IOSTheme.title1.copyWith(
                          color: IOSTheme.systemBlue,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _favoritesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 15)),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text('Error loading favorites', style: IOSTheme.body),
                      ),
                    );
                  }

                  final favorites = snapshot.data ?? [];

                  if (favorites.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Icon(
                                CupertinoIcons.bookmark,
                                color: Colors.white.withOpacity(0.3),
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Your list is empty',
                              style: IOSTheme.title3.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Save movies to watch later',
                              style: IOSTheme.body.copyWith(color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final movie = favorites[index];
                          // Staggered animation
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
                                offset: Offset(0, 30 * (1 - animation.value)),
                                child: Opacity(
                                  opacity: animation.value,
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MovieDetailsScreen(movie: movie),
                                  ),
                                ).then((_) => _loadFavorites());
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
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
                                              Colors.black.withOpacity(0.9),
                                            ],
                                            stops: const [0.5, 0.8, 1.0],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              movie["title"] ?? "Unknown",
                                              style: IOSTheme.headline.copyWith(fontSize: 16),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 10),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        movie["imdbRating"] ?? "N/A",
                                                        style: IOSTheme.caption1.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: favorites.length,
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
}
