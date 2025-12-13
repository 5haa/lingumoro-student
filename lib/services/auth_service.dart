import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student/services/firebase_notification_service.dart';
import 'package:student/services/preload_service.dart';
import 'package:student/services/pro_subscription_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _firebaseNotificationService = FirebaseNotificationService();
  final _proSubscriptionService = ProSubscriptionService();

  User? get currentUser => _supabase.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign up a new student (sends OTP to email)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? provinceId,
    String? motherLanguage,
  }) async {
    // Check if email already exists and what type of user it is
    final userType = await _supabase.rpc('check_user_type_by_email', 
      params: {'check_email': email}) as String?;
    
    if (userType == 'student') {
      throw Exception('This email is already registered as a student. Please login instead.');
    } else if (userType == 'teacher') {
      throw Exception('This email is registered as a teacher. Please use the Teacher app.');
    } else if (userType == 'duplicate' || userType == 'no_profile') {
      throw Exception('This email has account issues. Please contact support.');
    }
    
    // If user doesn't exist, proceed with signup
    // Sign up user - this will send OTP email
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: null, // Disable email link
    );

    // Note: User data will be passed via the OTP screen
    // Profile will be created after OTP verification when user has a session

    return response;
  }

  /// Verify OTP and create profile
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
    required String fullName,
    String? phone,
    String? provinceId,
    String? motherLanguage,
  }) async {
    // Verify the OTP - this will create an authenticated session
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );

    // Create or update student profile after successful verification
    if (response.user != null) {
      // Check if profile already exists (created by database trigger)
      final existing = await _supabase
          .from('students')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (existing == null) {
        // Create new profile
        await _supabase.from('students').insert({
          'id': response.user!.id,
          'email': response.user!.email,
          'full_name': fullName,
          'phone': phone,
          if (provinceId != null) 'province_id': provinceId,
          if (motherLanguage != null) 'mother_language': motherLanguage,
        });
      } else {
        // Update existing profile with correct data (trigger may have created with defaults)
        await _supabase.from('students').update({
          'full_name': fullName,
          if (phone != null) 'phone': phone,
          if (provinceId != null) 'province_id': provinceId,
          if (motherLanguage != null) 'mother_language': motherLanguage,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', response.user!.id);
      }
      
      // Initialize Firebase notifications after successful signup
      try {
        await _firebaseNotificationService.initialize();
        print('✅ Firebase notifications initialized successfully');
      } catch (e) {
        print('❌ Failed to initialize Firebase notifications: $e');
      }
      
      // Validate device session for pro subscription (force claim on signup)
      try {
        await _proSubscriptionService.validateAndUpdateDeviceSession(
          response.user!.id, 
          forceClaim: true
        );
        print('✅ Device session validated for new user');
      } catch (e) {
        print('❌ Failed to validate device session: $e');
      }
    }

    return response;
  }

  /// Resend OTP
  Future<void> resendOTP(String email) async {
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    // First, check if this email is registered as a student
    final userType = await _supabase.rpc('check_user_type_by_email', 
      params: {'check_email': email}) as String?;
    
    if (userType == 'teacher') {
      throw Exception('This account is registered as a teacher. Please use the Teacher app to login.');
    } else if (userType == 'not_found') {
      throw Exception('No account found with this email. Please sign up first.');
    } else if (userType == 'no_profile') {
      throw Exception('Account exists but profile is incomplete. Please contact support.');
    }
    
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Validate that user is actually a student (double-check after auth)
    if (response.user != null) {
      final isValidStudent = await _supabase.rpc('validate_user_type',
        params: {'user_id': response.user!.id, 'expected_type': 'student'}) as bool?;
      
      if (isValidStudent != true) {
        // Sign out immediately if not a valid student
        await _supabase.auth.signOut();
        throw Exception('This account is not registered as a student. Please use the correct app for your account type.');
      }
      
      await _checkSuspensionStatus(response.user!.id);
      
      // Initialize Firebase notifications after successful login
      try {
        await _firebaseNotificationService.initialize();
        print('✅ Firebase notifications initialized successfully');
      } catch (e) {
        print('❌ Failed to initialize Firebase notifications: $e');
      }
      
      // Validate and update device session for pro subscription (force claim on login)
      try {
        final sessionResult = await _proSubscriptionService.validateAndUpdateDeviceSession(
          response.user!.id,
          forceClaim: true
        );
        if (sessionResult['device_changed'] == true) {
          print('🔄 Pro subscription device session updated to this device');
        }
        print('✅ Device session validated: ${sessionResult}');
      } catch (e) {
        print('❌ Failed to validate device session: $e');
      }
    }

    return response;
  }

  /// Validate that user is a student (not used in login flow anymore, kept for backwards compatibility)
  @Deprecated('User validation is now done during login via validate_user_type RPC')
  Future<void> _ensureStudentRecordExists(User user) async {
    // This method is deprecated and should not create records automatically
    // User type validation is now handled during login
    print('⚠️ _ensureStudentRecordExists is deprecated');
  }

  /// Check if user account is suspended
  Future<void> _checkSuspensionStatus(String userId) async {
    final student = await _supabase
        .from('students')
        .select('is_suspended, suspension_reason')
        .eq('id', userId)
        .maybeSingle();

    if (student != null && (student['is_suspended'] == true)) {
      // Sign out the user immediately
      await _supabase.auth.signOut();
      
      final reason = student['suspension_reason'] ?? 'Your account has been suspended.';
      throw Exception('Account suspended: $reason');
    }
  }

  /// Check suspension status for current user (call on app startup)
  Future<bool> checkIfSuspended() async {
    if (currentUser == null) return false;

    try {
      final student = await _supabase
          .from('students')
          .select('is_suspended, suspension_reason')
          .eq('id', currentUser!.id)
          .maybeSingle();

      if (student != null && (student['is_suspended'] == true)) {
        await _supabase.auth.signOut();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    // Clear preloaded cache on logout
    PreloadService().clearCache();
  }

  /// Get student profile
  Future<Map<String, dynamic>?> getStudentProfile() async {
    if (currentUser == null) return null;

    final response = await _supabase
        .from('students')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();

    return response;
  }

  /// Update student profile
  Future<void> updateProfile({
    required String fullName,
    String? avatarUrl,
    String? bio,
  }) async {
    if (currentUser == null) throw Exception('No user logged in');

    await _supabase.from('students').update({
      'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
    }).eq('id', currentUser!.id);
  }

  /// Reset password (sends OTP)
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Verify password reset OTP
  Future<AuthResponse> verifyPasswordResetOTP({
    required String email,
    required String token,
  }) async {
    // Verify the password reset OTP
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );

    return response;
  }

  /// Resend password reset OTP
  Future<void> resendPasswordResetOTP(String email) async {
    await _supabase.auth.resend(
      type: OtpType.recovery,
      email: email,
    );
  }

  /// Update password after OTP verification
  Future<void> updatePassword(String newPassword) async {
    if (currentUser == null) {
      throw Exception('No user logged in. Please verify OTP first.');
    }

    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Request OTP for changing password (when logged in)
  Future<void> requestChangePasswordOTP() async {
    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    // Send OTP to the current user's email
    await _supabase.auth.resetPasswordForEmail(currentUser!.email!);
  }
}

