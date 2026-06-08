import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/content_section.dart';
import '../theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          'About & Contact',
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
            ContentSection(
              title: 'About LSSC Global',
              body: 'LSSC Global is a next-generation cryptocurrency exchange and asset management platform '
                  'designed to make digital asset trading accessible, secure, and efficient. '
                  'We provide a comprehensive suite of tools for buying, selling, and managing '
                  'cryptocurrency assets, all within a user-friendly interface.\n\n'
                  'Our mission is to bridge the gap between traditional finance and the decentralized '
                  'economy, empowering users worldwide to participate in the digital asset ecosystem '
                  'with confidence and ease.\n\n'
                  'We prioritize security, transparency, and compliance, adhering to industry best '
                  'practices and regulatory standards to ensure a safe trading environment for all users.',
            ),
            ContentSection(
              title: 'Contact Us',
              body: 'We\'re here to help. Reach out to us through any of the channels below.\n\n'
                  'Email: support@lsscone.com\n\n'
                  'For privacy-related inquiries: privacy@lsscone.com',
            ),
            ContentSection(
              title: 'Support Hours',
              body: 'Our support team is available 24 hours a day, 7 days a week.\n\n'
                  'We strive to respond to all inquiries within 24 hours.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

}
