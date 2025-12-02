import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/reading_service.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/screens/practice/reading_detail_screen.dart';
import '../../widgets/custom_back_button.dart';
import '../../l10n/app_localizations.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _readingService = ReadingService();
  final _authService = AuthService();
  final _proService = ProSubscriptionService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _readings = [];
  Map<String, bool> _progressMap = {};
  int _completedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _checkProAndLoadData();
  }
  
  Future<void> _checkProAndLoadData() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) {
      Navigator.pop(context);
      return;
    }

    // Check device session validity
    final result = await _proService.validateAndUpdateDeviceSession(
      studentId,
      forceClaim: false,
    );

    if (result['is_valid'] != true) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).proFeaturesActiveOnAnotherDevice),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // If valid, load data
    _loadData();
  }

  Future<void> _loadData() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    setState(() => _isLoading = true);

    try {
      final readings = await _readingService.getAllReadings();
      final progressMap = await _readingService.getStudentProgress(studentId);
      final completedCount = await _readingService.getCompletedCount(studentId);
      final totalCount = await _readingService.getTotalReadingsCount();

      setState(() {
        _readings = readings;
        _progressMap = progressMap;
        _completedCount = completedCount;
        _totalCount = totalCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorLoadingReadings} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _isReadingUnlocked(Map<String, dynamic> reading) async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return false;

    return await _readingService.isReadingUnlocked(
      studentId,
      reading,
      _readings,
      _progressMap,
    );
  }

  void _openReading(Map<String, dynamic> reading) async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    // Check if unlocked
    final isUnlocked = await _isReadingUnlocked(reading);
    
    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).completePreviousReading),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to reading detail
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingDetailScreen(
          reading: reading,
          studentId: studentId,
        ),
      ),
    );

    // Reload data if completed
    if (result == true) {
      _loadData();
    }
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
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : _readings.isEmpty
                        ? _buildEmptyState()
                        : _buildReadingsList(),
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
          Expanded(
            child: Center(
              child: Text(
                AppLocalizations.of(context).readings,
                style: const TextStyle(
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

  Widget _buildReadingsList() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressCard(),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).allReadings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...(_readings.asMap().entries.map((entry) {
            return _buildReadingCard(entry.value, entry.key);
          })),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final l10n = AppLocalizations.of(context);
    final percentage = _totalCount > 0 
        ? (_completedCount / _totalCount * 100).toInt() 
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const FaIcon(
              FontAwesomeIcons.book,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.yourProgress,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_completedCount / $_totalCount ${l10n.completed}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalCount > 0 ? _completedCount / _totalCount : 0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$percentage% ${l10n.percentComplete}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCard(Map<String, dynamic> reading, int index) {
    final isCompleted = _progressMap[reading['id']] ?? false;
    final hasAudio = reading['audio_url'] != null && reading['audio_url'].toString().isNotEmpty;

    return FutureBuilder<bool>(
      future: _isReadingUnlocked(reading),
      builder: (context, snapshot) {
        final isUnlocked = snapshot.data ?? false;
        final isLocked = !isUnlocked && !isCompleted;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            border: isCompleted
                ? Border.all(color: Colors.green.shade300, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLocked ? null : () => _openReading(reading),
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Order badge or status icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade400
                            : isLocked
                                ? AppColors.grey.withOpacity(0.3)
                                : Colors.blue.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const FaIcon(
                                FontAwesomeIcons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : isLocked
                                ? const FaIcon(
                                    FontAwesomeIcons.lock,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text(
                                    '${reading['order'] + 1}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reading['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isLocked
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (hasAudio) ...[
                                FaIcon(
                                  FontAwesomeIcons.volumeHigh,
                                  size: 12,
                                  color: isLocked
                                      ? AppColors.textSecondary
                                      : Colors.blue.shade600,
                                ),
                                const SizedBox(width: 6),
                              ],
                              FaIcon(
                                FontAwesomeIcons.coins,
                                size: 12,
                                color: isLocked
                                    ? AppColors.textSecondary
                                    : Colors.amber.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${reading['points']} pts',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isLocked
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (isLocked) ...[
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context).completePreviousToUnlock,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          AppLocalizations.of(context).completed,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )
                    else if (!isLocked)
                      const FaIcon(
                        FontAwesomeIcons.chevronRight,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.bookOpen,
                size: 50,
                color: AppColors.grey.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).noReadingsAvailable,
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textSecondary.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).checkBackLater,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
