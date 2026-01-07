class MoodRecommendation {
  final String title;
  final String? year;
  final String? reason;

  const MoodRecommendation({
    required this.title,
    this.year,
    this.reason,
  });

  factory MoodRecommendation.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString().trim() ?? '';
    return MoodRecommendation(
      title: rawTitle.isEmpty ? 'Unknown title' : rawTitle,
      year: json['year']?.toString().trim(),
      reason: json['reason']?.toString().trim(),
    );
  }

  static List<MoodRecommendation> fromJsonList(List<dynamic> items) {
    final results = <MoodRecommendation>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        results.add(MoodRecommendation.fromJson(item));
      }
    }
    return results;
  }
}
