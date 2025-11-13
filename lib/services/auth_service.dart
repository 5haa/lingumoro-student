import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign up a new student (sends OTP to email)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? provinceId,
  }) async {
    // Check if email already exists in auth.users table
    final emailExistsResponse = await _supabase
        .rpc('check_email_exists', params: {'check_email': email});

    if (emailExistsResponse == true) {
      throw Exception('This email is already registered. Please login instead.');
    }

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
  }) async {
    // Verify the OTP - this will create an authenticated session
    final response = await _supabase.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );

    // Create student profile after successful verification
    if (response.user != null) {
      // Check if profile already exists
      final existing = await _supabase
          .from('students')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('students').insert({
          'id': response.user!.id,
          'email': response.user!.email,
          'full_name': fullName,
          'phone': phone,
          if (provinceId != null) 'province_id': provinceId,
        });
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
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Check if account is suspended
    if (response.user != null) {
      await _checkSuspensionStatus(response.user!.id);
    }

    return response;
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
    String? phone,
    String? avatarUrl,
    String? bio,
  }) async {
    if (currentUser == null) throw Exception('No user logged in');

    await _supabase.from('students').update({
      'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
    }).eq('id', currentUser!.id);
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}

