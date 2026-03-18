import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/friends_provider.dart';
import '../../../models/user_profile.dart';
import '../../../models/friend_request_model.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<AuthProvider>().user?.id ?? '';
      if (userId.isNotEmpty) {
        context.read<FriendsProvider>().initialize(userId);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) {
      _searchCtrl.clear();
      context.read<FriendsProvider>().clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final friends = context.watch<FriendsProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            automaticallyImplyLeading: false,
            elevation: 0,
            title: const Text(
              'Friends',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            actions: [
              if (friends.pendingCount > 0) _Badge(count: friends.pendingCount),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _showSearch
                      ? Icons.close_rounded
                      : Icons.person_search_rounded,
                  color: AppColors.primary,
                ),
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: 4),
            ],
            bottom: _showSearch
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(68),
                    child: _SearchInputBar(
                      controller: _searchCtrl,
                      isSearching: friends.isSearching,
                      onSearch: (q) => friends.search(q),
                    ),
                  )
                : null,
          ),

          // ── Content ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Account‑number card
                _AccountNumberCard(
                  accountNumber: profile?.accountNumber,
                  username: profile?.username ?? '',
                ),

                // Search results
                if (_showSearch) ...[
                  const SizedBox(height: 24),
                  _SectionHeader('Search Results'),
                  const SizedBox(height: 10),
                  if (friends.isSearching)
                    const _LoadingRow()
                  else if (friends.searchResults.isEmpty &&
                      _searchCtrl.text.isNotEmpty)
                    const _EmptyHint(
                        'No user found. Try the full account number\n(e.g. GEO-3F8A2C1D)')
                  else
                    ...friends.searchResults.map(
                      (u) => _SearchResultCard(
                        user: u,
                        currentUserId: auth.user?.id ?? '',
                        onAddFriend: () async {
                          try {
                            await friends.sendFriendRequest(u.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Friend request sent to ${u.displayName ?? u.username}!'),
                                backgroundColor: AppColors.online,
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Could not send request. Already sent?'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],

                // Pending friend requests
                if (friends.pendingRequests.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(
                    'Friend Requests',
                    badge: friends.pendingCount,
                  ),
                  const SizedBox(height: 10),
                  ...friends.pendingRequests.map(
                    (req) => _FriendRequestCard(
                      request: req,
                      onAccept: () => friends.acceptRequest(req.id),
                      onReject: () => friends.rejectRequest(req.id),
                    ),
                  ),
                ],

                // Friends list
                const SizedBox(height: 28),
                _SectionHeader(
                  'Friends',
                  badge:
                      friends.friends.isEmpty ? null : friends.friends.length,
                ),
                const SizedBox(height: 10),
                if (friends.isLoading)
                  const _LoadingRow()
                else if (friends.friends.isEmpty)
                  const _EmptyHint(
                    'No friends yet.\nShare your account number or search to add friends.',
                  )
                else
                  ...friends.friends.map((u) => _FriendCard(user: u)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account number card ─────────────────────────────────────────────────────
class _AccountNumberCard extends StatelessWidget {
  final String? accountNumber;
  final String username;
  const _AccountNumberCard(
      {required this.accountNumber, required this.username});

  @override
  Widget build(BuildContext context) {
    final num = accountNumber ?? '...';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A4A), Color(0xFF0D1B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Your Account Number',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  num,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Copy button
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: num));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account number copied!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.textMuted, size: 14),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Share this number so others can add you as a friend.\nYour email and phone are never revealed.',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Search input bar ────────────────────────────────────────────────────────
class _SearchInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onSearch;
  const _SearchInputBar(
      {required this.controller,
      required this.isSearching,
      required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onSearch,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Enter account number (GEO-XXXXXXXX) or username…',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textMuted),
          suffixIcon: isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}

// ── Search result card ──────────────────────────────────────────────────────
class _SearchResultCard extends StatefulWidget {
  final UserProfile user;
  final String currentUserId;
  final VoidCallback onAddFriend;
  const _SearchResultCard(
      {required this.user,
      required this.currentUserId,
      required this.onAddFriend});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _Avatar(user: widget.user, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.displayName ?? widget.user.username,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.accountNumber ?? '@${widget.user.username}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _sent
                  ? Container(
                      key: const ValueKey('sent'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('Sent ✓',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                  : ElevatedButton.icon(
                      key: const ValueKey('add'),
                      onPressed: () {
                        setState(() => _sent = true);
                        widget.onAddFriend();
                      },
                      icon: const Icon(Icons.person_add_rounded, size: 14),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friend request card ─────────────────────────────────────────────────────
class _FriendRequestCard extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _FriendRequestCard(
      {required this.request, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final sender = request.sender;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          sender != null
              ? _Avatar(user: sender, radius: 24)
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceVariant,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender?.displayName ?? sender?.username ?? 'Unknown',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  sender?.accountNumber ?? 'Wants to be friends',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Reject
          GestureDetector(
            onTap: onReject,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: AppColors.error, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Accept
          GestureDetector(
            onTap: onAccept,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friend card ─────────────────────────────────────────────────────────────
class _FriendCard extends StatefulWidget {
  final UserProfile user;
  const _FriendCard({required this.user});

  @override
  State<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<_FriendCard> {
  bool _loading = false;

  Future<void> _openChat(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id ?? '';
    if (currentUserId.isEmpty) return;

    setState(() => _loading = true);
    try {
      final svc = SupabaseService();
      final convId = await svc.getOrCreateConversation(
        userId1: currentUserId,
        userId2: widget.user.id,
      );
      if (!context.mounted) return;
      context.push(
        '/chat/$convId',
        extra: {
          'name': widget.user.displayName ?? widget.user.username,
          'userId': widget.user.id,
          'avatar': widget.user.avatarUrl ?? '',
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _Avatar(user: widget.user, radius: 24),
              if (widget.user.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.displayName ?? widget.user.username,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.isOnline
                      ? 'Online now'
                      : widget.user.accountNumber ?? '@${widget.user.username}',
                  style: TextStyle(
                      color: widget.user.isOnline
                          ? AppColors.online
                          : AppColors.textMuted,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : () => _openChat(context),
              icon: _loading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.chat_bubble_rounded, size: 13),
              label: Text(_loading ? '' : 'Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final UserProfile user;
  final double radius;
  const _Avatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initial = (user.displayName ?? user.username)[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceVariant,
      backgroundImage:
          user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
      child: user.avatarUrl == null
          ? Text(initial,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: radius * 0.75,
                  fontWeight: FontWeight.w700))
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? badge;
  const _SectionHeader(this.title, {this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
