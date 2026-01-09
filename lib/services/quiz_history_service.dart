import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QuizHistoryService {
  static const String _key = 'quiz_history';
  static const int _maxItems = 10;

  static Future<List<Map<String, dynamic>>> getQuizHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final decoded = jsonDecode(data) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> addQuizResult({
    required String title,
    String? poster,
    required int score,
    required int total,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getQuizHistory();

    final entry = <String, dynamic>{
      'title': title,
      'poster': poster,
      'score': score,
      'total': total,
      'timestamp': DateTime.now().toIso8601String(),
    };

    history.insert(0, entry);
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }

    await prefs.setString(_key, jsonEncode(history));
  }
}
