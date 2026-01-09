import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import '../services/favorites_service.dart';
import '../services/review_service.dart';
import '../services/streaming_service.dart';
import '../services/ads_service.dart';
import '../services/api_service.dart';
import '../services/recently_viewed_service.dart';
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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _movieId = widget.movie['imdbID'] ?? '${widget.movie["title"]}_${widget.movie["year"]}';
    _imdbId = _resolveImdbId(widget.movie);

    RecentlyViewedService.addRecentlyViewed(widget.movie);
    _checkFavoriteStatus();
    _loadReviews();

    streamingData = StreamingService.getStreamingAvailability(
      widget.movie['title'],
      type: widget.movie['type'] ?? 'movie',
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
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
    final Uri url = Uri.parse('https://www.youtube.com/results?search_query=$query official trailer');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _showAdAndPlayTrailer(String query) async {
    HapticFeedback.heavyImpact();
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

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    _launchYouTubeSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.movie['poster']?.toString() ?? '';

    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: Stack(
        children: [
          _buildBackground(poster),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.62,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                leading: _buildGlassButton(
                  icon: CupertinoIcons.arrow_left,
                  onTap: () => Navigator.pop(context),
                ),
                actions: [
                  _buildGlassButton(
                    icon: _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    onTap: _toggleFavorite,
                    tint: _isFavorite ? BentoTheme.accent : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  _buildGlassButton(
                    icon: CupertinoIcons.bell,
                    onTap: _showReminderDialog,
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (poster.isNotEmpty)
                        Image.network(poster, fit: BoxFit.cover)
                      else
                        Container(decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.2),
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                              BentoTheme.background,
                            ],
                            stops: const [0.0, 0.35, 0.75, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 30,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (widget.movie['title'] ?? 'Unknown').toString(),
                                style: BentoTheme.display.copyWith(fontSize: 32, color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildTag(widget.movie['year'] ?? 'N/A'),
                                  const SizedBox(width: 8),
                                  _buildTag(widget.movie['imdbRating'] ?? 'N/A', icon: CupertinoIcons.star_fill),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.movie['genre'] ?? '',
                                      style: BentoTheme.caption.copyWith(color: BentoTheme.textSecondary),
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
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionTile(
                                label: 'Watch Trailer',
                                icon: CupertinoIcons.play_arrow_solid,
                                onTap: () => _showAdAndPlayTrailer(widget.movie['title']),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionTile(
                                label: 'Take Quiz',
                                icon: CupertinoIcons.question_circle_fill,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MovieQuizScreen(movie: widget.movie),
                                    ),
                                  );
                                },
                                accent: BentoTheme.accentSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('The Story'),
                        const SizedBox(height: 10),
                        BentoCard(
                          padding: const EdgeInsets.all(16),
                          borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
                          child: Text(
                            widget.movie['plot'] ?? 'No details available.',
                            style: BentoTheme.body.copyWith(color: BentoTheme.textSecondary, height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('The Stars'),
                        const SizedBox(height: 10),
                        _buildCastList(),
                        const SizedBox(height: 20),
                        _buildStreamingSection(),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle('The Verdict'),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: Text('Read All', style: BentoTheme.caption.copyWith(color: BentoTheme.accentSoft)),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildReviewsSummary(),
                        const SizedBox(height: 20),
                        BentoCard(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _adsService.showBannerAd(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(String poster) {
    return Container(
      decoration: BoxDecoration(
        gradient: BentoTheme.backgroundGradient,
        image: poster.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(poster),
                fit: BoxFit.cover,
                opacity: 0.08,
              )
            : null,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, Color tint = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: BentoCard(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Icon(icon, color: tint, size: 18),
      ),
    );
  }

  Widget _buildTag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: BentoTheme.outline),
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: BentoTheme.highlight),
            const SizedBox(width: 4),
          ],
          Text(text, style: BentoTheme.caption.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: BentoTheme.subtitle.copyWith(color: BentoTheme.accentSoft));
  }

  Widget _buildActionTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color accent = BentoTheme.accent,
  }) {
    return BentoCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      gradient: BentoTheme.surfaceGradient,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: BentoTheme.subtitle.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCastList() {
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
          return Text('No cast info', style: BentoTheme.body.copyWith(color: BentoTheme.textMuted));
        }

        return SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final actorName = cast[index];
              return BentoCard(
                padding: const EdgeInsets.all(10),
                borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BentoTheme.surfaceAlt,
                        border: Border.all(color: BentoTheme.outline),
                        image: const DecorationImage(
                          image: AssetImage('lib/assets/images/profile-pic.png'),
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
                        style: BentoTheme.caption.copyWith(color: BentoTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
            _buildSectionTitle('Available On'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: streamingInfo.map<Widget>((service) {
                return BentoCard(
                  onTap: () async {
                    final url = Uri.parse(service['link']);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        service['service'] == 'netflix'
                            ? CupertinoIcons.play_rectangle_fill
                            : CupertinoIcons.tv_fill,
                        color: service['service'] == 'netflix' ? const Color(0xFFE50914) : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        service['service'].toString().toUpperCase(),
                        style: BentoTheme.caption.copyWith(color: Colors.white),
                      ),
                    ],
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
          return BentoCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
            child: Column(
              children: [
                const Icon(CupertinoIcons.chat_bubble_2, color: BentoTheme.textMuted, size: 32),
                const SizedBox(height: 8),
                Text('No reviews yet', style: BentoTheme.subtitle.copyWith(color: BentoTheme.textSecondary)),
                const SizedBox(height: 12),
                CupertinoButton(
                  minSize: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  color: BentoTheme.surfaceAlt,
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
                  child: const Text('Be the first to review', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ],
            ),
          );
        }

        final topReview = reviews.first;
        return BentoCard(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.quote_bubble_fill, color: BentoTheme.accent, size: 18),
                      const SizedBox(width: 8),
                      Text('Featured Review', style: BentoTheme.caption),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.star_fill, color: BentoTheme.highlight, size: 14),
                      const SizedBox(width: 4),
                      Text(topReview.rating.toStringAsFixed(1), style: BentoTheme.caption.copyWith(color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(topReview.title, style: BentoTheme.title.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                topReview.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: BentoTheme.body.copyWith(color: BentoTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
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
                child: Text('Read more', style: BentoTheme.caption.copyWith(color: BentoTheme.accentSoft)),
              ),
            ],
          ),
        );
      },
    );
  }
}
