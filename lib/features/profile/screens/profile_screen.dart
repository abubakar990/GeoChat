import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../discovery/providers/discovery_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _svc = SupabaseService();
  final _picker = ImagePicker();
  bool _uploadingPhoto = false;

  void _showEditSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: auth.profile),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    // Show source chooser
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Change Profile Photo',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5BC8F5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFF5BC8F5), size: 20),
              ),
              title: const Text('Take Photo',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C83FD).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF7C83FD), size: 20),
              ),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final url = await _svc.uploadAvatar(
        userId: auth.user!.id,
        bytes: bytes,
        extension: ext.isEmpty ? 'jpg' : ext,
      );
      if (url != null) {
        await _svc.updateProfile(userId: auth.user!.id, avatarUrl: url);
        await auth.refreshProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    if (mounted) setState(() => _uploadingPhoto = false);
  }

  void _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out?',
        confirmLabel: 'Sign Out',
        isDangerous: true,
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthProvider>().signOut();
    }
  }

  // ── Preferences ──────────────────────────────────────────────────────
  bool _notificationsEnabled = true;
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAppVersion();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // MissingPluginException on hot restart — needs full reinstall
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (!value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Push notifications paused'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRadiusPicker() {
    final discovery = context.read<DiscoveryProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id ?? '';
    double tempRadius = discovery.radius;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Discovery Radius',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Find users within this distance',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),
              Text('${(tempRadius / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.surfaceVariant,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: tempRadius,
                  min: 1000,
                  max: 50000,
                  divisions: 49,
                  onChanged: (v) => setSheetState(() => tempRadius = v),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 km', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('50 km', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    discovery.setRadius(tempRadius, userId);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Radius set to ${(tempRadius / 1000).toStringAsFixed(1)} km'),
                        backgroundColor: AppColors.online,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    final languages = ['English', 'Urdu', 'Arabic', 'Hindi', 'Spanish', 'French'];
    String selected = 'English';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Language',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...languages.map((lang) => ListTile(
              title: Text(lang,
                  style: TextStyle(
                    color: lang == selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: lang == selected ? FontWeight.w700 : FontWeight.w400,
                  )),
              trailing: lang == selected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                  : null,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang == 'English'
                        ? 'Language is already English'
                        : '$lang support coming soon!'),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _openTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
  }

  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'GeoChat',
      applicationVersion: _appVersion,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
      ),
      children: [
        const Text(
          'GeoChat is a location-based messaging app that lets you discover and chat with people nearby.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final discovery = context.watch<DiscoveryProvider>();
    final profile = auth.profile;

    final initials =
        (profile?.displayName ?? profile?.username ?? 'U')[0].toUpperCase();
    final displayName = profile?.displayName ?? profile?.username ?? 'User';
    final username = profile?.username ?? '';
    final email = auth.user?.email ?? '';
    final accountNum = profile?.accountNumber ?? '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroHeader(
              initials: initials,
              avatarUrl: profile?.avatarUrl,
              displayName: displayName,
              username: username,
              onEdit: () => _showEditSheet(context, auth),
              onPickPhoto: _pickAndUploadAvatar,
              uploadingPhoto: _uploadingPhoto,
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Account Number card ──────────────────────────────────
                _AccountNumberCard(accountNumber: accountNum),
                const SizedBox(height: 28),

                // ── Identity ─────────────────────────────────────────────
                _SectionLabel('Identity'),
                const SizedBox(height: 10),
                _GlassCard(children: [
                  _InfoRow(
                    icon: Icons.badge_rounded,
                    iconColor: const Color(0xFF7C83FD),
                    label: 'Display Name',
                    value: displayName,
                    trailing: GestureDetector(
                      onTap: () => _showEditSheet(context, auth),
                      child: const Icon(Icons.edit_rounded,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ),
                  _RowDivider(),
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    iconColor: const Color(0xFF5BC8F5),
                    label: 'Username',
                    value: '@$username',
                    trailing: GestureDetector(
                      onTap: () => _showEditSheet(context, auth),
                      child: const Icon(Icons.edit_rounded,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ),
                  _RowDivider(),
                  _InfoRow(
                    icon: Icons.email_rounded,
                    iconColor: const Color(0xFFFB8C6F),
                    label: 'Email',
                    value: email,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Privacy & Location ───────────────────────────────────
                _SectionLabel('Privacy & Location'),
                const SizedBox(height: 10),
                _GlassCard(children: [
                  _SwitchRow(
                    icon: Icons.location_on_rounded,
                    iconColor: discovery.isLocationSharing
                        ? AppColors.online
                        : AppColors.textMuted,
                    label: 'Share My Location',
                    subtitle: discovery.isLocationSharing
                        ? 'Visible to nearby users'
                        : 'Hidden from the map',
                    value: discovery.isLocationSharing,
                    onChanged: (_) => discovery.toggleLocationSharing(),
                  ),
                  _RowDivider(),
                  _InfoRow(
                    icon: Icons.visibility_off_rounded,
                    iconColor: const Color(0xFFBDBDBD),
                    label: 'Ghost Mode',
                    value: 'Coming soon',
                    valueColor: AppColors.textMuted,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Preferences ──────────────────────────────────────────
                _SectionLabel('Preferences'),
                const SizedBox(height: 10),
                _GlassCard(children: [
                  _SwitchRow(
                    icon: Icons.notifications_rounded,
                    iconColor: _notificationsEnabled
                        ? const Color(0xFFFFB74D)
                        : AppColors.textMuted,
                    label: 'Notifications',
                    subtitle: _notificationsEnabled
                        ? 'All notifications on'
                        : 'Notifications paused',
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  _RowDivider(),
                  GestureDetector(
                    onTap: _showRadiusPicker,
                    child: _InfoRow(
                      icon: Icons.radar_rounded,
                      iconColor: const Color(0xFF81C784),
                      label: 'Discovery Radius',
                      value: '${(discovery.radius / 1000).toStringAsFixed(1)} km',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
                  _RowDivider(),
                  GestureDetector(
                    onTap: _showLanguagePicker,
                    child: _InfoRow(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF64B5F6),
                      label: 'Language',
                      value: 'English',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── About ────────────────────────────────────────────────
                _SectionLabel('About'),
                const SizedBox(height: 10),
                _GlassCard(children: [
                  GestureDetector(
                    onTap: _showAppInfo,
                    child: _InfoRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF90CAF9),
                      label: 'App Version',
                      value: _appVersion,
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
                  _RowDivider(),
                  GestureDetector(
                    onTap: _openPrivacyPolicy,
                    child: _InfoRow(
                      icon: Icons.shield_rounded,
                      iconColor: const Color(0xFF80CBC4),
                      label: 'Privacy Policy',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
                  _RowDivider(),
                  GestureDetector(
                    onTap: _openTermsOfService,
                    child: _InfoRow(
                      icon: Icons.description_rounded,
                      iconColor: const Color(0xFFA5D6A7),
                      label: 'Terms of Service',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
                ]),

                const SizedBox(height: 32),

                // ── Sign Out ─────────────────────────────────────────────
                GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded,
                            color: AppColors.error, size: 18),
                        SizedBox(width: 10),
                        Text('Sign Out',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Header with gradient, avatar glow, stat row ─────────────────────────
class _HeroHeader extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final String displayName;
  final String username;
  final VoidCallback onEdit;
  final VoidCallback onPickPhoto;
  final bool uploadingPhoto;

  const _HeroHeader({
    required this.initials,
    required this.avatarUrl,
    required this.displayName,
    required this.username,
    required this.onEdit,
    required this.onPickPhoto,
    this.uploadingPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Gradient background
        Container(
          height: 310 + topPad,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D1F35),
                Color(0xFF0A1628),
                Color(0xFF111827),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.primary.withOpacity(0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: -60,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF7C83FD).withOpacity(0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // Content
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  // Top row: title + edit
                  Row(
                    children: [
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.4),
                                width: 1),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: AppColors.primary, size: 14),
                              SizedBox(width: 6),
                              Text('Edit',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // outer glow
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 32,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      // ring
                      Container(
                        width: 100,
                        height: 100,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2979FF),
                              Color(0xFF7C83FD),
                              Color(0xFF5BC8F5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFF1A2A3E),
                          backgroundImage: (avatarUrl?.isNotEmpty == true)
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: (avatarUrl?.isNotEmpty == true)
                              ? null
                              : Text(initials,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                      // Camera button
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: uploadingPhoto ? null : onPickPhoto,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0A1628), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 8)
                              ],
                            ),
                            child: uploadingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: TextStyle(
                        color: AppColors.textMuted.withOpacity(0.8),
                        fontSize: 14),
                  ),
                  const SizedBox(height: 14),

                  // Active now badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.online.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.online.withOpacity(0.35), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulsingDot(),
                        const SizedBox(width: 7),
                        const Text('Active now',
                            style: TextStyle(
                                color: AppColors.online,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom fade into background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withOpacity(0.9),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pulsing dot ───────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.online.withOpacity(_anim.value),
          boxShadow: [
            BoxShadow(
              color: AppColors.online.withOpacity(_anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ],
        ),
      ),
    );
  }
}

// ── Account number card ───────────────────────────────────────────────────────
class _AccountNumberCard extends StatefulWidget {
  final String accountNumber;
  const _AccountNumberCard({required this.accountNumber});

  @override
  State<_AccountNumberCard> createState() => _AccountNumberCardState();
}

class _AccountNumberCardState extends State<_AccountNumberCard> {
  bool _copied = false;

  void _copy() async {
    Clipboard.setData(ClipboardData(text: widget.accountNumber));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2D4A), Color(0xFF0E1E34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 24,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Account Number',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Share to let others find you',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Number row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withOpacity(0.07), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.accountNumber,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _copy,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _copied
                          ? AppColors.online.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _copied
                            ? AppColors.online.withOpacity(0.5)
                            : AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      color: _copied ? AppColors.online : AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 11, color: AppColors.textMuted.withOpacity(0.5)),
              const SizedBox(width: 5),
              const Text(
                'Your email and phone are never revealed to others.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Edit profile bottom sheet ─────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final UserProfile? profile;
  const _EditProfileSheet({required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _userCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile?.displayName ?? '');
    _userCtrl = TextEditingController(text: widget.profile?.username ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _nameCtrl.text.trim();
    final newUser = _userCtrl.text.trim();

    if (newName == (widget.profile?.displayName ?? '') &&
        newUser == (widget.profile?.username ?? '')) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    final ok = await context.read<AuthProvider>().updateProfile(
          displayName: newName.isNotEmpty ? newName : null,
          username: newUser.isNotEmpty ? newUser : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Profile updated!'
            : context.read<AuthProvider>().error ?? 'Update failed'),
        backgroundColor: ok ? AppColors.online : AppColors.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Edit Profile',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),
            _EditField(
              controller: _nameCtrl,
              label: 'Display Name',
              hint: 'Your public name',
              icon: Icons.badge_rounded,
            ),
            const SizedBox(height: 16),
            _EditField(
              controller: _userCtrl,
              label: 'Username',
              hint: 'Unique handle (no spaces)',
              icon: Icons.alternate_email_rounded,
              prefix: '@',
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit field ────────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefix;

  const _EditField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            prefixText: prefix,
            prefixStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 15),
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }
}

// ── Reusable components ───────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppColors.textMuted.withOpacity(0.7),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      );
}

class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  const _GlassCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(children: children),
      );
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 54),
        color: Colors.white.withOpacity(0.05),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Colored icon badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(value!,
                          style: TextStyle(
                              color: valueColor ?? AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              thumbColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.textMuted;
              }),
              trackColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected)
                    ? AppColors.online
                    : AppColors.surfaceVariant;
              }),
            ),
          ],
        ),
      );
}

// ── Sign-out confirm dialog ───────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDangerous;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(message,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: isDangerous ? AppColors.error : AppColors.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      );
}
