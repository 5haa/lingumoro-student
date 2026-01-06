class ErrorHelper {
  /// Converts technical error messages to user-friendly messages
  static String getUserFriendlyError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    
    // Authentication errors - comprehensive patterns for Supabase
    if (errorMessage.contains('invalid login credentials') || 
        errorMessage.contains('invalid credentials') ||
        errorMessage.contains('incorrect password') ||
        errorMessage.contains('wrong password') ||
        errorMessage.contains('bad_credentials') ||
        errorMessage.contains('invalid_credentials') ||
        errorMessage.contains('invalid password') ||
        errorMessage.contains('password is incorrect') ||
        errorMessage.contains('authexception') ||
        errorMessage.contains('authapiexception') ||
        errorMessage.contains('signinwithotp') ||
        errorMessage.contains('signinerror')) {
      return 'Incorrect email or password. Please try again.';
    }
    
    if (errorMessage.contains('email not confirmed') ||
        errorMessage.contains('email_not_confirmed')) {
      return 'Please verify your email address before logging in.';
    }
    
    if (errorMessage.contains('user not found') ||
        errorMessage.contains('user does not exist')) {
      return 'No account found with this email address.';
    }
    
    if (errorMessage.contains('email already registered') ||
        errorMessage.contains('email already exists') ||
        errorMessage.contains('user already registered') ||
        errorMessage.contains('email_exists') ||
        errorMessage.contains('identity_already_exists') ||
        errorMessage.contains('already registered as a student') ||
        errorMessage.contains('already registered as a teacher')) {
      return 'An account with this email already exists. Please login instead.';
    }
    
    if (errorMessage.contains('over_request_rate_limit') ||
        errorMessage.contains('over_email_send_rate_limit') ||
        errorMessage.contains('over_sms_rate_limit') ||
        errorMessage.contains('email rate limit exceeded') ||
        errorMessage.contains('for security purposes')) {
      return 'Too many requests. Please wait a few minutes and try again.';
    }
    
    if (errorMessage.contains('weak password') ||
        errorMessage.contains('password should be at least')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    
    if (errorMessage.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout')) {
      return 'Network connection error. Please check your internet and try again.';
    }
    
    if (errorMessage.contains('too many requests') ||
        errorMessage.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    
    if (errorMessage.contains('token') && errorMessage.contains('expired')) {
      return 'Your session has expired. Please log in again.';
    }
    
    if (errorMessage.contains('invalid token') ||
        errorMessage.contains('invalid code') ||
        errorMessage.contains('invalid otp')) {
      return 'Invalid or expired verification code. Please try again.';
    }
    
    if (errorMessage.contains('suspended') ||
        errorMessage.contains('account suspended')) {
      return 'Your account has been suspended. Please contact support.';
    }
    
    // Password reset errors
    if (errorMessage.contains('same password')) {
      return 'New password must be different from your current password.';
    }
    
    // File upload errors
    if (errorMessage.contains('file too large') ||
        errorMessage.contains('size limit')) {
      return 'File is too large. Please choose a smaller file.';
    }
    
    if (errorMessage.contains('invalid file type') ||
        errorMessage.contains('unsupported format')) {
      return 'Invalid file type. Please choose a valid image file.';
    }
    
    // Payment/Subscription errors
    if (errorMessage.contains('payment failed')) {
      return 'Payment failed. Please check your payment details and try again.';
    }
    
    if (errorMessage.contains('subscription') && errorMessage.contains('expired')) {
      return 'Your subscription has expired. Please renew to continue.';
    }
    
    // Chat/messaging errors
    if (errorMessage.contains('blocked')) {
      return 'Unable to perform this action. The user may have blocked you.';
    }
    
    if (errorMessage.contains('not found')) {
      return 'The requested item could not be found.';
    }
    
    if (errorMessage.contains('permission denied') ||
        errorMessage.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }
    
    // Server errors
    if (errorMessage.contains('500') || 
        errorMessage.contains('internal server error')) {
      return 'Server error. Please try again later.';
    }
    
    if (errorMessage.contains('503') || 
        errorMessage.contains('service unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    
    // If no specific pattern matches, try to extract meaningful error message
    // Remove common prefixes to get the actual error message
    String cleanedError = error.toString();
    
    // Remove exception type prefixes (e.g., "AuthException: ", "PostgrestException: ")
    if (cleanedError.contains(':')) {
      final parts = cleanedError.split(':');
      if (parts.length > 1) {
        cleanedError = parts.sublist(1).join(':').trim();
      }
    }
    
    // If we have a meaningful error message, return it
    if (cleanedError.isNotEmpty && cleanedError.length > 3) {
      // Capitalize first letter
      return cleanedError[0].toUpperCase() + cleanedError.substring(1);
    }
    
    // Final fallback
    return 'An unexpected error occurred. Please try again.';
  }
}








