import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/app_card.dart';
import '../../components/app_button.dart';
import '../../components/notification_bell.dart';

class PendingAdminWithdrawalsScreen extends ConsumerWidget {
  const PendingAdminWithdrawalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingAdminWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pending Admin Withdrawals',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: const [NotificationBell()],
      ),
      body: pendingAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'All caught up',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No pending admin withdrawals',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(pendingAdminWithdrawalsProvider.future),
            child: ListView.builder(
              itemCount: list.length,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemBuilder: (context, i) {
                final w = list[i];
                return _PendingWithdrawalCard(
                  withdrawal: w,
                  index: i,
                  onTap: () => _showWithdrawalDetails(context, w),
                );
              },
            ),
          );
        },
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
                  'Failed to load withdrawals',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(pendingAdminWithdrawalsProvider),
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

  void _showWithdrawalDetails(BuildContext context, dynamic w) {
    final amount = () {
      try {
        return double.parse(w['amount'].toString()) / 1000000;
      } catch (_) {
        return 0.0;
      }
    }();

    final token = w['token']?.toString() ?? 'USDT';
    final toAddress = w['toAddress']?.toString() ?? '';
    final network = w['network']?.toString() ?? 'Unknown';
    final chainId = w['chainId'];
    final userId = w['userId']?.toString() ?? '';
    final withdrawalId = w['withdrawalId']?.toString() ?? '';
    final createdAt = w['createdAt'];
    final date = createdAt != null
        ? DateTime.fromMillisecondsSinceEpoch(createdAt as int)
        : null;
    final dateStr = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.3)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.overlayBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  size: 20,
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Withdrawal Details',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Amount', '${amount.toStringAsFixed(2)} $token'),
              const SizedBox(height: 10),
              _detailRow('Network', network),
              const SizedBox(height: 10),
              _detailRow('Chain ID', chainId?.toString() ?? 'N/A'),
              const SizedBox(height: 10),
              _detailRow('To Address', toAddress),
              const SizedBox(height: 10),
              _detailRow('User ID', userId),
              const SizedBox(height: 10),
              _detailRow('Withdrawal ID', withdrawalId),
              const SizedBox(height: 10),
              _detailRow('Requested At', dateStr),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              label: 'Close',
              onPressed: () => Navigator.of(ctx).pop(),
              height: 44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingWithdrawalCard extends StatelessWidget {
  final dynamic withdrawal;
  final int index;
  final VoidCallback onTap;

  const _PendingWithdrawalCard({
    required this.withdrawal,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amount = () {
      try {
        return double.parse(withdrawal['amount'].toString()) / 1000000;
      } catch (_) {
        return 0.0;
      }
    }();

    final token = withdrawal['token']?.toString() ?? 'USDT';
    final network = withdrawal['network']?.toString() ?? 'Unknown';
    final toAddress = withdrawal['toAddress']?.toString() ?? '';
    final createdAt = withdrawal['createdAt'];
    final timeAgo = createdAt != null
        ? _formatTimeAgo(DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(createdAt as int)))
        : '';

    return AnimatedEntry(
      delay: index * 40,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surfaceCardAlt,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.overlayBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.pending_actions_rounded,
                      size: 16,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${amount.toStringAsFixed(2)} $token',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        if (timeAgo.isNotEmpty)
                          Text(
                            timeAgo,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'To', value: _truncateAddress(toAddress)),
                    const SizedBox(height: 4),
                    _InfoRow(label: 'Network', value: network),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 14) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 6)}';
  }

  String _formatTimeAgo(Duration diff) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
