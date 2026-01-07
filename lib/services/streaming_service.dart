import 'dart:convert';
import 'package:http/http.dart' as http;

class StreamingService {
  static const String _apiKey = 'f5a78660bbmsh8da2d99f0a17edbp1615aejsn3221c36093ae';
  static const String _baseUrl = 'https://streaming-availability.p.rapidapi.com';

  static Future<Map<String, dynamic>> getStreamingAvailability(String title, {String? type}) async {
    try {
      // Determine the show type based on the type parameter
      final showType = type?.toLowerCase() == 'tv' || type?.toLowerCase() == 'series' 
          ? 'series' 
          : 'movie';

      final response = await http.get(
        Uri.parse('$_baseUrl/search/title?title=${Uri.encodeComponent(title)}&country=ae&show_type=$showType&output_language=en'),
        headers: {
          'x-rapidapi-key': _apiKey,
          'x-rapidapi-host': 'streaming-availability.p.rapidapi.com'
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch streaming data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching streaming data: $e');
    }
  }
} 