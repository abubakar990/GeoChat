enum NotificationType {
  newMessage,
  friendRequest,
  friendAccepted,
  wave,
  nearbyUser,
}

class AppNotification {
  final String id;
  final String userId; // recipient
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// Optional payload for deep-linking
  final String? referenceId; // e.g. conversationId, friendRequestId

  /// Actor who triggered the notification
  final String? actorName;
  final String? actorAvatar;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
    this.actorName,
    this.actorAvatar,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        referenceId: referenceId,
        actorName: actorName,
        actorAvatar: actorAvatar,
      );

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      type: _typeFromString(m['type'] as String? ?? ''),
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      isRead: m['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      referenceId: m['reference_id'] as String?,
      actorName: m['actor_name'] as String?,
      actorAvatar: m['actor_avatar'] as String?,
    );
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'new_message':
        return NotificationType.newMessage;
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'friend_accepted':
        return NotificationType.friendAccepted;
      case 'wave':
        return NotificationType.wave;
      case 'nearby_user':
        return NotificationType.nearbyUser;
      default:
        return NotificationType.newMessage;
    }
  }
}
