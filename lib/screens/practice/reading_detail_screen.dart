import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:student/services/reading_service.dart';
import 'package:student/config/app_colors.dart';
import '../../widgets/custom_back_button.dart';

class ReadingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> reading;
  final String studentId;

  const ReadingDetailScreen({
    super.key,
    required this.reading,
    required this.studentId,
  });

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  final _readingService = ReadingService();
  final _audioPlayer = AudioPlayer();
  
  bool _isLoadingQuestions = true;
  List<Map<String, dynamic>> _questions = [];
  List<int?> _selectedAnswers = [];
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  Map<String, dynamic>? _results;
  
  // Audio player state
  bool _isPlayingAudio = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    final audioUrl = widget.reading['audio_url'];
    if (audioUrl != null && audioUrl.toString().isNotEmpty) {
      _audioPlayer.setUrl(audioUrl);
      
      _audioPlayer.playerStateStream.listen((state) {
        setState(() {
          _isPlayingAudio = state.playing;
        });
      });

      _audioPlayer.durationStream.listen((duration) {
        setState(() {
          _audioDuration = duration ?? Duration.zero;
        });
      });

      _audioPlayer.positionStream.listen((position) {
        setState(() {
          _audioPosition = position;
        });
      });
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoadingQuestions = true);

    try {
      final questions = await _readingService.getQuestionsForReading(
        widget.reading['id'],
      );

      setState(() {
        _questions = questions;
        _selectedAnswers = List.filled(questions.length, null);
        _isLoadingQuestions = false;
      });
    } catch (e) {
      setState(() => _isLoadingQuestions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading questions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleAudioPlayback() {
    if (_isPlayingAudio) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _seekAudio(double value) {
    final position = Duration(seconds: value.toInt());
    _audioPlayer.seek(position);
  }

  Future<void> _submitAnswers() async {
    // Check if all questions are answered
    if (_selectedAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final results = await _readingService.submitAnswers(
        widget.studentId,
        widget.reading['id'],
        _selectedAnswers.cast<int>(),
        _questions,
        widget.reading['points'],
      );

      setState(() {
        _results = results;
        _hasSubmitted = true;
        _isSubmitting = false;
      });

      // Show results dialog
      _showResultsDialog();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting answers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResultsDialog() {
    if (_results == null) return;

    final score = _results!['score'] as int;
    final total = _results!['total'] as int;
    final allCorrect = _results!['allCorrect'] as bool;
    final pointsAwarded = _results!['pointsAwarded'] as int;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            FaIcon(
              allCorrect ? FontAwesomeIcons.trophy : FontAwesomeIcons.circleInfo,
              color: allCorrect ? Colors.amber.shade600 : Colors.blue.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              allCorrect ? 'Excellent!' : 'Try Again',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You got $score out of $total questions correct.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (allCorrect) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.coins,
                      color: Colors.amber.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '+$pointsAwarded points earned!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This reading is now complete. The next reading has been unlocked!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.circleExclamation,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You need to get all questions correct to earn points and unlock the next reading.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!allCorrect)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset for retry
                setState(() {
                  _selectedAnswers = List.filled(_questions.length, null);
                  _hasSubmitted = false;
                  _results = null;
                });
              },
              child: const Text('Try Again'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(allCorrect); // Return to list with completion status
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(allCorrect ? 'Continue' : 'Back to List'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReadingContent(),
                    const SizedBox(height: 24),
                    if (widget.reading['audio_url'] != null &&
                        widget.reading['audio_url'].toString().isNotEmpty)
                      _buildAudioPlayer(),
                    const SizedBox(height: 24),
                    _buildQuestionsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CustomBackButton(),
          const Expanded(
            child: Center(
              child: Text(
                'READING',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildReadingContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(
                  FontAwesomeIcons.book,
                  color: Colors.blue.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.reading['title'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.coins,
                          size: 12,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.reading['points']} points',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            widget.reading['content'],
            style: const TextStyle(
              fontSize: 16,
              height: 1.8,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.volumeHigh,
                color: Colors.blue.shade600,
                size: 18,
              ),
              const SizedBox(width: 12),
              const Text(
                'Listen to Reading',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: _toggleAudioPlayback,
                icon: FaIcon(
                  _isPlayingAudio
                      ? FontAwesomeIcons.pause
                      : FontAwesomeIcons.play,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: _audioPosition.inSeconds.toDouble(),
                      max: _audioDuration.inSeconds.toDouble(),
                      onChanged: _seekAudio,
                      activeColor: AppColors.primary,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_audioPosition),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatDuration(_audioDuration),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildQuestionsSection() {
    if (_isLoadingQuestions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text(
            'No questions available for this reading.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Answer the Questions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...(_questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(question, index);
        })),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting || _hasSubmitted ? null : _submitAnswers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit Answers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final options = List<String>.from(question['options']);
    final selectedAnswer = _selectedAnswers[index];
    final correctAnswer = question['correct_option_index'] as int;
    
    bool? isCorrect;
    if (_hasSubmitted && selectedAnswer != null) {
      isCorrect = selectedAnswer == correctAnswer;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: _hasSubmitted
            ? Border.all(
                color: isCorrect == true
                    ? Colors.green.shade300
                    : Colors.red.shade300,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question['question_text'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_hasSubmitted && isCorrect != null)
                FaIcon(
                  isCorrect
                      ? FontAwesomeIcons.circleCheck
                      : FontAwesomeIcons.circleXmark,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((optionEntry) {
            final optionIndex = optionEntry.key;
            final optionText = optionEntry.value;
            final isSelected = selectedAnswer == optionIndex;
            final isCorrectOption = _hasSubmitted && optionIndex == correctAnswer;
            
            return GestureDetector(
              onTap: _hasSubmitted
                  ? null
                  : () {
                      setState(() {
                        _selectedAnswers[index] = optionIndex;
                      });
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _hasSubmitted
                      ? isCorrectOption
                          ? Colors.green.shade50
                          : (isSelected && !isCorrectOption)
                              ? Colors.red.shade50
                              : AppColors.lightGrey
                      : isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasSubmitted
                        ? isCorrectOption
                            ? Colors.green.shade300
                            : (isSelected && !isCorrectOption)
                                ? Colors.red.shade300
                                : AppColors.border
                        : isSelected
                            ? AppColors.primary
                            : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasSubmitted
                            ? isCorrectOption
                                ? Colors.green
                                : (isSelected && !isCorrectOption)
                                    ? Colors.red
                                    : Colors.white
                            : isSelected
                                ? AppColors.primary
                                : Colors.white,
                        border: Border.all(
                          color: _hasSubmitted
                              ? isCorrectOption
                                  ? Colors.green
                                  : (isSelected && !isCorrectOption)
                                      ? Colors.red
                                      : AppColors.border
                              : isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: isSelected || isCorrectOption
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${String.fromCharCode(65 + optionIndex)}. $optionText',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

