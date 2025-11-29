import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/config/app_colors.dart';
import 'package:student/widgets/app_drawer.dart';
import 'package:student/l10n/app_localizations.dart';
import 'package:student/services/chat_service.dart';
import 'package:student/services/points_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home/home_screen.dart';
import 'classes/classes_screen.dart';
import 'practice/practice_screen.dart';
import 'chat/chat_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _unreadMessageCount = 0;
  final _chatService = ChatService();
  final _pointsNotificationService = PointsNotificationService();
  RealtimeChannel? _conversationChannel;
  
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const ClassesScreen(),
      const PracticeScreen(),
      const ChatScreen(),
      const ProfileScreen(),
    ];
    _loadUnreadCount();
    _setupRealtimeListener();
    
    // Setup points subscription after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPointsSubscription();
    });
  }

  void _setupPointsSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && mounted) {
      // Subscribe to real-time points updates
      _pointsNotificationService.subscribeToPointsUpdates(userId, context);
      print('✅ Subscribed to points updates for user: $userId');
    }
  }

  @override
  void dispose() {
    _conversationChannel?.unsubscribe();
    _pointsNotificationService.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Get conversations where student is the primary participant
      final result1 = await Supabase.instance.client
          .from('chat_conversations')
          .select('student_unread_count')
          .eq('student_id', userId);

      // Get conversations where student is participant2 (student-to-student chats)
      // In this case, their unread count is stored in teacher_unread_count
      final result2 = await Supabase.instance.client
          .from('chat_conversations')
          .select('teacher_unread_count')
          .eq('participant2_id', userId);

      int totalUnread = 0;
      for (var conv in result1) {
        totalUnread += (conv['student_unread_count'] as int?) ?? 0;
      }
      for (var conv in result2) {
        // For participant2, unread count is stored in teacher_unread_count
        totalUnread += (conv['teacher_unread_count'] as int?) ?? 0;
      }

      if (mounted) {
        setState(() {
          _unreadMessageCount = totalUnread;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  void _setupRealtimeListener() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _conversationChannel = Supabase.instance.client
        .channel('unread-messages-$userId')
        // Listen for updates where student is the primary participant
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: userId,
          ),
          callback: (payload) {
            _loadUnreadCount();
          },
        )
        // Listen for inserts where student is the primary participant
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: userId,
          ),
          callback: (payload) {
            _loadUnreadCount();
          },
        )
        // Listen for updates where student is participant2 (student-to-student chats)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant2_id',
            value: userId,
          ),
          callback: (payload) {
            _loadUnreadCount();
          },
        )
        // Listen for inserts where student is participant2 (student-to-student chats)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant2_id',
            value: userId,
          ),
          callback: (payload) {
            _loadUnreadCount();
          },
        )
        .subscribe();
  }
  
  List<Map<String, dynamic>> _getNavItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      {
        'icon': FontAwesomeIcons.house,
        'label': l10n.navHome,
      },
      {
        'icon': FontAwesomeIcons.graduationCap,
        'label': l10n.navClasses,
      },
      {
        'icon': FontAwesomeIcons.clipboardList,
        'label': l10n.navPractice,
      },
      {
        'icon': FontAwesomeIcons.message,
        'label': l10n.navChat,
      },
      {
        'icon': FontAwesomeIcons.user,
        'label': l10n.navProfile,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_getNavItems(context).length, (index) {
                final navItems = _getNavItems(context);
                return _buildNavItem(
                  navItems[index]['icon'],
                  navItems[index]['label'],
                  index,
                  _currentIndex == index,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(IconData icon, String label, int index, bool isActive) {
    // Check if this is the chat tab (index 3) and has unread messages
    final bool showBadge = index == 3 && _unreadMessageCount > 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isActive ? AppColors.redGradient : null,
                  color: isActive ? null : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  icon,
                  color: isActive ? AppColors.white : AppColors.grey,
                  size: 20,
                ),
              ),
              if (showBadge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? AppColors.primary : AppColors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
