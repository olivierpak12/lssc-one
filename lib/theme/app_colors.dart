import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const primary = Color(0xFF00C853);
  static const primaryDark = Color(0xFF1B5E20);
  static const primaryLight = Color(0xFF69F0AE);

  // Surfaces
  static const surface = Color(0xFF0F0F0F);
  static const surfaceAlt = Color(0xFF0A0A0A);
  static const surfaceCard = Color(0xFF1A1A1A);
  static const surfaceCardAlt = Color(0xFF1E1E1E);
  static const surfaceNav = Color(0xFF141414);
  static const surfaceElevated = Color(0xFF2A2A2A);

  // Accents
  static const accentGreen = primary;
  static const accentBlue = Color(0xFF2575FC);
  static const accentPurple = Color(0xFF6A11CB);
  static const accentOrange = Color(0xFFFF9800);
  static final accentBlueSoft = accentBlue.withValues(alpha: 0.1);
  static final accentPurpleSoft = accentPurple.withValues(alpha: 0.1);
  static final overlayPurpleSoft = accentPurple.withValues(alpha: 0.1);

  // Text
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB0B0B0);
  static const textTertiary = Color(0xFF808080);
  static const textMuted = Color(0xFF505050);

  // Borders
  static final borderSubtle = Colors.white.withValues(alpha: 0.05);
  static final borderLight = Colors.white.withValues(alpha: 0.12);
  static final borderPrimary = primary.withValues(alpha: 0.25);

  // Overlays
  static final overlayGreen = primary.withValues(alpha: 0.1);
  static final overlayGreenMedium = primary.withValues(alpha: 0.15);
  static final overlayGreenStrong = primary.withValues(alpha: 0.25);
  static final overlayRed = Colors.redAccent.withValues(alpha: 0.1);
  static final overlayOrange = accentOrange.withValues(alpha: 0.1);
  static final overlayBlue = accentBlue.withValues(alpha: 0.1);

  // Shadows
  static final shadowGreen = primary.withValues(alpha: 0.2);
  static final shadowBlue = accentBlue.withValues(alpha: 0.2);

  // Status
  static const success = primary;
  static const warning = accentOrange;
  static const error = Colors.redAccent;
  static const info = accentBlue;
}

class AppGradients {
  AppGradients._();

  static const primary = LinearGradient(
    colors: [Color(0xFF1B5E20), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryReverse = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const referral = LinearGradient(
    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final cardGreen = LinearGradient(
    colors: [AppColors.overlayGreen, AppColors.overlayGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const surfaceToCard = LinearGradient(
    colors: [AppColors.surfaceCard, AppColors.surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final darkOverlay = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.center,
    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
  );

  static const authBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D2818), Color(0xFF000000)],
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets screenV = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardLg = EdgeInsets.all(xl);

  static const SizedBox hXs = SizedBox(height: xs);
  static const SizedBox hSm = SizedBox(height: sm);
  static const SizedBox hMd = SizedBox(height: md);
  static const SizedBox hLg = SizedBox(height: lg);
  static const SizedBox hXl = SizedBox(height: xl);
  static const SizedBox hXxl = SizedBox(height: xxl);
  static const SizedBox hXxxl = SizedBox(height: xxxl);
  static const SizedBox hHuge = SizedBox(height: huge);

  static const SizedBox wXs = SizedBox(width: xs);
  static const SizedBox wSm = SizedBox(width: sm);
  static const SizedBox wMd = SizedBox(width: md);
  static const SizedBox wLg = SizedBox(width: lg);
  static const SizedBox wXl = SizedBox(width: xl);
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 25;
  static const double xxxl = 30;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius rXxxl = BorderRadius.all(Radius.circular(xxxl));
}
