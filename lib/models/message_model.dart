enum MessageType { text, image, locationShare, system }

extension MessageTypeExt on MessageType {
  String get value {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.locationShare:
        return 'location_share';
      case MessageType.system:
        return 'system';
    }
  }

  static MessageType fromString(String v) {
    switch (v) {
      case 'image':
        return MessageType.image;
      case 'location_share':
        return MessageType.locationShare;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final double? locationLat;
  final double? locationLng;
  final bool isEncrypted;
  final DateTime createdAt;
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.locationLat,
    this.locationLng,
    this.isEncrypted = false,
    required this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        senderId: map['sender_id'] as String,
        type: MessageTypeExt.fromString(map['type'] as String? ?? 'text'),
        content: map['content'] as String?,
        mediaUrl: map['media_url'] as String?,
        locationLat: map['location_lat'] != null
            ? (map['location_lat'] as num).toDouble()
            : null,
        locationLng: map['location_lng'] != null
            ? (map['location_lng'] as num).toDouble()
            : null,
        isEncrypted: map['is_encrypted'] as bool? ?? false,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        isRead: map['is_read'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type.value,
        'content': content,
        'media_url': mediaUrl,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'is_encrypted': isEncrypted,
      };
}
