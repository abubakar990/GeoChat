import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/discovery_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../alerts/widgets/system_alert_overlay.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/user_profile.dart';
import '../../../core/services/location_service.dart';
import '../../friends/providers/friends_provider.dart';
import '../../notifications/providers/notification_provider.dart';

class DiscoveryMapScreen extends StatefulWidget {
  const DiscoveryMapScreen({super.key});

  @override
  State<DiscoveryMapScreen> createState() => _DiscoveryMapScreenState();
}

class _DiscoveryMapScreenState extends State<DiscoveryMapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final _alertKey = GlobalKey<SystemAlertOverlayState>();
  final Set<Marker> _markers = {};
  bool _mapReady = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const String _mapStyle = '''[
    {"elementType":"geometry","stylers":[{"color":"#0D1B2E"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#4A6480"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#080F1A"}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#152030"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#080F1A"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#3A5272"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1B3048"}]},
    {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#080F1A"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#060D16"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#1A3050"}]}
  ]''';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alertKey.currentState?.startListening();
      context.read<DiscoveryProvider>().init(
            context.read<AuthProvider>().user?.id ?? '',
          );
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _buildMarkers(List<UserProfile> users) async {
    final newMarkers = <Marker>{};
    for (final user in users) {
      if (user.latitude == null || user.longitude == null) continue;
      final icon = await _buildAvatarMarker(user);
      newMarkers.add(Marker(
        markerId: MarkerId(user.id),
        position: LatLng(user.latitude!, user.longitude!),
        icon: icon,
        onTap: () => _onMarkerTapped(user),
      ));
    }
    if (mounted)
      setState(() => _markers
        ..clear()
        ..addAll(newMarkers));
  }

  Future<BitmapDescriptor> _buildAvatarMarker(UserProfile user) async {
    const size = 88.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Glow ring
    final glowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, glowPaint);

    // Blue ring
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      Paint()..color = AppColors.primary,
    );
    // Inner white circle
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 6,
      Paint()..color = const Color(0xFF1A2A3E),
    );

    // Initial letter
    final tp = TextPainter(
      text: TextSpan(
        text: (user.displayName ?? user.username)[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size / 2 - tp.width / 2, size / 2 - tp.height / 2),
    );

    // Online indicator
    if (user.isOnline) {
      canvas.drawCircle(Offset(size - 16, size - 16), 10,
          Paint()..color = const Color(0xFF0D1B2E));
      canvas.drawCircle(
          Offset(size - 16, size - 16), 8, Paint()..color = AppColors.online);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _onMarkerTapped(UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserQuickCard(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<DiscoveryProvider>();
    final myPos = discovery.currentPosition;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildMarkers(discovery.nearbyUsers);
    });

    return SystemAlertOverlay(
      key: _alertKey,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Full screen map ──────────────────────────────────────────
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: myPos != null
                      ? LatLng(myPos.latitude, myPos.longitude)
                      : const LatLng(37.7749, -122.4194),
                  zoom: 14,
                ),
                onMapCreated: (ctrl) {
                  _mapController = ctrl;
                  ctrl.setMapStyle(_mapStyle);
                  setState(() => _mapReady = true);
                },
                markers: discovery.isLocationSharing ? _markers : {},
                myLocationEnabled: myPos != null,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),

            // Map loading shimmer
            if (!_mapReady)
              Positioned.fill(
                child: Container(
                  color: AppColors.background,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),




            // ── Location OFF overlay ─────────────────────────────────────
            if (!discovery.isLocationSharing)
              Positioned.fill(
                child: _LocationDisabledOverlay(
                  onEnable: () => discovery.toggleLocationSharing(),
                ),
              ),

            // ── Nearby Now bottom panel ──────────────────────────────────
            if (discovery.isLocationSharing)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _NearbyNowPanel(
                  users: discovery.nearbyUsers,
                  onUserTap: _onMarkerTapped,
                  pulseAnim: _pulseAnim,
                ),
              ),

            // ── Re-center FAB ────────────────────────────────────────────
            if (_mapReady && discovery.isLocationSharing)
              Positioned(
                right: 16,
                bottom: discovery.nearbyUsers.isEmpty ? 100 : 250,
                child: _MapFAB(
                  icon: Icons.my_location_rounded,
                  onTap: () async {
                    // Re-request permissions just in case
                    await LocationService().requestPermissions();

                    final pos =
                        myPos ?? await LocationService().getCurrentPosition();
                    if (pos != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(pos.latitude, pos.longitude),
                          15,
                        ),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}



// ── Map FAB ─────────────────────────────────────────────────────────────────
class _MapFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFAB({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2979FF), // Blue background
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2), // White border
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26), // White target icon
      ),
    );
  }
}

// ── Location disabled overlay ────────────────────────────────────────────────
class _LocationDisabledOverlay extends StatelessWidget {
  final VoidCallback onEnable;
  const _LocationDisabledOverlay({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: AppColors.background.withOpacity(0.88),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.location_off_rounded,
                        color: AppColors.primary, size: 38),
                  ),
                  const SizedBox(height: 28),
                  const Text('Location sharing is off',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'Enable location sharing to discover\nnearby users and appear on their map.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onEnable,
                      icon: const Icon(Icons.location_on_rounded, size: 20),
                      label: const Text('Enable Location Sharing',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        shadowColor: AppColors.primary.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded,
                          size: 12,
                          color: AppColors.textMuted.withOpacity(0.6)),
                      const SizedBox(width: 5),
                      const Text(
                        'Your location is never shared without your consent.',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nearby Now panel ─────────────────────────────────────────────────────────
class _NearbyNowPanel extends StatelessWidget {
  final List<UserProfile> users;
  final ValueChanged<UserProfile> onUserTap;
  final Animation<double> pulseAnim;

  const _NearbyNowPanel({
    required this.users,
    required this.onUserTap,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.82),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.07), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: pulseAnim,
                      builder: (_, __) => Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.online.withOpacity(pulseAnim.value),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.online
                                  .withOpacity(pulseAnim.value * 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Nearby Now',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        )),
                    const SizedBox(width: 8),
                    if (users.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${users.length}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Cards
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'No one nearby yet — move around to discover people.',
                        style: TextStyle(
                            color: AppColors.textMuted.withOpacity(0.7),
                            fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    itemCount: users.length,
                    itemBuilder: (_, i) => _NearbyUserCard(
                      user: users[i],
                      onTap: () => onUserTap(users[i]),
                    ),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nearby user card ─────────────────────────────────────────────────────────
class _NearbyUserCard extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;

  const _NearbyUserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final distText = user.distance != null
        ? '${user.distance!.toStringAsFixed(0)}m away'
        : 'Nearby';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: (user.avatarUrl?.isNotEmpty == true)
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: (user.avatarUrl?.isNotEmpty == true)
                        ? null
                        : Text(
                            (user.displayName ?? user.username)[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (user.isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user.displayName ?? user.username,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.near_me_rounded,
                    size: 10, color: AppColors.primary),
                const SizedBox(width: 3),
                Text(distText,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            _WaveButton(user: user),
          ],
        ),
      ),
    );
  }
}

// ── Wave button ──────────────────────────────────────────────────────────────
class _WaveButton extends StatefulWidget {
  final UserProfile user;
  const _WaveButton({required this.user});

  @override
  State<_WaveButton> createState() => _WaveButtonState();
}

class _WaveButtonState extends State<_WaveButton>
    with SingleTickerProviderStateMixin {
  bool _waved = false;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    if (_waved) return; // avoid spam
    setState(() => _waved = true);
    _bounceCtrl.forward(from: 0);

    // Send the wave notification
    try {
      final notifProvider = context.read<NotificationProvider>();
      final auth = context.read<AuthProvider>();
      final myProfile = auth.user;
      final actorName = myProfile?.userMetadata?['display_name'] ?? 'Someone';

      await notifProvider.sendNotification(
        toUserId: widget.user.id,
        type: 'wave',
        title: '$actorName waved at you!',
        body: '👋 Say hi back!',
        actorName: actorName,
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _waved
              ? AppColors.surfaceVariant.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _waved ? Colors.transparent : Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _bounceAnim,
              child: const Text('👋', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Text(
              _waved ? 'Waved!' : 'Wave',
              style: TextStyle(
                color: _waved ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Premium Action Button ────────────────────────────────────────────────────
class _PremiumActionBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isSuccess;
  final IconData icon;
  final String label;

  const _PremiumActionBtn({
    required this.onTap,
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuccess
              ? [AppColors.online.withOpacity(0.8), AppColors.online]
              : [const Color(0xFF2979FF), const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (isSuccess ? AppColors.online : const Color(0xFF2979FF))
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Quick user card (bottom sheet on marker tap) ─────────────────────────────
class _UserQuickCard extends StatefulWidget {
  final UserProfile user;
  const _UserQuickCard({required this.user});

  @override
  State<_UserQuickCard> createState() => _UserQuickCardState();
}

class _UserQuickCardState extends State<_UserQuickCard> {
  bool _loadingChat = false;
  bool _sendingRequest = false;
  bool _requestSent = false;

  Future<void> _openChat() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id ?? '';
    if (myId.isEmpty) return;

    setState(() => _loadingChat = true);
    try {
      final convId = await SupabaseService().getOrCreateConversation(
        userId1: myId,
        userId2: widget.user.id,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      context.push('/chat/$convId', extra: {
        'name': widget.user.displayName ?? widget.user.username,
        'userId': widget.user.id,
        'avatar': widget.user.avatarUrl ?? '',
      });
    } catch (_) {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final friendsProvider = context.read<FriendsProvider>();
    setState(() => _sendingRequest = true);
    try {
      await friendsProvider.sendFriendRequest(widget.user.id);
      if (mounted) {
        setState(() {
          _requestSent = true;
          _sendingRequest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = context.watch<FriendsProvider>();
    final isFriend = friendsProvider.friends.any((f) => f.id == widget.user.id);

    final name = widget.user.displayName ?? widget.user.username;
    final distText = widget.user.distance != null
        ? '${widget.user.distance!.toStringAsFixed(0)}m away'
        : 'Nearby';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                // Avatar + badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 24,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage:
                          (widget.user.avatarUrl?.isNotEmpty == true)
                              ? NetworkImage(widget.user.avatarUrl!)
                              : null,
                      child: (widget.user.avatarUrl?.isNotEmpty == true)
                          ? null
                          : Text(initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26)),
                    ),
                    if (widget.user.isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.online,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.surface, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Name
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                const SizedBox(height: 6),

                // Distance + account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.near_me_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(distText,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    if (widget.user.accountNumber != null) ...[
                      Text('  ·  ',
                          style: TextStyle(
                              color: AppColors.textMuted.withOpacity(0.5))),
                      Text(widget.user.accountNumber!,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 22),

                // Action buttons
                Row(
                  children: [
                    // Wave
                    Expanded(
                      flex: 2,
                      child: _WaveButton(user: widget.user),
                    ),
                    const SizedBox(width: 12),

                    if (!isFriend)
                      // Friend Request
                      Expanded(
                        flex: 3,
                        child: _PremiumActionBtn(
                          onTap: (_sendingRequest || _requestSent)
                              ? null
                              : _sendFriendRequest,
                          isLoading: _sendingRequest,
                          isSuccess: _requestSent,
                          icon: _requestSent
                              ? Icons.how_to_reg_rounded
                              : Icons.person_add_rounded,
                          label: _requestSent ? 'Sent' : 'Add Friend',
                        ),
                      )
                    else
                      // Chat
                      Expanded(
                        flex: 3,
                        child: _PremiumActionBtn(
                          onTap: _loadingChat ? null : _openChat,
                          isLoading: _loadingChat,
                          icon: Icons.chat_bubble_rounded,
                          label: 'Start Chat',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
