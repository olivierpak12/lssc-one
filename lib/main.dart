import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/wallet_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/team_provider.dart';
import 'providers/purchases_provider.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: CryptoVaultApp()));
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);
  
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return ResetPasswordScreen(token: token);
      }),
      GoRoute(path: '/reset-transaction-password', builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        return ResetTransactionPasswordScreen(token: token);
      }),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/level', builder: (context, state) => const LevelScreen()),
          GoRoute(path: '/bike', builder: (context, state) => const BikeScreen()),
          GoRoute(path: '/team', builder: (context, state) => const TeamScreen()),
          GoRoute(path: '/my', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/deposit', builder: (context, state) => const DepositScreen()),
          GoRoute(path: '/withdraw', builder: (context, state) => const WithdrawScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/users', builder: (context, state) => const UserManagementScreen()),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;

      if (!auth.sessionRestored) return null;

      final isLoggingIn = path == '/login';
      final isVerifying = path == '/verify-email';
      final isForgotPassword = path == '/forgot-password';
      final isResetPassword = path == '/reset-password';
      final isResetTransPassword = path == '/reset-transaction-password';
      final isAdminPage = path.startsWith('/admin');

      if (auth.userId == null) {
        return (isLoggingIn || isForgotPassword || isResetPassword || isResetTransPassword) ? null : '/login';
      }

      if (isAdminPage && !auth.isAdmin) return '/';

      if (isLoggingIn || isVerifying || isForgotPassword || isResetPassword || isResetTransPassword) return '/';
      
      return null;
    },
  );
});

class CryptoVaultApp extends ConsumerWidget {
  const CryptoVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CryptoVault Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F0F0F),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF141414),
          indicatorColor: Color(0xFF00C853),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF141414),
          indicatorColor: Color(0xFF00C853),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      routerConfig: router,
    );
  }
}

// --- Replaceable Carousel Data ---
// To swap products, just edit this list. Each entry: title, subtitle, imageAsset/URL, tag.
final List<Map<String, String>> carouselProducts = [
  {
    'title': 'Crypto Savings Vault',
    'subtitle': 'Earn up to 8% APY on stablecoins',
    'image': 'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=600&h=300&fit=crop',
    'tag': 'Featured',
  },
  {
    'title': 'Instant Cross-Chain Bridge',
    'subtitle': 'Move assets across 10+ networks in seconds',
    'image': 'https://images.unsplash.com/photo-1621761191319-c6fb62004040?w=600&h=300&fit=crop',
    'tag': 'New',
  },
  {
    'title': 'DeFi Yield Optimizer',
    'subtitle': 'Auto-compound returns with one click',
    'image': 'https://images.unsplash.com/photo-1642790106117-e829e14a795f?w=600&h=300&fit=crop',
    'tag': 'Popular',
  },
];

// --- Responsive Main Shell ---
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _navItems = [
    ('/', Icons.home_rounded, 'Home'),
    ('/level', Icons.auto_graph_rounded, 'Level'),
    ('/bike', Icons.directions_bike_rounded, 'Bike'),
    ('/team', Icons.people_rounded, 'Team'),
    ('/my', Icons.person_rounded, 'My'),
  ];

  int _resolveIndex(String path) {
    for (int i = 0; i < _navItems.length; i++) {
      if (path == _navItems[i].$1) return i;
    }
    if (path == '/settings') return 4;
    if (path.startsWith('/admin')) return 4;
    if (path == '/deposit' || path == '/withdraw') return 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _resolveIndex(location);
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final colorScheme = Theme.of(context).colorScheme;

    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => context.go(_navItems[i].$1),
            labelType: NavigationRailLabelType.all,
            minExtendedWidth: 200,
            groupAlignment: -0.3,
            backgroundColor: const Color(0xFF0A0A0A),
            indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.shield_rounded, size: 32, color: colorScheme.primary),
            ),
            destinations: _navItems.map((item) => NavigationRailDestination(
              icon: Icon(item.$2),
              selectedIcon: Icon(item.$2, color: colorScheme.primary),
              label: Text(item.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
            )).toList(),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(child: child),
        ],
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(_navItems[i].$1),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0F0F0F),
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Icon(item.$2),
            activeIcon: Icon(item.$2, color: colorScheme.primary),
            label: item.$3,
          )).toList(),
        ),
      ),
    );
  }
}

// --- Level Screen ---
class LevelScreen extends ConsumerWidget {
  const LevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Container(
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                'MY EARNINGS',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Daily Profit Overview',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Colors.grey[400],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: const Color(0xFF0F0F0F),
        shadowColor: const Color(0xFF00C853).withValues(alpha: 0.3),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: purchasesAsync.when(
        data: (purchases) {
          if (purchases.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildPurchasesList(context, purchases);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Could not load your earnings',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C853).withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xFF00C853).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: Color(0xFF00C853),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Packages Yet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Purchase a bike package to start\ngenerating daily earnings!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/bike'),
              icon: const Icon(Icons.directions_bike_rounded, size: 20),
              label: Text(
                'Go to Shop',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasesList(BuildContext context, List<Map<String, dynamic>> purchases) {
    double totalDaily = 0;
    double totalInvestment = 0;

    for (final p in purchases) {
      totalDaily += (p['dailyIncome'] as num?)?.toDouble() ?? 0;
      totalInvestment += (p['equipmentPrice'] as num?)?.toDouble() ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(totalInvestment, totalDaily),
          const SizedBox(height: 24),
          Text(
            'Your Packages',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...purchases.map((p) => _buildPurchaseCard(p, context)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalInvestment, double totalDaily) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C853).withValues(alpha: 0.15),
            const Color(0xFF00C853).withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.monetization_on_outlined,
            label: 'Total Investment',
            value: '\$${totalInvestment.toStringAsFixed(2)}',
          ),
          Container(
            width: 1,
            height: 60,
            color: const Color(0xFF00C853).withValues(alpha: 0.3),
          ),
          _buildStatItem(
            icon: Icons.trending_up_rounded,
            label: 'Daily Profit',
            value: '\$${totalDaily.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF00C853)),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF00C853),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> purchase, BuildContext context) {
    final name = purchase['bikeName'] as String? ?? 'Package';
    final price = (purchase['equipmentPrice'] as num?)?.toDouble() ?? 0;
    final daily = (purchase['dailyIncome'] as num?)?.toDouble() ?? 0;
    final monthly = daily * 30;
    final purchasedAt = (purchase['purchasedAt'] as num?)?.toDouble() ?? 0;
    final date = purchasedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(purchasedAt.toInt())
        : null;
    final dateStr = date != null
        ? '${date.month}/${date.day}/${date.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E1E1E),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_bike_rounded,
              color: Color(0xFF00C853),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invested: \$${price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    'Purchased: $dateStr',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  '+\$${daily.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00C853),
                ),
              ),
              Text(
                '/day',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${monthly.toStringAsFixed(2)}/mo',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BikeScreen extends StatefulWidget {
  const BikeScreen({super.key});

  @override
  State<BikeScreen> createState() => _BikeScreenState();
}

class _BikeScreenState extends State<BikeScreen> {
  late List<BikeModel> bikes;

  @override
  void initState() {
    super.initState();
    bikes = [
      BikeModel(
        id: 'beginner',
        name: 'Beginner period',
        icon: '⚡',
        equipmentPrice: 17.00,
        dailyIncome: 1.90,
        imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s1',
        name: 'BLUE-S1',
        icon: '⚡',
        equipmentPrice: 57.00,
        dailyIncome: 6.30,
        imageUrl: 'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s2',
        name: 'BLUE-S2',
        icon: '⚡',
        equipmentPrice: 277.00,
        dailyIncome: 31.00,
        imageUrl: 'https://images.unsplash.com/photo-1532298229144-0ec0c57515c7?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s3',
        name: 'BLUE-S3',
        icon: '⚡',
        equipmentPrice: 677.00,
        dailyIncome: 80.00,
        imageUrl: 'https://images.unsplash.com/photo-1583117386995-5e72e4640a4f?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s4',
        name: 'BLUE-S4',
        icon: '⚡',
        equipmentPrice: 1166.00,
        dailyIncome: 138.00,
        imageUrl: 'https://images.unsplash.com/photo-1594969486096-6b88e6a7a3b9?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s5',
        name: 'BLUE-S5',
        icon: '⚡',
        equipmentPrice: 2266.00,
        dailyIncome: 268.00,
        imageUrl: 'https://images.unsplash.com/photo-1544161000-0183d6e3809e?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s6',
        name: 'BLUE-S6',
        icon: '⚡',
        equipmentPrice: 4466.00,
        dailyIncome: 548.00,
        imageUrl: 'https://images.unsplash.com/photo-1485871981521-9c4595b31c0c?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s7',
        name: 'BLUE-S7',
        icon: '⚡',
        equipmentPrice: 7766.00,
        dailyIncome: 955.00,
        imageUrl: 'https://images.unsplash.com/photo-1494908300279-974768797470?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s8',
        name: 'BLUE-S8',
        icon: '⚡',
        equipmentPrice: 16888.00,
        dailyIncome: 2046.00,
        imageUrl: 'https://images.unsplash.com/photo-1520521464425-753b1285b93b?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s9',
        name: 'BLUE-S9',
        icon: '⚡',
        equipmentPrice: 22888.00,
        dailyIncome: 2858.00,
        imageUrl: 'https://images.unsplash.com/photo-1566925189926-6a629091ecd6?w=200&h=200&fit=crop',
      ),
      BikeModel(
        id: 'blue_s10',
        name: 'BLUE-S10',
        icon: '⚡',
        equipmentPrice: 36888.00,
        dailyIncome: 4606.00,
        imageUrl: 'https://images.unsplash.com/photo-1517649763962-0c623066013c?w=200&h=200&fit=crop',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                'BIKE SHOP',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Choose Your Package',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Colors.grey[400],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: const Color(0xFF0F0F0F),
        shadowColor: const Color(0xFF00C853).withValues(alpha: 0.3),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Investment Stats Card
            _buildInvestmentStatsCard(),
            const SizedBox(height: 24),
            // Grid of Bikes
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600
                    ? (constraints.maxWidth > 900 ? 3 : 2)
                    : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: crossAxisCount == 1 ? 3.2 : (crossAxisCount == 2 ? 2.6 : 1.8),
                  ),
                  itemCount: bikes.length,
                  itemBuilder: (context, index) => BikeCard(
                    bike: bikes[index],
                    colorScheme: colorScheme,
                    onStatusChanged: () => setState(() {}),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentStatsCard() {
    double totalInvestment = 0.0;
    double interestCollectable = 0.0;
    
    for (var bike in bikes) {
      if (bike.isOwned) {
        totalInvestment += bike.equipmentPrice;
        interestCollectable += bike.dailyIncome * 30;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C853).withValues(alpha: 0.15),
            const Color(0xFF00C853).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: '💰',
            label: 'Current Investment',
            value: '\$${totalInvestment.toStringAsFixed(2)}',
          ),
          Container(
            width: 1,
            height: 60,
            color: const Color(0xFF00C853).withValues(alpha: 0.3),
          ),
          _buildStatItem(
            icon: '📈',
            label: 'Interest Collectable',
            value: '\$${interestCollectable.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF00C853),
          ),
        ),
      ],
    );
  }
}

class BikeModel {
  final String id;
  final String name;
  final String icon;
  final double equipmentPrice;
  final double dailyIncome;
  final String? imageUrl;
  bool isOwned;

  BikeModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.equipmentPrice,
    required this.dailyIncome,
    this.imageUrl,
    this.isOwned = false,
  });
}

class BikeCard extends ConsumerStatefulWidget {
  final BikeModel bike;
  final ColorScheme colorScheme;
  final VoidCallback? onStatusChanged;

  const BikeCard({
    required this.bike,
    required this.colorScheme,
    this.onStatusChanged,
    super.key,
  });

  @override
  ConsumerState<BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends ConsumerState<BikeCard> {
  bool _isLoading = false;

  void _joinBike() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      String balanceStr;
      final balanceAsync = ref.read(balanceProvider(userId));
      if (balanceAsync is AsyncData<String>) {
        balanceStr = balanceAsync.value;
      } else {
        balanceStr = await ref.read(balanceProvider(userId).future);
      }

      final balance = BigInt.parse(balanceStr);
      final priceInMicro = BigInt.from((widget.bike.equipmentPrice * 1000000).round());

      if (balance < priceInMicro) {
        _showInsufficientBalanceDialog();
        return;
      }

      final apiService = ref.read(apiServiceProvider);
      await apiService.buyBike(
        userId,
        widget.bike.id,
        widget.bike.equipmentPrice.toStringAsFixed(2),
      );

      ref.invalidate(balanceProvider(userId));

      if (mounted) {
        setState(() {
          widget.bike.isOwned = true;
        });
        widget.onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.bike.name} acquired!'),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${e.toString().replaceAll('"', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF00C853).withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange[400], size: 24),
            const SizedBox(width: 10),
            Text(
              'Insufficient Balance',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'You need \$${widget.bike.equipmentPrice.toStringAsFixed(2)} to purchase ${widget.bike.name}. Please deposit funds first.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[300],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/deposit');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Go to Deposit',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E1E1E),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          _buildImage(),
          Expanded(child: _buildDetails()),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildAction(),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: SizedBox(
        width: 100,
        height: 100,
        child: widget.bike.imageUrl != null
            ? Image.network(
                widget.bike.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackImage(),
              )
            : _fallbackImage(),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFF00C853).withValues(alpha: 0.1),
      child: Center(
        child: Text(widget.bike.icon, style: const TextStyle(fontSize: 36)),
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.bike.name,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '\$${widget.bike.equipmentPrice.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF00C853),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Daily: \$${widget.bike.dailyIncome.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction() {
    if (widget.bike.isOwned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF00C853).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFF00C853).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: const Color(0xFF00C853)),
            const SizedBox(width: 4),
            Text(
              'Owned',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00C853),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 80,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _joinBike,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          disabledBackgroundColor: Colors.grey[700],
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '\$${widget.bike.equipmentPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Buy now',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(teamStatsProvider);
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MY TEAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: statsAsync.when(
        data: (data) {
          final teamA = data['teamA'] as Map<String, dynamic>? ?? {};
          final teamB = data['teamB'] as Map<String, dynamic>? ?? {};
          final teamC = data['teamC'] as Map<String, dynamic>? ?? {};
          final summary = data['summary'] as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Team Cards Row ---
                Row(
                  children: [
                    Expanded(child: _buildTeamCard(
                      title: 'Team A',
                      count: '${teamA['count'] ?? 0}',
                      percent: '${teamA['benefitsPct'] ?? 19}%',
                      color: const Color(0xFF00C853),
                      gradientColors: [const Color(0xFF00C853).withValues(alpha: 0.15), const Color(0xFF00C853).withValues(alpha: 0.05)],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTeamCard(
                      title: 'Team B',
                      count: '${teamB['count'] ?? 0}',
                      percent: '${teamB['benefitsPct'] ?? 4}%',
                      color: const Color(0xFF448AFF),
                      gradientColors: [const Color(0xFF448AFF).withValues(alpha: 0.15), const Color(0xFF448AFF).withValues(alpha: 0.05)],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTeamCard(
                      title: 'Team C',
                      count: '${teamC['count'] ?? 0}',
                      percent: '${teamC['benefitsPct'] ?? 2}%',
                      color: const Color(0xFFFF6D00),
                      gradientColors: [const Color(0xFFFF6D00).withValues(alpha: 0.15), const Color(0xFFFF6D00).withValues(alpha: 0.05)],
                    )),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Period Filter Tabs ---
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildPeriodTab('today', 'Today'),
                      _buildPeriodTab('yesterday', 'Yesterday'),
                      _buildPeriodTab('last7days', '7 Days'),
                      _buildPeriodTab('thismonth', 'This Month'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- Stats Grid ---
                _buildStatRow([
                  ('Today\'s New Team\nMembers', '${summary['newMembersToday'] ?? 0}', colorScheme.primary),
                  ('Today\'s Team\nRecharge Amount', _formatAmount(summary['teamRechargeToday']), Colors.amberAccent),
                ]),
                const SizedBox(height: 10),
                _buildStatRow([
                  ('Today\'s Team\nWithdrawal Amount', _formatAmount(summary['teamWithdrawalToday']), Colors.redAccent),
                  ('Total Team Members', '${summary['totalMembers'] ?? 0}', colorScheme.primary),
                ]),
                const SizedBox(height: 10),
                _buildStatRow([
                  ('Team Total\nDeposit Amount', _formatAmount(summary['totalDeposit']), Colors.amberAccent),
                  ('Team Total\nWithdrawal Amount', _formatAmount(summary['totalWithdrawal']), Colors.redAccent),
                ]),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
      ),
    );
  }

  Widget _buildTeamCard({
    required String title,
    required String count,
    required String percent,
    required Color color,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          )),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          )),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Benefits $percent', style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String value, String label) {
    final selected = ref.watch(selectedPeriodProvider) == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(selectedPeriodProvider.notifier).state = value,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF00C853) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(List<(String, String, Color)> items) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.3)),
                const SizedBox(height: 8),
                Text(item.$2, style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: item.$3,
                )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    final num = BigInt.tryParse(amount.toString()) ?? BigInt.zero;
    if (num == BigInt.zero) return '0.00';
    final divisor = BigInt.from(1000000);
    final integerPart = num ~/ divisor;
    final remainder = num % divisor;
    final decimalStr = remainder.toString().padLeft(6, '0').substring(0, 2);
    return '${integerPart.toString()}.$decimalStr';
  }
}

// --- Auth / Login & Register ---
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _transPassCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  
  bool _isLogin = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        final queryCode = GoRouterState.of(context).uri.queryParameters['invitationCode'] ?? '';
        if (queryCode.isNotEmpty) {
          _inviteCtrl.text = queryCode;
          setState(() => _isLogin = false);
        }
        _initialized = true;
      }
    });
  }
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _obscureTransPass = true;

  Future<void> _handleSubmit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final transPass = _transPassCtrl.text.trim();
    final invite = _inviteCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showError('Please fill in required fields');
      return;
    }

    bool success;
    if (_isLogin) {
      success = await ref.read(authProvider.notifier).login(email, pass);
    } else {
      final confirmPass = _confirmPassCtrl.text.trim();
      if (pass != confirmPass) {
        _showError('Passwords do not match');
        return;
      }
      if (transPass.isEmpty) {
        _showError('Please set a transaction password');
        return;
      }
      success = await ref.read(authProvider.notifier).register(
        email: email,
        password: pass,
        transactionPassword: transPass,
        invitationCode: invite.isEmpty ? null : invite,
      );
    }

    if (success && mounted) {
      context.go('/');
    } else if (mounted) {
      final error = ref.read(authProvider).error ?? 'Authentication failed';
      _showError(error);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 900;
    final bool isTablet = size.width > 600;
    final double horizontalPadding = isDesktop ? size.width * 0.25 : isTablet ? size.width * 0.15 : 24.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.withValues(alpha: 0.05), Colors.black],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_rounded, size: 70, color: Color(0xFF00C853)),
                  const SizedBox(height: 15),
                  Text(
                    'CryptoVault Pro',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildTextField('Email Address', Icons.email_outlined, _emailCtrl),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Password', 
                    Icons.lock_outline, 
                    _passCtrl, 
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  
                  if (!_isLogin) ...[
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Confirm Password', 
                      Icons.lock_reset, 
                      _confirmPassCtrl, 
                      obscureText: _obscureConfirmPass,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Transaction Password', 
                      Icons.enhanced_encryption_outlined, 
                      _transPassCtrl, 
                      obscureText: _obscureTransPass,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureTransPass ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureTransPass = !_obscureTransPass),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField('Invite Code (Optional 5-digit code)', Icons.card_giftcard, _inviteCtrl),
                  ],
                  
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(_isLogin ? 'Access Wallet' : 'Create Account', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),

                  const SizedBox(height: 10),
                  if (_isLogin)
                    TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: const Text('Forgot Password?', style: TextStyle(color: Colors.white38)),
                    ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? "Don't have an account? Register" : "Already have an account? Login", style: const TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController ctrl, {bool obscureText = false, Widget? suffixIcon}) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}

// --- Email Verification ---
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.greenAccent),
              const SizedBox(height: 20),
              const Text('Verify Your Email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text(
                'A verification link has been sent to ${auth.email ?? "your email"}. Please click it to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => ref.read(authProvider.notifier).verifyEmail(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('I\'ve Verified (Simulate)'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).skipVerification();
                  context.go('/');
                },
                child: const Text('Skip for now', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
                child: const Text('Back to Login', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Forgot Password ---
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  Future<void> _handleSubmit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.requestPasswordReset(email);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600;
    final hp = isDesktop ? size.width * 0.25 : isTablet ? size.width * 0.15 : 24.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2818), Color(0xFF000000)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hp, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 70, color: Color(0xFF00C853)),
                  const SizedBox(height: 15),
                  Text(
                    'Forgot Password?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your email and we\'ll send you a reset link.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                  ),
                  const SizedBox(height: 35),
                  if (_sent)
                    Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF00C853)),
                        const SizedBox(height: 16),
                        Text(
                          'Reset link sent!',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your email inbox and click the link to reset your password.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildTextField('Email Address', Icons.email_outlined, _emailCtrl),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to Login', style: TextStyle(color: Colors.greenAccent)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}

// --- Reset Password ---
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;
  const ResetPasswordScreen({required this.token, super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _success = false;
  String? _error;

  Future<void> _handleSubmit() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Please fill in both fields');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.resetPassword(widget.token, newPass);
      setState(() => _success = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('"', '').replaceFirst(RegExp(r'\[CONVEX.*?\]\s*'), ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600;
    final hp = isDesktop ? size.width * 0.25 : isTablet ? size.width * 0.15 : 24.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2818), Color(0xFF000000)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hp, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(_success ? Icons.check_circle_outline : Icons.lock_reset, size: 70, color: const Color(0xFF00C853)),
                  const SizedBox(height: 15),
                  Text(
                    _success ? 'Password Reset!' : 'Reset Password',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _success
                        ? 'Your password has been updated successfully.'
                        : 'Enter your new password below.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                  ),
                  const SizedBox(height: 35),
                  if (_success)
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const Text('Go to Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ],
                    )
                  else ...[
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    _buildTextField(
                      'New Password',
                      Icons.lock_outline,
                      _newPassCtrl,
                      obscureText: _obscureNew,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Confirm Password',
                      Icons.lock_reset,
                      _confirmPassCtrl,
                      obscureText: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController ctrl, {bool obscureText = false, Widget? suffixIcon}) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}

// --- Reset Transaction Password ---
class ResetTransactionPasswordScreen extends ConsumerStatefulWidget {
  final String token;
  const ResetTransactionPasswordScreen({required this.token, super.key});

  @override
  ConsumerState<ResetTransactionPasswordScreen> createState() => _ResetTransactionPasswordScreenState();
}

class _ResetTransactionPasswordScreenState extends ConsumerState<ResetTransactionPasswordScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _success = false;
  String? _error;

  Future<void> _handleSubmit() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Please fill in both fields');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Transaction password must be at least 6 characters');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.resetTransactionPassword(widget.token, newPass);
      setState(() => _success = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('"', '').replaceFirst(RegExp(r'\[CONVEX.*?\]\s*'), ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600;
    final hp = isDesktop ? size.width * 0.25 : isTablet ? size.width * 0.15 : 24.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2818), Color(0xFF000000)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hp, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(_success ? Icons.check_circle_outline : Icons.lock_reset, size: 70, color: const Color(0xFF00C853)),
                  const SizedBox(height: 15),
                  Text(
                    _success ? 'Transaction Password Reset!' : 'Reset Transaction Password',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _success
                        ? 'Your transaction password has been updated successfully.'
                        : 'Enter your new transaction password below.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                  ),
                  const SizedBox(height: 35),
                  if (_success)
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const Text('Go to Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ],
                    )
                  else ...[
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    _buildTextField(
                      'New Transaction Password',
                      Icons.lock_outline,
                      _newPassCtrl,
                      obscureText: _obscureNew,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Confirm Transaction Password',
                      Icons.lock_reset,
                      _confirmPassCtrl,
                      obscureText: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Reset Transaction Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController ctrl, {bool obscureText = false, Widget? suffixIcon}) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}

// --- Dashboard ---
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).refreshUser());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    
    final balanceAsync = ref.watch(balanceProvider(userId));
    final txsAsync = ref.watch(transactionsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PORTFOLIO'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshUser();
          await ref.refresh(transactionsProvider(userId).future);
          ref.refresh(balanceProvider(userId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _ImageCarousel(),
              const SizedBox(height: 24),
              balanceAsync.when(
                data: (balance) => _PortfolioCard(balance: balance, isAdmin: auth.isAdmin),
                loading: () => _PortfolioCard(balance: "...", isLoading: true, isAdmin: auth.isAdmin),
                error: (e, s) => _PortfolioCard(balance: "0.00", isAdmin: auth.isAdmin),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: _ActionTile(icon: Icons.add_circle_outline, label: 'Deposit', color: Colors.greenAccent, onTap: () => context.push('/deposit'))),
                  const SizedBox(width: 15),
                  Expanded(child: _ActionTile(icon: Icons.arrow_circle_up_outlined, label: 'Withdraw', color: Colors.orangeAccent, onTap: () => context.push('/withdraw'))),
                ],
              ),
              const SizedBox(height: 32),
              const _VideoExplainer(),
              const SizedBox(height: 32),
              const _OurProductSection(),
              const SizedBox(height: 40),
              const _RecentActivityHeader(),
              const SizedBox(height: 20),
              txsAsync.when(
                data: (txs) => _TransactionList(transactions: txs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Failed to load transactions')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Image Carousel (easily replaceable via carouselProducts list at top) ---
class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel();

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageCtrl.hasClients) {
        final next = (_current + 1) % carouselProducts.length;
        _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: carouselProducts.length,
            itemBuilder: (context, i) {
              final p = carouselProducts[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(p['image']!),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p['tag'] ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                      const SizedBox(height: 6),
                      Text(p['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(p['subtitle']!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(carouselProducts.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _current == i ? const Color(0xFF00C853) : Colors.white24,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// --- Video Explainer Section ---
class _VideoExplainer extends StatelessWidget {
  const _VideoExplainer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Color(0xFF00C853), size: 22),
            SizedBox(width: 8),
            Text('How It Works', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF0D0D0D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill, size: 64, color: Color(0xFF00C853)),
                    const SizedBox(height: 12),
                    Text('Watch: How CryptoVault Protects Your Assets',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text('Tap to watch on YouTube', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Our Product Section (mirrors the video content with our company) ---
class _OurProductSection extends StatelessWidget {
  const _OurProductSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF00C853), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('How CryptoVault Helps', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _benefitRow(Icons.verified_user_rounded, 'Military-grade encryption keeps your funds safe at all times.'),
          const SizedBox(height: 10),
          _benefitRow(Icons.swap_horiz_rounded, 'Instant deposits and withdrawals across all major blockchain networks.'),
          const SizedBox(height: 10),
          _benefitRow(Icons.trending_up_rounded, 'Real-time balance tracking with automated sweep consolidation.'),
          const SizedBox(height: 10),
          _benefitRow(Icons.support_agent_rounded, '24/7 monitoring and support — our team never sleeps on security.'),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [const Color(0xFF00C853).withValues(alpha: 0.08), const Color(0xFF00C853).withValues(alpha: 0.02)],
              ),
              border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF00C853), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trusted by 10,000+ users worldwide. Start protecting your crypto today.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00C853)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.3)),
        ),
      ],
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final String balance;
  final bool isLoading;
  final bool isAdmin;
  const _PortfolioCard({required this.balance, this.isLoading = false, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    double displayBalance = 0;
    try {
      displayBalance = double.parse(balance) / 1000000;
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF00C853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Stablecoin Balance', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 4),
                      Text('ADMIN', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          isLoading 
            ? const SizedBox(height: 45, width: 45, child: CircularProgressIndicator(color: Colors.white))
            : Text('\$${displayBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Live monitoring active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityHeader extends StatelessWidget {
  const _RecentActivityHeader();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(color: Colors.greenAccent))),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<dynamic> transactions;
  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No transactions yet", style: TextStyle(color: Colors.white38)),
      ));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, i) {
        final tx = transactions[i];
        double amount = double.parse(tx['amount']) / 1000000;
        String token = tx['token'] ?? 'USDT';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                child: const Icon(Icons.call_received, color: Colors.greenAccent, size: 18),
              ),
              title: Text('$token Received (${tx['network']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text("${tx['txHash'].toString().substring(0, 10)}...", style: const TextStyle(fontSize: 12, color: Colors.white54)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  Text(tx['status'], style: TextStyle(fontSize: 10, color: tx['status'] == 'swept' ? Colors.blueAccent : Colors.greenAccent)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Deposit Screen ---
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});
  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  String selectedNetwork = 'Polygon Amoy';
  String selectedToken = 'USDT';
  
  final List<String> networks = ['Ethereum Sepolia', 'Polygon Amoy', 'BSC Testnet'];
  final List<String> tokens = ['USDT', 'USDC'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    final walletAsync = ref.watch(walletProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('DEPOSIT ASSETS')),
      body: walletAsync.when(
        data: (wallet) {
          if (wallet == null || wallet['address'] == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }
          return _buildBody(wallet['address']);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(String address) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTokenDropdown(),
          const SizedBox(height: 15),
          _buildNetworkDropdown(),
          const SizedBox(height: 40),
          _buildQRCode(address),
          const SizedBox(height: 40),
          Text('Your Permanent $selectedToken Address', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          _buildAddressDisplay(address),
          const SizedBox(height: 50),
          _buildSecurityNotice(),
        ],
      ),
    );
  }

  Widget _buildTokenDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedToken,
      decoration: InputDecoration(
        labelText: 'Select Token',
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      items: tokens.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => selectedToken = v!),
    );
  }

  Widget _buildNetworkDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedNetwork,
      decoration: InputDecoration(
        labelText: 'Select Network',
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      items: networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
      onChanged: (v) => setState(() => selectedNetwork = v!),
    );
  }

  Widget _buildQRCode(String address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: QrImageView(data: address, version: QrVersions.auto, size: 200.0),
    );
  }

  Widget _buildAddressDisplay(String address) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Expanded(child: Text(address, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.greenAccent))),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied to clipboard')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('Only send TESTNET $selectedToken to this address via $selectedNetwork. Using mainnet funds will result in permanent loss.', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent))),
        ],
      ),
    );
  }
}

// --- Withdraw Screen ---
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});
  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _addressCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _transPassCtrl = TextEditingController();
  
  String selectedNetwork = 'Polygon Amoy';
  String selectedToken = 'USDT';
  
  final Map<String, int> networkToChainId = {
    'Ethereum Sepolia': 11155111,
    'Polygon Amoy': 80002,
    'BSC Testnet': 97,
  };

  Future<void> _handleWithdraw() async {
    final address = _addressCtrl.text.trim();
    final amount = _amountCtrl.text.trim();
    final transPass = _transPassCtrl.text.trim();

    if (address.isEmpty || amount.isEmpty || transPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      final userId = ref.read(authProvider).userId!;
      final chainId = networkToChainId[selectedNetwork] ?? 80002;

      await ref.read(apiServiceProvider).requestWithdrawal({
        'userId': userId,
        'toAddress': address,
        'amount': (double.parse(amount) * 1000000).toInt().toString(),
        'chainId': chainId,
        'network': selectedNetwork,
        'token': selectedToken,
        'transactionPassword': transPass,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal Request Submitted')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WITHDRAW ASSETS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTokenDropdown(),
            const SizedBox(height: 20),
            _buildNetworkDropdown(),
            const SizedBox(height: 20),
            _buildInputField('Recipient Address', _addressCtrl, hint: '0x...'),
            const SizedBox(height: 20),
            _buildInputField('Amount', _amountCtrl, suffix: selectedToken, keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            _buildInputField('Transaction Password', _transPassCtrl, obscureText: true, hint: 'Required for security'),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _handleWithdraw,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text('Confirm $selectedToken Withdrawal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Asset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedToken,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
          items: ['USDT', 'USDC'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => selectedToken = v!),
        ),
      ],
    );
  }

  Widget _buildNetworkDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedNetwork,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
          items: networkToChainId.keys.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => selectedNetwork = v!),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {String? hint, String? suffix, TextInputType? keyboardType, bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// --- Profile ---
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).refreshUser());
  }

  String get _inviteLink {
    final code = ref.read(authProvider).myInviteCode ?? '';
    final base = Uri.base.origin;
    return '$base/#/register?invitationCode=$code';
  }

  Future<void> _copyInviteLink() async {
    final link = _inviteLink;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation link copied!'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _shareInviteLink() {
    final link = _inviteLink;
    Share.share(
      'Join me on CryptoVault Pro! Use my invitation link: $link',
      subject: 'Join me on CryptoVault Pro',
    );
  }

  void _requestTransactionPasswordReset() {
    final email = ref.read(authProvider).email ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF00C853).withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: Color(0xFF00C853), size: 24),
            const SizedBox(width: 10),
            Text(
              'Reset Transaction Password',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'A reset link will be sent to $email. Click the link to set a new transaction password.',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[300], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.requestTransactionPasswordReset(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reset link sent! Check your email.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF00C853),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reset link sent! Check your email.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Send Reset Link', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final email = auth.email ?? 'Not logged in';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
    double rewardsBalance = 0;
    try {
      rewardsBalance = double.parse(auth.teamRewardsBalance ?? "0") / 1000000;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.greenAccent),
            tooltip: 'Refresh',
            onPressed: () async {
              await ref.read(authProvider.notifier).refreshUser();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshed'), behavior: SnackBarBehavior.floating),
                );
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(initials, email, auth.role ?? 'user', auth.isAdmin),
            const SizedBox(height: 24),
            _buildBalanceCard(rewardsBalance),
            const SizedBox(height: 20),
            _buildInviteCard(),
            const SizedBox(height: 20),
            _buildActionCard(
              icon: Icons.lock_reset,
              title: 'Reset Transaction Password',
              subtitle: 'Send a reset link to your email',
              color: Colors.orangeAccent,
              onTap: _requestTransactionPasswordReset,
            ),
            if (auth.isAdmin) ...[
              const SizedBox(height: 20),
              _buildActionCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Dashboard',
                subtitle: 'Manage users and system',
                color: Colors.greenAccent,
                onTap: () => context.push('/admin'),
              ),
            ],
            const SizedBox(height: 20),
            _buildActionCard(
              icon: Icons.logout,
              title: 'Log Out',
              subtitle: null,
              color: Colors.redAccent,
              onTap: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String initials, String email, String role, bool isAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF0D2818)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.2),
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00C853),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFF00C853).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAdmin ? const Color(0xFF00C853) : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAdmin ? const Color(0xFF00C853) : Colors.white54,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C853).withValues(alpha: 0.12),
            const Color(0xFF00C853).withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.redeem, color: Color(0xFF00C853), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Rewards Balance',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${balance.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available for withdrawal',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/withdraw'),
              icon: const Icon(Icons.arrow_circle_up_outlined, size: 20),
              label: Text(
                'Withdraw',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    final link = _inviteLink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1E1E1E),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.link, color: Color(0xFF00C853), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Invite Friends',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              link,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF00C853),
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _copyInviteLink,
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(
                      'Copy',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C853),
                      side: const BorderSide(color: Color(0xFF00C853)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _shareInviteLink,
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(
                      'Share',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// --- Admin Dashboard ---
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ADMIN CONSOLE')),
      body: statsAsync.when(
        data: (stats) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  children: [
                    _buildStatCard('Total Deposits', '${stats['depositCount']}', Colors.greenAccent),
                    _buildStatCard('Total Volume', '\$${(stats['totalVolume'] / 1000000).toStringAsFixed(2)}', Colors.orangeAccent),
                    _buildStatCard('Pending Sweeps', '${stats['pendingSweeps']}', Colors.blueAccent),
                    _buildStatCard('Withdrawals', '${stats['withdrawalCount']}', Colors.purpleAccent),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                leading: const Icon(Icons.people_alt_outlined, color: Colors.greenAccent),
                title: const Text('User Management'),
                subtitle: const Text('View users and change roles'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/users'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, s) => Center(child: Text('Error loading stats: $e')),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MANAGE USERS')),
      body: usersAsync.when(
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final user = users[i];
            final String currentRole = user['role'] ?? 'user';

            return ListTile(
              title: Text(user['email'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Role: ${currentRole.toUpperCase()}', style: TextStyle(color: currentRole == 'admin' ? Colors.greenAccent : Colors.white54)),
              trailing: DropdownButton<String>(
                value: currentRole,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E1E1E),
                items: ['user', 'admin'].map((role) {
                  return DropdownMenuItem(
                    value: role, 
                    child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.greenAccent))
                  );
                }).toList(),
                onChanged: (newRole) async {
                  if (newRole != null && newRole != currentRole) {
                    await ref.read(adminNotifierProvider.notifier).updateUserRole(user['_id'], newRole);
                    if (user['_id'] == ref.read(authProvider).userId) {
                      await ref.read(authProvider.notifier).refreshUser();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated ${user['email']} to $newRole')));
                    }
                  }
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
