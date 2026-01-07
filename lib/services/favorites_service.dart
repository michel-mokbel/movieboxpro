import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';


class FavoritesService {
  static const String _key = 'favorites';

  static String _getMovieId(Map<String, dynamic> movie) {
    return movie['imdbID'] ?? '${movie["title"]}_${movie["year"]}';
  }

  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_key);
    if (favoritesJson == null) return [];
    
    List<dynamic> decoded = jsonDecode(favoritesJson);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<int> getFavoritesCount() async {
    final favorites = await getFavorites();
    return favorites.length;
  }

  static Future<void> addToFavorites(Map<String, dynamic> movie) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> favorites = await getFavorites();
    
    String movieId = _getMovieId(movie);
    // Check if movie already exists in favorites
    if (!favorites.any((element) => _getMovieId(element) == movieId)) {
      favorites.add(movie);
      await prefs.setString(_key, jsonEncode(favorites));
    }
  }

  static Future<void> removeFromFavorites(String movieId) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> favorites = await getFavorites();
    
    favorites.removeWhere((element) => _getMovieId(element) == movieId);
    await prefs.setString(_key, jsonEncode(favorites));
  }

  static Future<bool> isFavorite(String movieId) async {
    List<Map<String, dynamic>> favorites = await getFavorites();
    return favorites.any((element) => _getMovieId(element) == movieId);
  }
} 