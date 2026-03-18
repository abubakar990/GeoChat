import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/chat_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/message_model.dart';
import '../../alerts/widgets/system_alert_overlay.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;
  final String? otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
    this.otherUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollCtrl = ScrollController();
  final _alertKey = GlobalKey<SystemAlertOverlayState>();
  String? _liveDistance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alertKey.currentState?.startListening();
      _trackDistance();
    });
  }

  /// Subscribes to local position updates and fetches the other user's
  /// last known location from Supabase to compute a live distance.
  void _trackDistance() {
    LocationService().stream.listen((myPos) async {
      if (!mounted) return;
      try {
        final otherProfile =
            await SupabaseService().getProfile(widget.otherUserId);
        if (otherProfile?.latitude != null && otherProfile?.longitude != null) {
          final dist = LocationService.distanceBetween(
            myPos.latitude,
            myPos.longitude,
            otherProfile!.latitude!,
            otherProfile.longitude!,
          );
          if (mounted)
            setState(
                () => _liveDistance = LocationService.formatDistance(dist));
        }
      } catch (_) {}
    });
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendText(String text) async {
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    if (auth.user == null) return;
    await chat.sendText(
      conversationId: widget.conversationId,
      senderId: auth.user!.id,
      content: text,
      recipientId: widget.otherUserId,
      senderName:
          auth.profile?.displayName ?? auth.profile?.username ?? 'Someone',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _handleSendImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (xFile == null || !mounted) return;

    final bytes = await xFile.readAsBytes();
    final ext = xFile.name.split('.').last;
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    if (auth.user == null) return;

    await chat.sendImage(
      conversationId: widget.conversationId,
      senderId: auth.user!.id,
      bytes: bytes,
      extension: ext,
      recipientId: widget.otherUserId,
      senderName:
          auth.profile?.displayName ?? auth.profile?.username ?? 'Someone',
    );
  }

  Future<void> _handleSendLocation() async {
    final pos = LocationService().lastPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available yet'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    if (auth.user == null) return;
    await chat.sendLocation(
      conversationId: widget.conversationId,
      senderId: auth.user!.id,
      lat: pos.latitude,
      lng: pos.longitude,
      recipientId: widget.otherUserId,
      senderName:
          auth.profile?.displayName ?? auth.profile?.username ?? 'Someone',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();
    final myId = auth.user?.id ?? '';

    return SystemAlertOverlay(
      key: _alertKey,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(chat),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: chat.messagesStream(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  final messages = snapshot.data ?? [];
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom(),
                  );
                  if (messages.isEmpty) {
                    return _EmptyState(name: widget.otherUserName);
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = myId.isNotEmpty && msg.senderId == myId;
                      final showDate = i == 0 ||
                          !_isSameDay(messages[i - 1].createdAt, msg.createdAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _DateDivider(date: msg.createdAt),
                          MessageBubble(
                            message: msg,
                            isMe: isMe,
                            chatProvider: chat,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            ChatInput(
              onSendText: _handleSendText,
              onSendImage: _handleSendImage,
              onSendLocation: _handleSendLocation,
              encryptionEnabled: chat.encryptionEnabled,
              onToggleEncryption: chat.toggleEncryption,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatProvider chat) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            backgroundImage: (widget.otherUserAvatar?.isNotEmpty == true)
                ? NetworkImage(widget.otherUserAvatar!)
                : null,
            child: (widget.otherUserAvatar?.isNotEmpty == true)
                ? null
                : Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: chat.encryptionEnabled
                            ? AppColors.encrypted
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      chat.encryptionEnabled ? 'Encrypted' : 'Unencrypted',
                      style: TextStyle(
                        color: chat.encryptionEnabled
                            ? AppColors.encrypted
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_liveDistance != null) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _liveDistance!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            chat.encryptionEnabled
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
            color: chat.encryptionEnabled
                ? AppColors.encrypted
                : AppColors.textMuted,
            size: 20,
          ),
          onPressed: chat.toggleEncryption,
          tooltip: chat.encryptionEnabled ? 'Disable E2EE' : 'Enable E2EE',
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }
}

class _EmptyState extends StatelessWidget {
  final String name;
  const _EmptyState({required this.name});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start chatting with $name',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.encrypted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.encrypted.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded,
                      color: AppColors.encrypted, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'Messages are end-to-end encrypted',
                    style: TextStyle(color: AppColors.encrypted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Expanded(child: Divider(color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _label(),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.divider)),
          ],
        ),
      );
}
