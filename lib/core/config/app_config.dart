class AppConfig {
  AppConfig._();

  /// Convex site URL used by the Flutter client for HTTP calls.
  /// Safe to embed in Flutter Web — this is a public backend URL.
  /// Set via --dart-define=CONVEX_SITE_URL=...
  static const String convexSiteUrl = String.fromEnvironment(
    'CONVEX_SITE_URL',
  );

  /// Fallback Convex URL if [convexSiteUrl] is not set.
  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
  );

  /// Whether the app is operating in mainnet mode.
  /// Controls which network configurations are shown in the UI.
  /// Set via --dart-define=USE_MAINNET=true|false
  static const bool useMainnet = String.fromEnvironment(
    'USE_MAINNET',
    defaultValue: 'false',
  ) == 'true';

  /// Safely resolves the Convex backend URL.
  /// Tries [convexSiteUrl] first, then falls back to [convexUrl].
  static String get resolvedConvexUrl {
    if (convexSiteUrl.isNotEmpty) return convexSiteUrl;
    if (convexUrl.isNotEmpty) return convexUrl;
    throw ArgumentError(
      'CONVEX_SITE_URL or CONVEX_URL not set. '
      'Pass --dart-define=CONVEX_SITE_URL=... or --dart-define=CONVEX_URL=...',
    );
  }
}
