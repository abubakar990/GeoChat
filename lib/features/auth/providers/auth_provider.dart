import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final _svc = SupabaseService();
  final _loc = LocationService();

  User? _user;
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  // Set to true after signUp until the user confirms their email
  bool _needsEmailVerification = false;
  String? _pendingEmail; // email we're waiting to be confirmed

  User? get user => _user;
  UserProfile? get profile => _profile;
  UserProfile? get userProfile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get needsEmailVerification => _needsEmailVerification;
  String? get pendingEmail => _pendingEmail;

  /// True only when fully signed-in with a confirmed email
  bool get isAuthenticated =>
      _user != null && (_user!.emailConfirmedAt != null);

  AuthProvider() {
    // Listen for FCM token refreshes and persist them to Supabase
    PushNotificationService.instance.onTokenRefreshed = (newToken) {
      if (_user != null) {
        AppLogger.info('AuthProvider', 'FCM token refreshed, saving to Supabase...');
        _svc.saveFcmToken(userId: _user!.id, token: newToken);
      }
    };

    final current = Supabase.instance.client.auth.currentUser;
    // Only restore session if email is confirmed
    if (current != null && current.emailConfirmedAt != null) {
      _user = current;
      _loadProfile();
      _saveFcmToken(current.id);
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final u = data.session?.user;

      if (u == null) {
        // Signed out — but skip resetting if we're in the signup flow
        if (_isSigningUp) return;
        _user = null;
        _profile = null;
        _needsEmailVerification = false;
        _pendingEmail = null;
        notifyListeners();
        return;
      }

      if (u.emailConfirmedAt == null) {
        // Email not yet confirmed — stay on verification screen
        // Don't update _user so isAuthenticated stays false
        _pendingEmail = u.email;
        notifyListeners();
        return;
      }

      // Email confirmed → full sign-in
      _user = u;
      _needsEmailVerification = false;
      _pendingEmail = null;
      _loadProfile();
      _saveFcmToken(u.id);
    });
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    _profile = await _svc.getProfile(_user!.id);
    notifyListeners();
  }

  /// Upload the FCM token to Supabase so other users can push to this device.
  /// Uses waitForToken to handle the case where the token isn't ready yet.
  Future<void> _saveFcmToken(String userId) async {
    String? token = PushNotificationService.instance.token;
    if (token == null || token.isEmpty) {
      AppLogger.info('AuthProvider', 'FCM token not ready, waiting...');
      token = await PushNotificationService.instance.waitForToken();
    }
    if (token != null && token.isNotEmpty) {
      AppLogger.info('AuthProvider', 'Saving FCM token to Supabase for user $userId');
      await _svc.saveFcmToken(userId: userId, token: token);
    } else {
      AppLogger.warning('AuthProvider', 'No FCM token available to save!');
    }
  }

  bool _isSigningUp = false;

  /// Returns true if signup succeeded (email sent).
  /// Sets [needsEmailVerification] on success.
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    _setLoading(true);
    _isSigningUp = true;
    try {
      await _svc.signUp(email: email, password: password, username: username);

      // Supabase may create a session even when email isn't confirmed yet.
      // Sign out immediately so the unconfirmed session doesn't trigger
      // the auth listener and briefly flash the home screen.
      await Supabase.instance.client.auth.signOut();

      _needsEmailVerification = true;
      _pendingEmail = email;
      _isSigningUp = false;
      _setLoading(false);
      return true;
    } catch (e) {
      _isSigningUp = false;
      _setError(_parseError(e.toString()));
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _svc.signIn(email: email, password: password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_parseError(e.toString()));
      return false;
    }
  }

  Future<void> signOut() async {
    if (_user != null) {
      await _svc.updateOnlineStatus(userId: _user!.id, isOnline: false);
    }
    _loc.stopTracking();
    _needsEmailVerification = false;
    _pendingEmail = null;
    await _svc.signOut();
  }

  /// Resend the confirmation email. Returns true on success.
  Future<bool> resendVerificationEmail() async {
    if (_pendingEmail == null) return false;
    _setLoading(true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _pendingEmail!,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to resend email. Try again in a moment.');
      return false;
    }
  }

  /// Called when user taps "Back to Sign In" on verify screen
  void cancelVerification() {
    _needsEmailVerification = false;
    _pendingEmail = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> updateProfile({String? displayName, String? username}) async {
    if (_user == null) return false;
    _setLoading(true);
    try {
      await _svc.updateProfile(
        userId: _user!.id,
        displayName: displayName,
        username: username,
      );
      await _loadProfile();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Re-fetches the profile from the database and notifies listeners.
  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    _error = null;
    notifyListeners();
  }

  void _setError(String e) {
    _error = e;
    _isLoading = false;
    notifyListeners();
  }

  String _parseError(String e) {
    if (e.contains('Invalid login credentials'))
      return 'Invalid email or password';
    if (e.contains('already registered')) return 'This email is already in use';
    if (e.contains('Email not confirmed'))
      return 'Please verify your email before signing in';
    if (e.contains('User already registered'))
      return 'An account with this email already exists';
    return 'Something went wrong. Please try again.';
  }
}
