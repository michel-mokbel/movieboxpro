import 'dart:ui';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
import '../models/quiz_question.dart';
import '../repositories/dashboard_repository.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import '../services/quiz_history_service.dart';
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
  bool _resultSaved = false;

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
      _resultSaved = false;
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

      final options = questions.map((question) => question.allOptions(random: _random)).toList();

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
      _saveQuizResult();
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
      _resultSaved = false;
    });
  }

  Future<void> _saveQuizResult() async {
    if (_resultSaved || _questions.isEmpty) return;
    _resultSaved = true;
    final title = _selectedMovie?['title']?.toString() ?? 'Random Pick';
    final poster = _selectedMovie?['poster']?.toString();
    await QuizHistoryService.addQuizResult(
      title: title,
      poster: poster,
      score: _score,
      total: _questions.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movie Quiz', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
                  const SizedBox(height: 6),
                  Text('Test your knowledge', style: BentoTheme.display),
                  const SizedBox(height: 20),
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: BentoTheme.backgroundGradient,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(color: Colors.transparent),
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
        BentoCard(
          padding: const EdgeInsets.all(6),
          borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
          child: CupertinoSegmentedControl<String>(
            groupValue: _source,
            borderColor: Colors.transparent,
            selectedColor: BentoTheme.accent.withOpacity(0.25),
            unselectedColor: Colors.transparent,
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
                child: Text('Favorites', style: BentoTheme.subtitle.copyWith(color: BentoTheme.textPrimary)),
              ),
              'trending': Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Trending', style: BentoTheme.subtitle.copyWith(color: BentoTheme.textPrimary)),
              ),
            },
          ),
        ),
        const SizedBox(height: 16),
        ...movies.map(_buildMovieTile).toList(),
      ],
    );
  }

  Widget _buildMovieTile(Map<String, dynamic> movie) {
    final poster = movie['poster']?.toString();
    final title = movie['title']?.toString() ?? 'Unknown title';
    final year = movie['year']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        onTap: () {
          setState(() {
            _selectedMovie = movie;
          });
          _startQuizForMovie(movie);
        },
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 50,
                height: 72,
                child: poster != null && poster.isNotEmpty
                    ? Image.network(poster, fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(gradient: BentoTheme.surfaceGradient),
                        child: const Icon(CupertinoIcons.film, color: Colors.white54),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BentoTheme.title.copyWith(color: Colors.white)),
                  if (year != null) ...[
                    const SizedBox(height: 4),
                    Text(year, style: BentoTheme.caption),
                  ],
                ],
              ),
            ),
            const Icon(CupertinoIcons.play_circle_fill, color: BentoTheme.accent, size: 24),
          ],
        ),
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
          Text(_selectedMovie?['title']?.toString() ?? '', style: BentoTheme.subtitle),
        const SizedBox(height: 8),
        Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: BentoTheme.caption,
        ),
        const SizedBox(height: 16),
        BentoCard(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
          child: Text(currentQuestion.question, style: BentoTheme.title.copyWith(color: Colors.white)),
        ),
        const SizedBox(height: 16),
        ...options.map((option) => _buildOptionTile(option, currentQuestion.correctAnswer)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                color: _selectedAnswer == null ? Colors.white24 : BentoTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: _selectedAnswer == null ? null : _nextQuestion,
                child: Text(
                  _currentIndex == _questions.length - 1 ? 'Finish' : 'Next',
                  style: BentoTheme.subtitle.copyWith(color: Colors.white),
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

    Color background = BentoTheme.surfaceAlt.withOpacity(0.8);
    Color border = BentoTheme.outline;
    if (_selectedAnswer != null) {
      if (isCorrect) {
        background = BentoTheme.accent.withOpacity(0.25);
        border = BentoTheme.accent.withOpacity(0.7);
      } else if (isSelected) {
        background = Colors.redAccent.withOpacity(0.25);
        border = Colors.redAccent.withOpacity(0.7);
      }
    } else if (isSelected) {
      background = BentoTheme.accent.withOpacity(0.2);
      border = BentoTheme.accent.withOpacity(0.5);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(BentoTheme.radiusMedium),
        color: background,
        border: Border.all(color: border),
        onTap: () => _selectAnswer(option),
        child: Row(
          children: [
            Expanded(
              child: Text(option, style: BentoTheme.body.copyWith(color: Colors.white)),
            ),
            if (_selectedAnswer != null)
              Icon(
                isCorrect
                    ? CupertinoIcons.check_mark_circled_solid
                    : isSelected
                        ? CupertinoIcons.xmark_circle_fill
                        : CupertinoIcons.circle,
                color: isCorrect
                    ? BentoTheme.accent
                    : isSelected
                        ? Colors.redAccent
                        : Colors.white24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return BentoCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.star_fill, color: BentoTheme.highlight, size: 28),
          const SizedBox(height: 12),
          Text('Quiz Complete', style: BentoTheme.title.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text('You scored $_score out of ${_questions.length}.', style: BentoTheme.body),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: BentoTheme.accent,
            onPressed: () {
              setState(() {
                _currentIndex = 0;
                _score = 0;
                _selectedAnswer = null;
                _showResults = false;
              });
            },
            child: Text(
              'Retry Quiz',
              style: BentoTheme.subtitle.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: Colors.white24,
            onPressed: _resetQuiz,
            child: Text(
              'Try Another Quiz',
              style: BentoTheme.subtitle.copyWith(color: Colors.white),
            ),
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
    return BentoCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BentoTheme.accent, size: 28),
          const SizedBox(height: 12),
          Text(title, style: BentoTheme.title.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(message, style: BentoTheme.body),
        ],
      ),
    );
  }
}
