import 'user_profile.dart';
import 'message_model.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final MessageModel? lastMessage;
  final UserProfile? otherUser;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.otherUser,
    required this.createdAt,
    this.updatedAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map) =>
      ConversationModel(
        id: map['id'] as String,
        participantIds: List<String>.from(
          map['participant_ids'] as List? ?? [],
        ),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
        unreadCount: map['unread_count'] as int? ?? 0,
      );

  ConversationModel copyWith({
    MessageModel? lastMessage,
    UserProfile? otherUser,
    int? unreadCount,
  }) => ConversationModel(
    id: id,
    participantIds: participantIds,
    lastMessage: lastMessage ?? this.lastMessage,
    otherUser: otherUser ?? this.otherUser,
    createdAt: createdAt,
    updatedAt: updatedAt,
    unreadCount: unreadCount ?? this.unreadCount,
  );
}
