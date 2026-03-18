import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../models/message_model.dart';
import '../../models/conversation_model.dart';
import '../../models/friend_request_model.dart';
import '../../models/notification_model.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    if (res.user != null) {
      await _client.from(AppConstants.profilesTable).insert({
        'id': res.user!.id,
        'username': username,
        'email': email,
        'is_online': false,
      });
    }
    return res;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  // ─── Profiles ────────────────────────────────────────────────────────────

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final res = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res == null) {
        // No profile row — auto-create one from auth metadata
        final authUser = _client.auth.currentUser;
        final meta = authUser?.userMetadata ?? {};
        final username = (meta['username'] as String?) ??
            authUser?.email?.split('@').first ??
            'user_${userId.substring(0, 6)}';
        final email = authUser?.email ?? '';

        await _client.from(AppConstants.profilesTable).upsert({
          'id': userId,
          'username': username,
          'email': email,
          'is_online': true,
        });

        // Re-fetch after creating
        final created = await _client
            .from(AppConstants.profilesTable)
            .select()
            .eq('id', userId)
            .maybeSingle();

        print('[getProfile] auto-created profile: $created');
        return created == null ? null : UserProfile.fromMap(created);
      }

      print('[getProfile] fetched: username=${res['username']}, '
          'account_number=${res['account_number']}, '
          'display_name=${res['display_name']}');
      return UserProfile.fromMap(res);
    } catch (e) {
      print('[getProfile] ERROR: $e');
      return null;
    }
  }

  Future<void> updateLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    await _client.from(AppConstants.profilesTable).update({
      'latitude': latitude,
      'longitude': longitude,
      'last_known_location': 'POINT($longitude $latitude)',
      'last_seen': DateTime.now().toIso8601String(),
      'is_online': true,
    }).eq('id', userId);
  }

  Future<void> updateOnlineStatus({
    required String userId,
    required bool isOnline,
  }) async {
    await _client.from(AppConstants.profilesTable).update({
      'is_online': isOnline,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Saves the FCM device token for this user so other clients can push to them.
  Future<void> saveFcmToken({
    required String userId,
    required String token,
  }) async {
    try {
      await _client.from(AppConstants.profilesTable).update({
        'fcm_token': token,
      }).eq('id', userId);
    } catch (e) {
      print('[saveFcmToken] $e');
    }
  }

  /// Returns the FCM token for [userId], or null if not set.
  Future<String?> getFcmToken(String userId) async {
    try {
      final res = await _client
          .from(AppConstants.profilesTable)
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();
      return res?['fcm_token'] as String?;
    } catch (e) {
      print('[getFcmToken] $e');
      return null;
    }
  }

  /// Enables or disables location sharing.
  /// When disabled: lat/lng and geography point are cleared so the user
  /// disappears from everyone else's map immediately.
  Future<void> updateLocationSharing({
    required String userId,
    required bool enabled,
  }) async {
    if (enabled) {
      await _client.from(AppConstants.profilesTable).update({
        'is_location_sharing': true,
      }).eq('id', userId);
    } else {
      // Wipe location data so the PostGIS query returns no result for this user.
      await _client.from(AppConstants.profilesTable).update({
        'is_location_sharing': false,
        'latitude': null,
        'longitude': null,
        'last_known_location': null,
      }).eq('id', userId);
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? username,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await _client
          .from(AppConstants.profilesTable)
          .update(updates)
          .eq('id', userId);
    }
  }

  // ─── Nearby Users (PostGIS RPC) ──────────────────────────────────────────

  Future<List<UserProfile>> getNearbyUsers({
    required double latitude,
    required double longitude,
    required String currentUserId,
    double radius = AppConstants.defaultRadius,
  }) async {
    final res = await _client.rpc(
      'get_nearby_users',
      params: {
        'lat': latitude,
        'long': longitude,
        'radius': radius,
        'current_user_id': currentUserId,
      },
    );
    return (res as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Conversations ───────────────────────────────────────────────────────

  Future<String> getOrCreateConversation({
    required String userId1,
    required String userId2,
  }) async {
    final existing = await _client
        .from(AppConstants.conversationsTable)
        .select('id')
        .contains('participant_ids', [userId1, userId2]).maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await _client
        .from(AppConstants.conversationsTable)
        .insert({
          'participant_ids': [userId1, userId2],
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<List<ConversationModel>> getConversations(String userId) async {
    final res = await _client
        .from(AppConstants.conversationsTable)
        .select()
        .contains('participant_ids', [userId]).order('updated_at',
            ascending: false);
    return (res as List)
        .map((e) => ConversationModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfile?> getOtherParticipant({
    required List<String> participantIds,
    required String currentUserId,
  }) async {
    final otherId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return null;
    return getProfile(otherId);
  }

  // ─── Messages ────────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required MessageType type,
    String? content,
    String? mediaUrl,
    double? locationLat,
    double? locationLng,
    bool isEncrypted = false,
  }) async {
    await _client.from(AppConstants.messagesTable).insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'type': type.value,
      'content': content,
      'media_url': mediaUrl,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'is_encrypted': isEncrypted,
    });
    await _client
        .from(AppConstants.conversationsTable)
        .update({'updated_at': DateTime.now().toIso8601String()}).eq(
            'id', conversationId);
  }

  Stream<List<Map<String, dynamic>>> subscribeToMessages(
    String conversationId,
  ) =>
      _client
          .from(AppConstants.messagesTable)
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at')
          .handleError((e) => print('[Realtime Error] Messages stream: $e'));

  /// Returns the most recent message in a conversation, or null if none.
  Future<Map<String, dynamic>?> getLastMessage(String conversationId) async {
    try {
      final res = await _client
          .from(AppConstants.messagesTable)
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }

  // ─── Storage ─────────────────────────────────────────────────────────────

  Future<String?> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String extension,
  }) async {
    final path = '$userId/avatar.$extension';
    await _client.storage.from(AppConstants.avatarsBucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(AppConstants.avatarsBucket).getPublicUrl(path);
  }

  Future<String?> uploadMessageMedia({
    required String conversationId,
    required String messageId,
    required List<int> bytes,
    required String extension,
  }) async {
    final path = '$conversationId/$messageId.$extension';
    await _client.storage
        .from(AppConstants.messageMediaBucket)
        .uploadBinary(path, Uint8List.fromList(bytes));
    return _client.storage
        .from(AppConstants.messageMediaBucket)
        .getPublicUrl(path);
  }

  // ─── Friends & Account Number ─────────────────────────────────────────────

  /// Search by account number (GEO-XXXXXXXX) OR username / display name.
  /// Never exposes email or phone.
  Future<List<UserProfile>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final upper = q.toUpperCase();

    // ── Account number detection ───────────────────────────────────────────
    // Accept any of:  "GEO-ABC12345"  |  "GEO ABC12345"  |  "ABC12345"
    final cleanedUpper = upper.replaceAll(RegExp(r'[\s\-]'), '');
    String? accountNumQuery;

    if (upper.startsWith('GEO-') || upper.startsWith('GEO ')) {
      // User typed the full account number (with or without dash)
      accountNumQuery =
          'GEO-${cleanedUpper.substring(3)}'; // strip GEO, re-add GEO-
    } else if (cleanedUpper.startsWith('GEO')) {
      accountNumQuery = 'GEO-${cleanedUpper.substring(3)}';
    } else if (RegExp(r'^[A-F0-9]{8}$').hasMatch(cleanedUpper)) {
      // User typed just the 8-char hex part
      accountNumQuery = 'GEO-$cleanedUpper';
    }

    if (accountNumQuery != null) {
      print('[searchUsers] account number query: $accountNumQuery');

      // Try exact match first
      final exact = await _client
          .from(AppConstants.profilesTable)
          .select(
              'id, username, display_name, avatar_url, account_number, is_online, last_seen')
          .eq('account_number', accountNumQuery)
          .neq('id', _client.auth.currentUser?.id ?? '')
          .maybeSingle();

      if (exact != null) {
        print('[searchUsers] exact match: ${exact['account_number']}');
        return [UserProfile.fromMap(exact)];
      }

      // Fallback: case-insensitive partial match on account_number
      print('[searchUsers] no exact match, trying ilike...');
      final fuzzy = await _client
          .from(AppConstants.profilesTable)
          .select(
              'id, username, display_name, avatar_url, account_number, is_online, last_seen')
          .ilike(
              'account_number', '%${accountNumQuery.replaceAll('GEO-', '')}%')
          .neq('id', _client.auth.currentUser?.id ?? '')
          .limit(3);
      print('[searchUsers] ilike result count: ${(fuzzy as List).length}');
      return (fuzzy as List)
          .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    // ── Username / display name search ────────────────────────────────────
    final res = await _client
        .from(AppConstants.profilesTable)
        .select(
            'id, username, display_name, avatar_url, account_number, is_online, last_seen')
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .neq('id', _client.auth.currentUser?.id ?? '')
        .limit(15);
    print('[searchUsers] username/name results: ${(res as List).length}');
    return (res as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Send a friend request.
  Future<void> sendFriendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    await _client.from(AppConstants.friendRequestsTable).insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
    });
  }

  /// Get pending requests RECEIVED by [userId], with sender profile joined.
  Future<List<FriendRequest>> getPendingRequests(String userId) async {
    final res = await _client
        .from(AppConstants.friendRequestsTable)
        .select(
          'id, sender_id, receiver_id, status, created_at, '
          'sender:sender_id(id, username, display_name, avatar_url, account_number, is_online, last_seen)',
        )
        .eq('receiver_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => FriendRequest.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Get all accepted friends via PostGIS RPC.
  Future<List<UserProfile>> getFriends(String userId) async {
    final res = await _client.rpc(
      'get_friends',
      params: {'user_id': userId},
    );
    return (res as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Accept or reject a friend request.
  Future<void> respondToFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    await _client.from(AppConstants.friendRequestsTable).update({
      'status': accept ? 'accepted' : 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  /// Returns true if the two users have an accepted friendship.
  Future<bool> areFriends(String userId1, String userId2) async {
    final res = await _client.rpc(
      'are_friends',
      params: {'user1_id': userId1, 'user2_id': userId2},
    );
    return res as bool? ?? false;
  }

  /// Returns current status of a request between two users, or null if none.
  /// Also returns the direction ('sent' or 'received') via the map.
  Future<Map<String, String>?> getFriendRequestStatus(
    String currentUserId,
    String otherUserId,
  ) async {
    final res = await _client
        .from(AppConstants.friendRequestsTable)
        .select('id, status, sender_id')
        .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),'
            'and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
        .maybeSingle();
    if (res == null) return null;
    final direction =
        (res['sender_id'] as String) == currentUserId ? 'sent' : 'received';
    return {
      'id': res['id'] as String,
      'status': res['status'] as String,
      'direction': direction,
    };
  }

  // ─── Notifications ───────────────────────────────────────────────────────

  /// Fetch all notifications for [userId], newest first.
  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final res = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(60);
      return (res as List)
          .map((e) => AppNotification.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[getNotifications] $e');
      return [];
    }
  }

  /// Mark a single notification as read.
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('[markNotificationRead] $e');
    }
  }

  /// Mark every notification for [userId] as read.
  Future<void> markAllNotificationsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('[markAllNotificationsRead] $e');
    }
  }

  /// Insert a new notification row (called by the sender's client or via DB trigger).
  Future<void> createNotification({
    required String userId,
    required String
        type, // 'new_message','friend_request','friend_accepted','wave'
    required String title,
    required String body,
    String? referenceId,
    String? actorName,
    String? actorAvatar,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'reference_id': referenceId,
        'actor_name': actorName,
        'actor_avatar': actorAvatar,
        'is_read': false,
      });
    } catch (e) {
      print('[createNotification] $e');
    }
  }

  /// Real-time stream: emits the full refreshed list whenever the
  /// notifications table changes for [userId].
  Stream<List<Map<String, dynamic>>> subscribeToNotifications(String userId) =>
      _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(60)
          .handleError(
              (e) => print('[Realtime Error] Notifications stream: $e'));
}
