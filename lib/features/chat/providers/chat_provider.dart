import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/encryption_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../models/message_model.dart';

class ChatProvider extends ChangeNotifier {
  final _svc = SupabaseService();
  final _enc = EncryptionService();
  final _push = PushNotificationService.instance;

  bool _encryptionEnabled = true;
  bool get encryptionEnabled => _encryptionEnabled;

  Stream<List<MessageModel>> messagesStream(String conversationId) =>
      _svc.subscribeToMessages(conversationId).map((list) {
        final msgs = list.map((e) => MessageModel.fromMap(e)).toList();
        msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return msgs;
      });

  /// Send text message + FCM push + in-app notification to recipient.
  Future<void> sendText({
    required String conversationId,
    required String senderId,
    required String content,
    String? recipientId,
    String? senderName,
  }) async {
    String finalContent = content;
    bool encrypted = false;

    if (_encryptionEnabled) {
      try {
        final key = await _enc.getOrCreateKey(conversationId);
        finalContent = await _enc.encrypt(content, key);
        encrypted = true;
      } catch (_) {}
    }

    await _svc.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      type: MessageType.text,
      content: finalContent,
      isEncrypted: encrypted,
    );

    if (recipientId != null && recipientId.isNotEmpty) {
      final preview =
          content.length > 60 ? '${content.substring(0, 60)}…' : content;
      await _dispatchPush(
        recipientId: recipientId,
        title: senderName ?? 'New message',
        body: preview,
        type: 'new_message',
        referenceId: conversationId,
        senderName: senderName,
      );
    }
  }

  Future<void> sendImage({
    required String conversationId,
    required String senderId,
    required List<int> bytes,
    required String extension,
    String? recipientId,
    String? senderName,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final url = await _svc.uploadMessageMedia(
      conversationId: conversationId,
      messageId: id,
      bytes: bytes,
      extension: extension,
    );
    await _svc.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      type: MessageType.image,
      mediaUrl: url,
    );

    if (recipientId != null && recipientId.isNotEmpty) {
      await _dispatchPush(
        recipientId: recipientId,
        title: senderName ?? 'New photo',
        body: '📷 Sent you a photo',
        type: 'new_message',
        referenceId: conversationId,
        senderName: senderName,
      );
    }
  }

  Future<void> sendLocation({
    required String conversationId,
    required String senderId,
    required double lat,
    required double lng,
    String? recipientId,
    String? senderName,
  }) async {
    await _svc.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      type: MessageType.locationShare,
      locationLat: lat,
      locationLng: lng,
    );

    if (recipientId != null && recipientId.isNotEmpty) {
      await _dispatchPush(
        recipientId: recipientId,
        title: senderName ?? 'New location',
        body: '📍 Shared their location with you',
        type: 'new_message',
        referenceId: conversationId,
        senderName: senderName,
      );
    }
  }

  /// Looks up the recipient's FCM token then sends both a push notification
  /// (via Edge Function) and an in-app notification row.
  Future<void> _dispatchPush({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    String? referenceId,
    String? senderName,
  }) async {
    // 1. In-app notification (realtime feed)
    await _svc.createNotification(
      userId: recipientId,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      actorName: senderName,
    );

    // 2. FCM push (appears in the tray even when app is closed)
    final fcmToken = await _svc.getFcmToken(recipientId);
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
  }

  Future<String> resolveContent(MessageModel msg) async {
    if (!msg.isEncrypted || msg.content == null) return msg.content ?? '';
    try {
      final key = await _enc.getOrCreateKey(msg.conversationId);
      return await _enc.decrypt(msg.content!, key) ?? '[Encrypted]';
    } catch (_) {
      return '[Encrypted]';
    }
  }

  void toggleEncryption() {
    _encryptionEnabled = !_encryptionEnabled;
    notifyListeners();
  }
}
