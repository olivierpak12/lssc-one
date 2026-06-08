import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/content_section.dart';
import '../theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          'Privacy Policy',
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
              title: 'Information We Collect',
              body: 'When you create an account and use LSSC Global, we collect the following information:\n\n'
                  '• Email address\n'
                  '• Phone number\n'
                  '• Cryptocurrency wallet addresses\n'
                  '• KYC documents (government-issued ID, proof of address) for identity verification\n'
                  '• Transaction history and account activity',
            ),
            ContentSection(
              title: 'How We Use Your Information',
              body: 'We use the information we collect for the following purposes:\n\n'
                  '• Account creation and verification\n'
                  '• Processing transactions and maintaining your account\n'
                  '• Complying with anti-money laundering (AML) and know-your-customer (KYC) regulations\n'
                  '• Communicating important account updates and security notices\n'
                  '• Improving our platform and user experience',
            ),
            ContentSection(
              title: 'Data Sharing and Disclosure',
              body: 'We do not sell, trade, or rent your personal information to third parties. '
                  'We may share your information only when required by law, to protect our rights, '
                  'or with trusted service providers who assist in operating our platform under strict confidentiality agreements.',
            ),
            ContentSection(
              title: 'Cookies and Analytics',
              body: 'We use cookies and similar tracking technologies to enhance your experience, '
                  'analyze usage patterns, and improve our platform. You can control cookie preferences '
                  'through your browser settings. We also use analytics tools to understand how our '
                  'platform is used and to optimize performance.',
            ),
            ContentSection(
              title: 'Data Security',
              body: 'We implement industry-standard security measures including encryption, '
                  'secure servers, and regular security audits to protect your personal information. '
                  'However, no method of transmission over the internet is 100% secure.',
            ),
            ContentSection(
              title: 'Your Rights and Choices',
              body: 'You have the right to access, update, or delete your personal information. '
                  'You can manage your account settings or contact us to exercise these rights. '
                  'You may opt out of marketing communications at any time.',
            ),
            ContentSection(
              title: 'Contact Us',
              body: 'For privacy-related inquiries or requests, please contact us at:\n\n'
                  'Email: privacy@lsscone.com\n\n'
                  'We will respond to your request within a reasonable timeframe.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

}
