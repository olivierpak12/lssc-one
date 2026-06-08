import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/app_card.dart';
import '../../components/app_button.dart';

class UserDetailScreen extends ConsumerWidget {
  final String email;
  const UserDetailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(userReportProvider(email));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          email,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: reportAsync.when(
        data: (report) => _UserReportContent(report: report),
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
        ),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Failed to load report',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(userReportProvider(email)),
                  fullWidth: false,
                  height: 44,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserReportContent extends StatelessWidget {
  final Map<String, dynamic> report;
  const _UserReportContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final user = report['user'] as Map<String, dynamic>? ?? {};
    final summary = report['summary'] as Map<String, dynamic>? ?? {};
    final deposits = report['deposits'] as List<dynamic>? ?? [];
    final withdrawals = report['withdrawals'] as List<dynamic>? ?? [];
    final purchases = report['purchases'] as List<dynamic>? ?? [];
    final balances = report['balances'] as List<dynamic>? ?? [];
    final commissions = report['commissions'] as List<dynamic>? ?? [];
    final team = report['team'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserProfileCard(user: user),
          const SizedBox(height: 12),
          _FinancialSummaryCard(summary: summary),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Balances', icon: Icons.account_balance_wallet_rounded),
          const SizedBox(height: 8),
          _BalancesSection(balances: balances),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Deposits (${deposits.length})', icon: Icons.arrow_downward_rounded),
          const SizedBox(height: 8),
          _DepositsSection(deposits: deposits),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Withdrawals (${withdrawals.length})', icon: Icons.arrow_upward_rounded),
          const SizedBox(height: 8),
          _WithdrawalsSection(withdrawals: withdrawals),
          if (purchases.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(title: 'Purchases (${purchases.length})', icon: Icons.shopping_bag_rounded),
            const SizedBox(height: 8),
            _PurchasesSection(purchases: purchases),
          ],
          if (commissions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(title: 'Commissions (${commissions.length})', icon: Icons.redeem_rounded),
            const SizedBox(height: 8),
            _CommissionsSection(commissions: commissions),
          ],
          if ((team['totalMembers'] ?? 0) > 0) ...[
            const SizedBox(height: 20),
            _SectionHeader(title: 'Team (${team['totalMembers']})', icon: Icons.people_rounded),
            const SizedBox(height: 8),
            _TeamSection(team: team),
          ],
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserProfileCard({required this.user});

  String _formatDate(num? ms) {
    if (ms == null) return 'N/A';
    final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'user';
    final userId = user['_id']?.toString() ?? '';
    final isAdmin = role == 'admin';
    final myInviteCode = user['myInviteCode']?.toString() ?? '';
    final referralCode = user['referralCode']?.toString() ?? '';
    final referredBy = user['referredBy']?.toString() ?? '';
    final verified = user['emailVerified'] == true;
    final teamSize = user['teamSize'] ?? 0;
    final createdAt = user['createdAt'] as num?;

    return AnimatedScaleIn(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              isAdmin ? AppColors.primaryDark.withValues(alpha: 0.5) : AppColors.accentPurple.withValues(alpha: 0.15),
              AppColors.surfaceCardAlt,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isAdmin ? AppColors.borderPrimary : AppColors.accentPurple.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: isAdmin ? AppGradients.primary : AppGradients.referral,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.overlayGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ADMIN',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            verified ? Icons.verified_rounded : Icons.cancel_outlined,
                            size: 12,
                            color: verified ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            verified ? 'Verified' : 'Not verified',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: verified ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people_outline, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Team: $teamSize',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'User ID', value: userId, mono: true),
                  const SizedBox(height: 4),
                  _DetailRow(label: 'Role', value: role),
                  const SizedBox(height: 4),
                  _DetailRow(label: 'Invite Code', value: myInviteCode),
                  const SizedBox(height: 4),
                  _DetailRow(label: 'Referral Code', value: referralCode),
                  if (referredBy.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _DetailRow(label: 'Referred By', value: referredBy, mono: true),
                  ],
                  const SizedBox(height: 4),
                  _DetailRow(label: 'Created', value: _formatDate(createdAt)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _DetailRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: mono
              ? Text(
                  value,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                  ),
                )
              : Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _FinancialSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total Deposited', summary['totalDeposited'] ?? 0, Icons.arrow_downward_rounded, AppColors.success),
      ('Total Withdrawn', summary['totalWithdrawn'] ?? 0, Icons.arrow_upward_rounded, AppColors.warning),
      ('Total Fees Paid', summary['totalFeesPaid'] ?? 0, Icons.receipt_rounded, AppColors.accentOrange),
      ('Total Commissions', summary['totalCommissionsEarned'] ?? 0, Icons.redeem_rounded, AppColors.accentPurple),
    ];

    final infoItems = [
      ('Earning Balance', summary['currentEarningsBalance'] ?? 0),
      ('Referral Balance', summary['referralBalance'] ?? 0),
      ('Team Rewards', summary['teamRewardsBalance'] ?? 0),
      ('Net Worth', summary['netWorth'] ?? 0),
    ];

    return AnimatedEntry(
      delay: 50,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.overlayGreen, AppColors.surfaceCardAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: AppGradients.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'FINANCIAL SUMMARY',
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                return Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: items.map((item) {
                    return SizedBox(
                      width: isWide ? (constraints.maxWidth - 8) / 2 - 4 : constraints.maxWidth,
                      child: _SummaryStat(
                        icon: item.$3,
                        label: item.$1,
                        value: item.$2 is num ? (item.$2 as num).toDouble() : 0,
                        color: item.$4,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 10),
            Row(
              children: infoItems.map((item) {
                final val = item.$2 is num ? (item.$2 as num).toDouble() : 0;
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        '\$${val.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$1,
                        style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  const _SummaryStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${value.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancesSection extends StatelessWidget {
  final List<dynamic> balances;
  const _BalancesSection({required this.balances});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return _EmptyState(message: 'No balances');
    }
    return Column(
      children: balances.asMap().entries.map((entry) {
        final b = entry.value as Map<String, dynamic>;
        final amount = (b['amount'] as num?)?.toDouble() ?? 0;
        final token = b['tokenSymbol']?.toString() ?? '';
        final chainId = b['chainId'] ?? 0;
        final updatedAt = b['updatedAt'] as num?;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TightRow(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.overlayGreen, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.primary),
            ),
            title: '$token (Chain $chainId)',
            subtitle: updatedAt != null ? _timeAgo(updatedAt) : '',
            trailing: '\$${amount.toStringAsFixed(2)}',
            trailingColor: amount > 0 ? AppColors.primary : AppColors.textMuted,
          ),
        );
      }).toList(),
    );
  }

  String _timeAgo(num ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DepositsSection extends StatelessWidget {
  final List<dynamic> deposits;
  const _DepositsSection({required this.deposits});

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed': return AppColors.success;
      case 'swept': return AppColors.accentBlue;
      case 'pending': return AppColors.warning;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (deposits.isEmpty) {
      return _EmptyState(message: 'No deposits');
    }
    return Column(
      children: deposits.asMap().entries.map((entry) {
        final d = entry.value as Map<String, dynamic>;
        final amount = (d['amount'] as num?)?.toDouble() ?? 0;
        final token = d['token']?.toString() ?? '';
        final status = d['status']?.toString() ?? '';
        final network = d['network']?.toString() ?? '';
        final txHash = d['txHash']?.toString() ?? '';
        final createdAt = d['createdAt'] as num?;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TransactionTile(
            icon: Icons.arrow_downward_rounded,
            iconColor: AppColors.success,
            title: '+${amount.toStringAsFixed(2)} $token',
            subtitle: network.isNotEmpty ? network : null,
            status: status,
            statusColor: _statusColor(status),
            txHash: txHash,
            time: createdAt != null ? _formatDate(createdAt) : null,
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(num ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _WithdrawalsSection extends StatelessWidget {
  final List<dynamic> withdrawals;
  const _WithdrawalsSection({required this.withdrawals});

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed': return AppColors.success;
      case 'pending': return AppColors.warning;
      case 'failed': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (withdrawals.isEmpty) {
      return _EmptyState(message: 'No withdrawals');
    }
    return Column(
      children: withdrawals.asMap().entries.map((entry) {
        final w = entry.value as Map<String, dynamic>;
        double amount = 0;
        try {
          final raw = w['amount'];
          if (raw is num) {
            amount = raw.toDouble();
          } else if (raw is String) {
            amount = double.parse(raw) / 1000000;
          }
        } catch (_) {}
        final token = w['token']?.toString() ?? 'USDT';
        final status = w['status']?.toString() ?? '';
        final network = w['network']?.toString() ?? '';
        final txHash = w['txHash']?.toString() ?? '';
        final toAddress = w['toAddress']?.toString() ?? '';
        final error = w['error']?.toString() ?? '';
        final createdAt = w['createdAt'] as num?;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TransactionTile(
            icon: Icons.arrow_upward_rounded,
            iconColor: AppColors.warning,
            title: '-${amount.toStringAsFixed(2)} $token',
            subtitle: network.isNotEmpty ? network : null,
            status: status,
            statusColor: _statusColor(status),
            txHash: txHash,
            toAddress: toAddress,
            error: error,
            time: createdAt != null ? _formatDate(createdAt) : null,
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(num ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _TransactionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String status;
  final Color statusColor;
  final String? txHash;
  final String? toAddress;
  final String? error;
  final String? time;

  const _TransactionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.status,
    required this.statusColor,
    this.txHash,
    this.toAddress,
    this.error,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          if (txHash != null && txHash!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _MonoText(label: 'Tx', value: _truncateHash(txHash!)),
          ],
          if (toAddress != null && toAddress!.isNotEmpty) ...[
            const SizedBox(height: 3),
            _MonoText(label: 'To', value: _truncateAddress(toAddress!)),
          ],
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.overlayRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                error!,
                style: GoogleFonts.poppins(fontSize: 9, color: AppColors.error, height: 1.3),
              ),
            ),
          ],
          if (time != null) ...[
            const SizedBox(height: 4),
            Text(
              time!,
              style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _truncateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 6)}';
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 14) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 6)}';
  }
}

class _MonoText extends StatelessWidget {
  final String label;
  final String value;
  const _MonoText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 9, color: AppColors.textTertiary, fontFamily: 'monospace', letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }
}

class _PurchasesSection extends StatelessWidget {
  final List<dynamic> purchases;
  const _PurchasesSection({required this.purchases});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: purchases.asMap().entries.map((entry) {
        final p = entry.value as Map<String, dynamic>;
        final name = p['bikeName']?.toString() ?? 'Package';
        final price = (p['equipmentPrice'] as num?)?.toDouble() ?? 0;
        final daily = (p['dailyIncome'] as num?)?.toDouble() ?? 0;
        final purchasedAt = p['purchasedAt'] as num?;
        final date = purchasedAt != null ? DateTime.fromMillisecondsSinceEpoch(purchasedAt.toInt()) : null;
        final dateStr = date != null ? '${date.month}/${date.day}/${date.year}' : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TightRow(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.overlayGreen, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.directions_bike_rounded, size: 14, color: AppColors.primary),
            ),
            title: name,
            subtitle: dateStr.isNotEmpty ? 'Purchased: $dateStr' : null,
            trailing: '\$${price.toStringAsFixed(0)} (\+\$${daily.toStringAsFixed(2)}/day)',
            trailingColor: AppColors.primary,
          ),
        );
      }).toList(),
    );
  }
}

class _CommissionsSection extends StatelessWidget {
  final List<dynamic> commissions;
  const _CommissionsSection({required this.commissions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: commissions.asMap().entries.map((entry) {
        final c = entry.value as Map<String, dynamic>;
        final fromUser = c['fromUsername']?.toString() ?? 'Unknown';
        final amount = (c['commissionAmount'] as num?)?.toDouble() ?? 0;
        final level = c['level'] ?? 0;
        final percent = c['percent'] ?? 0;
        final createdAt = c['createdAt'] as num?;
        final date = createdAt != null ? DateTime.fromMillisecondsSinceEpoch(createdAt.toInt()) : null;
        final dateStr = date != null ? '${date.month}/${date.day}/${date.year}' : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _TightRow(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_outline, size: 14, color: AppColors.accentPurple),
            ),
            title: fromUser,
            subtitle: 'Level $level \u2022 ${percent}% \u2022 $dateStr',
            trailing: '+\$${amount.toStringAsFixed(2)}',
            trailingColor: AppColors.primary,
          ),
        );
      }).toList(),
    );
  }
}

class _TeamSection extends StatelessWidget {
  final Map<String, dynamic> team;
  const _TeamSection({required this.team});

  @override
  Widget build(BuildContext context) {
    final byLevel = team['byLevel'] as Map<String, dynamic>? ?? {};
    final totalMembers = team['totalMembers'] ?? 0;

    return AnimatedEntry(
      delay: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$totalMembers member${totalMembers == 1 ? '' : 's'}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            ...byLevel.entries.map((levelEntry) {
              final level = levelEntry.key;
              final members = levelEntry.value as List<dynamic>? ?? [];
              if (members.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level (${members.length})',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    ...members.map((m) {
                      final member = m as Map<String, dynamic>;
                      final memEmail = member['email']?.toString() ?? '';
                      final memUsername = member['username']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _TightRow(
                          leading: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.overlayGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (memEmail.isNotEmpty ? memEmail[0] : '?').toUpperCase(),
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                          title: memEmail,
                          subtitle: memUsername.isNotEmpty ? '@$memUsername' : null,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TightRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;

  const _TightRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trailingColor ?? AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
