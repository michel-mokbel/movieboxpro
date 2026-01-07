import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../services/movie_service.dart';
import 'info_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final movies = await MovieService.fetchAllByType("movie");
      final tvShows = await MovieService.fetchAllByType("tv_show");

      final results = [...movies, ...tvShows].where((item) {
        final title = item["title"]?.toString().toLowerCase() ?? "";
        final plot = item["plot"]?.toString().toLowerCase() ?? "";
        final cast = (item["cast"] as List<String>?)?.join(" ").toLowerCase() ?? "";
        final searchQuery = query.toLowerCase();

        return title.contains(searchQuery) || 
               plot.contains(searchQuery) || 
               cast.contains(searchQuery);
      }).toList();

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
      
      if (results.isNotEmpty) {
        HapticFeedback.selectionClick();
      _animationController.forward(from: 0.0);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
                  Color(0xFF1A1A1A),
                  Colors.black,
                  Color(0xFF0D0D0D),
                ],
                ),
            ),
          ),
          
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Text(
                        "Explore",
                        style: IOSTheme.largeTitle.copyWith(
                          fontSize: 42,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -1,
                    ),
                  ),
                      const SizedBox(height: 20),
                      Hero(
                        tag: 'search_bar',
                        child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: CupertinoSearchTextField(
                      controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _performSearch,
                      style: const TextStyle(color: Colors.white),
                                placeholderStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                backgroundColor: Colors.transparent,
                                prefixIcon: const Icon(CupertinoIcons.search, color: Colors.white),
                                suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white),
                                padding: const EdgeInsets.all(16),
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 15)),
                  )
              else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                SliverFillRemaining(
                  child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(CupertinoIcons.search, color: Colors.white.withOpacity(0.3), size: 60),
                            const SizedBox(height: 16),
                            Text(
                          'No results found',
                          style: IOSTheme.body.copyWith(color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                    ),
                        ),
                      )
              else
                SliverPadding(
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
                              offset: Offset(0, 50 * (1 - animation.value)),
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
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        movie["poster"] ?? "",
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                        color: Colors.white.withOpacity(0.05),
                                        child: Icon(
                                          CupertinoIcons.film,
                                          color: Colors.white.withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                            Colors.black.withOpacity(0.8),
                                            ],
                                          stops: const [0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              movie["title"] ?? "Unknown",
                                            style: IOSTheme.subhead.copyWith(
                                              fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                              const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  movie["imdbRating"] ?? "N/A",
                                                style: IOSTheme.caption1.copyWith(color: Colors.white70),
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
                      childCount: _searchResults.length,
                        ),
                      ),
            ),
                
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        ],
      ),
    );
  }
}
