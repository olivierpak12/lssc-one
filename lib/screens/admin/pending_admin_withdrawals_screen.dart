import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/app_card.dart';
import '../../components/app_button.dart';
import '../../components/notification_bell.dart';

class PendingAdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const PendingAdminWithdrawalsScreen({super.key});
  @override
  ConsumerState<PendingAdminWithdrawalsScreen> createState() => _PendingAdminWithdrawalsScreenState();
}

class _PendingAdminWithdrawalsScreenState extends ConsumerState<PendingAdminWithdrawalsScreen> {
  bool _isProcessingAll = false;
  final Set<String> _processingIds = {};

  @override
  Widget build(BuildContext context) {
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
                      : AppColors.overlayBlue,
                  border: Border.all(
                    color: _isProcessingAll
                        ? AppColors.textMuted.withValues(alpha: 0.1)
                        : AppColors.accentBlue.withValues(alpha: 0.2),
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
                          color: AppColors.accentBlue,
                        ),
                      )
                    else
                      const Icon(Icons.bolt, size: 16, color: AppColors.accentBlue),
                    const SizedBox(width: 6),
                    Text(
                      _isProcessingAll ? 'Processing...' : 'Process All',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isProcessingAll ? AppColors.textMuted : AppColors.accentBlue,
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
                final id = w['_id']?.toString() ?? '';
                final isProcessing = _processingIds.contains(id);
                return _PendingWithdrawalCard(
                  withdrawal: w,
                  index: i,
                  isProcessing: isProcessing,
                  onTap: () => _showWithdrawalDetails(context, w),
                  onProcess: isProcessing ? null : () => _processSingle(id),
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

  Future<void> _processSingle(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline, size: 22, color: AppColors.accentBlue),
            const SizedBox(width: 10),
            Text(
              'Process Withdrawal',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Send this withdrawal on-chain? This will use real gas fees.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Process', style: GoogleFonts.poppins(color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingIds.add(id));
    try {
      final result = await ref.read(adminNotifierProvider.notifier).processPendingAdminWithdrawal(id);
      if (mounted) {
        final success = result['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? (success ? 'Processed' : 'Failed')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: success ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFB71C1C),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 22, color: AppColors.warning),
            const SizedBox(width: 10),
            Text(
              'Process All?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Process all pending admin withdrawals on-chain? This will use real gas fees.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Process All', style: GoogleFonts.poppins(color: AppColors.warning, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final list = ref.read(pendingAdminWithdrawalsProvider).valueOrNull ?? [];
    setState(() => _isProcessingAll = true);

    int successCount = 0;
    int failCount = 0;
    for (final w in list) {
      final id = w['_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      try {
        final result = await ref.read(adminNotifierProvider.notifier).processPendingAdminWithdrawal(id);
        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (_) {
        failCount++;
      }
    }

    if (mounted) {
      setState(() => _isProcessingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processed $successCount successfully, $failCount failed.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: failCount > 0 ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
        ),
      );
    }
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
    final amountUsd = w['amountUsd'];
    final network = w['network']?.toString() ?? 'Unknown';
    final toAddress = w['toAddress']?.toString() ?? '';
    final chainId = w['chainId'];
    final userId = w['userId']?.toString() ?? '';
    final withdrawalId = w['withdrawalId']?.toString() ?? '';
    final id = w['_id']?.toString() ?? '';
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
              _detailRow('Amount', '${amount.toStringAsFixed(2)} $token${amountUsd != null ? ' (\$${(amountUsd as num).toStringAsFixed(2)})' : ''}'),
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
              label: 'Process Now',
              icon: Icons.send,
              onPressed: () {
                Navigator.of(ctx).pop();
                _processSingle(id);
              },
              height: 44,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppOutlineButton(
              label: 'Close',
              onPressed: () => Navigator.of(ctx).pop(),
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
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback? onProcess;

  const _PendingWithdrawalCard({
    required this.withdrawal,
    required this.index,
    required this.isProcessing,
    required this.onTap,
    this.onProcess,
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
                  child: GestureDetector(
                    onTap: onTap,
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
                        Row(
                          children: [
                            if (timeAgo.isNotEmpty)
                              Text(
                                timeAgo,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            if (withdrawal['amountUsd'] != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '\$${(withdrawal['amountUsd'] as num).toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: AppPressable(
                    onTap: onProcess,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isProcessing
                            ? AppColors.textMuted.withValues(alpha: 0.2)
                            : AppColors.accentBlue,
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
            GestureDetector(
              onTap: onTap,
              child: Container(
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
            ),
          ],
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
