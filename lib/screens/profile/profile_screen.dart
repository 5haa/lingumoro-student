import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:student/services/auth_service.dart';
import 'package:student/services/level_service.dart';
import 'package:student/services/pro_subscription_service.dart';
import 'package:student/services/photo_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:student/services/points_notification_service.dart';
import 'package:student/widgets/pro_upgrade_modal.dart';
import 'dart:async';
import 'package:student/screens/auth/auth_screen.dart';
import 'package:student/screens/auth/change_password_screen.dart';
import 'package:student/screens/profile/edit_profile_screen.dart';
import 'package:student/screens/profile/blocked_users_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/error_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  final _authService = AuthService();
  final _levelService = LevelService();
  final _proService = ProSubscriptionService();
  final _photoService = PhotoService();
  final _preloadService = PreloadService();
  final _pointsNotificationService = PointsNotificationService();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _levelProgress;
  Map<String, dynamic>? _proSubscription;
  Map<String, dynamic>? _deviceSessionInfo;
  Map<String, dynamic>? _mainPhoto;
  bool _isLoading = false;
  StreamSubscription? _pointsSubscription;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _loadProfileFromCache();
    _subscribeToPointsUpdates();
    // Force reload to get fresh device session info
    Future.microtask(() => _loadProfile());
  }

  void _subscribeToPointsUpdates() {
    final user = _authService.currentUser;
    if (user == null) return;
    
    // Subscribe to real-time points updates
    _pointsNotificationService.subscribeToPointsUpdates(user.id, context);
    
    // Listen to points updates
    _pointsSubscription = _pointsNotificationService.onPointsUpdate.listen((update) async {
      print('📊 Points update received in profile: ${update['pointsGained']} points');
      
      // Force refresh from API (bypass cache)
      await _preloadService.refreshUserData();
      
      // Reload profile to get fresh data
      if (mounted) {
        setState(() {
          _levelProgress = _preloadService.levelProgress;
          _profile = _preloadService.profile;
        });
      }
    });
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }

  void _loadProfileFromCache() {
    // Try to load from preloaded cache first
    if (_preloadService.hasUserData) {
      _profile = _preloadService.profile;
      _levelProgress = _preloadService.levelProgress;
      _proSubscription = _preloadService.proSubscription;
      _mainPhoto = _preloadService.mainPhoto;
      _deviceSessionInfo = _proService.getCachedDeviceSession();
      _isLoading = false;
      
      // Ensure device session validity is checked
      if (_proSubscription != null && _deviceSessionInfo != null) {
        // Update pro subscription to reflect device session validity
        final deviceValid = _deviceSessionInfo!['is_valid'] == true;
        final hasPro = _proSubscription!['expires_at'] != null;
        
        // Override pro status based on device session
        if (hasPro && !deviceValid) {
          print('⚠️ Pro subscription exists but device session is invalid');
        }
      }
      
      print('✅ Loaded profile data from cache');
      
      // Force rebuild to show cached data
      if (mounted) {
        setState(() {});
      }
    } else {
      // Fallback to API call if cache is empty
      _isLoading = true;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final profile = await _authService.getStudentProfile();
      final studentId = _authService.currentUser?.id;
      
      Map<String, dynamic>? progress;
      Map<String, dynamic>? proSub;
      Map<String, dynamic>? mainPhoto;
      Map<String, dynamic>? deviceSession;
      if (studentId != null) {
        progress = await _levelService.getStudentProgress(studentId);
        proSub = await _proService.getProStatus(studentId);
        mainPhoto = await _photoService.getMainPhoto(studentId);
        // Validate device session
        deviceSession = await _proService.validateAndUpdateDeviceSession(studentId);
      }
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _levelProgress = progress;
          _proSubscription = proSub;
          _mainPhoto = mainPhoto;
          _deviceSessionInfo = deviceSession;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getLevelStatus(BuildContext context, int level) {
    final l10n = AppLocalizations.of(context);
    if (level >= 1 && level <= 10) {
      return l10n.levelBeginner;
    } else if (level >= 11 && level <= 20) {
      return l10n.levelIntermediate;
    } else if (level >= 21 && level <= 30) {
      return l10n.levelAdvanced;
    } else if (level >= 31 && level <= 40) {
      return l10n.levelExpert;
    } else if (level >= 41 && level <= 50) {
      return l10n.levelMaster;
    } else if (level >= 51 && level <= 60) {
      return l10n.levelGrandMaster;
    } else if (level >= 61 && level <= 70) {
      return l10n.levelLegend;
    } else if (level >= 71 && level <= 80) {
      return l10n.levelMythic;
    } else if (level >= 81 && level <= 90) {
      return l10n.levelTranscendent;
    } else {
      return l10n.levelSupreme;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const FaIcon(
                        FontAwesomeIcons.bars,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).profile,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 45),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Profile Avatar and Basic Info
                            _buildProfileHeader(context),
                            const SizedBox(height: 25),
                            
                            // User Level Card
                            if (_levelProgress != null) _buildUserLevelCard(),
                            if (_levelProgress != null) const SizedBox(height: 15),
                            
                            // Subscription Card
                            _buildSubscriptionCard(context),
                          const SizedBox(height: 25),
                          
                          // Personal Information Section
                          _buildSectionTitle(AppLocalizations.of(context).personalInformation),
                          const SizedBox(height: 12),
                          _buildInfoCard(
                            icon: FontAwesomeIcons.envelope,
                            title: AppLocalizations.of(context).email,
                            value: _profile?['email'] ?? 'N/A',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(profile: _profile ?? {}),
                                ),
                              ).then((result) async {
                                if (result == true) {
                                  await _preloadService.refreshUserData();
                                  _loadProfile();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 25),
                          
                          // Security Section
                          _buildSectionTitle(AppLocalizations.of(context).security),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            icon: FontAwesomeIcons.lock,
                            title: AppLocalizations.of(context).changePassword,
                            subtitle: AppLocalizations.of(context).updatePassword,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChangePasswordScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            icon: FontAwesomeIcons.userSlash,
                            title: AppLocalizations.of(context).blockedUsers,
                            subtitle: AppLocalizations.of(context).manageBlockedUsers,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BlockedUsersScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 30),
                          
                          // Logout Button
                          CustomButton(
                            text: AppLocalizations.of(context).logout.toUpperCase(),
                            onPressed: () => _showLogoutDialog(context),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final fullName = _profile?['full_name'] ?? AppLocalizations.of(context).studentPlaceholder;
    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'ST';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture Section (Left)
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  shape: BoxShape.circle,
                ),
                child: (_mainPhoto?['photo_url'] != null || _profile?['avatar_url'] != null)
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _mainPhoto?['photo_url'] ?? _profile!['avatar_url'],
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero, // No fade animation for cached images
                          fadeOutDuration: Duration.zero,
                          placeholderFadeInDuration: Duration.zero,
                          placeholder: (context, url) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(profile: _profile ?? {}),
                      ),
                    ).then((result) async {
                      if (result == true) {
                        await _preloadService.refreshUserData();
                        _loadProfile();
                      }
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          
          // User Info Section (Right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                if (_profile?['bio'] != null && (_profile!['bio'] as String).isNotEmpty)
                  Text(
                    _profile!['bio'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(
                    children: [
                      const Icon(
                        Icons.school,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).languageLearner,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(profile: _profile ?? {}),
                      ),
                    ).then((result) async {
                      if (result == true) {
                        await _preloadService.refreshUserData();
                        _loadProfile();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.penToSquare,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).editProfileButton,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLevelCard() {
    final l10n = AppLocalizations.of(context);
    final level = _levelProgress!['level'] as int;
    final points = _levelProgress!['points'] as int;
    final isMaxLevel = _levelProgress!['isMaxLevel'] as bool;
    final progressPercent = _levelProgress!['progressPercent'] as double;
    final nextLevel = _levelProgress!['nextLevel'] as int?;
    final pointsToNext = _levelProgress!['pointsToNext'] as int;
    final status = _getLevelStatus(context, level);
    
    // Calculate XP for current level
    final pointsForCurrentLevel = (level - 1) * LevelService.pointsPerLevel;
    final pointsForNextLevel = level * LevelService.pointsPerLevel;
    final currentLevelXP = points - pointsForCurrentLevel;
    final totalLevelXP = pointsForNextLevel - pointsForCurrentLevel;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5FC3E4).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.currentLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.currentLevel} $level',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.trophy,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (!isMaxLevel)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$points ${l10n.xpPoints}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isMaxLevel)
                Text(
                  '$pointsToNext ${l10n.xpToNextLevel} $nextLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Text(
                  l10n.maxLevelReached,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // Check both subscription existence and device session validity
    final hasProSubscription = _proSubscription != null && 
                               _proSubscription!['expires_at'] != null;
    
    // Check device session validity
    final hasValidSession = _deviceSessionInfo?['is_valid'] == true;
    
    // Pro is active only if both subscription exists and device session is valid
    final isPro = hasProSubscription && hasValidSession;
    
    // Check if pro is active on another device
    final activeOnOtherDevice = hasProSubscription && !hasValidSession;
    
    String? expiryText;
    
    if (hasProSubscription && _proSubscription!['expires_at'] != null) {
      try {
        final expiresAt = _proSubscription!['expires_at'] as String;
        expiryText = _proService.formatExpiryDate(expiresAt);
      } catch (e) {
        expiryText = null;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPro && hasValidSession ? AppColors.redGradient : null,
        color: (isPro && hasValidSession) ? null : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: (isPro && hasValidSession) ? null : Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: (isPro && hasValidSession)
              ? AppColors.primary.withOpacity(0.3)
              : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPro && hasValidSession) 
                    ? Colors.white.withOpacity(0.2) 
                    : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(
                  (isPro && hasValidSession) ? FontAwesomeIcons.crown : FontAwesomeIcons.user,
                  color: (isPro && hasValidSession) ? Colors.white : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (isPro && hasValidSession) ? l10n.proMember : l10n.freeMember,
                      style: TextStyle(
                        color: (isPro && hasValidSession) ? Colors.white : AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (isPro && hasValidSession)
                        ? (expiryText != null 
                            ? '${l10n.expiresPro}: $expiryText'
                            : l10n.unlimitedFeatures)
                        : activeOnOtherDevice
                          ? l10n.proActiveOnAnotherDevice
                          : l10n.limitedFeatures,
                      style: TextStyle(
                        color: (isPro && hasValidSession) 
                          ? Colors.white.withOpacity(0.9) 
                          : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPro)
                GestureDetector(
                  onTap: () => _showRedeemVoucherDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      l10n.upgrade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Show activation button if pro is active on another device
          if (activeOnOtherDevice) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).proSubscriptionActiveMessage,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _activateOnThisDevice,
                icon: const Icon(Icons.phone_android, size: 18),
                label: Text(AppLocalizations.of(context).activateOnThisDevice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FaIcon(
                icon,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FaIcon(
                icon,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }


  void _showLogoutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Capture the navigator context before showing dialog
    final navigatorContext = Navigator.of(context).context;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.rightFromBracket,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.logoutConfirm,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            l10n.areYouSureLogout,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                l10n.cancel,
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Close the dialog first
                Navigator.of(dialogContext).pop();
                
                // Perform logout
                try {
                  await _authService.signOut();
                  
                  // Navigate using the root navigator context
                  if (mounted) {
                    Navigator.of(navigatorContext).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ErrorHelper.getUserFriendlyError(e)),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.redGradient,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  l10n.logout,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRedeemVoucherDialog() {
    showProUpgradeModal(
      context,
      onSuccess: () {
        _loadProfile();
      },
    );
  }

  Future<void> _activateOnThisDevice() async {
    final studentId = _authService.currentUser?.id;
    if (studentId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );

    try {
      // Validate and update device session (force claim)
      final result = await _proService.validateAndUpdateDeviceSession(
        studentId,
        forceClaim: true,
      );
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (result['is_valid'] == true) {
        // 1. Clear pro service cache to force fresh check
        _proService.clearDeviceSessionCache();
        
        // 2. Update global preload cache immediately
        await _preloadService.refreshUserData();
        
        // 3. Invalidate practice cache to force reload
        _preloadService.invalidatePractice();
        
        // 4. Reload profile to reflect changes locally
        await _loadProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).proFeaturesActivated),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocalizations.of(context).failedToActivate}: ${result['error'] ?? AppLocalizations.of(context).unknownError}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getUserFriendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
