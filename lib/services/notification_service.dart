
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';

class NotificationService {

  Future<void> scheduleMovieReminder({
    required String movieTitle,
    required DateTime scheduledTime,
    String? movieId,
    required BuildContext context,
  }) async {

      if (!context.mounted) return;
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: BentoTheme.surface,
          title: const Text('Notifications Disabled', style: TextStyle(color: BentoTheme.textPrimary)),
          content: const Text(
            'Notifications are required for reminders. Would you like to enable them?',
            style: TextStyle(color: BentoTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: BentoTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: BentoTheme.accent)),
            ),
          ],
        ));

    }

  
  }

  Future<void> cancelMovieReminder(String movieId) async {
    
    // Remove from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final reminders = prefs.getStringList('movie_reminders') ?? [];
    reminders.removeWhere((reminder) => reminder.startsWith('$movieId|'));
    await prefs.setStringList('movie_reminders', reminders);
  }

  Future<List<Map<String, dynamic>>> getScheduledReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = prefs.getStringList('movie_reminders') ?? [];
    
    return reminders.map((reminder) {
      final parts = reminder.split('|');
      return {
        'movieId': parts[0],
        'title': parts[1],
        'scheduledTime': DateTime.parse(parts[2]),
      };
    }).toList();
  }
