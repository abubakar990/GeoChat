import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF2979FF)],
          ).createShader(bounds),
          child: const Text('Privacy Policy',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated('March 9, 2026'),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Welcome to GeoChat! Your privacy is important to us. This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our mobile application.',
            ),
            _buildSection(
              'Information We Collect',
              '• **Account Information**: Email address, username, and profile photo when you create an account.\n\n'
              '• **Location Data**: With your permission, we collect your precise location to show nearby users and enable proximity-based chat features. You can enable or disable location sharing at any time.\n\n'
              '• **Messages**: Your chat messages are end-to-end encrypted. We cannot read your message content. We store encrypted message data to deliver messages between users.\n\n'
              '• **Device Information**: Device type, operating system, and push notification tokens to deliver notifications.\n\n'
              '• **Usage Data**: How you interact with the app (features used, timestamps) to improve our service.',
            ),
            _buildSection(
              'How We Use Your Information',
              '• To provide and maintain our proximity-based messaging service\n'
              '• To show nearby users on the discovery map\n'
              '• To send push notifications for messages and friend requests\n'
              '• To improve and optimize the app experience\n'
              '• To detect and prevent fraud or abuse',
            ),
            _buildSection(
              'Data Security',
              'We implement industry-standard security measures including:\n\n'
              '• End-to-end encryption for all messages\n'
              '• Secure HTTPS connections for all data transfers\n'
              '• Encrypted storage for sensitive data\n'
              '• Regular security audits',
            ),
            _buildSection(
              'Location Data',
              'Location sharing is entirely optional. When enabled:\n\n'
              '• Your location is shared with nearby users within your configured discovery radius\n'
              '• Location data is updated in real-time while the app is active\n'
              '• You can disable location sharing at any time from the map screen or profile settings\n'
              '• We do not store historical location data beyond the current session',
            ),
            _buildSection(
              'Data Sharing',
              'We do not sell your personal information. We may share data with:\n\n'
              '• Other GeoChat users (username, profile photo, location when sharing is enabled)\n'
              '• Service providers (cloud hosting, push notification services)\n'
              '• Law enforcement when required by law',
            ),
            _buildSection(
              'Your Rights',
              '• **Access**: You can view all your personal data in your profile\n'
              '• **Delete**: You can delete your account and all associated data at any time\n'
              '• **Location Control**: Toggle location sharing on/off at any time\n'
              '• **Notification Control**: Manage push notification preferences in settings',
            ),
            _buildSection(
              'Contact Us',
              'If you have questions about this Privacy Policy, please contact us at:\n\n'
              'Email: privacy@geochat.app',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text('Last updated: $date',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          const SizedBox(height: 10),
          Text(body,
              style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                  fontSize: 14,
                  height: 1.7)),
        ],
      ),
    );
  }
}
