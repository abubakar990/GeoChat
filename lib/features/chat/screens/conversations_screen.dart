import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/conversation_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';

// Key used to persist hidden conversation IDs per user
String _hiddenKey(String userId) => 'hidden_convs_$userId';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _svc = SupabaseService();
  final _searchCtrl = TextEditingController();

  List<_ConvWithUser> _allItems = [];
  List<_ConvWithUser> _filtered = [];
  Set<String> _hiddenIds = {};
  bool _loading = true;
  bool _showSearch = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = context.read<AuthProvider>().user?.id ?? '';
      if (userId.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // Load hidden IDs from local prefs
      final prefs = await SharedPreferences.getInstance();
      final hiddenList = prefs.getStringList(_hiddenKey(userId)) ?? [];
      _hiddenIds = hiddenList.toSet();

      final convs = await _svc.getConversations(userId);

      final items = await Future.wait(convs.map((c) async {
        final other = await _svc.getOtherParticipant(
          participantIds: c.participantIds,
          currentUserId: userId,
        );
        final lastMsgMap = await _svc.getLastMessage(c.id);
        final lastMsg = lastMsgMap != null ? MessageModel.fromMap(lastMsgMap) : null;
        return _ConvWithUser(conv: c, other: other, lastMessage: lastMsg);
      }));

      if (mounted) {
        setState(() {
          _allItems = items;
          _loading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allItems.where((item) {
        // Skip hidden ones
        if (_hiddenIds.contains(item.conv.id)) return false;
        // If no search query, show all
        if (q.isEmpty) return true;
        final name = (item.other?.displayName ?? item.other?.username ?? '')
            .toLowerCase();
        final acct = (item.other?.accountNumber ?? '').toLowerCase();
        return name.contains(q) || acct.contains(q);
      }).toList();
    });
  }

  Future<void> _hideConversation(String convId) async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    if (userId.isEmpty) return;

    _hiddenIds.add(convId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenKey(userId), _hiddenIds.toList());
    _applyFilter();
  }

  Future<void> _unhideAll() async {
    final userId = context.read<AuthProvider>().user?.id ?? '';
    if (userId.isEmpty) return;
    _hiddenIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenKey(userId));
    _applyFilter();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) {
      _searchCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search conversations…',
                  hintStyle:
                      const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textMuted, size: 20),
                ),
              )
            : Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF2979FF)],
                    ).createShader(bounds),
                    child: const Text('Chats',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22)),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppColors.primary, size: 20),
            ),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : _filtered.isEmpty
                  ? _showSearch
                      ? _NoResultsState(query: _searchCtrl.text)
                      : _EmptyState(
                          hiddenCount: _hiddenIds.length,
                          onUnhide: _hiddenIds.isNotEmpty ? _unhideAll : null,
                        )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => Padding(
                          padding: const EdgeInsets.only(left: 80),
                          child: Container(
                            height: 0.5,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        itemBuilder: (ctx, i) {
                          final item = _filtered[i];
                          return _DismissibleTile(
                            key: ValueKey(item.conv.id),
                            item: item,
                            onDismiss: () => _hideConversation(item.conv.id),
                            onTap: () {
                              final other = item.other;
                              ctx.push(
                                '/chat/${item.conv.id}',
                                extra: {
                                  'name': other?.displayName ??
                                      other?.username ??
                                      'User',
                                  'userId': other?.id ?? '',
                                  'avatar': other?.avatarUrl ?? '',
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── Data holder ──────────────────────────────────────────────────────────────
class _ConvWithUser {
  final ConversationModel conv;
  final UserProfile? other;
  final MessageModel? lastMessage;
  const _ConvWithUser({required this.conv, required this.other, this.lastMessage});
}

// ── Swipeable tile ───────────────────────────────────────────────────────────
class _DismissibleTile extends StatelessWidget {
  final _ConvWithUser item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _DismissibleTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${item.conv.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x00000000), Color(0xFFE53935)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text('Remove',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Remove chat?',
                    style: TextStyle(color: AppColors.textPrimary)),
                content: const Text(
                  'This chat will be hidden for you only.\nThe other person will still see it.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Remove',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDismiss(),
      child: _ConversationTile(item: item, onTap: onTap),
    );
  }
}

// ── Conversation tile ────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final _ConvWithUser item;
  final VoidCallback onTap;
  const _ConversationTile({required this.item, required this.onTap});

  static const _avatarGradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [Color(0xFF43e97b), Color(0xFF38f9d7)],
    [Color(0xFFfa709a), Color(0xFFfee140)],
    [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
  ];

  @override
  Widget build(BuildContext context) {
    final other = item.other;
    final name = other?.displayName ?? other?.username ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isOnline = other?.isOnline ?? false;

    // Pick a gradient based on name hash
    final gradientIdx = name.hashCode.abs() % _avatarGradients.length;
    final gradientColors = _avatarGradients[gradientIdx];

    // Use last message time if available, otherwise conversation time
    final lastMsg = item.lastMessage;
    final timeSource = lastMsg?.createdAt ?? item.conv.updatedAt ?? item.conv.createdAt;
    final timeStr = _formatTime(timeSource);

    // Build subtitle from last message
    String subtitle;
    if (lastMsg != null) {
      switch (lastMsg.type) {
        case MessageType.image:
          subtitle = '📷 Photo';
          break;
        case MessageType.locationShare:
          subtitle = '📍 Location';
          break;
        case MessageType.system:
          subtitle = lastMsg.content ?? 'System message';
          break;
        default:
          subtitle = lastMsg.isEncrypted
              ? '🔒 Encrypted message'
              : (lastMsg.content ?? '');
      }
    } else {
      subtitle = 'Tap to start chatting';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.05),
        highlightColor: AppColors.primary.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar with gradient + online dot
              Stack(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (other?.avatarUrl?.isNotEmpty != true)
                          ? LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: (other?.avatarUrl?.isNotEmpty == true)
                        ? ClipOval(
                            child: Image.network(
                              other!.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(initial,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20)),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(initial,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20)),
                          ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.background, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.online.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Name + last message preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.2)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(timeStr,
                        style: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Empty / No Results / Error states ───────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final int hiddenCount;
  final VoidCallback? onUnhide;
  const _EmptyState({required this.hiddenCount, this.onUnhide});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textMuted, size: 56),
            const SizedBox(height: 16),
            const Text('No conversations yet',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
                'Start a chat from your Friends list\nor tap someone on the map',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center),
            if (hiddenCount > 0 && onUnhide != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onUnhide,
                icon: const Icon(Icons.restore_rounded,
                    size: 16, color: AppColors.primary),
                label: Text('Restore $hiddenCount hidden chat(s)',
                    style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      );
}

class _NoResultsState extends StatelessWidget {
  final String query;
  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text('No results for "$query"',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(error,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
}
