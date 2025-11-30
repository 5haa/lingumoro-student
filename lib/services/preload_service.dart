import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/language_service.dart';
import 'package:student/services/carousel_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/photo_service.dart';
import 'package:student/services/student_service.dart';
import 'package:student/services/blocking_service.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/session_service.dart';
import 'package:student/services/practice_service.dart';
import 'package:student/services/quiz_practice_service.dart';
import 'package:student/services/ai_story_service.dart';
import 'package:student/services/rating_service.dart';

/// Helper class to cache teachers data with timestamp and ratings
class _CachedTeachers {
  final List<Map<String, dynamic>> teachers;
  final Map<String, Map<String, dynamic>> ratings;
  final DateTime timestamp;

  _CachedTeachers({
    required this.teachers,
    required this.ratings,
    required this.timestamp,
  });

  bool get isStale => DateTime.now().difference(timestamp).inMinutes > 5;
}

/// Service to preload and cache all app data
class PreloadService {
  final _languageService = LanguageService();
  final _carouselService = CarouselService();
  final _authService = AuthService();
  final _levelService = LevelService();
  final _proService = ProSubscriptionService();
  final _photoService = PhotoService();
  final _studentService = StudentService();
  final _blockingService = BlockingService();
  final _chatService = ChatService();
  final _sessionService = SessionService();
  final _practiceService = PracticeService();
  final _quizService = QuizPracticeService();
  final _aiStoryService = AIStoryService();
  final _ratingService = RatingService();

  // Cached data - Basic
  List<Map<String, dynamic>>? _languages;
  List<Map<String, dynamic>>? _carouselSlides;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _levelProgress;
  Map<String, dynamic>? _proSubscription;
  Map<String, dynamic>? _mainPhoto;
  List<String>? _enrolledLanguages;
  Set<String>? _blockedUserIds;

  // Cached data - Teachers (keyed by languageId)
  final Map<String, _CachedTeachers> _teachersCache = {};

  // Cached data - Students
  List<Map<String, dynamic>>? _students;
  DateTime? _studentsTimestamp;

  // Cached data - Chat
  List<Map<String, dynamic>>? _conversations;
  List<Map<String, dynamic>>? _availableTeachers;
  List<Map<String, dynamic>>? _pendingChatRequests;
  DateTime? _chatTimestamp;

  // Cached data - Chat Messages (keyed by conversationId)
  final Map<String, List<Map<String, dynamic>>> _messagesCache = {};

  // Cached data - Classes
  List<Map<String, dynamic>>? _upcomingSessions;
  List<Map<String, dynamic>>? _finishedSessions;
  DateTime? _sessionsTimestamp;

  // Cached data - Practice
  List<Map<String, dynamic>>? _practiceVideos;
  Map<String, bool>? _watchedVideos;
  Map<String, dynamic>? _quizStats;
  int? _completedReadings;
  int? _totalReadings;
  DateTime? _practiceTimestamp;

  // Singleton pattern
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal();

  /// Preload all data for logged-in users
  Future<void> preloadData({required bool isLoggedIn, BuildContext? context}) async {
    try {
      final List<Future> tasks = [];
      
      // Futures for data loading
      Future? languagesFuture;
      Future? carouselFuture;
      Future? userDataFuture;
      
      // 1. Start data loading tasks
      if (isLoggedIn) {
        languagesFuture = _loadLanguages();
        carouselFuture = _loadCarousel();
        userDataFuture = _loadUserData(); // Loads profile, level, pro, photo, enrolled langs, blocked
        tasks.addAll([languagesFuture, carouselFuture, userDataFuture]);
      } else {
        languagesFuture = _loadLanguages();
        carouselFuture = _loadCarousel();
        tasks.addAll([languagesFuture, carouselFuture]);
      }
      
      // 2. Start image precaching task in parallel
      if (context != null && context.mounted) {
        tasks.add(_precacheImages(
          context, 
          isLoggedIn: isLoggedIn,
          languagesFuture: languagesFuture,
          carouselFuture: carouselFuture,
          userDataFuture: userDataFuture,
        ));
      } else {
        print('⚠️ Context not mounted or null, skipping image precaching');
      }
      
      // Wait for everything to finish
      await Future.wait(tasks);
      
      print('✅ Preloading completed successfully');
    } catch (e) {
      print('❌ Error during preloading: $e');
      // Don't throw - allow app to continue even if preload fails
    }
  }

  /// Precache images to prevent loading flash
  Future<void> _precacheImages(
    BuildContext context, {
    required bool isLoggedIn,
    Future? languagesFuture,
    Future? carouselFuture,
    Future? userDataFuture,
  }) async {
    if (!context.mounted) return;
    
    try {
      final List<Future> imageFutures = [];
      print('🖼️ Starting image precaching...');
      
      // 1. IMMEDIATE: Precache asset images (logo, student and teacher cards)
      // We use const AssetImage to ensure the cache key matches the const provider in HomeScreen
      imageFutures.add(
        precacheImage(const AssetImage('assets/images/logo.jpg'), context)
          .then((_) => print('  ✅ Cached logo.jpg'))
          .catchError((e) => print('  ❌ Failed to precache logo.jpg: $e'))
      );
      imageFutures.add(
        precacheImage(const AssetImage('assets/images/student.jpg'), context)
          .then((_) => print('  ✅ Cached student.jpg'))
          .catchError((e) => print('  ❌ Failed to precache student.jpg: $e'))
      );
      imageFutures.add(
        precacheImage(const AssetImage('assets/images/teacher.jpg'), context)
          .then((_) => print('  ✅ Cached teacher.jpg'))
          .catchError((e) => print('  ❌ Failed to precache teacher.jpg: $e'))
      );

      // 2. DELAYED: Precache network images (wait for data to load)
      
      // Carousel Images
      if (carouselFuture != null) {
        imageFutures.add(carouselFuture.then((_) {
          if (_carouselSlides != null && context.mounted) {
            final futures = <Future>[];
            for (var slide in _carouselSlides!) {
              final imageUrl = slide['image_url'] as String?;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                futures.add(precacheImage(CachedNetworkImageProvider(imageUrl), context)
                    .catchError((e) => print('  ❌ Failed to precache carousel: $e')));
              }
            }
            return Future.wait(futures);
          }
        }));
      }

      // Language Flags
      if (languagesFuture != null) {
        imageFutures.add(languagesFuture.then((_) {
          if (_languages != null && context.mounted) {
            final futures = <Future>[];
            for (var language in _languages!) {
              final flagUrl = language['flag_url'] as String?;
              if (flagUrl != null && flagUrl.isNotEmpty) {
                futures.add(precacheImage(CachedNetworkImageProvider(flagUrl), context)
                    .catchError((e) => print('  ❌ Failed to precache flag: $e')));
              }
            }
            return Future.wait(futures);
          }
        }));
      }

      // User Profile Images
      if (userDataFuture != null && isLoggedIn) {
        imageFutures.add(userDataFuture.then((_) {
          if (context.mounted) {
            final futures = <Future>[];
            final avatarUrl = _profile?['avatar_url'] as String?;
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              futures.add(precacheImage(CachedNetworkImageProvider(avatarUrl), context)
                  .catchError((e) => print('  ❌ Failed to precache avatar: $e')));
            }
            final mainPhotoUrl = _mainPhoto?['photo_url'] as String?;
            if (mainPhotoUrl != null && mainPhotoUrl.isNotEmpty) {
              futures.add(precacheImage(CachedNetworkImageProvider(mainPhotoUrl), context)
                  .catchError((e) => print('  ❌ Failed to precache main photo: $e')));
            }
            return Future.wait(futures);
          }
        }));
      }
      
      // Wait for all precaching (including the chained network ones)
      await Future.wait(imageFutures);
      print('✅ All image precaching tasks finished');
    } catch (e) {
      print('❌ Error precaching images: $e');
    }
  }

  Future<void> _loadLanguages() async {
    try {
      _languages = await _languageService.getActiveLanguages();
      print('✅ Preloaded ${_languages?.length ?? 0} languages');
    } catch (e) {
      print('❌ Failed to preload languages: $e');
      _languages = [];
    }
  }

  Future<void> _loadCarousel() async {
    try {
      _carouselSlides = await _carouselService.getActiveSlides();
      print('✅ Preloaded ${_carouselSlides?.length ?? 0} carousel slides');
    } catch (e) {
      print('❌ Failed to preload carousel: $e');
      _carouselSlides = [];
    }
  }

  Future<void> _loadUserData() async {
    try {
      final studentId = _authService.currentUser?.id;
      if (studentId == null) return;

      // Load user-specific data in parallel
      final results = await Future.wait([
        _authService.getStudentProfile(),
        _levelService.getStudentProgress(studentId),
        _proService.getProStatus(studentId),
        _photoService.getMainPhoto(studentId),
        _studentService.getStudentLanguages(),
        _blockingService.getBlockedUserIds(),
        _blockingService.getUsersWhoBlockedMe(),
        _proService.validateAndUpdateDeviceSession(studentId), // ADDED: Validate device session
      ]);

      _profile = results[0] as Map<String, dynamic>?;
      _levelProgress = results[1] as Map<String, dynamic>?;
      _proSubscription = results[2] as Map<String, dynamic>?;
      _mainPhoto = results[3] as Map<String, dynamic>?;
      _enrolledLanguages = results[4] as List<String>?;
      
      final blocked = results[5] as Set<String>;
      final blockers = results[6] as Set<String>;
      _blockedUserIds = {...blocked, ...blockers};
      
      // Device session info is in results[7]
      final deviceSession = results[7] as Map<String, dynamic>?;
      
      // Update pro subscription to include device session validity
      if (_proSubscription != null && deviceSession != null) {
        _proSubscription!['device_session_valid'] = deviceSession['is_valid'] == true;
      }

      print('✅ Preloaded user profile data (including subscriptions & device session & blocks)');
    } catch (e) {
      print('❌ Failed to preload user data: $e');
    }
  }

  // Getters for cached data
  List<Map<String, dynamic>>? get languages => _languages;
  List<Map<String, dynamic>>? get carouselSlides => _carouselSlides;
  Map<String, dynamic>? get profile => _profile;
  Map<String, dynamic>? get levelProgress => _levelProgress;
  Map<String, dynamic>? get proSubscription => _proSubscription;
  Map<String, dynamic>? get mainPhoto => _mainPhoto;
  List<String>? get enrolledLanguages => _enrolledLanguages;
  Set<String>? get blockedUserIds => _blockedUserIds;

  // Check if data is loaded
  bool get hasLanguages => _languages != null;
  bool get hasCarousel => _carouselSlides != null;
  bool get hasUserData => _profile != null;
  bool get hasEnrolledLanguages => _enrolledLanguages != null;

  /// Clear all cached data (useful for logout)
  void clearCache() {
    _languages = null;
    _carouselSlides = null;
    _profile = null;
    _levelProgress = null;
    _proSubscription = null;
    _mainPhoto = null;
    _enrolledLanguages = null;
    _blockedUserIds = null;
    _teachersCache.clear();
    _students = null;
    _studentsTimestamp = null;
    _conversations = null;
    _availableTeachers = null;
    _pendingChatRequests = null;
    _chatTimestamp = null;
    _messagesCache.clear();
    _upcomingSessions = null;
    _finishedSessions = null;
    _sessionsTimestamp = null;
    _practiceVideos = null;
    _watchedVideos = null;
    _quizStats = null;
    _completedReadings = null;
    _totalReadings = null;
    _practiceTimestamp = null;
    print('🧹 All caches cleared');
  }

  /// Refresh user data (call this after profile updates)
  Future<void> refreshUserData() async {
    try {
      final studentId = _authService.currentUser?.id;
      if (studentId == null) return;

      await _loadUserData();
      print('🔄 User data refreshed');
    } catch (e) {
      print('❌ Failed to refresh user data: $e');
    }
  }

  // ========== TEACHERS CACHE ==========
  
  /// Get cached teachers for a language
  ({List<Map<String, dynamic>> teachers, Map<String, Map<String, dynamic>> ratings})? getTeachers(String languageId) {
    final cached = _teachersCache[languageId];
    if (cached == null || cached.isStale) return null;
    return (teachers: cached.teachers, ratings: cached.ratings);
  }

  /// Cache teachers for a language
  Future<void> cacheTeachers(String languageId, List<Map<String, dynamic>> teachers, Map<String, Map<String, dynamic>> ratings) async {
    _teachersCache[languageId] = _CachedTeachers(
      teachers: teachers,
      ratings: ratings,
      timestamp: DateTime.now(),
    );
    print('📦 Cached ${teachers.length} teachers for language $languageId');
  }

  /// Invalidate teachers cache for a specific language
  void invalidateTeachers(String languageId) {
    _teachersCache.remove(languageId);
    print('🗑️ Invalidated teachers cache for $languageId');
  }

  // ========== STUDENTS CACHE ==========
  
  /// Get cached students list
  List<Map<String, dynamic>>? get students {
    if (_students == null || _studentsTimestamp == null) return null;
    // Students cache is valid as long as enrollment hasn't changed
    return _students;
  }

  /// Cache students list
  void cacheStudents(List<Map<String, dynamic>> students) {
    _students = students;
    _studentsTimestamp = DateTime.now();
    print('📦 Cached ${students.length} students');
  }

  /// Invalidate students cache (call when enrollment changes)
  void invalidateStudents() {
    _students = null;
    _studentsTimestamp = null;
    print('🗑️ Invalidated students cache');
  }

  /// Check if students cache should be invalidated (enrollment changed)
  bool shouldInvalidateStudents(List<String> currentEnrollment) {
    if (_enrolledLanguages == null) return true;
    if (_enrolledLanguages!.length != currentEnrollment.length) return true;
    return !_enrolledLanguages!.toSet().containsAll(currentEnrollment);
  }

  // ========== CHAT CACHE ==========
  
  /// Get cached chat data
  ({
    List<Map<String, dynamic>> conversations,
    List<Map<String, dynamic>> teachers,
    List<Map<String, dynamic>> requests
  })? get chatData {
    if (_conversations == null || _chatTimestamp == null) return null;
    // Chat stays valid - refresh only via real-time updates or manual refresh
    return (
      conversations: _conversations!,
      teachers: _availableTeachers ?? [],
      requests: _pendingChatRequests ?? []
    );
  }

  /// Cache chat data
  void cacheChat({
    required List<Map<String, dynamic>> conversations,
    required List<Map<String, dynamic>> teachers,
    required List<Map<String, dynamic>> requests,
  }) {
    _conversations = conversations;
    _availableTeachers = teachers;
    _pendingChatRequests = requests;
    _chatTimestamp = DateTime.now();
    print('📦 Cached ${conversations.length} conversations, ${teachers.length} teachers, ${requests.length} requests');
  }

  /// Invalidate chat cache (call when chat data changes)
  void invalidateChat() {
    _conversations = null;
    _availableTeachers = null;
    _pendingChatRequests = null;
    _chatTimestamp = null;
    print('🗑️ Invalidated chat cache');
  }

  // ========== CHAT MESSAGES CACHE ==========
  
  /// Get cached messages for a conversation
  List<Map<String, dynamic>>? getMessages(String conversationId) {
    return _messagesCache[conversationId];
  }

  /// Cache messages for a conversation
  void cacheMessages(String conversationId, List<Map<String, dynamic>> messages) {
    _messagesCache[conversationId] = messages;
    print('📦 Cached ${messages.length} messages for conversation $conversationId');
  }

  /// Update a single message in cache (for real-time updates)
  void addMessageToCache(String conversationId, Map<String, dynamic> message) {
    if (_messagesCache[conversationId] != null) {
      // Check if message already exists
      final exists = _messagesCache[conversationId]!.any((m) => m['id'] == message['id']);
      if (!exists) {
        _messagesCache[conversationId]!.add(message);
      }
    }
  }

  /// Invalidate messages cache for a specific conversation
  void invalidateMessages(String conversationId) {
    _messagesCache.remove(conversationId);
    print('🗑️ Invalidated messages cache for $conversationId');
  }

  // ========== CLASSES/SESSIONS CACHE ==========
  
  /// Get cached sessions
  ({List<Map<String, dynamic>> upcoming, List<Map<String, dynamic>> finished})? get sessions {
    if (_upcomingSessions == null || _sessionsTimestamp == null) return null;
    // Sessions stay valid - refresh via real-time updates or manual refresh
    return (upcoming: _upcomingSessions!, finished: _finishedSessions ?? []);
  }

  /// Cache sessions
  void cacheSessions({
    required List<Map<String, dynamic>> upcoming,
    required List<Map<String, dynamic>> finished,
  }) {
    _upcomingSessions = upcoming;
    _finishedSessions = finished;
    _sessionsTimestamp = DateTime.now();
    print('📦 Cached ${upcoming.length} upcoming and ${finished.length} finished sessions');
  }

  /// Invalidate sessions cache
  void invalidateSessions() {
    _upcomingSessions = null;
    _finishedSessions = null;
    _sessionsTimestamp = null;
    print('🗑️ Invalidated sessions cache');
  }

  // ========== PRACTICE CACHE ==========
  
  /// Get cached practice data
  ({
    List<Map<String, dynamic>> videos,
    Map<String, bool> watchedVideos,
    Map<String, dynamic> quizStats,
    int? completedReadings,
    int? totalReadings
  })? get practiceData {
    if (_practiceVideos == null || _practiceTimestamp == null) return null;
    return (
      videos: _practiceVideos!,
      watchedVideos: _watchedVideos ?? {},
      quizStats: _quizStats ?? {},
      completedReadings: _completedReadings ?? 0,
      totalReadings: _totalReadings ?? 0
    );
  }

  /// Cache practice data
  void cachePractice({
    required List<Map<String, dynamic>> videos,
    required Map<String, bool> watchedVideos,
    required Map<String, dynamic> quizStats,
    int? completedReadings,
    int? totalReadings,
  }) {
    _practiceVideos = videos;
    _watchedVideos = watchedVideos;
    _quizStats = quizStats;
    _completedReadings = completedReadings;
    _totalReadings = totalReadings;
    _practiceTimestamp = DateTime.now();
    print('📦 Cached ${videos.length} practice videos and stats');
  }

  /// Invalidate practice cache (call when user completes activity)
  void invalidatePractice() {
    _practiceVideos = null;
    _watchedVideos = null;
    _quizStats = null;
    _completedReadings = null;
    _totalReadings = null;
    _practiceTimestamp = null;
    print('🗑️ Invalidated practice cache');
  }
}

