import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Review {
  final String id;
  final String title;
  final String content;
  final double rating;
  final DateTime timestamp;
  final String type; // 'movie' or 'tv_show'
  final String mediaId;

  Review({
    required this.id,
    required this.title,
    required this.content,
    required this.rating,
    required this.timestamp,
    required this.type,
    required this.mediaId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'rating': rating,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'mediaId': mediaId,
  };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    rating: json['rating'].toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    type: json['type'],
    mediaId: json['mediaId'],
  );
}

class ReviewService {
  static const String _key = 'user_reviews';

  static Future<List<Review>> getReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final String? reviewsJson = prefs.getString(_key);
    if (reviewsJson == null) return [];
    
    List<dynamic> decoded = jsonDecode(reviewsJson);
    return decoded.map((item) => Review.fromJson(item)).toList();
  }

  static Future<List<Review>> getReviewsForMedia(String mediaId) async {
    final reviews = await getReviews();
    return reviews.where((review) => review.mediaId == mediaId).toList();
  }

  static Future<void> addReview(Review review) async {
    final prefs = await SharedPreferences.getInstance();
    List<Review> reviews = await getReviews();
    
    // Remove existing review for the same media if exists
    reviews.removeWhere((r) => r.mediaId == review.mediaId);
    
    reviews.add(review);
    await prefs.setString(_key, jsonEncode(reviews.map((r) => r.toJson()).toList()));
  }

  static Future<void> deleteReview(String mediaId) async {
    final prefs = await SharedPreferences.getInstance();
    List<Review> reviews = await getReviews();
    
    reviews.removeWhere((review) => review.mediaId == mediaId);
    await prefs.setString(_key, jsonEncode(reviews.map((r) => r.toJson()).toList()));
  }

  static Future<Review?> getReviewForMedia(String mediaId) async {
    final reviews = await getReviews();
    try {
      return reviews.firstWhere((review) => review.mediaId == mediaId);
    } catch (e) {
      return null;
    }
  }

  static Future<double?> getAverageRating(String mediaId) async {
    final reviews = await getReviewsForMedia(mediaId);
    if (reviews.isEmpty) return null;
    
    final sum = reviews.fold(0.0, (sum, review) => sum + review.rating);
    return sum / reviews.length;
  }
} 