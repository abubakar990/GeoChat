import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          child: const Text('Terms of Service',
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
              '1. Acceptance of Terms',
              'By downloading, installing, or using GeoChat, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.',
            ),
            _buildSection(
              '2. Description of Service',
              'GeoChat is a proximity-based messaging application that allows users to:\n\n'
              '• Discover nearby users through a real-time map\n'
              '• Send end-to-end encrypted messages\n'
              '• Share locations with friends\n'
              '• Send and receive friend requests\n'
              '• Wave at nearby users',
            ),
            _buildSection(
              '3. User Accounts',
              '• You must provide a valid email address to create an account\n'
              '• You are responsible for maintaining the security of your account\n'
              '• You must be at least 13 years old to use GeoChat\n'
              '• One person may only have one account\n'
              '• You must not share your account credentials with others',
            ),
            _buildSection(
              '4. Acceptable Use',
              'You agree NOT to use GeoChat to:\n\n'
              '• Harass, bully, or threaten other users\n'
              '• Send spam, unsolicited messages, or advertising\n'
              '• Impersonate other people or entities\n'
              '• Share illegal, obscene, or harmful content\n'
              '• Attempt to hack, reverse engineer, or compromise the app\n'
              '• Collect user data without consent\n'
              '• Use the app for any unlawful purpose',
            ),
            _buildSection(
              '5. Content & Messages',
              '• Messages are end-to-end encrypted — GeoChat cannot read your messages\n'
              '• You are responsible for the content you share\n'
              '• We reserve the right to remove accounts that violate these terms\n'
              '• You retain ownership of content you create',
            ),
            _buildSection(
              '6. Location Services',
              '• Location sharing is optional and can be disabled at any time\n'
              '• When enabled, your approximate location is visible to nearby users\n'
              '• You consent to your location being shared with other users when this feature is active\n'
              '• GeoChat is not responsible for any consequences arising from location sharing',
            ),
            _buildSection(
              '7. Privacy',
              'Your use of GeoChat is also governed by our Privacy Policy, which explains how we collect, use, and protect your data. Please review our Privacy Policy for full details.',
            ),
            _buildSection(
              '8. Intellectual Property',
              'The GeoChat app, including its design, code, logos, and branding, is the intellectual property of GeoChat and is protected by applicable laws. You may not copy, modify, or distribute any part of the app without prior written consent.',
            ),
            _buildSection(
              '9. Termination',
              '• You may delete your account at any time\n'
              '• We may suspend or terminate accounts that violate these terms\n'
              '• Upon termination, your data will be deleted in accordance with our Privacy Policy',
            ),
            _buildSection(
              '10. Disclaimer of Warranties',
              'GeoChat is provided "as is" without warranties of any kind. We do not guarantee that the service will be uninterrupted, secure, or error-free. You use the app at your own risk.',
            ),
            _buildSection(
              '11. Limitation of Liability',
              'To the fullest extent permitted by law, GeoChat shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the app.',
            ),
            _buildSection(
              '12. Changes to Terms',
              'We may update these Terms of Service from time to time. We will notify users of significant changes through the app. Continued use of GeoChat after changes constitutes acceptance of the updated terms.',
            ),
            _buildSection(
              '13. Contact Us',
              'If you have questions about these Terms of Service, please contact us at:\n\n'
              'Email: support@geochat.app',
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
