import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/message_model.dart';
import '../providers/chat_provider.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final ChatProvider chatProvider;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatProvider,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String? _resolvedContent;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.text) _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final content = await widget.chatProvider.resolveContent(widget.message);
    if (mounted)
      setState(() {
        _resolvedContent = content;
        _resolving = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final msg = widget.message;

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildBubble(msg, isMe),
          const SizedBox(height: 3),
          _buildMeta(msg, isMe),
        ],
      ),
    );
  }

  Widget _buildBubble(MessageModel msg, bool isMe) {
    Widget content;
    switch (msg.type) {
      case MessageType.image:
        content = _ImageBubble(url: msg.mediaUrl, isMe: isMe);
        break;
      case MessageType.locationShare:
        content = _LocationBubble(
          lat: msg.locationLat,
          lng: msg.locationLng,
          isMe: isMe,
        );
        break;
      case MessageType.system:
        return _SystemBubble(content: msg.content ?? '');
      default:
        content = _TextBubble(
          text: _resolving ? null : (_resolvedContent ?? msg.content ?? ''),
          isMe: isMe,
          isEncrypted: msg.isEncrypted,
        );
    }

    return Container(
      decoration: BoxDecoration(
        color: isMe ? AppColors.messageSelf : AppColors.messageOther,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        child: content,
      ),
    );
  }

  Widget _buildMeta(MessageModel msg, bool isMe) {
    final time = _formatTime(msg.createdAt);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (msg.isEncrypted) ...[
          const Icon(Icons.lock_rounded, color: AppColors.encrypted, size: 10),
          const SizedBox(width: 3),
        ],
        Text(
          time,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Bubble Sub-types ─────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final String? text;
  final bool isMe;
  final bool isEncrypted;

  const _TextBubble({this.text, required this.isMe, required this.isEncrypted});

  @override
  Widget build(BuildContext context) {
    if (text == null) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 40,
          height: 14,
          child: LinearProgressIndicator(color: Colors.white38),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        text!,
        style: TextStyle(
          color: isMe ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final String? url;
  final bool isMe;

  const _ImageBubble({this.url, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        width: 200,
        height: 160,
        color: AppColors.surfaceVariant,
        child: const Icon(
          Icons.broken_image_rounded,
          color: AppColors.textMuted,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: 220,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: 220,
        height: 160,
        color: AppColors.surfaceVariant,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (_, __, ___) =>
          const Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
    );
  }
}

class _LocationBubble extends StatelessWidget {
  final double? lat;
  final double? lng;
  final bool isMe;

  const _LocationBubble({this.lat, this.lng, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text('Location unavailable',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final latStr = lat!.toStringAsFixed(5);
    final lngStr = lng!.toStringAsFixed(5);

    Future<void> openMaps() async {
      // Try Google Maps app first, then fall back to browser
      final googleMapsUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
        if (await canLaunchUrl(geoUri)) await launchUrl(geoUri);
      }
    }

    return GestureDetector(
      onTap: openMaps,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map placeholder with gradient + ripple
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openMaps,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMe
                          ? [
                              Colors.white.withOpacity(0.20),
                              Colors.white.withOpacity(0.08),
                            ]
                          : [
                              AppColors.primary.withOpacity(0.18),
                              AppColors.primary.withOpacity(0.05),
                            ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: isMe ? Colors.white : AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to open in Maps',
                          style: TextStyle(
                            color: isMe
                                ? Colors.white.withOpacity(0.85)
                                : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.my_location_rounded,
                    size: 12,
                    color: isMe
                        ? Colors.white.withOpacity(0.7)
                        : AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$latStr, $lngStr',
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.85)
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: isMe
                      ? Colors.white.withOpacity(0.6)
                      : AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final String content;
  const _SystemBubble({required this.content});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            content,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
}
