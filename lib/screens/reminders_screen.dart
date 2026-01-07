import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';

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
    // Load reminders from local storage or service
    // Placeholder for now as the original implementation was empty
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
      // Logic to delete reminder
      setState(() {
        _loadReminders();
      });
      if (!mounted) return;
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
                        "Movie",
                        style: IOSTheme.largeTitle.copyWith(
                          fontSize: 42,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        "Reminders",
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
                future: _remindersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 15)),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text('Error loading reminders', style: IOSTheme.body),
                      ),
                    );
                  }

                  final reminders = snapshot.data ?? [];

                  if (reminders.isEmpty) {
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
                                CupertinoIcons.bell_slash,
                                color: Colors.white.withOpacity(0.3),
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No reminders set',
                              style: IOSTheme.title3.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the bell icon on movie details to set one',
                              style: IOSTheme.body.copyWith(color: Colors.white.withOpacity(0.5)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Sort reminders by date
                  reminders.sort((a, b) => (a['scheduledTime'] as DateTime)
                      .compareTo(b['scheduledTime'] as DateTime));

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final reminder = reminders[index];
                        final DateTime scheduledTime = reminder['scheduledTime'] as DateTime;
                        final bool isPast = scheduledTime.isBefore(DateTime.now());

                        // Staggered animation
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
                              offset: Offset(0, 30 * (1 - animation.value)),
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
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                              decoration: BoxDecoration(
                                color: IOSTheme.systemBlue,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(CupertinoIcons.trash, color: Colors.white),
                            ),
                            onDismissed: (_) => _deleteReminder(
                              reminder['movieId'],
                              reminder['title'],
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isPast ? Colors.white10 : IOSTheme.systemBlue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.bell_fill,
                                        color: isPast ? Colors.white38 : IOSTheme.systemBlue,
                                      ),
                                    ),
                                    title: Text(
                                      reminder['title'],
                                      style: IOSTheme.headline.copyWith(
                                        color: isPast ? Colors.white38 : Colors.white,
                                        decoration: isPast ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        DateFormat('MMM d, y - h:mm a').format(scheduledTime),
                                        style: IOSTheme.caption1.copyWith(
                                          color: isPast ? Colors.white24 : Colors.white60,
                                        ),
                                      ),
                                    ),
                                  ),
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
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}
