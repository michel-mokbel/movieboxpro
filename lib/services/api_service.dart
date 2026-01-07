import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../models/mood_recommendation.dart';
import '../models/quiz_question.dart';
import 'movie_service.dart';

class ApiService {
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _retryDelay = Duration(seconds: 2);
  static const String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _openRouterModel = 'mistralai/devstral-2512:free';
  static String _openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');

  static void setOpenRouterApiKey(String apiKey) {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) return;
    _openRouterApiKey = trimmed;
  }

  Future<String> getChatbotResponse(String userMessage) async {
    if (_openRouterApiKey.isEmpty) {
      print('Chatbot API: Missing OPENROUTER_API_KEY');
      return 'Chatbot is unavailable. Please try again later.';
    }

    const systemMessage =
        'You are a movie expert and recommendation system. Help users find movies, provide information about movies, actors, directors, and give personalized recommendations.';
    final userContent =
        '$userMessage Please respond in a friendly and helpful manner.';

    return _generateWithOpenRouter(
      [
        {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': userContent},
      ],
      label: 'Chatbot API',
      temperature: 0.5,
      maxTokens: 900,
    );
  }

  Future<List<MoodRecommendation>> getMoodBasedRecommendations(String mood) async {
    if (_openRouterApiKey.isEmpty) {
      return [];
    }
    final prompt =
        'Recommend 5 movies perfect for $mood mood. Consider emotional tone, themes, and viewing context. '
        'Return JSON array of objects with "title", "year", and "reason". No markdown.';
    final response = await _generateWithOpenRouter(
      [
        {'role': 'user', 'content': prompt},
      ],
      label: 'Mood API',
      temperature: 0.6,
      maxTokens: 600,
    );

    final parsed = _parseJsonList(response);
    if (parsed != null) {
      final results = MoodRecommendation.fromJsonList(parsed);
      if (results.isNotEmpty) {
        return results;
      }
    }

    return _parseLinesAsRecommendations(response);
  }

  Future<List<QuizQuestion>> generateMovieQuiz(String movieTitle) async {
    if (_openRouterApiKey.isEmpty) {
      return [];
    }
    final prompt =
        'Generate 5 trivia questions about "$movieTitle". '
        'Return JSON array of objects with "question", "correctAnswer", and "wrongAnswers" (array of 3). No markdown.';
    final response = await _generateWithOpenRouter(
      [
        {'role': 'user', 'content': prompt},
      ],
      label: 'Quiz API',
      temperature: 0.5,
      maxTokens: 700,
    );

    final parsed = _parseJsonList(response);
    if (parsed != null) {
      return QuizQuestion.fromJsonList(parsed);
    }

    return [];
  }

  Future<List<String>> fetchCast(
    String imdbId,
    String type, {
    String? title,
  }) async {
    final resolvedId = imdbId.trim();
    try {
      if (resolvedId.isNotEmpty) {
        final details = await MovieService.fetchDetails(resolvedId, type);
        final cast = _extractCastFromData(details);
        if (cast.isNotEmpty) return cast;
      }

      final fallbackTitle = title?.trim() ?? '';
      if (fallbackTitle.isNotEmpty) {
        final aiCast = await _fetchCastFromAi(fallbackTitle, type);
        if (aiCast.isNotEmpty) return aiCast;

        final candidates = await MovieService.fetchAllByType(type);
        final normalizedTitle = fallbackTitle.toLowerCase();
        final match = candidates.firstWhere(
          (item) => (item['title']?.toString().toLowerCase() ?? '') == normalizedTitle,
          orElse: () => {},
        );
        final fallbackId = match['imdbID'] ?? match['imdbId'] ?? match['imdb_id'] ?? match['id'];
        final fallbackIdString = fallbackId?.toString().trim() ?? '';
        if (fallbackIdString.isNotEmpty) {
          final details = await MovieService.fetchDetails(fallbackIdString, type);
          return _extractCastFromData(details);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _fetchCastFromAi(String title, String type) async {
    if (_openRouterApiKey.isEmpty) return [];
    final prompt =
        'Provide the main cast for the $type titled "$title". '
        'Return a JSON array of names only. No markdown.';
    final response = await _generateWithOpenRouter(
      [
        {'role': 'user', 'content': prompt},
      ],
      label: 'Cast API',
      temperature: 0.4,
      maxTokens: 200,
    );

    final parsed = _parseJsonList(response);
    if (parsed != null) {
      return _normalizeCastList(parsed);
    }
    return _normalizeCastList(response);
  }

  Future<String> _generateWithOpenRouter(
    List<Map<String, String>> messages, {
    required String label,
    double temperature = 0.6,
    int maxTokens = 700,
  }) async {
    final payload = {
      "model": _openRouterModel,
      "messages": messages,
      "temperature": temperature,
      "max_tokens": maxTokens,
      "top_p": 0.8
    };

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        print('$label: Attempt ${attempt + 1}/$_maxRetries - Sending POST request...');
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_openRouterApiKey',
          },
          body: jsonEncode(payload),
        ).timeout(_timeout);

        print('$label: Response received - Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices']?[0]?['message']?['content'];
          if (text != null && text.isNotEmpty) {
            print('$label: Success - Response text length: ${text.length} characters');
            return text;
          }
          print('$label: Warning - Response structure missing text field');
          return '';
        } else if (response.statusCode == 429) {
          print('$label: Rate limited (429) - Will retry');
          if (attempt < _maxRetries - 1) {
            final delay = _retryDelay * (attempt + 1);
            final retryAfterHeader = response.headers['retry-after'];
            final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '');
            final retryAfterDelay = retryAfterSeconds != null
                ? Duration(seconds: retryAfterSeconds)
                : delay;
            print('$label: Retrying in ${retryAfterDelay.inSeconds} seconds...');
            await Future.delayed(retryAfterDelay);
            continue;
          }
          return '';
        } else if (response.statusCode >= 500) {
          print('$label: Server error ${response.statusCode} - Will retry');
          if (attempt < _maxRetries - 1) {
            final delay = _retryDelay * (attempt + 1);
            await Future.delayed(delay);
            continue;
          }
        } else {
          print('$label: Client error ${response.statusCode} - No retry');
          return '';
        }
      } on SocketException catch (e) {
        print('$label: SocketException - ${e.message}');
        if (attempt < _maxRetries - 1) {
          final delay = _retryDelay * (attempt + 1);
          await Future.delayed(delay);
          continue;
        }
        return '';
      } on HttpException catch (e) {
        print('$label: HttpException - ${e.message}');
        if (attempt < _maxRetries - 1) {
          final delay = _retryDelay * (attempt + 1);
          await Future.delayed(delay);
          continue;
        }
        return '';
      } on FormatException catch (e) {
        print('$label: FormatException - ${e.message}');
        return '';
      } catch (e) {
        print('$label: Unexpected error: $e');
        if (attempt < _maxRetries - 1) {
          final delay = _retryDelay * (attempt + 1);
          await Future.delayed(delay);
          continue;
        }
        return '';
      }
    }

    print('$label: All attempts failed - Returning empty response');
    return '';
  }

  List<dynamic>? _parseJsonList(String response) {
    if (response.isEmpty) return null;
    final jsonText = _extractJson(response);
    if (jsonText == null || jsonText.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['questions'] is List) {
        return decoded['questions'] as List<dynamic>;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  List<String> _extractCastFromData(Map<String, dynamic> data) {
    final rawCast = data['cast'] ?? data['actors'] ?? data['actor'];
    return _normalizeCastList(rawCast);
  }

  List<String> _normalizeCastList(dynamic rawCast) {
    if (rawCast is List) {
      return rawCast
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (rawCast is String) {
      return rawCast
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return [];
  }

  String? _extractJson(String text) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fencedMatch = fenced.firstMatch(text);
    if (fencedMatch != null) {
      return fencedMatch.group(1);
    }

    final listStart = text.indexOf('[');
    final listEnd = text.lastIndexOf(']');
    if (listStart != -1 && listEnd != -1 && listEnd > listStart) {
      return text.substring(listStart, listEnd + 1);
    }

    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
      return text.substring(objStart, objEnd + 1);
    }

    return null;
  }

  List<MoodRecommendation> _parseLinesAsRecommendations(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return [];
    }

    final results = <MoodRecommendation>[];
    for (final line in lines) {
      var cleaned = line.replaceAll(RegExp(r'^\d+[\).]\s*'), '');
      cleaned = cleaned.replaceAll(RegExp(r'^[-•]\s*'), '');
      if (cleaned.isEmpty) continue;

      final parts = cleaned.split(' - ');
      if (parts.length > 1) {
        results.add(MoodRecommendation(
          title: parts.first.trim(),
          reason: parts.sublist(1).join(' - ').trim(),
        ));
      } else {
        results.add(MoodRecommendation(title: cleaned));
      }
    }

    return results;
  }

  Future<void> sendContactMessage(String name, String email, String message) async {
    // Implement your contact form submission logic here
    // For example, sending to a backend server or email service
    await Future.delayed(const Duration(seconds: 1)); // Simulated delay
    // You can add actual implementation later
  }
}
