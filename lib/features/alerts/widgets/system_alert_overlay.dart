import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/broadcast_service.dart';
import '../../../core/constants/app_colors.dart';

/// Wraps any [child] widget and listens to the global_announcements Supabase
/// Broadcast channel.  When a payload arrives, it renders a high-priority
/// blurred overlay on top of [child] without interrupting navigation.
class SystemAlertOverlay extends StatefulWidget {
  final Widget child;

  const SystemAlertOverlay({super.key, required this.child});

  @override
  State<SystemAlertOverlay> createState() => SystemAlertOverlayState();
}

class SystemAlertOverlayState extends State<SystemAlertOverlay>
    with SingleTickerProviderStateMixin {
  final _broadcast = BroadcastService();
  SystemAlert? _currentAlert;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  void startListening() {
    _broadcast.listen(onAlert: _showAlert);
  }

  void _showAlert(SystemAlert alert) {
    if (mounted) {
      setState(() => _currentAlert = alert);
      _ctrl.forward(from: 0);
    }
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) setState(() => _currentAlert = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentAlert != null)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: _ctrl.value,
              child: _AlertModal(alert: _currentAlert!, onDismiss: _dismiss),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _broadcast.dispose();
    _ctrl.dispose();
    super.dispose();
  }
}

class _AlertModal extends StatelessWidget {
  final SystemAlert alert;
  final VoidCallback onDismiss;

  const _AlertModal({required this.alert, required this.onDismiss});

  Color get _accentColor {
    switch (alert.type) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (alert.type) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'warning':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Stack(
        children: [
          // Blurred backdrop
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: AppColors.overlayDark),
          ),

          // Alert card
          Center(
            child: GestureDetector(
              onTap: () {}, // prevent dismissal when tapping card
              child:
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _accentColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header gradient band
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _accentColor.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: _accentColor.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _icon,
                                      color: _accentColor,
                                      size: 28,
                                    ),
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(period: 1200.ms),
                                  )
                                  .fade(begin: 0.7, end: 1.0)
                                  .scale(
                                    begin: const Offset(0.95, 0.95),
                                    end: const Offset(1.05, 1.05),
                                  ),
                              const SizedBox(height: 14),
                              Text(
                                alert.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            children: [
                              Text(
                                alert.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatTime(alert.timestamp),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Dismiss button
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _accentColor,
                                        _accentColor.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: onDismiss,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                    ),
                                    child: const Text(
                                      'Dismiss',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(
                    begin: const Offset(0.85, 0.85),
                    duration: 350.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
