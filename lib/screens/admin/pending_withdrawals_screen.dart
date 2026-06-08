import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/app_card.dart';
import '../../components/app_button.dart';
import '../../components/notification_bell.dart';

class PendingWithdrawalsScreen extends ConsumerStatefulWidget {
  const PendingWithdrawalsScreen({super.key});
  @override
  ConsumerState<PendingWithdrawalsScreen> createState() => _PendingWithdrawalsScreenState();
}

class _PendingWithdrawalsScreenState extends ConsumerState<PendingWithdrawalsScreen> {
  bool _isProcessingAll = false;
  final Set<String> _processingIds = {};

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Withdrawals',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (pendingAsync.hasValue && pendingAsync.value!.isNotEmpty)
            AppPressable(
              onTap: (_isProcessingAll || _processingIds.isNotEmpty) ? null : _processAll,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _isProcessingAll
                      ? AppColors.textMuted.withValues(alpha: 0.2)
                      : AppColors.overlayOrange,
                  border: Border.all(
                    color: _isProcessingAll
                        ? AppColors.textMuted.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessingAll)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.warning,
                        ),
                      )
                    else
                      const Icon(Icons.bolt, size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      _isProcessingAll ? 'Processing...' : 'Process All',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isProcessingAll ? AppColors.textMuted : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const NotificationBell(),
        ],
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
                    'No pending withdrawal requests',
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
            onRefresh: () => ref.refresh(pendingWithdrawalsProvider.future),
            child: ListView.builder(
              itemCount: list.length,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemBuilder: (context, i) {
                final w = list[i];
                final id = w['_id']?.toString() ?? '';
                final isProcessing = _processingIds.contains(id);

                double amount = 0;
                try {
                  amount = double.parse(w['amount'].toString()) / 1000000;
                } catch (_) {}

                final toAddress = w['toAddress']?.toString() ?? '';
                final token = w['token']?.toString() ?? 'USDT';
                final network = w['network']?.toString() ?? 'Unknown';
                final createdAt = w['createdAt'];
                final timeAgo = createdAt != null
                    ? _formatTimeAgo(DateTime.now().difference(
                        DateTime.fromMillisecondsSinceEpoch(createdAt as int)))
                    : '';

                return AnimatedEntry(
                  delay: i * 40,
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
                                color: AppColors.overlayGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.currency_bitcoin,
                                size: 16,
                                color: AppColors.success,
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
                            SizedBox(
                              height: 36,
                              child: AppPressable(
                                onTap: isProcessing ? null : () => _processSingle(id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: isProcessing
                                        ? AppColors.textMuted.withValues(alpha: 0.2)
                                        : AppColors.primary,
                                  ),
                                  alignment: Alignment.center,
                                  child: isProcessing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: AppColors.textMuted,
                                          ),
                                        )
                                      : Text(
                                          'Process',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
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
                  onPressed: () => ref.invalidate(pendingWithdrawalsProvider),
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

  Future<void> _processSingle(String id) async {
    setState(() => _processingIds.add(id));
    try {
      await ref.read(adminNotifierProvider.notifier).processWithdrawal(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing withdrawal...'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceElevated,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  Future<void> _processAll() async {
    setState(() => _isProcessingAll = true);
    try {
      await ref.read(adminNotifierProvider.notifier).processAllWithdrawals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing started for all requests'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAll = false);
      }
    }
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
