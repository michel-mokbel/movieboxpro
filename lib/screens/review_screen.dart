import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
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

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextFormField(
            controller: controller,
            style: IOSTheme.body,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: IOSTheme.body.copyWith(color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              errorStyle: IOSTheme.caption1.copyWith(color: IOSTheme.systemBlue),
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ambient Background
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(widget.media['poster'] ?? ''),
                fit: BoxFit.cover,
                opacity: 0.1,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
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
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: const Icon(CupertinoIcons.trash, color: IOSTheme.systemBlue, size: 20),
                      ),
                    ),
                ],
              ),

              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingReview == null ? 'Write Review' : 'Edit Review',
                            style: IOSTheme.largeTitle,
                          ),
                          const SizedBox(height: 32),

                          // Media Info
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    widget.media['poster'] ?? '',
                                    height: 120,
                                    width: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 120,
                                      width: 80,
                                      color: Colors.grey[800],
                                      child: const Icon(CupertinoIcons.film, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.media['title'] ?? 'Unknown Title',
                                      style: IOSTheme.title2,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.media['year'] ?? '',
                                      style: IOSTheme.body.copyWith(color: Colors.white.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // Rating
                          Text('Your Rating', style: IOSTheme.headline),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _rating.toStringAsFixed(1),
                                  style: IOSTheme.largeTitle.copyWith(color: Colors.amber),
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.amber,
                                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.amber.withOpacity(0.2),
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
                          const SizedBox(height: 32),

                          // Inputs
                          Text('Review Details', style: IOSTheme.headline),
                          const SizedBox(height: 16),
                          _buildGlassTextField(
                            controller: _titleController,
                            placeholder: 'Title (e.g., Great Movie!)',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildGlassTextField(
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
                          const SizedBox(height: 40),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              borderRadius: BorderRadius.circular(16),
                              onPressed: _isSubmitting ? null : _submitReview,
                              child: _isSubmitting
                                  ? const CupertinoActivityIndicator(color: Colors.white)
                                  : Text(
                                      widget.existingReview == null ? 'Submit Review' : 'Update Review',
                                      style: IOSTheme.headline.copyWith(color: Colors.white),
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
}
