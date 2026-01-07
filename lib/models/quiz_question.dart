import 'dart:math';

class QuizQuestion {
  final String question;
  final String correctAnswer;
  final List<String> wrongAnswers;

  const QuizQuestion({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswers,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawQuestion = json['question']?.toString().trim() ?? '';
    final rawCorrect = json['correctAnswer']?.toString().trim() ?? '';
    final rawWrong = json['wrongAnswers'];
    final wrongAnswers = <String>[];
    if (rawWrong is List) {
      for (final item in rawWrong) {
        final answer = item?.toString().trim();
        if (answer != null && answer.isNotEmpty) {
          wrongAnswers.add(answer);
        }
      }
    }

    return QuizQuestion(
      question: rawQuestion.isEmpty ? 'Unknown question' : rawQuestion,
      correctAnswer: rawCorrect.isEmpty ? 'Unknown answer' : rawCorrect,
      wrongAnswers: wrongAnswers,
    );
  }

  static List<QuizQuestion> fromJsonList(List<dynamic> items) {
    final results = <QuizQuestion>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        results.add(QuizQuestion.fromJson(item));
      }
    }
    return results;
  }

  List<String> allOptions({Random? random}) {
    final options = <String>[...wrongAnswers, correctAnswer];
    options.shuffle(random ?? Random());
    return options;
  }
}
