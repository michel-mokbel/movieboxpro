import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentlyViewedService {
  static const String _key = 'recently_viewed';
  static const int _maxItems = 20;

  static String _getItemId(Map<String, dynamic> item) {
    return item['imdbID'] ??
        item['imdbId'] ??
        item['id'] ??
        '${item["title"]}_${item["year"]}';
  }

  static Future<List<Map<String, dynamic>>> getRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonData = prefs.getString(_key);
    if (jsonData == null) return [];

    final decoded = jsonDecode(jsonData) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> addRecentlyViewed(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getRecentlyViewed();

    final itemId = _getItemId(item);
    items.removeWhere((existing) => _getItemId(existing) == itemId);
    items.insert(0, item);

    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }

    await prefs.setString(_key, jsonEncode(items));
  }
}
