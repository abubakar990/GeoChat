import 'user_profile.dart';

/// Represents a friend request between two users.
class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;

  /// Populated when fetching pending received requests (joined from profiles).
  final UserProfile? sender;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.sender,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    return FriendRequest(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      sender: map['sender'] != null
          ? UserProfile.fromMap(map['sender'] as Map<String, dynamic>)
          : null,
    );
  }
}
