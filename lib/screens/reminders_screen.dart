import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _remindersFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadReminders();
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

  void _loadReminders() {
    setState(() {
      _remindersFuture = Future.value([]);
    });
  }

  Future<void> _deleteReminder(String movieId, String title) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Are you sure you want to delete the reminder for "$title"?'),
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

    if (confirmed == true) {
      setState(() {
        _loadReminders();
      });
      if (!mounted) return;
    }
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
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _remindersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(child: _buildMessage('Error loading reminders'));
                  }

                  final reminders = snapshot.data ?? [];

                  if (reminders.isEmpty) {
                    return SliverFillRemaining(child: _buildEmptyState());
                  }

                  reminders.sort((a, b) => (a['scheduledTime'] as DateTime)
                      .compareTo(b['scheduledTime'] as DateTime));

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final reminder = reminders[index];
                        final DateTime scheduledTime = reminder['scheduledTime'] as DateTime;
                        final bool isPast = scheduledTime.isBefore(DateTime.now());

                        final animation = CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            (index / reminders.length).clamp(0.0, 1.0) * 0.5,
                            1.0,
                            curve: Curves.easeOutCubic,
                          ),
                        );

                        return AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, 24 * (1 - animation.value)),
                              child: Opacity(
                                opacity: animation.value,
                                child: child,
                              ),
                            );
                          },
                          child: Dismissible(
                            key: Key(reminder['movieId']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                              decoration: BoxDecoration(
                                color: BentoTheme.accent,
                                borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(CupertinoIcons.trash, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteReminder(
                              reminder['movieId'],
                              reminder['title'],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: BentoCard(
                                padding: const EdgeInsets.all(16),
                                borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isPast
                                            ? BentoTheme.surfaceAlt
                                            : BentoTheme.accent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: BentoTheme.outline),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.bell_fill,
                                        color: isPast ? BentoTheme.textMuted : BentoTheme.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reminder['title'],
                                            style: BentoTheme.title.copyWith(
                                              color: isPast ? BentoTheme.textMuted : Colors.white,
                                              decoration: isPast ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMM d, y - h:mm a').format(scheduledTime),
                                            style: BentoTheme.caption.copyWith(
                                              color: isPast ? BentoTheme.textMuted : BentoTheme.textSecondary,
                                            ),
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
                      childCount: reminders.length,
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
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reminders', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('Your watch alerts', style: BentoTheme.display),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: BentoCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BentoTheme.surfaceAlt.withOpacity(0.8),
                border: Border.all(color: BentoTheme.outline),
              ),
              child: const Icon(CupertinoIcons.bell_slash, color: BentoTheme.textMuted, size: 36),
            ),
            const SizedBox(height: 16),
            Text('No reminders set', style: BentoTheme.title.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Tap the bell icon on movie details to set one', style: BentoTheme.body, textAlign: TextAlign.center),
          ],
        ),
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
}
