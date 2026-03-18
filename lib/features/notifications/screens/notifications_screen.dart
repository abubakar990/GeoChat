import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _NotificationsHeader(provider: provider)),

          if (notifications.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else ...[
            // Group by today / yesterday / earlier
            ..._buildGroupedSections(context, notifications, provider),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSections(
    BuildContext context,
    List<AppNotification> notifications,
    NotificationProvider provider,
  ) {
    final now = DateTime.now();
    final today = <AppNotification>[];
    final yesterday = <AppNotification>[];
    final earlier = <AppNotification>[];

    for (final n in notifications) {
      final diff = now.difference(n.createdAt);
      if (diff.inDays == 0) {
        today.add(n);
      } else if (diff.inDays == 1) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    final sections = <Widget>[];

    if (today.isNotEmpty) {
      sections.add(_sectionHeader('Today'));
      sections.add(_notifList(context, today, provider));
    }
    if (yesterday.isNotEmpty) {
      sections.add(_sectionHeader('Yesterday'));
      sections.add(_notifList(context, yesterday, provider));
    }
    if (earlier.isNotEmpty) {
      sections.add(_sectionHeader('Earlier'));
      sections.add(_notifList(context, earlier, provider));
    }

    return sections;
  }

  Widget _sectionHeader(String label) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      );

  Widget _notifList(
    BuildContext context,
    List<AppNotification> items,
    NotificationProvider provider,
  ) =>
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _NotifCard(
              notification: items[i],
              onTap: () => _handleTap(context, items[i], provider),
            ).animate().fadeIn(delay: (i * 40).ms).slideX(begin: 0.05),
            childCount: items.length,
          ),
        ),
      );

  void _handleTap(
    BuildContext context,
    AppNotification n,
    NotificationProvider provider,
  ) {
    // Mark as read
    if (!n.isRead) provider.markRead(n.id);

    // Deep-link by type
    switch (n.type) {
      case NotificationType.newMessage:
        if (n.referenceId != null) {
          context.push('/chat/${n.referenceId}',
              extra: {'name': n.actorName ?? 'User', 'userId': ''});
        }
        break;
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        // Navigate to friends tab
        break;
      default:
        break;
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _NotificationsHeader extends StatelessWidget {
  final NotificationProvider provider;
  const _NotificationsHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1F35),
            const Color(0xFF111827),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded,
                    color: AppColors.primary, size: 22),
                if (provider.hasUnread)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0D1F35), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notifications',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                if (provider.unreadCount > 0)
                  Text(
                    '${provider.unreadCount} unread',
                    style:
                        const TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (provider.hasUnread)
            GestureDetector(
              onTap: provider.markAllRead,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3), width: 1),
                ),
                child: const Text('Mark all read',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotifCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _NotifMeta.of(notification.type);
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withOpacity(0.07)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withOpacity(0.2)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: meta.color.withOpacity(0.3), width: 1),
                ),
                child: Icon(meta.icon, color: meta.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primary.withOpacity(0.5),
                                    blurRadius: 6)
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeago.format(notification.createdAt),
                      style: TextStyle(
                          color: AppColors.textMuted.withOpacity(0.55),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notification metadata ─────────────────────────────────────────────────────
class _NotifMeta {
  final IconData icon;
  final Color color;

  const _NotifMeta(this.icon, this.color);

  static _NotifMeta of(NotificationType type) {
    switch (type) {
      case NotificationType.newMessage:
        return const _NotifMeta(Icons.chat_bubble_rounded, Color(0xFF5BC8F5));
      case NotificationType.friendRequest:
        return const _NotifMeta(Icons.person_add_rounded, Color(0xFF7C83FD));
      case NotificationType.friendAccepted:
        return const _NotifMeta(Icons.people_rounded, Color(0xFF81C784));
      case NotificationType.wave:
        return const _NotifMeta(Icons.waving_hand_rounded, Color(0xFFFFB74D));
      case NotificationType.nearbyUser:
        return const _NotifMeta(Icons.location_on_rounded, Color(0xFFFB8C6F));
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_rounded,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No notifications yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'You\'ll see messages, friend requests,\nand waves here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }
}
