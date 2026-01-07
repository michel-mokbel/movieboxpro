import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import '../models/quiz_question.dart';
import '../repositories/dashboard_repository.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import '../widgets/ai_loader.dart';

class MovieQuizScreen extends StatefulWidget {
  final Map<String, dynamic>? movie;

  const MovieQuizScreen({super.key, this.movie});

  @override
  State<MovieQuizScreen> createState() => _MovieQuizScreenState();
}

class _MovieQuizScreenState extends State<MovieQuizScreen> {
  final ApiService _apiService = ApiService();
  final Random _random = Random();

  bool _loadingMovies = true;
  bool _isGenerating = false;
  String _source = 'favorites';
  String? _error;
  bool _autoFallbackStarted = false;

  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _trending = [];
  Map<String, dynamic>? _selectedMovie;

  List<QuizQuestion> _questions = [];
  List<List<String>> _options = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _loadMovieSources();
    if (widget.movie != null) {
      _selectedMovie = widget.movie;
      _startQuizForMovie(widget.movie!);
    }
  }

  Future<void> _loadMovieSources() async {
    try {
      final favorites = await FavoritesService.getFavorites();
      final dashboard = await DashboardRepository.fetchDashboardData();
      final trending = dashboard['trendingMovies'] ?? [];

      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _trending = trending;
        _loadingMovies = false;
      });

      if (favorites.isEmpty && widget.movie == null && !_autoFallbackStarted) {
        _autoFallbackStarted = true;
        await _startRandomQuiz();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMovies = false;
        _error = 'Unable to load movies. Please try again.';
      });
    }
  }

  Future<void> _startQuizForMovie(Map<String, dynamic> movie) async {
    final title = movie['title']?.toString();
    if (title == null || title.trim().isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedMovie = movie;
      _isGenerating = true;
      _error = null;
      _questions = [];
      _options = [];
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _showResults = false;
    });

    try {
      final questions = await _apiService.generateMovieQuiz(title.trim());
      if (!mounted) return;

      if (questions.isEmpty) {
        setState(() {
          _isGenerating = false;
          _error = 'No quiz questions returned. Try a different movie.';
        });
        return;
      }

      final options = questions
          .map((question) => question.allOptions(random: _random))
          .toList();

      setState(() {
        _questions = questions;
        _options = options;
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _error = 'Unable to generate quiz. Please try again.';
      });
    }
  }

  Future<void> _startRandomQuiz() async {
    if (_isGenerating) return;
    try {
      final movies = await MovieService.fetchAllByType('movie');
      final tvShows = await MovieService.fetchAllByType('tv_show');
      final combined = [...movies, ...tvShows];
      if (combined.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'No movies or series available right now.';
        });
        return;
      }
      combined.shuffle(_random);
      await _startQuizForMovie(combined.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load a random movie. Please try again.';
      });
    }
  }

  void _selectAnswer(String answer) {
    if (_selectedAnswer != null) return;
    final currentQuestion = _questions[_currentIndex];
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAnswer = answer;
      if (answer == currentQuestion.correctAnswer) {
        _score += 1;
      }
    });
  }

  void _nextQuestion() {
    if (_selectedAnswer == null) return;
    if (_currentIndex >= _questions.length - 1) {
      setState(() {
        _showResults = true;
      });
      return;
    }

    setState(() {
      _currentIndex += 1;
      _selectedAnswer = null;
    });
  }

  void _resetQuiz() {
    setState(() {
      _questions = [];
      _options = [];
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _showResults = false;
      _selectedMovie = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0B14),
                  Color(0xFF141414),
                  Color(0xFF040404),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movie',
                    style: IOSTheme.largeTitle.copyWith(
                      fontSize: 42,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'Quiz',
                    style: IOSTheme.title1.copyWith(
                      color: IOSTheme.systemBlue,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isGenerating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: AiLoader(label: 'Generating your quiz...'),
                      ),
                    )
                  else if (_showResults)
                    _buildResults()
                  else if (_questions.isNotEmpty)
                    _buildQuiz()
                  else
                    _buildSelection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelection() {
    if (_loadingMovies) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: AiLoader(label: 'Loading your library...'),
        ),
      );
    }

    final movies = _source == 'favorites' ? _favorites : _trending;

    if (_error != null) {
      return _buildMessageCard(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Something went wrong',
        message: _error!,
      );
    }

    if (movies.isEmpty) {
      if (_source == 'favorites') {
        return _buildMessageCard(
          icon: CupertinoIcons.film,
          title: 'No favorites yet',
          message: 'Generating a quiz from a random pick...',
        );
      }
      return _buildMessageCard(
        icon: CupertinoIcons.film,
        title: 'No movies here yet',
        message: 'Trending list is empty right now.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSegmentedControl<String>(
          groupValue: _source,
          borderColor: Colors.white.withOpacity(0.1),
          selectedColor: IOSTheme.systemBlue.withOpacity(0.3),
          unselectedColor: Colors.white.withOpacity(0.05),
          onValueChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() {
              _source = value;
              _error = null;
            });
          },
          children: {
            'favorites': Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Favorites',
                style: IOSTheme.subhead.copyWith(color: Colors.white70),
              ),
            ),
            'trending': Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Trending',
                style: IOSTheme.subhead.copyWith(color: Colors.white70),
              ),
            ),
          },
        ),
        const SizedBox(height: 20),
        ...movies.map(_buildMovieTile).toList(),
      ],
    );
  }

  Widget _buildMovieTile(Map<String, dynamic> movie) {
    final poster = movie['poster']?.toString();
    final title = movie['title']?.toString() ?? 'Unknown title';
    final year = movie['year']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedMovie = movie;
          });
          _startQuizForMovie(movie);
        },
        leading: Container(
          width: 48,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withOpacity(0.1),
            image: poster != null && poster.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(poster),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: poster != null && poster.isNotEmpty
              ? null
              : const Icon(CupertinoIcons.film, color: Colors.white54),
        ),
        title: Text(title, style: IOSTheme.title3.copyWith(color: Colors.white)),
        subtitle: year == null
            ? null
            : Text(
                year,
                style: IOSTheme.subhead.copyWith(color: Colors.white60),
              ),
        trailing: const Icon(CupertinoIcons.play_circle_fill, color: IOSTheme.systemBlue),
      ),
    );
  }

  Widget _buildQuiz() {
    final currentQuestion = _questions[_currentIndex];
    final options = _options[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedMovie != null)
          Text(
            _selectedMovie?['title']?.toString() ?? '',
            style: IOSTheme.subhead.copyWith(color: Colors.white70),
          ),
        const SizedBox(height: 8),
        Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: IOSTheme.subhead.copyWith(color: Colors.white60),
        ),
        const SizedBox(height: 16),
        Text(
          currentQuestion.question,
          style: IOSTheme.title3.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 20),
        ...options.map((option) => _buildOptionTile(option, currentQuestion.correctAnswer)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: _selectedAnswer == null ? Colors.white24 : IOSTheme.systemBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: _selectedAnswer == null ? null : _nextQuestion,
                child: Text(
                  _currentIndex == _questions.length - 1 ? 'Finish' : 'Next',
                  style: IOSTheme.headline.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionTile(String option, String correctAnswer) {
    final isSelected = option == _selectedAnswer;
    final isCorrect = option == correctAnswer;

    Color background = Colors.white.withOpacity(0.05);
    Color border = Colors.white.withOpacity(0.08);
    if (_selectedAnswer != null) {
      if (isCorrect) {
        background = IOSTheme.systemBlue.withOpacity(0.25);
        border = IOSTheme.systemBlue.withOpacity(0.6);
      } else if (isSelected) {
        background = Colors.redAccent.withOpacity(0.25);
        border = Colors.redAccent.withOpacity(0.6);
      }
    } else if (isSelected) {
      background = IOSTheme.systemBlue.withOpacity(0.2);
      border = IOSTheme.systemBlue.withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: ListTile(
        onTap: () => _selectAnswer(option),
        title: Text(
          option,
          style: IOSTheme.body.copyWith(color: Colors.white),
        ),
        trailing: _selectedAnswer == null
            ? null
            : Icon(
                isCorrect
                    ? CupertinoIcons.check_mark_circled_solid
                    : isSelected
                        ? CupertinoIcons.xmark_circle_fill
                        : CupertinoIcons.circle,
                color: isCorrect
                    ? IOSTheme.systemBlue
                    : isSelected
                        ? Colors.redAccent
                        : Colors.white24,
              ),
      ),
    );
  }

  Widget _buildResults() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.star_fill, color: IOSTheme.systemBlue, size: 28),
          const SizedBox(height: 12),
          Text(
            'Quiz Complete',
            style: IOSTheme.title3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'You scored $_score out of ${_questions.length}.',
            style: IOSTheme.body.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: IOSTheme.systemBlue,
            onPressed: () {
              setState(() {
                _currentIndex = 0;
                _score = 0;
                _selectedAnswer = null;
                _showResults = false;
              });
            },
            child: const Text('Retry Quiz'),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: Colors.white24,
            onPressed: _resetQuiz,
            child: const Text('Choose Another Movie'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: IOSTheme.systemBlue, size: 28),
          const SizedBox(height: 12),
          Text(title, style: IOSTheme.title3.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            message,
            style: IOSTheme.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
