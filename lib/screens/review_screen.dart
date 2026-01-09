import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import 'package:uuid/uuid.dart';
import '../services/review_service.dart';

class ReviewScreen extends StatefulWidget {
  final Map<String, dynamic> media;
  final String type; // 'movie' or 'tv_show'
  final Review? existingReview;

  const ReviewScreen({
    super.key,
    required this.media,
    required this.type,
    this.existingReview,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _titleController.text = widget.existingReview!.title;
      _contentController.text = widget.existingReview!.content;
      _rating = widget.existingReview!.rating;
    }
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final review = Review(
        id: widget.existingReview?.id ?? const Uuid().v4(),
        title: _titleController.text,
        content: _contentController.text,
        rating: _rating,
        timestamp: DateTime.now(),
        type: widget.type,
        mediaId: widget.media['imdbID'] ?? '${widget.media["title"]}_${widget.media["year"]}',
      );

      await ReviewService.addReview(review);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Error saving review: $e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildBentoTextField({
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return BentoCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextFormField(
            controller: controller,
            style: BentoTheme.body.copyWith(color: BentoTheme.textPrimary),
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: BentoTheme.body.copyWith(color: BentoTheme.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              errorStyle: BentoTheme.caption.copyWith(color: BentoTheme.accent),
            ),
            validator: validator,
          ),
        ),
      ),
    );
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
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: BentoCard(
                    padding: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(14),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 18),
                  ),
                ),
                actions: [
                  if (widget.existingReview != null)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final confirm = await showCupertinoDialog<bool>(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('Delete Review'),
                            content: const Text('Are you sure you want to delete this review?'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await ReviewService.deleteReview(widget.media['imdbID'] ??
                              '${widget.media["title"]}_${widget.media["year"]}');
                          if (!mounted) return;
                          Navigator.pop(context, true);
                        }
                      },
                      child: BentoCard(
                        padding: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(14),
                        child: const Icon(CupertinoIcons.trash, color: BentoTheme.accent, size: 18),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingReview == null ? 'Write Review' : 'Edit Review',
                            style: BentoTheme.display,
                          ),
                          const SizedBox(height: 20),
                          BentoCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    widget.media['poster'] ?? '',
                                    height: 110,
                                    width: 76,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 110,
                                      width: 76,
                                      decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
                                      child: const Icon(CupertinoIcons.film, color: Colors.white54),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.media['title'] ?? 'Unknown Title',
                                        style: BentoTheme.title.copyWith(color: Colors.white),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(widget.media['year'] ?? '', style: BentoTheme.caption),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Your Rating', style: BentoTheme.subtitle),
                          const SizedBox(height: 12),
                          BentoCard(
                            padding: const EdgeInsets.all(18),
                            borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
                            child: Column(
                              children: [
                                Text(_rating.toStringAsFixed(1), style: BentoTheme.display.copyWith(color: BentoTheme.highlight)),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: BentoTheme.highlight,
                                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                                    thumbColor: Colors.white,
                                    overlayColor: BentoTheme.highlight.withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: _rating,
                                    min: 1.0,
                                    max: 5.0,
                                    divisions: 8,
                                    onChanged: (value) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _rating = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Review Details', style: BentoTheme.subtitle),
                          const SizedBox(height: 12),
                          _buildBentoTextField(
                            controller: _titleController,
                            placeholder: 'Title (e.g., Great Movie!)',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildBentoTextField(
                            controller: _contentController,
                            placeholder: 'Share your thoughts...',
                            maxLines: 6,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please write your review';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: BentoTheme.accent,
                              borderRadius: BorderRadius.circular(16),
                              onPressed: _isSubmitting ? null : _submitReview,
                              child: _isSubmitting
                                  ? const CupertinoActivityIndicator(color: Colors.white)
                                  : Text(
                                      widget.existingReview == null ? 'Submit Review' : 'Update Review',
                                      style: BentoTheme.subtitle.copyWith(color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
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

  Widget _buildBackground() {
    final poster = widget.media['poster']?.toString() ?? '';
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
}
