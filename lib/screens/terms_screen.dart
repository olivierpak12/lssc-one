import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/content_section.dart';
import '../theme/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Terms of Service',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: June 8, 2026',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            ContentSection(
              title: 'Acceptance of Terms',
              body: 'By creating an account or using LSSC Global, you agree to be bound by these Terms of Service. '
                  'If you do not agree with any part of these terms, you must not use our platform.',
            ),
            ContentSection(
              title: 'Eligibility',
              body: 'You must be at least 18 years old to use LSSC Global. By registering, you confirm that:\n\n'
                  '• You are 18 years of age or older\n'
                  '• You have the legal capacity to enter into binding agreements\n'
                  '• Your use of the platform complies with all applicable laws in your jurisdiction',
            ),
            ContentSection(
              title: 'Platform Services',
              body: 'LSSC Global is a cryptocurrency asset exchange and management platform. '
                  'We facilitate the trading, management, and transfer of digital assets. '
                  'We reserve the right to modify, suspend, or discontinue any aspect of our services at any time.',
            ),
            ContentSection(
              title: 'Account Security',
              body: 'You are solely responsible for maintaining the confidentiality of your account credentials, '
                  'including your password and transaction password. You must notify us immediately of any '
                  'unauthorized use of your account. We are not liable for any loss or damage arising from '
                  'your failure to safeguard your account.',
            ),
            ContentSection(
              title: 'Wallet Security',
              body: 'You are solely responsible for the security of your cryptocurrency wallets. '
                  'We strongly recommend enabling all available security features and using hardware wallets '
                  'for large holdings. We are not responsible for any losses resulting from compromised private keys or wallet addresses.',
            ),
            ContentSection(
              title: 'Prohibited Activities',
              body: 'The following activities are strictly prohibited on our platform:\n\n'
                  '• Fraud, misrepresentation, or deceptive practices\n'
                  '• Money laundering or terrorist financing\n'
                  '• Using the platform for any illegal activity\n'
                  '• Attempting to manipulate the platform or its systems\n'
                  '• Interfering with other users\' access to the platform\n'
                  '• Any activity that violates applicable laws or regulations',
            ),
            ContentSection(
              title: 'Limitation of Liability',
              body: 'LSSC Global is not liable for any losses resulting from:\n\n'
                  '• Market volatility or cryptocurrency price fluctuations\n'
                  '• Technical failures, downtime, or service interruptions\n'
                  '• Unauthorized access to your account due to your negligence\n'
                  '• Actions taken by third parties\n'
                  '• Regulatory changes affecting cryptocurrency assets\n\n'
                  'All trading and investment activities carry inherent risk. You acknowledge '
                  'that you are using the platform at your own risk.',
            ),
            ContentSection(
              title: 'Account Termination',
              body: 'We reserve the right to suspend or terminate your account at our discretion, '
                  'including but not limited to:\n\n'
                  '• Violation of these Terms of Service\n'
                  '• Suspicious or fraudulent activity\n'
                  '• Extended periods of inactivity\n'
                  '• Failure to complete KYC verification\n'
                  '• Legal or regulatory requirements\n\n'
                  'Upon termination, your access to the platform will be revoked. Remaining funds '
                  'will be handled in accordance with applicable laws and regulations.',
            ),
            ContentSection(
              title: 'Changes to Terms',
              body: 'We may update these Terms of Service from time to time. We will notify users of material '
                  'changes via email or through the platform. Continued use of the platform after changes '
                  'constitutes acceptance of the updated terms.',
            ),
            ContentSection(
              title: 'Contact',
              body: 'For questions about these Terms of Service, please contact us at:\n\n'
                  'Email: support@lsscone.com',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

}
