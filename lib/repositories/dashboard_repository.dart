import 'dart:math';
import 'package:moviemagicbox/services/movie_service.dart';

class DashboardRepository {
  /// Fetch dashboard data
  static Future<Map<String, List<Map<String, dynamic>>>> fetchDashboardData() async {
    try {
      // Fetch all movies and TV shows using caching
      final allMovies = await MovieService.fetchAllByType("movie");
      final allTvShows = await MovieService.fetchAllByType("tv_show");

      // Shuffle data for randomization
      allMovies.shuffle(Random());
      allTvShows.shuffle(Random());

      // Split data into sections
      final trendingMovies = allMovies.take(5).toList();
      final trendingTvShows = allTvShows.take(5).toList();
      final topRatedMovies = allMovies.skip(5).take(5).toList();
      final topRatedTvShows = allTvShows.skip(5).take(5).toList();

      return {
        "trendingMovies": trendingMovies,
        "trendingTvShows": trendingTvShows,
        "topRatedMovies": topRatedMovies,
        "topRatedTvShows": topRatedTvShows,
      };
    } catch (e) {
      print("Error fetching dashboard data: $e");
      return {
        "trendingMovies": [],
        "trendingTvShows": [],
        "topRatedMovies": [],
        "topRatedTvShows": [],
      };
    }
  }
}
