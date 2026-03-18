import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final _svc = SupabaseService();
  final _push = PushNotificationService.instance;

  String _userId = '';
  List<AppNotification> _notifications = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _initialized = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  // ── Initialization ────────────────────────────────────────────────────────
  void initialize(String userId) {
    if (_initialized && _userId == userId) return;
    _userId = userId;
    _initialized = true;
    _sub?.cancel();

    _sub = _svc.subscribeToNotifications(userId).listen((rows) {
      _notifications = rows.map((r) => AppNotification.fromMap(r)).toList();
      notifyListeners();
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> markRead(String notificationId) async {
    // Optimistic update
    _notifications = _notifications
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    notifyListeners();
    await _svc.markNotificationRead(notificationId);
  }

  Future<void> markAllRead() async {
    // Optimistic update
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    await _svc.markAllNotificationsRead(_userId);
  }

  /// Called by other providers/screens to push a notification to
  /// another user (e.g., when sending a message or friend request).
  Future<void> sendNotification({
    required String toUserId,
    required String type,
    required String title,
    required String body,
    String? referenceId,
    String? actorName,
    String? actorAvatar,
  }) async {
    // 1. In-app notification
    await _svc.createNotification(
      userId: toUserId,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      actorName: actorName,
      actorAvatar: actorAvatar,
    );

    // 2. Real OS push notification via Edge Function
    try {
      final fcmToken = await _svc.getFcmToken(toUserId);
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _push.sendPushToUser(
          toFcmToken: fcmToken,
          title: title,
          body: body,
          type: type,
          referenceId: referenceId,
          supabaseUrl: AppConstants.supabaseUrl,
          supabaseAnonKey: AppConstants.supabaseAnonKey,
        );
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
