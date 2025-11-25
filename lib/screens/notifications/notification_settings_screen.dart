import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_back_button.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  bool _isLoading = true;
  bool _pushNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = true;
  bool _chatEnabled = true;
  bool _sessionEnabled = true;
  bool _paymentEnabled = true;
  bool _pointsEnabled = true;
  bool _ratingEnabled = true;
  bool _marketingEnabled = false;
  bool _systemEnabled = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await _notificationService.getPreferences();
      if (prefs != null && mounted) {
        setState(() {
          _pushNotificationsEnabled = prefs['push_notifications_enabled'] ?? true;
          _inAppNotificationsEnabled = prefs['in_app_notifications_enabled'] ?? true;
          _chatEnabled = prefs['chat_enabled'] ?? true;
          _sessionEnabled = prefs['session_enabled'] ?? true;
          _paymentEnabled = prefs['payment_enabled'] ?? true;
          _pointsEnabled = prefs['points_enabled'] ?? true;
          _ratingEnabled = prefs['rating_enabled'] ?? true;
          _marketingEnabled = prefs['marketing_enabled'] ?? false;
          _systemEnabled = prefs['system_enabled'] ?? true;
          _quietHoursEnabled = prefs['quiet_hours_enabled'] ?? false;
          
          if (prefs['quiet_hours_start'] != null) {
            final start = TimeOfDay.fromDateTime(DateTime.parse('2000-01-01 ${prefs['quiet_hours_start']}'));
            _quietHoursStart = start;
          }
          if (prefs['quiet_hours_end'] != null) {
            final end = TimeOfDay.fromDateTime(DateTime.parse('2000-01-01 ${prefs['quiet_hours_end']}'));
            _quietHoursEnd = end;
          }
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    final preferences = {
      'push_notifications_enabled': _pushNotificationsEnabled,
      'in_app_notifications_enabled': _inAppNotificationsEnabled,
      'chat_enabled': _chatEnabled,
      'session_enabled': _sessionEnabled,
      'payment_enabled': _paymentEnabled,
      'points_enabled': _pointsEnabled,
      'rating_enabled': _ratingEnabled,
      'marketing_enabled': _marketingEnabled,
      'system_enabled': _systemEnabled,
      'quiet_hours_enabled': _quietHoursEnabled,
      'quiet_hours_start': '${_quietHoursStart.hour.toString().padLeft(2, '0')}:${_quietHoursStart.minute.toString().padLeft(2, '0')}:00',
      'quiet_hours_end': '${_quietHoursEnd.hour.toString().padLeft(2, '0')}:${_quietHoursEnd.minute.toString().padLeft(2, '0')}:00',
    };

    final success = await _notificationService.updatePreferences(preferences);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Settings saved' : 'Failed to save settings'),
          backgroundColor: success ? AppColors.primary : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietHoursStart : _quietHoursEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _quietHoursStart = picked;
        } else {
          _quietHoursEnd = picked;
        }
      });
      await _savePreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CustomBackButton(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'NOTIFICATION SETTINGS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 45),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Settings List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildSection('General'),
                        _buildToggleTile(
                          'Push Notifications',
                          'Receive notifications even when app is closed',
                          FontAwesomeIcons.bell,
                          _pushNotificationsEnabled,
                          (value) {
                            setState(() => _pushNotificationsEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'In-App Notifications',
                          'Show notifications while using the app',
                          FontAwesomeIcons.bellConcierge,
                          _inAppNotificationsEnabled,
                          (value) {
                            setState(() => _inAppNotificationsEnabled = value);
                            _savePreferences();
                          },
                        ),

                        const SizedBox(height: 20),
                        _buildSection('Notification Categories'),
                        _buildToggleTile(
                          'Chat Messages',
                          'Get push notifications about new messages',
                          FontAwesomeIcons.message,
                          _chatEnabled,
                          (value) {
                            setState(() => _chatEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'Sessions & Classes',
                          'Reminders and updates about your sessions',
                          FontAwesomeIcons.graduationCap,
                          _sessionEnabled,
                          (value) {
                            setState(() => _sessionEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'Payments & Subscriptions',
                          'Updates about payments and subscription status',
                          FontAwesomeIcons.creditCard,
                          _paymentEnabled,
                          (value) {
                            setState(() => _paymentEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'Points & Rewards',
                          'Get notified when you earn points',
                          FontAwesomeIcons.star,
                          _pointsEnabled,
                          (value) {
                            setState(() => _pointsEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'Ratings',
                          'Reminders to rate your teachers',
                          FontAwesomeIcons.starHalfStroke,
                          _ratingEnabled,
                          (value) {
                            setState(() => _ratingEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'Marketing & Promotions',
                          'Special offers and new features',
                          FontAwesomeIcons.gift,
                          _marketingEnabled,
                          (value) {
                            setState(() => _marketingEnabled = value);
                            _savePreferences();
                          },
                        ),
                        _buildToggleTile(
                          'System Notifications',
                          'Important system updates and announcements',
                          FontAwesomeIcons.circleInfo,
                          _systemEnabled,
                          (value) {
                            setState(() => _systemEnabled = value);
                            _savePreferences();
                          },
                        ),

                        const SizedBox(height: 20),
                        _buildSection('Quiet Hours'),
                        _buildToggleTile(
                          'Enable Quiet Hours',
                          'Mute notifications during specific hours',
                          FontAwesomeIcons.moon,
                          _quietHoursEnabled,
                          (value) {
                            setState(() => _quietHoursEnabled = value);
                            _savePreferences();
                          },
                        ),

                        if (_quietHoursEnabled) ...[
                          _buildTimeTile(
                            'Start Time',
                            _quietHoursStart,
                            () => _selectTime(true),
                          ),
                          _buildTimeTile(
                            'End Time',
                            _quietHoursEnd,
                            () => _selectTime(false),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.blueGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: FaIcon(
                icon,
                color: AppColors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.clock,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                time.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const FaIcon(
                FontAwesomeIcons.chevronRight,
                color: AppColors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

