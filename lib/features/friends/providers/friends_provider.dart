import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/user_profile.dart';
import '../../../models/friend_request_model.dart';

class FriendsProvider extends ChangeNotifier {
  final _svc = SupabaseService();
  final _push = PushNotificationService.instance;

  String _userId = '';
  List<FriendRequest> _pendingRequests = [];
  List<UserProfile> _friends = [];
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  RealtimeChannel? _channel;

  // ── Getters ─────────────────────────────────────────────────────────────────
  List<FriendRequest> get pendingRequests => _pendingRequests;
  List<UserProfile> get friends => _friends;
  List<UserProfile> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;
  int get pendingCount => _pendingRequests.length;

  // ── Initialization ───────────────────────────────────────────────────────────
  void initialize(String userId) {
    if (_userId == userId && _channel != null) return; // already initialised
    _userId = userId;
    _subscribeToRequests();
    // Defer the first load so notifyListeners() is never called during a
    // Flutter build phase (IndexedStack mounts all children at first build).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      _pendingRequests = await _svc.getPendingRequests(_userId);
      _friends = await _svc.getFriends(_userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Real-time: refresh whenever the friend_requests table changes for this user.
  void _subscribeToRequests() {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('friend_requests:receiver:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: _userId,
          ),
          callback: (_) => _loadAll(),
        );

    try {
      _channel?.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError) {
          print('[Realtime Status] $_userId requests channel: $status');
        }
      });
    } catch (e) {
      print('[Realtime Exception] Friend requests subscription failed: $e');
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────────
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _svc.searchUsers(query.trim());
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> sendFriendRequest(String receiverId) async {
    try {
      await _svc.sendFriendRequest(
        senderId: _userId,
        receiverId: receiverId,
      );
      final myProfile = await _svc.getProfile(_userId);
      final actorName =
          myProfile?.displayName ?? myProfile?.username ?? 'Someone';
      final title = '$actorName sent you a friend request';
      const body = 'Tap to view and respond.';

      // In-app notification row
      await _svc.createNotification(
        userId: receiverId,
        type: 'friend_request',
        title: title,
        body: body,
        referenceId: _userId,
        actorName: actorName,
        actorAvatar: myProfile?.avatarUrl,
      );

      // Real OS push notification
      final fcmToken = await _svc.getFcmToken(receiverId);
      AppLogger.info('FriendsProvider', 'receiverId: $receiverId, fcmToken: $fcmToken');
      if (fcmToken != null && fcmToken.isNotEmpty) {
        AppLogger.info('FriendsProvider', 'Sending push notification to $receiverId');
        await _push.sendPushToUser(
          toFcmToken: fcmToken,
          title: title,
          body: body,
          type: 'friend_request',
          referenceId: _userId,
          supabaseUrl: AppConstants.supabaseUrl,
          supabaseAnonKey: AppConstants.supabaseAnonKey,
        );
      } else {
        AppLogger.warning('FriendsProvider', 'Skipping push notification, no FCM token for $receiverId');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      await _svc.respondToFriendRequest(requestId: requestId, accept: true);
      final req = _pendingRequests.firstWhere((r) => r.id == requestId,
          orElse: () => _pendingRequests.first);
      final myProfile = await _svc.getProfile(_userId);
      final actorName =
          myProfile?.displayName ?? myProfile?.username ?? 'Someone';
      final title = '$actorName accepted your friend request!';
      const body = "You're now friends. Start chatting!";

      // In-app notification to the original sender
      await _svc.createNotification(
        userId: req.senderId,
        type: 'friend_accepted',
        title: title,
        body: body,
        referenceId: _userId,
        actorName: actorName,
        actorAvatar: myProfile?.avatarUrl,
      );

      // Real OS push notification
      final fcmToken = await _svc.getFcmToken(req.senderId);
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _push.sendPushToUser(
          toFcmToken: fcmToken,
          title: title,
          body: body,
          type: 'friend_accepted',
          referenceId: _userId,
          supabaseUrl: AppConstants.supabaseUrl,
          supabaseAnonKey: AppConstants.supabaseAnonKey,
        );
      }

      await _loadAll();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await _svc.respondToFriendRequest(requestId: requestId, accept: false);
      _pendingRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, String>?> getFriendStatus(String otherUserId) =>
      _svc.getFriendRequestStatus(_userId, otherUserId);

  Future<void> refresh() => _loadAll();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
