import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconCtrl;
  bool _resentSuccess = false;
  int _resendCooldown = 0; // seconds remaining before next resend

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendVerificationEmail();
    if (!mounted) return;

    if (ok) {
      setState(() {
        _resentSuccess = true;
        _resendCooldown = 60;
      });
      _startCooldown();
    }
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.pendingEmail ?? 'your email';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => auth.cancelVerification(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 13, color: AppColors.textMuted),
                          SizedBox(width: 6),
                          Text('Back to Sign In',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const Spacer(),

                // Animated envelope icon
                AnimatedBuilder(
                  animation: _iconCtrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -6 * _iconCtrl.value),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            const Color(0xFF7C83FD).withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withOpacity(0.2 + 0.15 * _iconCtrl.value),
                            blurRadius: 40,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        color: AppColors.primary,
                        size: 52,
                      ),
                    ),
                  ),
                ).animate().scale(
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.5, 0.5)),

                const SizedBox(height: 36),

                // Title
                const Text(
                  'Check your inbox',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                const SizedBox(height: 14),

                // Subtitle with email highlighted
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.6),
                    children: [
                      const TextSpan(text: 'We sent a verification link to\n'),
                      TextSpan(
                        text: email,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                          text:
                              '\n\nClick the link in the email to activate\nyour account and start chatting.'),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 40),

                // Steps
                _StepRow(
                  step: '1',
                  text: 'Open your email app',
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                const SizedBox(height: 12),
                _StepRow(
                  step: '2',
                  text: 'Find the email from GeoChat',
                ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),
                const SizedBox(height: 12),
                _StepRow(
                  step: '3',
                  text: 'Tap the verification link',
                ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),

                const SizedBox(height: 40),

                // Success banner
                if (_resentSuccess)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.online.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.online.withOpacity(0.35), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.online, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verification email resent! Check your spam folder if you don\'t see it.',
                            style: TextStyle(
                                color: AppColors.online,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2),

                // Error banner
                if (auth.error != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.35), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(auth.error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),

                // Resend button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _resendCooldown > 0
                          ? null
                          : AppColors.primaryGradient,
                      color:
                          _resendCooldown > 0 ? AppColors.surfaceVariant : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _resendCooldown > 0
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: (auth.isLoading || _resendCooldown > 0)
                          ? null
                          : _resend,
                      icon: auth.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                      label: Text(
                        auth.isLoading
                            ? 'Sending…'
                            : _resendCooldown > 0
                                ? 'Resend in ${_resendCooldown}s'
                                : 'Resend verification email',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _resendCooldown > 0
                              ? AppColors.textMuted
                              : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 16),

                // Hint
                Text(
                  'Can\'t find it? Check your spam/junk folder.',
                  style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.6),
                      fontSize: 12),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 800.ms),

                const Spacer(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step row ──────────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final String step;
  final String text;
  const _StepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.primary.withOpacity(0.4), width: 1),
          ),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 14),
        Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
      ],
    );
  }
}
