import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'providers/wallet_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/team_provider.dart';
import 'providers/purchases_provider.dart';
import 'providers/referral_provider.dart';
import 'models/referral.dart';
import 'services/api_service.dart';
import 'core/config/app_config.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart' show AppTheme;
import 'theme/app_animations.dart';
import 'components/app_button.dart';
import 'components/app_card.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LSSCONEApp()));
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
      GoRoute(path: '/register', builder: (context, state) => const AuthScreen()),
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
          GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
          GoRoute(path: '/lssc', builder: (context, state) => const LsscScreen()),
          GoRoute(path: '/bike', builder: (context, state) => const LsscScreen()),
          GoRoute(path: '/team', builder: (context, state) => const TeamScreen()),
          GoRoute(path: '/my', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/deposit', builder: (context, state) => const DepositScreen()),
          GoRoute(path: '/withdraw', builder: (context, state) => const WithdrawScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/users', builder: (context, state) => const UserManagementScreen()),
          GoRoute(path: '/activity', builder: (context, state) => const ActivityHistoryScreen()),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;

      if (!auth.sessionRestored) return null;

      final isLoggingIn = path == '/login';
      final isRegister = path == '/register';
      final isVerifying = path == '/verify-email';
      final isForgotPassword = path == '/forgot-password';
      final isResetPassword = path == '/reset-password';
      final isResetTransPassword = path == '/reset-transaction-password';
      final isAdminPage = path.startsWith('/admin');

      if (auth.userId == null) {
        return (isLoggingIn || isRegister || isForgotPassword || isResetPassword || isResetTransPassword) ? null : '/login';
      }

      if (isAdminPage && !auth.isAdmin) return '/';

      if (isLoggingIn || isRegister || isVerifying || isForgotPassword || isResetPassword || isResetTransPassword) return '/';
      
      return null;
    },
  );
});

class LSSCONEApp extends ConsumerWidget {
  const LSSCONEApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LSSC ONE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}

// --- Responsive Main Shell ---
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _navItems = [
    ('/', Icons.home_rounded, 'Home'),
    ('/earnings', Icons.auto_graph_rounded, 'Earnings'),
    ('/lssc', Icons.directions_bike_rounded, 'LSSC'),
    ('/team', Icons.people_rounded, 'Team'),
    ('/my', Icons.person_rounded, 'Me'),
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
            indicatorColor: AppColors.primary.withValues(alpha: 0.2),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.asset('asset/logo.png', width: 32, height: 32),
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
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(_navItems[i].$1),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Icon(item.$2),
            activeIcon: Icon(item.$2, color: AppColors.primary),
            label: item.$3,
          )).toList(),
        ),
      ),
    );
  }
}

// --- Earnings Screen ---
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});
  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _claimingPurchaseId;
  String? _claimError;
  String? _claimSuccess;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim(String purchaseId) async {
    setState(() {
      _claimingPurchaseId = purchaseId;
      _claimError = null;
      _claimSuccess = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final auth = ref.read(authProvider);
      if (auth.userId == null) return;

      final response = await apiService.claimDailyEarnings(auth.userId!, purchaseId);
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final amount = data['amount'] ?? '0';
        setState(() {
          _claimSuccess = 'Claimed \$$amount!';
        });
        ref.invalidate(purchasesProvider);
        ref.invalidate(balanceProvider(auth.userId!));
        ref.invalidate(withdrawableBalanceProvider(auth.userId!));
        ref.invalidate(referralStatsProvider);
      } else {
        final errMsg = data is Map ? (data['message'] ?? 'Claim failed') : 'Claim failed';
        setState(() => _claimError = errMsg.toString());
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() => _claimError = msg);
    } finally {
      setState(() => _claimingPurchaseId = null);
    }
  }

  bool _canClaim(Map<String, dynamic> purchase) {
    final lastClaimed = purchase['lastClaimedAt'] as num?;
    if (lastClaimed == null) return true;
    return DateTime.now().millisecondsSinceEpoch - lastClaimed.toInt() >= 86400000;
  }

  int _hoursUntilClaim(Map<String, dynamic> purchase) {
    final lastClaimed = purchase['lastClaimedAt'] as num?;
    if (lastClaimed == null) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastClaimed.toInt();
    final remaining = 86400000 - elapsed;
    if (remaining <= 0) return 0;
    return (remaining / 3600000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final referralStatsAsync = ref.watch(referralStatsProvider);
    final auth = ref.watch(authProvider);
    final withdrawableAsync = auth.userId != null
        ? ref.watch(withdrawableBalanceProvider(auth.userId!))
        : null;

    final purchases = purchasesAsync.asData?.value ?? [];
    final referralStats = referralStatsAsync.asData?.value;

    double totalDailyProfit = 0;
    double totalInvestment = 0;
    for (final p in purchases) {
      totalDailyProfit += (p['dailyIncome'] as num?)?.toDouble() ?? 0;
      totalInvestment += (p['equipmentPrice'] as num?)?.toDouble() ?? 0;
    }

    final referralBalance = referralStats?.referralBalance ?? 0;
    final totalReferralEarnings = referralStats?.totalReferralEarnings ?? 0;

    final withdrawableBalance = withdrawableAsync?.asData?.value != null
        ? (double.tryParse(withdrawableAsync!.asData!.value) ?? 0) / 1000000
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EARNINGS'),
      ),
      body: Column(
        children: [
          AnimatedEntry(
            delay: 0,
            child: _buildCombinedSummary(
              totalInvestment,
              totalDailyProfit,
              referralBalance,
              totalReferralEarnings,
            ),
          ),
          AnimatedEntry(
            delay: 40,
            child: _buildDailyWithdrawCard(withdrawableBalance),
          ),
          AnimatedEntry(
            delay: 80,
            child: _buildTabBar(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                purchasesAsync.when(
                  data: (purchaseData) {
                    if (purchaseData.isEmpty) {
                      return _buildEmptyProducts();
                    }
                    return _buildProductsTab(purchaseData);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                          AppSpacing.hLg,
                          Text(
                            'Error loading packages: ${e.toString()}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildReferralsTab(referralStats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppGradients.primary,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        indicatorPadding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'PRODUCTS'),
          Tab(text: 'REFERRALS'),
        ],
      ),
    );
  }

  Widget _buildCombinedSummary(
    double totalInvestment,
    double totalDailyProfit,
    double referralBalance,
    double totalReferralEarnings,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.overlayGreen,
            AppColors.surfaceCardAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.borderPrimary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowGreen.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: AppGradients.primary,
                  ),
                ),
                AppSpacing.wSm,
                Text(
                  'OVERVIEW',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildStatItemSmall(
                Icons.monetization_on_outlined,
                'Total Investment',
                '\$${totalInvestment.toStringAsFixed(2)}',
              ),
              _buildStatItemSmall(
                Icons.trending_up_rounded,
                'Daily Profit',
                '\$${totalDailyProfit.toStringAsFixed(2)}',
              ),
            ],
          ),
          AppSpacing.hMd,
          Row(
            children: [
              _buildStatItemSmall(
                Icons.account_balance_wallet_rounded,
                'Referral Balance',
                '\$${referralBalance.toStringAsFixed(2)}',
              ),
              _buildStatItemSmall(
                Icons.emoji_events_rounded,
                'Total Referral',
                '\$${totalReferralEarnings.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemSmall(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          AppSpacing.hXs,
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          AppSpacing.hXs,
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyWithdrawCard(double dailyProfit) {
    final isZero = dailyProfit <= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: AppPressable(
        onTap: isZero ? null : () => context.push('/withdraw'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isZero ? AppColors.surfaceCardAlt : AppColors.surfaceCard,
            border: Border.all(
              color: isZero ? AppColors.borderSubtle : AppColors.borderPrimary,
              width: isZero ? 1 : 1.5,
            ),
            boxShadow: isZero
                ? null
                : [
                    BoxShadow(
                      color: AppColors.shadowGreen.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isZero
                      ? AppColors.textMuted.withValues(alpha: 0.1)
                      : AppColors.overlayGreen,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: isZero ? AppColors.textMuted : AppColors.primary,
                ),
              ),
              AppSpacing.wMd,
              Expanded(
                child: Text(
                  isZero ? 'No Daily Withdrawable' : 'Daily Withdrawable',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isZero ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '\$${dailyProfit.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isZero ? AppColors.textMuted : AppColors.primary,
                ),
              ),
              if (!isZero) ...[
                AppSpacing.wSm,
                Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(List<Map<String, dynamic>> purchases) {
    final purchaseWidgets = purchases
        .where((p) => p.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        ...purchaseWidgets.asMap().entries.map((entry) {
          final index = entry.key;
          final purchase = entry.value;
          return AnimatedScaleIn(
            delay: index * 40,
            child: _buildPurchaseCard(purchase),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyProducts() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.overlayGreen,
                  border: Border.all(
                    color: AppColors.overlayGreenStrong,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.hXxl,
              Text(
                'No Packages Yet',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              AppSpacing.hMd,
              Text(
                'Purchase an LSSC package to start\ngenerating daily earnings!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
              AppSpacing.hXxxl,
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: 'Go to Shop',
                  icon: Icons.directions_bike_rounded,
                  onPressed: () => context.push('/lssc'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralsTab(ReferralStats? stats) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        if (stats != null) _buildReferralStatsCard(stats),
        AppSpacing.hXl,
        Text(
          'Recent Commissions',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        AppSpacing.hMd,
        _buildRecentCommissions(),
      ],
    );
  }

  Widget _buildReferralStatsCard(ReferralStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withValues(alpha: 0.15),
            AppColors.surfaceCardAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.accentPurple.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: AppGradients.referral,
                ),
              ),
              AppSpacing.wSm,
              Text(
                'TEAM STATS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          AppSpacing.hMd,
          Row(
            children: [
              _buildSmallStat('Team', '${stats.totalTeamMembers}'),
              _buildSmallStat('Active', '${stats.activeMembers}'),
              _buildSmallStat('Deposits', '\$${stats.totalTeamDeposit.toStringAsFixed(2)}'),
            ],
          ),
          AppSpacing.hMd,
          Row(
            children: [
              _buildSmallStat('Today Earned', '\$${stats.todayEarnings.toStringAsFixed(2)}'),
              _buildSmallStat('Total Earned', '\$${stats.totalReferralEarnings.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          AppSpacing.hXs,
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCommissions() {
    final earningsAsync = ref.watch(referralEarningsProvider);

    return earningsAsync.when(
      data: (earnings) {
        final recent = earnings.take(5).toList();
        if (recent.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No commissions yet.\nInvite friends to earn!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          );
        }
        return Column(
          children: [
            ...recent.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedScaleIn(
                delay: entry.key * 30,
                child: _buildCommissionTile(entry.value),
              ),
            )),
            if (earnings.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: () => context.push('/referrals/earnings'),
                  child: Text(
                    'View All (${earnings.length})',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Could not load commissions',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildCommissionTile(ReferralCommission item) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
    final dateStr = '${date.month}/${date.day}/${date.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceCardAlt,
        border: Border.all(color: AppColors.overlayGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.overlayGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          AppSpacing.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fromUsername,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Level ${item.level} \u2022 ${item.percent}% of \$${item.depositAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+\$${item.commissionAmount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPurchaseCard(Map<String, dynamic> purchase) {
    final purchaseId = purchase['_id'] as String? ?? '';
    final name = purchase['bikeName'] as String? ?? 'Package';
    final price = (purchase['equipmentPrice'] as num?)?.toDouble() ?? 0;
    final daily = (purchase['dailyIncome'] as num?)?.toDouble() ?? 0;
    final monthly = daily * 30;
    final purchasedAt = (purchase['purchasedAt'] as num?)?.toDouble() ?? 0;
    final date = purchasedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(purchasedAt.toInt())
        : null;
    final dateStr =
        date != null ? '${date.month}/${date.day}/${date.year}' : '';
    final canClaim = _canClaim(purchase);
    final hoursLeft = _hoursUntilClaim(purchase);
    final isClaiming = _claimingPurchaseId == purchaseId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceCardAlt,
        border: Border.all(
          color: canClaim ? AppColors.overlayGreenMedium : AppColors.borderSubtle,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.overlayGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bike_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              AppSpacing.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    AppSpacing.hXs,
                    Text(
                      'Invested: \$${price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        'Purchased: $dateStr',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              AppSpacing.wMd,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+\$${daily.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '/day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  AppSpacing.hXs,
                  Text(
                    '\$${monthly.toStringAsFixed(2)}/mo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.hMd,
          Container(
            height: 1,
            color: AppColors.borderSubtle,
          ),
          AppSpacing.hMd,
          Row(
            children: [
              if (!canClaim)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${hoursLeft}h remaining',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.overlayGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ready to claim',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const Spacer(),
              _claimError != null && _claimingPurchaseId == null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _claimError!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.error,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              _claimSuccess != null && _claimingPurchaseId == null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _claimSuccess!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              _ClaimButton(
                isClaiming: isClaiming,
                canClaim: canClaim,
                onClaim: () => _handleClaim(purchaseId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({
    required this.isClaiming,
    required this.canClaim,
    required this.onClaim,
  });

  final bool isClaiming;
  final bool canClaim;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final isEnabled = canClaim && !isClaiming;

    return AppPressable(
      onTap: isEnabled ? onClaim : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isEnabled
              ? AppGradients.primary
              : null,
          color: isEnabled ? null : AppColors.textMuted.withValues(alpha: 0.12),
          border: isEnabled
              ? null
              : Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
        ),
        alignment: Alignment.center,
        child: isClaiming
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textMuted,
                ),
              )
            : Text(
                isEnabled ? 'Claim' : 'Claim',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? Colors.black : AppColors.textMuted,
                ),
              ),
      ),
    );
  }
}

class LsscScreen extends ConsumerStatefulWidget {
  const LsscScreen({super.key});

  @override
  ConsumerState<LsscScreen> createState() => _LsscScreenState();
}

class _LsscScreenState extends ConsumerState<LsscScreen> {
  static const _bikeOrder = [
    'a1',
    'a2',
    'a3',
    'b1',
    'b2',
    'b3',
    's1',
    's2',
    's3',
  ];

  late List<LsscModel> bikes;

  @override
  void initState() {
    super.initState();
    bikes = [
      LsscModel(
        id: 'a1',
        name: 'A1',
        icon: '⚡',
        equipmentPrice: 20.00,
        dailyIncome: 2.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 'a2',
        name: 'A2',
        icon: '⚡',
        equipmentPrice: 100.00,
        dailyIncome: 6.60,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 'a3',
        name: 'A3',
        icon: '⚡',
        equipmentPrice: 380.00,
        dailyIncome: 25.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 'b1',
        name: 'B1',
        icon: '⚡',
        equipmentPrice: 780.00,
        dailyIncome: 52.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 'b2',
        name: 'B2',
        icon: '⚡',
        equipmentPrice: 1800.00,
        dailyIncome: 120.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 'b3',
        name: 'B3',
        icon: '⚡',
        equipmentPrice: 4800.00,
        dailyIncome: 320.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 's1',
        name: 'S1',
        icon: '⚡',
        equipmentPrice: 12800.00,
        dailyIncome: 853.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 's2',
        name: 'S2',
        icon: '⚡',
        equipmentPrice: 25800.00,
        dailyIncome: 1720.00,
        imageUrl: 'asset/lssc.png',
      ),
      LsscModel(
        id: 's3',
        name: 'S3',
        icon: '⚡',
        equipmentPrice: 58000.00,
        dailyIncome: 3850.00,
        imageUrl: 'asset/lssc.png',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Container(
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(
                'lssc global',
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
      body: purchasesAsync.when(
        data: (purchases) {
          final ownedBikeIds = purchases
              .map((p) => p['bikeId'] as String? ?? '')
              .toSet();
          for (final bike in bikes) {
            bike.isOwned = ownedBikeIds.contains(bike.id);
          }
          final userId = ref.watch(authProvider).userId;
          final balanceAsync = userId != null
              ? ref.watch(balanceProvider(userId))
              : const AsyncValue.data('0');

          return balanceAsync.when(
            data: (balanceStr) {
              final userBalance = BigInt.tryParse(balanceStr) ?? BigInt.zero;
              final highestOwnedIndex = _bikeOrder
                  .asMap()
                  .entries
                  .where((entry) => ownedBikeIds.contains(entry.value))
                  .map((entry) => entry.key)
                  .fold<int?>(null, (prev, index) => prev == null ? index : index > prev ? index : prev) ?? -1;
              final nextBikeIndex = highestOwnedIndex + 1;
              final hasOwnedPackages = highestOwnedIndex >= 0;
              final previousOwnedBikeRefund = hasOwnedPackages
                  ? BigInt.from((bikes[highestOwnedIndex].equipmentPrice * 1000000).round())
                      * BigInt.from(98) ~/ BigInt.from(100)
                  : BigInt.zero;
              final effectiveBalance = userBalance + previousOwnedBikeRefund;

              BigInt maxAffordablePrice = BigInt.from(-1);
              for (final bike in bikes) {
                if (!ownedBikeIds.contains(bike.id)) {
                  final bikePriceMicros = BigInt.from((bike.equipmentPrice * 1000000).round());
                  if (effectiveBalance >= bikePriceMicros && bikePriceMicros > maxAffordablePrice) {
                    maxAffordablePrice = bikePriceMicros;
                  }
                }
              }

              final highestAffordableBike = maxAffordablePrice > BigInt.from(-1)
                  ? bikes.firstWhere((bike) => BigInt.from((bike.equipmentPrice * 1000000).round()) == maxAffordablePrice)
                  : null;

              String nextPackageMessage;
              if (nextBikeIndex < bikes.length) {
                final nextBike = bikes[nextBikeIndex];
                final currentDailyIncome = hasOwnedPackages
                    ? bikes[highestOwnedIndex].dailyIncome
                    : 0.0;
                final incomeGain = nextBike.dailyIncome - currentDailyIncome;
                final nextPriceMicros = BigInt.from((nextBike.equipmentPrice * 1000000).round());
                final neededMicros = effectiveBalance >= nextPriceMicros
                    ? BigInt.zero
                    : nextPriceMicros - effectiveBalance;
                final neededUsd = neededMicros == BigInt.zero
                    ? '0.00'
                    : (neededMicros.toDouble() / 1000000).toStringAsFixed(2);
                nextPackageMessage = neededMicros == BigInt.zero
                    ? 'Upgrade to ${nextBike.name} for +\$${incomeGain.toStringAsFixed(2)}/day.'
                    : 'Need \$${neededUsd} more to upgrade to ${nextBike.name} for +\$${incomeGain.toStringAsFixed(2)}/day.';
              } else if (maxAffordablePrice > BigInt.from(-1)) {
                final availableBike = bikes.firstWhere(
                  (bike) => !ownedBikeIds.contains(bike.id) &&
                      BigInt.from((bike.equipmentPrice * 1000000).round()) == maxAffordablePrice,
                );
                nextPackageMessage =
                    'You can afford ${availableBike.name} and earn \$${availableBike.dailyIncome.toStringAsFixed(2)}/day.';
              } else {
                final starterBike = bikes.firstWhere((bike) => !ownedBikeIds.contains(bike.id));
                final neededMicros = BigInt.from((starterBike.equipmentPrice * 1000000).round()) - userBalance;
                final neededUsd = (neededMicros.toDouble() / 1000000).toStringAsFixed(2);
                nextPackageMessage =
                    'Need \$${neededUsd} more to afford ${starterBike.name} and earn \$${starterBike.dailyIncome.toStringAsFixed(2)}/day.';
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(purchasesProvider);
                  final userId = ref.read(authProvider).userId;
                  if (userId != null) {
                    ref.invalidate(balanceProvider(userId));
                  }
                  await Future.wait([
                    ref.refresh(purchasesProvider.future),
                    if (userId != null)
                      ref.refresh(balanceProvider(userId).future),
                  ]);
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInvestmentStatsCard(nextPackageMessage, userBalance),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 3
                              : (constraints.maxWidth > 600 ? 2 : 1);
                          final childAspectRatio = crossAxisCount == 3
                              ? 1.18
                              : (crossAxisCount == 2 ? 1.28 : 1.4);

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: bikes.length,
                            itemBuilder: (context, index) {
                            final bike = bikes[index];
                            final isOwned = ownedBikeIds.contains(bike.id);
                            final isLowerPackage = highestOwnedIndex > index && !isOwned;
                            final bikePriceMicros = BigInt.from((bike.equipmentPrice * 1000000).round());
                            final isNextPackage = index == nextBikeIndex;

                            final canBuy = !isOwned && !isLowerPackage && (
                              hasOwnedPackages
                                  ? (isNextPackage && effectiveBalance >= bikePriceMicros)
                                  : (bikePriceMicros == maxAffordablePrice)
                            );

                            String? disabledReason;
                            if (isOwned) {
                              disabledReason = null;
                            } else if (isLowerPackage) {
                              disabledReason = 'Only upgrade available';
                            } else if (hasOwnedPackages) {
                              if (isNextPackage) {
                                disabledReason = effectiveBalance >= bikePriceMicros
                                    ? null
                                    : 'Deposit more or close the current package to upgrade';
                              } else {
                                disabledReason = 'Only upgrade available';
                              }
                            } else {
                              if (bikePriceMicros == maxAffordablePrice) {
                                disabledReason = null;
                              } else if (maxAffordablePrice > BigInt.from(-1) && bikePriceMicros < maxAffordablePrice) {
                                disabledReason =
                                    'Your deposit qualifies for ${highestAffordableBike?.name ?? 'a higher package'} only';
                              } else {
                                disabledReason = 'Insufficient balance';
                              }
                            }

                            return LsscCard(
                              bike: bike,
                              colorScheme: colorScheme,
                              isOwned: isOwned,
                              canBuy: canBuy,
                              isNextPackage: isNextPackage,
                              disabledReason: disabledReason,
                              onStatusChanged: () => setState(() {}),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load packages',
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Could not load packages',
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

  Widget _buildInvestmentStatsCard(String nextPackageMessage, BigInt userBalanceMicros) {
    double totalInvestment = 0.0;
    double interestCollectable = 0.0;

    for (var bike in bikes) {
      if (bike.isOwned) {
        totalInvestment += bike.equipmentPrice;
        interestCollectable += bike.dailyIncome * 30;
      }
    }

    final userBalance = userBalanceMicros.toDouble() / 1000000;

    return AppCard(
      borderRadius: 20,
      color: AppColors.surfaceCard,
      borderColor: AppColors.overlayGreenStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                label: 'Monthly Earnings',
                value: '\$${interestCollectable.toStringAsFixed(2)}',
              ),
              Container(
                width: 1,
                height: 60,
                color: const Color(0xFF00C853).withValues(alpha: 0.3),
              ),
              _buildStatItem(
                icon: '💳',
                label: 'Your Balance',
                value: '\$${userBalance.toStringAsFixed(2)}',
              ),
            ],
          ),
          if (interestCollectable > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                'Your packages earn daily. This is your total projected income for 30 days from all your active packages.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Next upgrade',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/deposit'),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Deposit',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nextPackageMessage,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.green[200],
              fontWeight: FontWeight.w600,
            ),
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
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          AppSpacing.hSm,
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          AppSpacing.hXs,
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class LsscModel {
  final String id;
  final String name;
  final String icon;
  final double equipmentPrice;
  final double dailyIncome;
  final String? imageUrl;
  bool isOwned;

  LsscModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.equipmentPrice,
    required this.dailyIncome,
    this.imageUrl,
    this.isOwned = false,
  });
}

class LsscCard extends ConsumerStatefulWidget {
  final LsscModel bike;
  final ColorScheme colorScheme;
  final bool isOwned;
  final bool canBuy;
  final bool isNextPackage;
  final String? disabledReason;
  final VoidCallback? onStatusChanged;

  const LsscCard({
    required this.bike,
    required this.colorScheme,
    required this.isOwned,
    required this.canBuy,
    required this.isNextPackage,
    this.disabledReason,
    this.onStatusChanged,
    super.key,
  });

  @override
  ConsumerState<LsscCard> createState() => _LsscCardState();
}

class _LsscCardState extends ConsumerState<LsscCard> {
  bool _isLoading = false;

  void _joinLssc() async {
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

      BigInt refundAmount = BigInt.zero;
      final purchasesAsync = ref.read(purchasesProvider);
      final purchases = purchasesAsync is AsyncData<List<Map<String, dynamic>>>
          ? purchasesAsync.value
          : await ref.read(purchasesProvider.future);

      final highestOwnedIndex = purchases
          .map((p) => _LsscScreenState._bikeOrder.indexOf(p['bikeId'] as String? ?? ''))
          .where((index) => index >= 0)
          .fold<int?>(null, (prev, index) => prev == null ? index : index > prev ? index : prev) ?? -1;
      if (highestOwnedIndex >= 0) {
        final nextIndex = highestOwnedIndex + 1;
        if (nextIndex < _LsscScreenState._bikeOrder.length && widget.bike.id == _LsscScreenState._bikeOrder[nextIndex]) {
          final refundPurchase = purchases.firstWhere(
            (p) => _LsscScreenState._bikeOrder.indexOf(p['bikeId'] as String? ?? '') == highestOwnedIndex,
            orElse: () => {},
          );
          {
            final refundPrice = (refundPurchase['equipmentPrice'] as num).toDouble();
            refundAmount = BigInt.from((refundPrice * 1000000).round()) *
                BigInt.from(98) ~/
                BigInt.from(100);
          }
        }
      }

      final effectiveBalance = balance + refundAmount;
      if (effectiveBalance < priceInMicro) {
        _showInsufficientBalanceDialog();
        return;
      }

      if (!widget.canBuy) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.disabledReason ?? 'This package is locked until you buy level 1.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final apiService = ref.read(apiServiceProvider);
      await apiService.buyBike(
        userId,
        widget.bike.id,
        widget.bike.equipmentPrice.toStringAsFixed(2),
      );

      ref.invalidate(balanceProvider(userId));
      ref.invalidate(purchasesProvider);

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
    final isHighlighted = widget.isOwned || widget.isNextPackage;
    final isDisabledByBalance = !widget.canBuy && !widget.isOwned;
    
    return AppPressable(
      onTap: widget.canBuy ? null : null,
      child: Opacity(
        opacity: isDisabledByBalance ? 0.4 : 1.0,
        child: AppCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(12),
          color: isHighlighted
              ? const Color(0xFF0C2B16)
              : AppColors.surfaceCard,
          borderColor: isHighlighted
              ? AppColors.primary
              : AppColors.overlayGreenMedium,
          borderWidth: isHighlighted ? 1.5 : 1,
          glowColor: isHighlighted ? AppColors.primary : null,
          child: Row(
            children: [
              _buildImage(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetails(),
                    const SizedBox(height: 6),
                    _buildStatsRow(),
                    const SizedBox(height: 10),
                    _buildAction(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final isCompact = MediaQuery.of(context).size.width > 900;
    final imgWidth = isCompact ? 80.0 : 92.0;
    final imgHeight = isCompact ? 96.0 : 120.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: imgWidth,
        height: imgHeight,
        child: Image.asset(
          widget.bike.imageUrl ?? 'asset/lssc.png',
          fit: BoxFit.contain,
          width: imgWidth,
          height: imgHeight,
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Image.asset(
      'asset/lssc.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF00C853).withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.bike.name,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        if (widget.isOwned)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Currently Owned',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00C853),
              ),
            ),
          )
        else if (widget.isNextPackage)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Next upgrade',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00C853),
              ),
            ),
          ),
        Text(
          'Price: \$${widget.bike.equipmentPrice.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    // Calculate daily income percentage based on price
    final dailyPercentage = (widget.bike.dailyIncome / widget.bike.equipmentPrice * 100).toStringAsFixed(2);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rate of return
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Rate of return',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$dailyPercentage%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Invest cycle (daily income)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Invest cycle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${widget.bike.dailyIncome.toStringAsFixed(2)}/day',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF81C784),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Available investments
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
            Text(
              'Unlimited',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAction() {
    if (widget.isOwned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF00C853).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFF00C853).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 14, color: const Color(0xFF00C853)),
            const SizedBox(width: 6),
            Text(
              'Currently Owned',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00C853),
              ),
            ),
          ],
        ),
      );
    }

    if (!widget.canBuy) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[850],
          border: Border.all(
            color: Colors.grey[700]!,
          ),
        ),
        child: Text(
          widget.disabledReason ?? 'Insufficient balance',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\$${widget.bike.equipmentPrice.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _isLoading ? null : _joinLssc,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            disabledBackgroundColor: Colors.grey[700],
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  'Buy now',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
        ),
      ],
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
    ref.watch(selectedPeriodProvider);

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

          final aCount = teamA['count'] as int? ?? 0;
          final bCount = teamB['count'] as int? ?? 0;
          final cCount = teamC['count'] as int? ?? 0;

          final aIncome = teamA['benefitsPct'] as int? ?? 0;
          final bIncome = teamB['benefitsPct'] as int? ?? 0;
          final cIncome = teamC['benefitsPct'] as int? ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                _buildStatRow([
                  ('Team A', '$aCount', AppColors.success),
                  ('Team B', '$bCount', AppColors.accentBlue),
                  ('Team C', '$cCount', AppColors.accentPurple),
                ]),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildTeamCard(title: 'Team A', count: '$aCount', percent: '$aIncome%', color: AppColors.success, gradientColors: [const Color(0xFF1B5E20).withValues(alpha: 0.3), Colors.transparent])),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTeamCard(title: 'Team B', count: '$bCount', percent: '$bIncome%', color: AppColors.accentBlue, gradientColors: [AppColors.overlayBlue, Colors.transparent])),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTeamCard(title: 'Team C', count: '$cCount', percent: '$cIncome%', color: AppColors.accentPurple, gradientColors: [AppColors.overlayPurpleSoft, Colors.transparent])),
                  ],
                ),
                const SizedBox(height: 24),
                _buildRecentCommissions(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading team data')),
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

  Widget _buildRecentCommissions() {
    final earningsAsync = ref.watch(referralEarningsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Commissions', style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        )),
        const SizedBox(height: 12),
        earningsAsync.when(
          data: (earnings) {
            final recent = earnings.take(5).toList();
            if (recent.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF1E1E1E),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'No commissions yet.\nInvite friends to earn!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
                ),
              );
            }
            return Column(
              children: [
                ...recent.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCommissionTile(e),
                )),
                if (earnings.length > 5)
                  TextButton(
                    onPressed: () => context.push('/referrals/earnings'),
                    child: Text(
                      'View All (${earnings.length})',
                      style: const TextStyle(color: Color(0xFF00C853)),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1E1E1E),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Could not load commissions',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionTile(ReferralCommission item) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
    final dateStr = '${date.month}/${date.day}/${date.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF00C853),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fromUsername,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Level ${item.level} \u2022 ${item.percent}% of \$${item.depositAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+\$${item.commissionAmount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00C853),
                  ),
                ),
                Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _buildPeriodTab('today', 'Today'),
        const SizedBox(width: 8),
        _buildPeriodTab('last7days', 'Week'),
        const SizedBox(width: 8),
        _buildPeriodTab('thismonth', 'Month'),
      ],
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
        try {
          final queryCode = GoRouterState.of(context).uri.queryParameters['invitationCode'] ?? GoRouterState.of(context).uri.queryParameters['ref'] ?? '';
          if (queryCode.isNotEmpty) {
            _inviteCtrl.text = queryCode;
            setState(() => _isLogin = false);
          }
        } catch (_) {}
        _initialized = true;
      }
    });
  }
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _obscureTransPass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _transPassCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    
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

      // Check referral code validity before registering
      if (invite.isNotEmpty) {
        final isValid = await ref.read(authProvider.notifier).checkReferralCode(invite);
        if (!isValid) {
          _showError('Invalid referral code. Please check and try again.');
          return;
        }
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

    return AnimatedEntry(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.authBackground,
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
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('asset/logo.png'),
                          fit: BoxFit.contain,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowGreen.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.hLg,
                    Text(
                      'LSSC ONE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    AppSpacing.hXxxl,
                    
                    _buildTextField('Email Address', Icons.email_outlined, _emailCtrl),
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Password', 
                      Icons.lock_outline, 
                      _passCtrl, 
                      obscureText: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: AppColors.primary),
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
                          icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility, color: AppColors.primary),
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
                          icon: Icon(_obscureTransPass ? Icons.visibility_off : Icons.visibility, color: AppColors.primary),
                          onPressed: () => setState(() => _obscureTransPass = !_obscureTransPass),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildTextField('Invite Code (Optional 5-digit code)', Icons.card_giftcard, _inviteCtrl),
                    ],
                    
                    AppSpacing.hXxxl,
                    AppPrimaryButton(
                      label: _isLogin ? 'Access Wallet' : 'Create Account',
                      isLoading: authState.isLoading,
                      onPressed: authState.isLoading ? null : _handleSubmit,
                    ),

                    AppSpacing.hMd,
                    if (_isLogin)
                      TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Forgot Password?'),
                      ),
                    AppSpacing.hXs,
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin ? "Don't have an account? Register" : "Already have an account? Login",
                      ),
                    ),
                  ],
                ),
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
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                child: const Text('I\'ve Verified (Simulate)'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).skipVerification();
                  if (context.mounted) context.go('/');
                },
                child: const Text('Skip for now', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
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
          gradient: AppGradients.authBackground,
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
                  Icon(Icons.lock_reset, size: 70, color: AppColors.primary),
                  AppSpacing.hLg,
                  Text(
                    'Forgot Password?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  AppSpacing.hSm,
                  Text(
                    'Enter your email and we\'ll send you a reset link.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 35),
                  if (_sent)
                    Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: AppColors.primary),
                        AppSpacing.hLg,
                        Text(
                          'Reset link sent!',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        AppSpacing.hSm,
                        Text(
                          'Check your email inbox and click the link to reset your password.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textTertiary),
                        ),
                        AppSpacing.hXxxl,
                        AppPrimaryButton(
                          label: 'Back to Login',
                          onPressed: () => context.go('/login'),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildTextField('Email Address', Icons.email_outlined, _emailCtrl),
                        AppSpacing.hXxxl,
                        AppPrimaryButton(
                          label: 'Send Reset Link',
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _handleSubmit,
                        ),
                        AppSpacing.hMd,
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to Login'),
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
        prefixIcon: Icon(icon),
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
                          : const Text('Reset Transaction Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

// --- Welcome Modal ---
const String telegramGroupUrl = 'https://t.me/+GQf04WTt82o4ZmI8';
const String telegramChannelUrl = 'https://t.me/+IUXpCCZDOA8yMDM0';
const String contactAssistantUrl = 'https://t.me/Lssc1support';

void _showWelcomeModal(BuildContext context, String? email) {
  final userName = email != null ? email.split('@').first : 'Valued User';
  final hour = DateTime.now().hour;
  String greeting;
  IconData greetingIcon;
  if (hour < 12) {
    greeting = 'Good Morning';
    greetingIcon = Icons.wb_sunny_outlined;
  } else if (hour < 17) {
    greeting = 'Good Afternoon';
    greetingIcon = Icons.wb_cloudy_outlined;
  } else {
    greeting = 'Good Evening';
    greetingIcon = Icons.nightlight_round;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      contentPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header ---
            Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF00C853)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(greetingIcon, size: 40, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  greeting,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // --- Body ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [
                Text(
                  'Welcome to LSSC ONE! 🚀',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Stay updated with the latest news, features, and community discussions.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[400],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // --- Telegram Section ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF0088CC).withValues(alpha: 0.1),
                    border: Border.all(
                      color: const Color(0xFF0088CC).withValues(alpha: 0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0088CC).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.telegram,
                          color: Color(0xFF0088CC),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Our Telegram',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Get real-time updates & support',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final url = Uri.parse(telegramGroupUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF0088CC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Join',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // --- Telegram Channel ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF0088CC).withValues(alpha: 0.08),
                    border: Border.all(
                      color: const Color(0xFF0088CC).withValues(alpha: 0.25),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0088CC).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.telegram,
                          color: Color(0xFF0088CC),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'View Our Telegram Channel',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Follow announcements and news updates',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final url = Uri.parse(telegramChannelUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF0088CC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'View',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // --- Contact Assistant ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF00C853).withValues(alpha: 0.08),
                    border: Border.all(
                      color: const Color(0xFF00C853).withValues(alpha: 0.25),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.headset_mic_rounded,
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
                              'Contact Assistant',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'We\'re here to help 24/7',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final url = Uri.parse(contactAssistantUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Contact',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // --- Footer Close ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    ),
  );
}

// --- Dashboard ---
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).refreshUser());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_welcomeShown) return;
    final auth = ref.read(authProvider);
    if (auth.sessionRestored && auth.userId != null) {
      _welcomeShown = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _showWelcomeModal(context, auth.email);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    
    final balanceAsync = ref.watch(balanceProvider(userId));
    final activityAsync = ref.watch(activityProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PORTFOLIO'),
        actions: [
          AppIconButton(
            icon: Icons.settings_outlined,
            onPressed: () => context.push('/settings'),
          ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              AnimatedEntry(
                delay: 80,
                child: balanceAsync.when(
                  data: (balance) => _PortfolioCard(balance: balance, isAdmin: auth.isAdmin),
                  loading: () => _PortfolioCard(balance: "...", isLoading: true, isAdmin: auth.isAdmin),
                  error: (e, s) => _PortfolioCard(balance: "0.00", isAdmin: auth.isAdmin),
                ),
              ),
              AppSpacing.hXl,
              AnimatedEntry(
                delay: 160,
                child: const _LiveActivityTicker(),
              ),
              AppSpacing.hXl,
              AnimatedEntry(
                delay: 240,
                child: _AffiliatePromotionCard(onTap: () => context.push('/earnings')),
              ),
              AppSpacing.hXxxl,
              AnimatedEntry(
                delay: 300,
                child: Row(
                  children: [
                    Expanded(child: _ActionTile(icon: Icons.add_circle_outline, label: 'Deposit', color: AppColors.success, onTap: () => context.push('/deposit'))),
                    AppSpacing.wLg,
                    Expanded(child: _ActionTile(icon: Icons.arrow_circle_up_outlined, label: 'Withdraw', color: AppColors.warning, onTap: () => context.push('/withdraw'))),
                  ],
                ),
              ),
              AppSpacing.hXxxl,
              AnimatedEntry(
                delay: 420,
                child: const _OurProductSection(),
              ),
              AppSpacing.hXxxl,
              AnimatedEntry(
                delay: 480,
                child: const _RecentActivityHeader(),
              ),
              AppSpacing.hXl,
              AnimatedEntry(
                delay: 540,
                child: activityAsync.when(
                  data: (items) => _ActivityList(items: items),
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, s) => _ErrorState(
                    message: 'Failed to load activity',
                    onRetry: () => ref.invalidate(activityProvider(userId)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        gradient: AppGradients.primary,
        boxShadow: [BoxShadow(color: AppColors.shadowGreen, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('Total Stablecoin Balance', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
              ),
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
          AppSpacing.hMd,
          isLoading 
            ? const SizedBox(height: 45, width: 45, child: CircularProgressIndicator(color: Colors.white))
            : Text('\$${displayBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
          AppSpacing.hLg,
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

// --- Live Activity Ticker ---
class _LiveActivityTicker extends StatefulWidget {
  const _LiveActivityTicker();

  @override
  State<_LiveActivityTicker> createState() => _LiveActivityTickerState();
}

class _LiveActivityTickerState extends State<_LiveActivityTicker>
    with SingleTickerProviderStateMixin {
  final List<_MockTx> _items = [];
  final _scrollController = ScrollController();
  late Timer _addTimer;
  late AnimationController _animController;
  final _random = Random();

  static const _usernames = [
    '0x7F3e…A2b1', '0x4D8a…C9f0', '0xE12b…B7d3',
    '0x9A5c…F6e2', '0xB80d…D4a8', '0x3C2f…E1b9',
    '0xK91g…H5c0', '0xM72h…J8d1', '0xP63i…L2e4',
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 10; i++) {
      _items.add(_generateTx());
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 75),
    )..addListener(_onTick);
    _animController.repeat();

    _addTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _items.add(_generateTx());
        if (_items.length > 25) _items.removeAt(0);
      });
    });
  }

  void _onTick() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final half = maxScroll / 2;
    final pos = _animController.value * half;
    if (_animController.value >= 0.99) {
      _animController.reset();
      _scrollController.jumpTo(0);
    } else {
      _scrollController.jumpTo(pos);
    }
  }

  @override
  void dispose() {
    _addTimer.cancel();
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _MockTx _generateTx() {
    final isDeposit = _random.nextBool();
    final rawAmount = 50 + _random.nextDouble() * 4950;
    final amount = double.parse(rawAmount.toStringAsFixed(2));
    return _MockTx(
      username: _usernames[_random.nextInt(_usernames.length)],
      amount: amount,
      isDeposit: isDeposit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary, blurRadius: 4),
                  ],
                ),
              ),
              AppSpacing.wSm,
              Text(
                'Live Transactions',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${_items.length} txs',
                style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          AppSpacing.hMd,
          SizedBox(
            height: 36,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _items.length * 2,
              itemBuilder: (context, index) {
                final tx = _items[index % _items.length];
                return _buildTxChip(tx);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxChip(_MockTx tx) {
    final isDep = tx.isDeposit;
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDep
            ? AppColors.overlayGreen
            : AppColors.overlayOrange,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDep
              ? AppColors.overlayGreenMedium
              : AppColors.accentOrange.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDep ? Icons.arrow_downward : Icons.arrow_upward,
            color: isDep ? AppColors.success : AppColors.warning,
            size: 11,
          ),
          AppSpacing.wXs,
          Text(
            tx.username,
            style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
          ),
          AppSpacing.wXs,
          Text(
            '${isDep ? '+' : '-'}\$${tx.amount.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              color: isDep ? AppColors.success : AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockTx {
  final String username;
  final double amount;
  final bool isDeposit;
  _MockTx({
    required this.username,
    required this.amount,
    required this.isDeposit,
  });
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surfaceCardAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            AppSpacing.hSm,
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// --- Our Product Section ---
class _OurProductSection extends StatelessWidget {
  const _OurProductSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      borderColor: AppColors.overlayGreenMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.overlayGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
              ),
              AppSpacing.wMd,
              Expanded(
                child: Text('How LSSC ONE Helps', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          AppSpacing.hLg,
          _benefitRow(Icons.verified_user_rounded, 'Military-grade encryption keeps your funds safe at all times.'),
          AppSpacing.hMd,
          _benefitRow(Icons.swap_horiz_rounded, 'Instant deposits and withdrawals across all major blockchain networks.'),
          AppSpacing.hMd,
          _benefitRow(Icons.trending_up_rounded, 'Real-time balance tracking with automated sweep consolidation.'),
          AppSpacing.hMd,
          _benefitRow(Icons.support_agent_rounded, '24/7 monitoring and support — our team never sleeps on security.'),
          AppSpacing.hLg,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.overlayGreen,
              border: Border.all(color: AppColors.overlayGreenMedium),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                AppSpacing.wMd,
                Expanded(
                  child: Text(
                    'Trusted by 10,000+ users worldwide. Start protecting your crypto today.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary.withValues(alpha: 0.7)),
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
        Icon(icon, size: 18, color: AppColors.primary),
        AppSpacing.wMd,
        Expanded(
          child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary.withValues(alpha: 0.7), height: 1.3)),
        ),
      ],
    );
  }
}

// --- Activity History Full Page ---
class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    final activityAsync = ref.watch(activityProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activityProvider(userId));
          await ref.refresh(activityProvider(userId).future);
        },
        child: activityAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No activity yet', style: TextStyle(color: Colors.white38))),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ...items.asMap().entries.map((entry) {
                  return AnimatedScaleIn(
                    delay: entry.key * 30,
                    child: _buildItem(entry.value),
                  );
                }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Failed to load activity', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.invalidate(activityProvider(userId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(dynamic item) {
    final bool isDeposit = item['type'] == 'deposit';
    double amount = 0;
    try {
      amount = double.parse(item['amount'].toString()) / 1000000;
    } catch (_) {}
    String token = item['token'] ?? 'USDT';
    String status = item['status'] ?? 'pending';
    if (status == 'swept') status = 'confirmed';
    String hash = item['txHash']?.toString() ?? "";
    String displayHash = hash.isNotEmpty && hash.length > 10 ? "${hash.substring(0, 10)}..." : (hash.isNotEmpty ? hash : "Pending...");

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 15,
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isDeposit ? AppColors.overlayGreen : AppColors.overlayOrange),
          child: Icon(
            isDeposit ? Icons.call_received : Icons.call_made,
            color: isDeposit ? AppColors.success : AppColors.warning,
            size: 18,
          ),
        ),
        title: Text(
          isDeposit ? '$token Received' : '$token Withdrawal',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(displayHash, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textTertiary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: isDeposit ? AppColors.success : AppColors.warning),
            ),
            Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: status == 'confirmed' || status == 'completed' ? AppColors.success : AppColors.warning),
            ),
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
        Flexible(
          child: Text('Recent Activity', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        TextButton(onPressed: () => context.push('/activity'), child: const Text('See All', style: TextStyle(color: Colors.greenAccent))),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<dynamic> items;
  const _ActivityList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No activity yet", style: TextStyle(color: Colors.white38)),
      ));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final bool isDeposit = item['type'] == 'deposit';
        
        double amount = 0;
        try {
          amount = double.parse(item['amount'].toString()) / 1000000;
        } catch (_) {}
        
        String token = item['token'] ?? 'USDT';
        String status = item['status'] ?? 'pending';
        // Map 'swept' to 'confirmed' for the UI
        if (status == 'swept') status = 'confirmed';
        
        String hash = item['txHash']?.toString() ?? "";
        String displayHash = "Pending...";
        if (hash.isNotEmpty) {
          displayHash = hash.length > 10 ? "${hash.substring(0, 10)}..." : hash;
        }

        return AnimatedScaleIn(
          delay: i * 30,
          child: AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            borderRadius: 15,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (isDeposit ? AppColors.overlayGreen : AppColors.overlayOrange),
                child: Icon(
                  isDeposit ? Icons.call_received : Icons.call_made, 
                  color: isDeposit ? AppColors.success : AppColors.warning, 
                  size: 18
                ),
              ),
              title: Text(
                isDeposit ? '$token Received' : '$token Withdrawal', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)
              ),
              subtitle: Text(displayHash, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textTertiary)),
              trailing: Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)}', 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, 
                        color: isDeposit ? AppColors.success : AppColors.warning
                      )
                    ),
                    Text(
                      status.toUpperCase(), 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10, 
                        fontWeight: FontWeight.w700,
                        color: status == 'confirmed' || status == 'completed' ? AppColors.success : AppColors.warning
                      )
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Affiliate / Referral Promotion Card ---
class _AffiliatePromotionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AffiliatePromotionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCardAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
          gradient: LinearGradient(
            colors: [AppColors.accentBlue.withValues(alpha: 0.05), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.overlayBlue, shape: BoxShape.circle),
              child: Icon(Icons.people_outline, color: AppColors.accentBlue),
            ),
            AppSpacing.wLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Affiliate Program', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Earn up to 23% in commissions', style: GoogleFonts.poppins(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white54)),
            TextButton.icon(
              onPressed: onRetry, 
              icon: const Icon(Icons.refresh, size: 18), 
              label: const Text('Try Again'),
              style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
            ),
          ],
        ),
      ),
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
  String selectedNetwork = '';
  String selectedToken = 'USDT';
  final List<String> tokens = ['USDT', 'USDC'];
  List<dynamic> networks = [];

  static const List<Map<String, dynamic>> _mainnetFallbackNetworks = [
    {'chainId': 1, 'name': 'Ethereum Mainnet'},
    {'chainId': 137, 'name': 'Polygon Mainnet'},
  ];

  static const List<Map<String, dynamic>> _testnetFallbackNetworks = [
    {'chainId': 11155111, 'name': 'Ethereum Sepolia'},
    {'chainId': 80002, 'name': 'Polygon Amoy'},
  ];

  List<dynamic> get _visibleNetworks {
    const useMainnet = AppConfig.useMainnet;
    final filtered = useMainnet
        ? networks.where((n) => const [1, 137].contains(n['chainId'] as int?)).toList()
        : networks.where((n) => const [11155111, 80002].contains(n['chainId'] as int?)).toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }
    return useMainnet ? _mainnetFallbackNetworks : _testnetFallbackNetworks;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    final walletAsync = ref.watch(walletProvider(userId));
    final networksAsync = ref.watch(networksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DEPOSIT ASSETS')),
      body: networksAsync.when(
        data: (netList) {
          networks = netList;
          // Debug print to console to confirm networks received
          print('DepositScreen: networks loaded: ${networks.map((n) => n['name']).toList()}');
          final netNames = _visibleNetworks
              .map((n) => n['name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .cast<String>()
              .toList();
          if (selectedNetwork.isEmpty && netNames.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => selectedNetwork = netNames[0]);
            });
          }
          return walletAsync.when(
            data: (wallet) {
              if (wallet == null || wallet['address'] == null) {
                return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
              }
              return _buildBody(wallet['address']);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, s) => Center(child: Text('Error loading networks: $e')),
      ),
    );
  }

  Widget _buildBody(String address) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTokenDropdown(),
              const SizedBox(height: 15),
              _buildNetworkDropdown(),
              // Debug: show networks received from provider to help troubleshooting
              if (networks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Networks: ${networks.map((n) => n['name']).join(', ')}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ),
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
        ),
      ),
    );
  }

  Widget _buildTokenDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedToken,
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
    final netNames = _visibleNetworks
        .map((n) => n['name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toList();

    // Ensure selectedNetwork is always valid or empty
    if (netNames.isNotEmpty && !netNames.contains(selectedNetwork)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => selectedNetwork = netNames[0]);
        }
      });
    }

    return DropdownButtonFormField<String>(
      value: netNames.contains(selectedNetwork) ? selectedNetwork : '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Select Network',
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      items: netNames.isEmpty
          ? [const DropdownMenuItem(value: '', child: Text('No supported networks'))]
          : [const DropdownMenuItem(value: '', child: Text('Select a network')), ...netNames.map((n) => DropdownMenuItem(value: n, child: Text(n)))],
      onChanged: netNames.isEmpty
          ? null
          : (v) {
              print('DepositScreen: network changed -> $v');
              if (v != null && v.isNotEmpty) {
                setState(() => selectedNetwork = v);
              }
            },
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
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 15,
      color: AppColors.overlayOrange,
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
          AppSpacing.wMd,
          Expanded(child: Text('Only send $selectedToken to this address via $selectedNetwork. Using unsupported networks will result in permanent loss.', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning))),
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
  
  static const _storage = FlutterSecureStorage();
  
  String selectedNetwork = '';
  String selectedToken = 'USDT';
  bool _isLoading = false;
  Timer? _refreshTimer;
  List<dynamic> networks = [];

  static const List<Map<String, dynamic>> _mainnetFallbackNetworks = [
    {'chainId': 1, 'name': 'Ethereum Mainnet'},
    {'chainId': 137, 'name': 'Polygon Mainnet'},
  ];

  static const List<Map<String, dynamic>> _testnetFallbackNetworks = [
    {'chainId': 11155111, 'name': 'Ethereum Sepolia'},
    {'chainId': 80002, 'name': 'Polygon Amoy'},
  ];

  List<dynamic> get _visibleNetworks {
    const useMainnet = AppConfig.useMainnet;
    final filtered = useMainnet
        ? networks.where((n) => const [1, 137].contains(n['chainId'] as int?)).toList()
        : networks.where((n) => const [11155111, 80002].contains(n['chainId'] as int?)).toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }
    return useMainnet ? _mainnetFallbackNetworks : _testnetFallbackNetworks;
  }
  
  @override
  void initState() {
    super.initState();
    _loadSavedDetails();
    // Auto-refresh withdrawal status every 10 seconds while on this screen
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        final userId = ref.read(authProvider).userId;
        if (userId != null) {
          ref.invalidate(withdrawalsProvider(userId));
          ref.invalidate(withdrawableBalanceProvider(userId));
        }
      }
    });
  }

  Future<void> _loadSavedDetails() async {
    final savedAddress = await _storage.read(key: 'last_withdrawal_address');
    final savedPass = await _storage.read(key: 'last_transaction_password');
    if (mounted) {
      if (savedAddress != null) _addressCtrl.text = savedAddress;
      if (savedPass != null) _transPassCtrl.text = savedPass;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _amountCtrl.dispose();
    _transPassCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleWithdraw(double available) async {
    FocusManager.instance.primaryFocus?.unfocus();
    
    String addressInput = _addressCtrl.text.trim().replaceAll(' ', '');
    final amountStr = _amountCtrl.text.trim();
    final transPass = _transPassCtrl.text.trim();

    if (addressInput.isEmpty || amountStr.isEmpty || transPass.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    final amount = double.tryParse(amountStr) ?? 0;

    if (amount < 2.0) {
      _showError(r'Minimum withdrawal amount is $2.00');
      return;
    }

    if (amount > available) {
      _showError('Insufficient balance.');
      return;
    }

    // Auto-fix address formatting
    String cleanAddress = addressInput;
    if (cleanAddress.startsWith('I') || cleanAddress.startsWith('l')) {
        if (cleanAddress.length >= 40 && !cleanAddress.startsWith('0x')) {
             cleanAddress = '0x${cleanAddress.substring(1)}';
        }
    }
    if (!cleanAddress.startsWith('0x')) cleanAddress = '0x$cleanAddress';

    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(cleanAddress)) {
      _showError('Invalid Wallet Address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(authProvider).userId!;
      final net = _visibleNetworks.cast<Map<String, dynamic>>().firstWhere(
        (n) => n['name'] == selectedNetwork,
        orElse: () => _visibleNetworks.isNotEmpty ? _visibleNetworks[0] : {'chainId': 137},
      );
      final chainId = net['chainId'] as int;

      await ref.read(apiServiceProvider).requestWithdrawal({
        'userId': userId,
        'toAddress': cleanAddress,
        'amount': (amount * 1000000).toInt().toString(),
        'chainId': chainId,
        'network': selectedNetwork,
        'token': selectedToken,
        'transactionPassword': transPass,
      });
      
      // Save details for next time
      await _storage.write(key: 'last_withdrawal_address', value: cleanAddress);
      await _storage.write(key: 'last_transaction_password', value: transPass);
      
      if (mounted) {
        _showSuccess('Withdrawal Request Submitted');
        _amountCtrl.clear();
        // Keep address and password but clear amount
        ref.invalidate(withdrawalsProvider(userId));
        ref.invalidate(withdrawableBalanceProvider(userId));
        ref.invalidate(activityProvider(userId));
      }
    } catch (e) {
      String errorMsg = "Withdrawal failed";
      if (e is DioException) {
        final data = e.response?.data;
        if (data != null) {
          errorMsg = data.toString()
              .replaceAll('"', '')
              .replaceFirst(RegExp(r'\[CONVEX.*?\]\s*'), '')
              .replaceFirst('Uncaught Error: ', '')
              .trim();
        } else {
          errorMsg = e.message ?? "Connection error";
        }
      }
      if (mounted) _showError(errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating)
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.greenAccent, behavior: SnackBarBehavior.floating)
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    final balanceAsync = ref.watch(withdrawableBalanceProvider(userId));
    final withdrawalsAsync = ref.watch(withdrawalsProvider(userId));
    final networksAsync = ref.watch(networksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('WITHDRAW'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _buildSectionTitle('Network & Asset'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildModernDropdown(
                    label: 'Select Token',
                    value: selectedToken,
                    items: ['USDT', 'USDC'],
                    onChanged: (v) => setState(() => selectedToken = v!),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10)),
                  networksAsync.when(
                    data: (netList) {
                      networks = netList;
                                      final visibleNetworks = _visibleNetworks;
                      print('WithdrawScreen: visible networks: ${visibleNetworks.map((n) => n['name']).toList()}');
                      final netNames = visibleNetworks
                          .map((n) => n['name'] as String?)
                          .where((name) => name != null && name.isNotEmpty)
                          .cast<String>()
                          .toList();
                      
                      // Initialize selectedNetwork if not set or invalid
                      if ((selectedNetwork.isEmpty || !netNames.contains(selectedNetwork)) && netNames.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => selectedNetwork = netNames[0]);
                        });
                      }
                      
                      return _buildModernDropdown(
                        label: 'Target Network',
                        value: netNames.contains(selectedNetwork) ? selectedNetwork : '',
                        items: netNames,
                        onChanged: netNames.isEmpty
                            ? null
                            : (v) {
                                print('WithdrawScreen: network changed -> $v');
                                if (v != null && v.isNotEmpty) {
                                  setState(() => selectedNetwork = v);
                                }
                              },
                      );
                    },
                    loading: () => _buildModernDropdown(
                      label: 'Target Network',
                      value: '',
                      items: const ['Loading...'],
                      onChanged: null,
                    ),
                    error: (_, __) => _buildModernDropdown(
                      label: 'Target Network',
                      value: '',
                      items: const ['Error loading networks'],
                      onChanged: null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Withdrawal Details'),
            const SizedBox(height: 12),
            _buildAddressInput(),
            const SizedBox(height: 16),
            
            balanceAsync.when(
              data: (balance) => _buildAmountInput((double.tryParse(balance) ?? 0) / 1000000),
              loading: () => _buildAmountInput(0.0, isLoading: true),
              error: (e, s) => _buildAmountInput(0.0),
            ),
            
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 40),
            
            balanceAsync.when(
              data: (balance) => _buildSummary((double.tryParse(balance) ?? 0) / 1000000),
              loading: () => _buildSummary(0.0),
              error: (e, s) => _buildSummary(0.0),
            ),
            
            AppSpacing.hXxl,
            AppPrimaryButton(
              label: 'Withdraw $selectedToken',
              isLoading: _isLoading,
              onPressed: (_isLoading || (double.tryParse(_amountCtrl.text) ?? 0) < 2.0) ? null : () {
                final bal = balanceAsync.asData?.value ?? "0";
                _handleWithdraw((double.tryParse(bal) ?? 0) / 1000000);
              },
            ),
            
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Withdrawal Process & History'),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.greenAccent),
                  onPressed: () {
                    ref.invalidate(withdrawalsProvider(userId));
                    ref.invalidate(balanceProvider(userId));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            withdrawalsAsync.when(
              data: (withdrawals) => _WithdrawalHistoryList(withdrawals: withdrawals),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )),
              error: (e, s) => const Text('Failed to load history', style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5));
  }

  Widget _buildModernDropdown({required String label, required String? value, required List<String> items, required ValueChanged<String?>? onChanged}) {
    // Ensure value always matches one of the items, or use empty string if no valid items
    String selectedValue = '';
    if (items.isNotEmpty && value != null && items.contains(value)) {
      selectedValue = value;
    }
    
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ),
        Expanded(
          flex: 2,
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedValue,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF2A2A2A),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.greenAccent),
            items: items.isEmpty
                ? [const DropdownMenuItem(value: '', child: Text('Loading...', style: TextStyle(fontWeight: FontWeight.bold)))]
                : items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
            onChanged: items.isEmpty ? null : onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressInput() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _addressCtrl,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Recipient Address (0x...)',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Colors.greenAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAmountInput(double displayBalance, {bool isLoading = false}) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final isInvalid = _amountCtrl.text.isNotEmpty && amount < 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), 
            borderRadius: BorderRadius.circular(15),
            border: isInvalid ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5)) : null,
          ),
          child: TextField(
            controller: _amountCtrl,
            onChanged: (v) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.toll_outlined, color: Colors.greenAccent),
              suffixIcon: TextButton(
                onPressed: () => setState(() => _amountCtrl.text = displayBalance.toStringAsFixed(2)),
                child: const Text('MAX', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (isInvalid)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 6),
            child: Text("Amount must be at least \$2.00", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(r'Min: $2.00', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Available earnings + referrals: \$${isLoading ? '...' : displayBalance.toStringAsFixed(2)} $selectedToken',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _transPassCtrl,
        obscureText: true,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Transaction Password',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.lock_outline, color: Colors.greenAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSummary(double available) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    const fee = 0.25;
    final amountToReceive = amount > fee ? amount - fee : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 15,
      color: AppColors.overlayGreen,
      borderColor: AppColors.overlayGreen,
      child: Column(
        children: [
          _buildSummaryRow('Total to Deduct', '${amount.toStringAsFixed(2)} $selectedToken', isBold: true),
          const SizedBox(height: 8),
          _buildSummaryRow('Withdrawal Fee', '0.25 $selectedToken'),
          const Divider(color: Colors.white10, height: 20),
          _buildSummaryRow('You will Receive', '${amountToReceive.toStringAsFixed(2)} $selectedToken', isBold: true, color: Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: TextStyle(color: color ?? (isBold ? Colors.white : Colors.white), fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

class _WithdrawalHistoryList extends StatelessWidget {
  final List<dynamic> withdrawals;
  const _WithdrawalHistoryList({required this.withdrawals});

  @override
  Widget build(BuildContext context) {
    if (withdrawals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, color: Colors.white12, size: 40),
            SizedBox(height: 10),
            Text("No withdrawals yet", style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    // Sort by createdAt desc
    final sorted = List.from(withdrawals);
    sorted.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));

    return Column(
      children: sorted.map((w) => _WithdrawalProcessItem(w: w)).toList(),
    );
  }
}

class _WithdrawalProcessItem extends StatelessWidget {
  final dynamic w;
  const _WithdrawalProcessItem({required this.w});

  @override
  Widget build(BuildContext context) {
    double amount = 0;
    try { amount = double.parse(w['amount'].toString()) / 1000000; } catch (_) {}
    
    String status = w['status'] ?? 'pending';
    String token = w['token'] ?? 'USDT';
    String network = w['network'] ?? 'Unknown';
    String txHash = w['txHash']?.toString() ?? "";
    
    DateTime date = DateTime.fromMillisecondsSinceEpoch(w['createdAt'] ?? 0);
    String dateStr = "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$token Withdrawal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('$network • $dateStr', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              Text('-${amount.toStringAsFixed(2)}', style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: status == 'failed' ? Colors.redAccent : Colors.orangeAccent,
                decoration: status == 'failed' ? TextDecoration.lineThrough : null,
              )),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatusStepper(status),
          if (status == 'processing')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                  SizedBox(width: 8),
                  Text("Broadcasting to Blockchain...", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (status == 'failed') 
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.redAccent, size: 12),
                  SizedBox(width: 4),
                  Text("Failed & Balance Refunded", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (txHash.isNotEmpty && txHash.length >= 16) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("TX Hash: ${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 8)}", style: const TextStyle(fontSize: 10, color: Colors.white24, fontFamily: 'monospace')),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: txHash));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied')));
                  },
                  child: const Icon(Icons.copy, size: 14, color: Colors.greenAccent),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusStepper(String status) {
    int currentStep = 0;
    if (status == 'pending') currentStep = 1;
    if (status == 'processing') currentStep = 2;
    if (status == 'completed') currentStep = 3;
    if (status == 'failed') currentStep = -1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepIndicator('Requested', currentStep >= 1, isFailed: currentStep == -1),
        _buildStepLine(currentStep >= 2, isFailed: currentStep == -1),
        _buildStepIndicator('Verifying', currentStep >= 2, isFailed: currentStep == -1),
        _buildStepLine(currentStep >= 3, isFailed: currentStep == -1),
        _buildStepIndicator('On-Chain', currentStep >= 3, isFailed: currentStep == -1),
      ],
    );
  }

  Widget _buildStepIndicator(String label, bool isActive, {bool isFailed = false}) {
    Color color = isActive ? Colors.greenAccent : Colors.white10;
    if (isFailed) color = Colors.redAccent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFailed ? Icons.close : (isActive ? Icons.check_circle : Icons.circle), 
            color: color, 
            size: 14
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildStepLine(bool isActive, {bool isFailed = false}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        decoration: BoxDecoration(
          color: isFailed ? Colors.redAccent.withValues(alpha: 0.1) : (isActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white10),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
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
      'Join me on LSSC ONE! Use my invitation link: $link',
      subject: 'Join me on LSSC ONE',
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
    final userId = auth.userId ?? "";
    final withdrawableAsync = ref.watch(withdrawableBalanceProvider(userId));

    double withdrawableBalance = 0;
    if (withdrawableAsync.asData?.value != null) {
      withdrawableBalance = (double.tryParse(withdrawableAsync.asData!.value) ?? 0) / 1000000;
    }

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
            AnimatedEntry(delay: 0, child: _buildProfileHeader(initials, email, auth.role ?? 'user', auth.isAdmin)),
            AppSpacing.hXxl,
            AnimatedEntry(delay: 80, child: _buildBalanceCard(withdrawableBalance)),
            AppSpacing.hXl,
            AnimatedEntry(delay: 160, child: _buildInviteCard()),
            AppSpacing.hXl,
            AnimatedEntry(
              delay: 240,
              child: _buildActionCard(
                icon: Icons.lock_reset,
                title: 'Reset Transaction Password',
                subtitle: 'Send a reset link to your email',
                color: AppColors.warning,
                onTap: _requestTransactionPasswordReset,
              ),
            ),
            if (auth.isAdmin) ...[
              AppSpacing.hXl,
              AnimatedEntry(
                delay: 300,
                child: _buildActionCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin Dashboard',
                  subtitle: 'Manage users and system',
                  color: AppColors.success,
                  onTap: () => context.push('/admin'),
                ),
              ),
            ],
            AppSpacing.hXl,
            AnimatedEntry(
              delay: 360,
              child: _buildActionCard(
                icon: Icons.logout,
                title: 'Log Out',
                subtitle: null,
                color: AppColors.error,
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String initials, String email, String role, bool isAdmin) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      gradient: LinearGradient(
        colors: [AppColors.primaryDark, const Color(0xFF0D2818)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppColors.overlayGreenStrong,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.overlayGreenMedium,
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          AppSpacing.wLg,
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
                AppSpacing.hXs,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAdmin ? AppColors.overlayGreenMedium : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAdmin ? AppColors.primary : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAdmin ? AppColors.primary : AppColors.textTertiary,
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
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      borderColor: AppColors.overlayGreenStrong,
      borderWidth: 1.5,
      glowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.overlayGreenMedium,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.redeem, color: AppColors.primary, size: 22),
              ),
              AppSpacing.wMd,
              Text(
                'My Balance',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              ),
            ],
          ),
          AppSpacing.hLg,
          Text(
            '\$${balance.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
          ),
          AppSpacing.hXs,
          Text(
            'Available for withdrawal',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
          ),
          AppSpacing.hXl,
          AppPrimaryButton(
            label: 'Withdraw',
            icon: Icons.arrow_circle_up_outlined,
            onPressed: () => context.push('/withdraw'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    final link = _inviteLink;
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      borderColor: AppColors.overlayGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.overlayGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.link, color: AppColors.primary, size: 20),
              ),
              AppSpacing.wMd,
              Text(
                'Invite Friends',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          AppSpacing.hLg,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              link,
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSpacing.hLg,
          Row(
            children: [
              Expanded(
                child: AppOutlineButton(
                  label: 'Copy',
                  icon: Icons.copy,
                  onPressed: _copyInviteLink,
                ),
              ),
              AppSpacing.wMd,
              Expanded(
                child: AppPrimaryButton(
                  label: 'Share',
                  icon: Icons.share,
                  onPressed: _shareInviteLink,
                  height: 48,
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
    return AppPressable(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
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
            AppSpacing.wLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.hXs,
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
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
                    _buildStatCard('Total Deposits', '${stats['depositCount']}', AppColors.success),
                    _buildStatCard('Total Volume', '\$${(stats['totalVolume'] / 1000000).toStringAsFixed(2)}', AppColors.warning),
                    _buildStatCard('Pending Sweeps', '${stats['pendingSweeps']}', AppColors.info),
                    _buildStatCard('Pending Withdrawals', '${stats['pendingWithdrawals']}', AppColors.warning),
                  ],
                ),
              ),
              AppSpacing.hXl,
              AppPressable(
                onTap: () => context.push('/admin/users'),
                child: AppCard(
                  borderRadius: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_outlined, color: AppColors.success),
                      AppSpacing.wMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User Management', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            Text('View users and change roles', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              AppSpacing.hMd,
              AppPressable(
                onTap: () => context.push('/admin/withdrawals'),
                child: AppCard(
                  borderRadius: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.outbox_outlined, color: AppColors.warning),
                      AppSpacing.wMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Withdrawal Management', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            Text('Process pending requests', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading stats: $e')),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(15),
      borderRadius: 15,
      borderColor: color.withValues(alpha: 0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textTertiary)),
          AppSpacing.hMd,
          Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, i) {
            final user = users[i];
            final String currentRole = user['role'] ?? 'user';

            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 15,
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(user['email'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                subtitle: Text('Role: ${currentRole.toUpperCase()}', style: GoogleFonts.poppins(color: currentRole == 'admin' ? AppColors.success : AppColors.textTertiary)),
                trailing: DropdownButton<String>(
                  value: currentRole,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.surfaceElevated,
                  items: ['user', 'admin'].map((role) {
                    return DropdownMenuItem(
                      value: role, 
                      child: Text(role.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary))
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

class PendingWithdrawalsScreen extends ConsumerStatefulWidget {
  const PendingWithdrawalsScreen({super.key});
  @override
  ConsumerState<PendingWithdrawalsScreen> createState() => _PendingWithdrawalsScreenState();
}

class _PendingWithdrawalsScreenState extends ConsumerState<PendingWithdrawalsScreen> {
  bool _isProcessingAll = false;

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PENDING WITHDRAWALS'),
        actions: [
          if (pendingAsync.hasValue && pendingAsync.value!.isNotEmpty)
            AppIconButton(
              icon: _isProcessingAll ? Icons.hourglass_empty : Icons.bolt,
              color: AppColors.warning,
              badge: _isProcessingAll ? null : null,
              onPressed: _isProcessingAll ? null : () async {
                setState(() => _isProcessingAll = true);
                await ref.read(adminNotifierProvider.notifier).processAllWithdrawals();
                if (mounted) {
                  setState(() => _isProcessingAll = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing started for all requests')));
                }
              },
            ),
        ],
      ),
      body: pendingAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text('No pending withdrawals', style: GoogleFonts.poppins(color: AppColors.textMuted)));
          }
          return ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final w = list[i];
              double amount = 0;
              try { amount = double.parse(w['amount'].toString()) / 1000000; } catch (_) {}
              
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                borderRadius: 15,
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text('${amount.toStringAsFixed(2)} ${w['token']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.success)),
                  subtitle: Text('To: ${w['toAddress'].substring(0, 10)}...\nNet: ${w['network']}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textTertiary)),
                  trailing: AppPrimaryButton(
                    label: 'PROCESS',
                    onPressed: () async {
                      await ref.read(adminNotifierProvider.notifier).processWithdrawal(w['_id']);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal processing...')));
                      }
                    },
                    height: 40,
                    fullWidth: false,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
