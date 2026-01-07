import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../services/favorites_service.dart';
import '../services/review_service.dart';
import '../services/streaming_service.dart';
import '../services/ads_service.dart';
import '../services/api_service.dart';
import '../widgets/ai_loader.dart';
import 'review_screen.dart';
import 'movie_quiz_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> with TickerProviderStateMixin {
  late Future<Review?> userReview;
  late Future<List<Review>> allReviews;
  late Future<Map<String, dynamic>> streamingData;
  final AdsService _adsService = AdsService();
  final ApiService _apiService = ApiService();
  Future<List<String>>? _castFuture;
  late final String _imdbId;
  
  bool _isFavorite = false;
  late String _movieId;
  final ScrollController _scrollController = ScrollController();
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _movieId = widget.movie['imdbID'] ?? '${widget.movie["title"]}_${widget.movie["year"]}';
    _imdbId = _resolveImdbId(widget.movie);

    _checkFavoriteStatus();
    _loadReviews();
    
    streamingData = StreamingService.getStreamingAvailability(
        widget.movie["title"],
        type: widget.movie["type"] ?? 'movie'
    );

    // Fade in animation for content
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Pulse animation for the play button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _loadReviews() {
    userReview = ReviewService.getReviewForMedia(_movieId);
    allReviews = ReviewService.getReviewsForMedia(_movieId);
  }

  Future<void> _checkFavoriteStatus() async {
    final isFav = await FavoritesService.isFavorite(_movieId);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.selectionClick();
    if (_isFavorite) {
      setState(() {
        _isFavorite = false;
      });
      await FavoritesService.removeFromFavorites(_movieId);
      return;
    }

    final favoriteCount = await FavoritesService.getFavoritesCount();
    final shouldShowAd = favoriteCount % 3 == 0;

    if (!_adsService.isInitialized || !_adsService.adsEnabled || !shouldShowAd) {
      setState(() {
        _isFavorite = true;
      });
      await FavoritesService.addToFavorites(widget.movie);
      return;
    }

    if (mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CupertinoActivityIndicator(radius: 15),
          );
        },
      );
    }

    try {
      await Future.any([
        _adsService.showRewardedAd(),
        Future.delayed(const Duration(seconds: 5), () => false)
      ]);
    } catch (e) {
      print('Error showing ad: $e');
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    setState(() {
      _isFavorite = true;
    });
    await FavoritesService.addToFavorites(widget.movie);
  }

  Future<void> _showReminderDialog() async {
    HapticFeedback.mediumImpact();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!context.mounted) return;

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark(),
            child: child!,
          );
        },
      );

      if (pickedTime != null && context.mounted) {
        showCupertinoDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Reminder Set'),
            content: const Text('You will be notified when it\'s time to watch.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _launchYouTubeSearch(String query) async {
    final Uri url = Uri.parse("https://www.youtube.com/results?search_query=$query official trailer");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _showAdAndPlayTrailer(String query) async {
    HapticFeedback.heavyImpact();
    // Animation effect before launching
    await Future.delayed(const Duration(milliseconds: 100));
    
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CupertinoActivityIndicator(radius: 15),
        );
      },
    );

    // Simulate ad delay if needed
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    _launchYouTubeSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Massive Cinematic Header
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.75, // 75% of screen height
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            stretch: true,
            leading: _buildGlassIconButton(
              CupertinoIcons.arrow_left,
              () => Navigator.pop(context),
            ),
            actions: [
              _buildGlassIconButton(
                _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                _toggleFavorite,
                color: _isFavorite ? IOSTheme.systemBlue : Colors.white,
              ),
              const SizedBox(width: 8),
              _buildGlassIconButton(
                CupertinoIcons.bell,
                _showReminderDialog,
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image
                  Image.network(
                    widget.movie["poster"] ?? "",
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3), // Slight dim at top
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.8),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.2, 0.5, 0.85, 1.0],
                      ),
                    ),
                  ),
                  // Title & Meta placed directly on image at bottom
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.movie["title"] ?? "Unknown").toString().toUpperCase(),
                            style: IOSTheme.largeTitle.copyWith(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              height: 0.9,
                              shadows: [
                                Shadow(
                                  color: IOSTheme.systemBlue.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildTag(widget.movie["year"] ?? "N/A"),
                              const SizedBox(width: 8),
                              _buildTag(widget.movie["imdbRating"] ?? "N/A", icon: CupertinoIcons.star_fill, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.movie["genre"] ?? "",
                                  style: IOSTheme.subhead.copyWith(color: Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Content Body
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Play Button Section
                    const SizedBox(height: 20),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: GestureDetector(
                        onTap: () => _showAdAndPlayTrailer(widget.movie["title"]),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(35),
                            gradient: const LinearGradient(
                              colors: [IOSTheme.systemBlue, Color(0xFF990000)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: IOSTheme.systemBlue.withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.play_arrow_solid, color: IOSTheme.systemBlue, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                "WATCH TRAILER",
                                style: IOSTheme.title3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieQuizScreen(movie: widget.movie),
                          ),
                        );
                      },
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1C1C1E), IOSTheme.systemBlue],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.question_circle_fill,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "TAKE QUIZ",
                              style: IOSTheme.title3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Synopsis
                    _buildSectionTitle("THE STORY"),
                    const SizedBox(height: 12),
                    Text(
                      widget.movie["plot"] ?? "No details available.",
                      style: IOSTheme.body.copyWith(
                        height: 1.8,
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Cast Section (Horizontal Scroll)
                    _buildSectionTitle("THE STARS"),
                    const SizedBox(height: 16),
                    _buildCastList(),

                    const SizedBox(height: 40),
                    
                    // Available On Section
                    _buildStreamingSection(),

                    const SizedBox(height: 40),

                    // Reviews Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle("THE VERDICT"),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Text("Read All", style: IOSTheme.subhead.copyWith(color: IOSTheme.systemBlue)),
                          onPressed: () async {
                             // Navigation to full reviews
                             // ... existing logic ...
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildReviewsSummary(),
                    
                    const SizedBox(height: 40),
                    
                    // Ad Banner
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _adsService.showBannerAd(),
                    ),
                    
                    const SizedBox(height: 50), // Bottom Padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: IconButton(
              icon: Icon(icon, color: color, size: 20),
              onPressed: onTap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, {IconData? icon, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color ?? Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: IOSTheme.caption1.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: IOSTheme.subhead.copyWith(
        color: IOSTheme.systemBlue,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildCastList() {
    // If we have cast in the initial movie object, use it.
    // Otherwise, we might need to wait for full details.
    
    final initialCast = _extractCastFromData(widget.movie);
    _castFuture ??= initialCast.isNotEmpty
        ? Future.value(initialCast)
        : _apiService.fetchCast(
            _imdbId,
            widget.movie['type'] ?? 'movie',
            title: widget.movie['title']?.toString(),
          );

    return FutureBuilder<List<String>>(
      future: _castFuture,
      initialData: initialCast.isNotEmpty ? initialCast : null,
      builder: (context, snapshot) {
        final cast = snapshot.data ?? initialCast;

        if (snapshot.connectionState == ConnectionState.waiting && cast.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: AiLoader(label: 'Loading cast...', size: 42),
            ),
          );
        }

        if (cast.isEmpty) {
          return const Text("No cast info", style: TextStyle(color: Colors.white54));
        }

        return SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final actorName = cast[index];
              return Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      image: const DecorationImage(
                        image: AssetImage('lib/assets/images/profile-pic.png'), // Placeholder or implement actor image search
                        fit: BoxFit.cover,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: actorName.isNotEmpty ? null : const Icon(CupertinoIcons.person, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 70,
                    child: Text(
                      actorName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: IOSTheme.caption1.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    );
  }

  String _resolveImdbId(Map<String, dynamic> data) {
    final id = data['imdbID'] ?? data['imdbId'] ?? data['imdb_id'] ?? data['id'];
    return id?.toString().trim() ?? '';
  }

  List<String> _extractCastFromData(Map<String, dynamic> data) {
    final rawCast = data['cast'] ?? data['actors'] ?? data['actor'];
    return _normalizeCastList(rawCast);
  }

  List<String> _normalizeCastList(dynamic rawCast) {
    if (rawCast is List) {
      return rawCast
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (rawCast is String) {
      return rawCast
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return [];
  }
  
  Widget _buildStreamingSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: streamingData,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final streamingInfo = snapshot.data?['result']?[0]?['streamingInfo']?['ae'];
        if (streamingInfo == null || streamingInfo.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("AVAILABLE ON"),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: streamingInfo.map<Widget>((service) {
                return GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(service["link"]);
                    if (await canLaunchUrl(url)) {
                       await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Icon(
                            service["service"] == "netflix" ? CupertinoIcons.play_rectangle_fill : CupertinoIcons.tv_fill,
                            color: service["service"] == "netflix" ? const Color(0xFFE50914) : Colors.white,
                            size: 20,
                          ),
                         const SizedBox(width: 8),
                         Text(
                           service["service"].toString().toUpperCase(),
                           style: IOSTheme.caption1.copyWith(fontWeight: FontWeight.bold),
                         ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsSummary() {
    return FutureBuilder<List<Review>>(
      future: allReviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator();
        }
        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(CupertinoIcons.chat_bubble_2, color: Colors.white30, size: 32),
                  const SizedBox(height: 8),
                  Text("No reviews yet", style: IOSTheme.subhead.copyWith(color: Colors.white54)),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    minSize: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: () async {
                       final existingReview = await userReview;
                        if (!mounted) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReviewScreen(
                              media: widget.movie,
                              type: widget.movie['Type'] ?? 'movie',
                              existingReview: existingReview,
                            ),
                          ),
                        );
                        if (result == true) setState(() => _loadReviews());
                    },
                    child: const Text("Be the first to review", style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        }

        // Show just the top review in a nice card
        final topReview = reviews.first;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.quote_bubble_fill, color: IOSTheme.systemBlue, size: 20),
                      const SizedBox(width: 8),
                      Text("Featured Review", style: IOSTheme.caption1.copyWith(color: Colors.white54)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(topReview.rating.toStringAsFixed(1), style: IOSTheme.subhead.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                topReview.title,
                style: IOSTheme.headline.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                topReview.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: IOSTheme.body.copyWith(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                    // Navigate to reviews
                     final existingReview = await userReview;
                      if (!mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewScreen(
                            media: widget.movie,
                            type: widget.movie['Type'] ?? 'movie',
                            existingReview: existingReview,
                          ),
                        ),
                      );
                      if (result == true) setState(() => _loadReviews());
                },
                child: Text("Read more", style: IOSTheme.subhead.copyWith(color: IOSTheme.systemBlue)),
              ),
            ],
          ),
        );
      },
    );
  }
}
