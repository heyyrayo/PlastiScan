import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorHandler {
  static String message(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Email or password is incorrect.';

        case 'email_not_confirmed':
          return 'Please verify your email before signing in.';

        case 'user_already_exists':
          return 'An account with this email already exists.';

        case 'weak_password':
          return 'Please choose a stronger password.';

        case 'over_email_send_rate_limit':
          return 'Too many emails were requested. Please try again later.';

        default:
          return error.message.isNotEmpty
              ? error.message
              : 'Authentication failed. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }
}
