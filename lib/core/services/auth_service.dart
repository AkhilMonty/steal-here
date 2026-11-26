import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/notification_repository.dart';
import 'supabase_service.dart';

/// Handles user authentication through Supabase.
class AuthService {
  AuthService._();

  static SupabaseClient get _client => SupabaseService.client;

  /// Registers a new user with email, password, name, and phone number.
  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    return _client.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {'full_name': fullName.trim(), 'phone': phone.trim()},
      emailRedirectTo: 'stealhere://auth-callback',
    );
  }

  // Tracks whether the current session was opened through password recovery.
  static bool _isPasswordRecoverySession = false;

  static bool get isPasswordRecoverySession => _isPasswordRecoverySession;

  static void markPasswordRecoveryStarted() {
    _isPasswordRecoverySession = true;
  }

  static void clearPasswordRecovery() {
    _isPasswordRecoverySession = false;
  }

  /// Signs in an existing user using email and password.
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    return _client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  /// Sends a password reset email to the user.
  static Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    await _client.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: 'stealhere://auth-callback',
    );
  }

  /// Updates the authenticated user's password.
  /// Updates the authenticated user's password and creates a notification.

  /// Changes the password after verifying the current password.
  static Future<UserResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;

    if (email == null || email.isEmpty) {
      throw StateError('No authenticated user email is available.');
    }

    // Verify the customer's current password.
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );

    // Reuse the existing password update and notification logic.
    return updatePassword(newPassword: newPassword);
  }

  static Future<UserResponse> updatePassword({
    required String newPassword,
    bool signOutAfterUpdate = false,
  }) async {
    // Update password through Supabase first.
    final response = await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    // Notify only after a successful password update.
    try {
      await NotificationRepository().createNotification(
        title: 'Password Changed Successfully',
        message:
            'Your account password was changed successfully. '
            'If you did not make this change, please secure your account.',
        category: 'security',
        metadata: {'event': 'password_changed', 'user_id': response.user?.id},
      );
    } catch (error) {
      // Notification failure must not undo a successful password change.
      // ignore: avoid_print
      print('PASSWORD NOTIFICATION ERROR: $error');
    }

    // End the recovery session after a successful password reset.
    if (signOutAfterUpdate) {
      try {
        await _client.auth.signOut();
      } catch (error) {
        // Password has already been updated successfully.
        // ignore: avoid_print
        print('PASSWORD RESET SIGN OUT ERROR: $error');
      }
    }

    clearPasswordRecovery();

    return response;
  }

  /// Requests an email address change through Supabase.
  /// Requests an email address change through Supabase.
  static Future<UserResponse> updateEmail({required String newEmail}) async {
    final normalizedEmail = newEmail.trim().toLowerCase();

    // Submit the email change request to Supabase.
    final response = await _client.auth.updateUser(
      UserAttributes(email: normalizedEmail),
      emailRedirectTo: 'stealhere://auth-callback',
    );

    // Notify the customer that email confirmation has been requested.
    try {
      await NotificationRepository().createNotification(
        title: 'Email Change Requested',
        message:
            'A request to change your account email has been submitted. '
            'Please check your inbox and complete the confirmation process.',
        category: 'account',
        metadata: {
          'event': 'email_change_requested',
          'user_id': response.user?.id,
        },
      );
    } catch (error) {
      // Notification failure must not affect the email change request.
      // ignore: avoid_print
      print('EMAIL CHANGE NOTIFICATION ERROR: $error');
    }

    return response;
  }

  /// Updates the authenticated user's profile information.
  static Future<UserResponse> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final currentUser = _client.auth.currentUser;

    if (currentUser == null) {
      throw StateError('No authenticated user found.');
    }

    final updatedMetadata = <String, dynamic>{
      ...currentUser.userMetadata ?? <String, dynamic>{},
      'full_name': fullName.trim(),
      'phone': phone.trim(),
    };

    return _client.auth.updateUser(UserAttributes(data: updatedMetadata));
  }

  /// Signs out the current user.
  static Future<void> logout() async {
    clearPasswordRecovery();
    await _client.auth.signOut();
  }

  /// Returns the currently authenticated user, if available.
  static User? get currentUser => _client.auth.currentUser;

  /// Returns whether a user is currently authenticated.
  static bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes.
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
