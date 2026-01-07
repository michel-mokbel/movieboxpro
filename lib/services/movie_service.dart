import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MovieService {
  static const String lambdaBaseUrl =
      // "https://rkkz3numqb.execute-api.eu-central-1.amazonaws.com/MagicMovieBox";
      "https://ys05q5ql4d.execute-api.eu-central-1.amazonaws.com/MovieMagicBox";

  /// Fetch movie or TV show details with caching
  static Future<Map<String, dynamic>> fetchDetails(String id, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "details_$type$id";

    // Check if the data exists in the cache
    if (prefs.containsKey(cacheKey)) {
      return jsonDecode(prefs.getString(cacheKey)!);
    }

    // If not cached, fetch from API
    try {
      final requestBody = {
        "action": "getById",
        "parameters": {
          "id": id.startsWith("tt") ? id : "tt$id",
          "type": type,
        }
      };

      final response = await http.post(
        Uri.parse(lambdaBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save data to cache
        prefs.setString(cacheKey, jsonEncode(data));
        return data;
      } else {
        throw Exception("Failed to fetch data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching details: $e");
      rethrow;
    }
  }

  /// Fetch all movies or TV shows by type with caching
  static Future<List<Map<String, dynamic>>> fetchAllByType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "all_$type";

    try {
      // Check cache
      if (prefs.containsKey(cacheKey)) {
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          try {
            return List<Map<String, dynamic>>.from(jsonDecode(cachedData));
          } catch (e) {
            print("Error parsing cached data: $e");
            // If cache is corrupted, remove it
            await prefs.remove(cacheKey);
          }
        }
      }

      // Fetch from API if not cached
      final requestBody = {
        "action": "getAllByType",
        "parameters": {"type": type},
      };

      final response = await http.post(
        Uri.parse(lambdaBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10)); // Add timeout

      if (response.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        // Save to cache
        prefs.setString(cacheKey, jsonEncode(data));
        return data;
      } else {
        print("Failed to fetch all data: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching all by type: $e");
      return []; // Return empty list instead of throwing
    }
  }
}
