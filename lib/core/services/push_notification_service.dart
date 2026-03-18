import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level handler — MUST be a top-level function (not inside a class).
// Called by FCM when a message arrives while the app is terminated/background.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // flutter_local_notifications will auto-display data-only messages here
  // For notification messages FCM shows them natively — nothing extra needed.
  AppLogger.info('FCM', 'Background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification channels (Android 8+)
// ─────────────────────────────────────────────────────────────────────────────
const _messagesChannel = AndroidNotificationChannel(
  'geochat_messages',
  'Messages',
  description: 'New chat messages',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  enableLights: true,
  ledColor: Color(0xFF007BFF),
);

const _friendsChannel = AndroidNotificationChannel(
  'geochat_friends',
  'Friends',
  description: 'Friend requests and social updates',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

const _generalChannel = AndroidNotificationChannel(
  'geochat_general',
  'General',
  description: 'General alerts',
  importance: Importance.defaultImportance,
);

// ─────────────────────────────────────────────────────────────────────────────
// PushNotificationService
// ─────────────────────────────────────────────────────────────────────────────
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifs = FlutterLocalNotificationsPlugin();

  String? _token;
  String? get token => _token;

  /// Function called when user taps a notification while app is open.
  /// Set this from main.dart / home shell to handle navigation.
  void Function(RemoteMessage)? onMessageTap;

  /// Called when FCM token is first obtained or refreshed.
  /// Use this to persist the token to your backend (e.g. Supabase profiles).
  void Function(String newToken)? onTokenRefreshed;

  // ── Initialise ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    // Register background handler before anything else
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Create Android channels
    final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_messagesChannel);
    await androidPlugin?.createNotificationChannel(_friendsChannel);
    await androidPlugin?.createNotificationChannel(_generalChannel);

    // Initialize flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Called when user taps a local (foreground) notification
        AppLogger.info('LocalNotif', 'tapped: ${details.payload}');
      },
    );

    // Request permission (Android 13+, iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    AppLogger.info('FCM', 'Permission status: ${settings.authorizationStatus}');

    // Get & cache token
    try {
      _token = await _fcm.getToken();
      AppLogger.info('FCM',
          'Token obtained: ${_token != null ? '${_token!.substring(0, 20)}...' : 'NULL'}');
    } catch (e) {
      AppLogger.error('FCM', 'Failed to get token', e);
    }

    // Token refresh — also notify external listeners so they can persist it
    _fcm.onTokenRefresh.listen((newToken) {
      _token = newToken;
      AppLogger.info('FCM', 'Token refreshed: ${newToken.substring(0, 20)}...');
      onTokenRefreshed?.call(newToken);
    });

    // ── Foreground messages ────────────────────────────────────────────────
    // FCM does NOT show a heads-up notification by default when app is open.
    // We display it ourselves with flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // ── App opened from background via notification tap ────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      AppLogger.info('FCM', 'Notification tapped (background→foreground)');
      onMessageTap?.call(msg);
    });

    // ── App was terminated and opened via notification tap ─────────────────
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      AppLogger.info('FCM', 'App opened from terminated state via notification');
      // Small delay to allow the widget tree to mount
      Future.delayed(const Duration(milliseconds: 300), () {
        onMessageTap?.call(initial);
      });
    }
  }

  /// Wait up to [timeout] for the FCM token to become available.
  /// Useful when the token might not be ready at auth-restore time.
  Future<String?> waitForToken({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_token != null) return _token;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (_token != null) return _token;
    }
    AppLogger.warning('FCM', 'waitForToken timed out — token is still null');
    return null;
  }

  // ── Display notification when app is in foreground ─────────────────────────
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] as String? ?? 'general';
    final channelId = _channelIdForType(type);

    await _localNotifs.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelNameForType(type),
          channelDescription: 'GeoChat notification',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF007BFF),
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
          ),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  String _channelIdForType(String type) {
    if (type == 'new_message') return 'geochat_messages';
    if (type == 'friend_request' || type == 'friend_accepted') {
      return 'geochat_friends';
    }
    return 'geochat_general';
  }

  String _channelNameForType(String type) {
    if (type == 'new_message') return 'Messages';
    if (type == 'friend_request' || type == 'friend_accepted') return 'Friends';
    return 'General';
  }

  // ── Send a push to another user via Supabase Edge Function ────────────────
  /// [toFcmToken] — the recipient's FCM token (fetched from profiles table).
  /// Uses Supabase client's built-in functions.invoke() for proper auth.
  Future<void> sendPushToUser({
    required String toFcmToken,
    required String title,
    required String body,
    required String type,
    String? referenceId,
    String? supabaseUrl, // kept for API compat, no longer used
    String? supabaseAnonKey, // kept for API compat, no longer used
  }) async {
    AppLogger.info('FCM', '── Sending push ──────────────────────────────');
    AppLogger.info('FCM', '  to token: ${toFcmToken.substring(0, 20)}...');
    AppLogger.info('FCM', '  title: $title');
    AppLogger.info('FCM', '  type: $type');

    try {
      // Use the Supabase client's functions.invoke() which automatically
      // handles authentication (attaches the correct JWT from the session).
      final response = await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'token': toFcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': type,
            if (referenceId != null) 'referenceId': referenceId,
          },
        },
      );

      AppLogger.info('FCM', '  Response status: ${response.status}');

      if (response.status == 200) {
        AppLogger.info('FCM', '✅ Push sent successfully');
      } else {
        AppLogger.error('FCM', 'Edge Function error: status ${response.status}');
      }
    } catch (e) {
      AppLogger.error('FCM', 'Failed to invoke Edge Function', e);
    }
  }
}
