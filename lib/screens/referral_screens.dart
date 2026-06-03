import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/referral_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../models/referral.dart';
import '../theme/app_colors.dart';
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/notification_bell.dart';

class ReferralDashboardScreen extends ConsumerWidget {
  const ReferralDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(referralStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('AFFILIATE PROGRAM', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(referralStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedEntry(
                delay: 0,
                child: statsAsync.when(
                  data: (stats) => _EarningsOverviewCard(stats: stats),
                  loading: () => const _LoadingCard(),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
              ),
              AppSpacing.hXxxl,
              AnimatedEntry(
                delay: 80,
                child: _buildQuickActions(context),
              ),
              AppSpacing.hXxxl,
              AnimatedEntry(
                delay: 160,
                child: Text('TEAM STATISTICS', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
              ),
              AppSpacing.hLg,
              AnimatedEntry(
                delay: 200,
                child: statsAsync.when(
                  data: (stats) => _TeamStatsGrid(stats: stats),
                  loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                  error: (e, s) => const SizedBox(),
                ),
              ),
              AppSpacing.hXxxl,
              AnimatedEntry(
                delay: 280,
                child: const _ReferralCodeCard(),
              ),
              AppSpacing.hXxxl,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionCard(icon: Icons.people_outline, label: 'My Team', color: AppColors.accentBlue, onTap: () => context.push('/referrals/team'))),
        AppSpacing.wLg,
        Expanded(child: _ActionCard(icon: Icons.history_edu_outlined, label: 'Earnings', color: AppColors.accentPurple, onTap: () => context.push('/referrals/earnings'))),
        AppSpacing.wLg,
        Expanded(child: _ActionCard(icon: Icons.leaderboard_outlined, label: 'Leaders', color: AppColors.warning, onTap: () => context.push('/referrals/leaderboard'))),
      ],
    );
  }
}

class _EarningsOverviewCard extends StatelessWidget {
  final ReferralStats stats;
  const _EarningsOverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppGradients.referral,
        boxShadow: [BoxShadow(color: AppColors.shadowBlue, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Referral Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
          AppSpacing.hSm,
          Text('\$${stats.referralBalance.toStringAsFixed(2)}', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          AppSpacing.hXl,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildSmallStat('Today Earnings', '\$${stats.todayEarnings.toStringAsFixed(2)}')),
              AppSpacing.wMd,
              Expanded(child: _buildSmallStat('Total Earnings', '\$${stats.totalReferralEarnings.toStringAsFixed(2)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TeamStatsGrid extends StatelessWidget {
  final ReferralStats stats;
  const _TeamStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildStatTile('Total Team', stats.totalTeamMembers.toString(), Icons.group),
        _buildStatTile('Active Members', stats.activeMembers.toString(), Icons.bolt, color: AppColors.success),
        _buildStatTile('Team Deposits', '\$${stats.totalTeamDeposit.toStringAsFixed(0)}', Icons.arrow_downward, color: AppColors.success),
        _buildStatTile('Team Withdraws', '\$${stats.totalTeamWithdraw.toStringAsFixed(0)}', Icons.arrow_upward, color: AppColors.warning),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, {Color color = AppColors.accentBlue}) {
    return AppCard(
      padding: const EdgeInsets.all(15),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              AppSpacing.wSm,
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: AppColors.textTertiary, fontSize: 11))),
            ],
          ),
          AppSpacing.hSm,
          Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends ConsumerWidget {
  const _ReferralCodeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final String code = authState.referralCode ?? "---"; 
    final String link = authState.referralLink ?? "https://lssc.com/register?ref=$code";

    return AppCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 25,
      borderColor: AppColors.overlayGreenMedium,
      child: Column(
        children: [
          Text('INVITE FRIENDS', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 1)),
          AppSpacing.hXl,
          _buildCopyField('Referral Code', code, context),
          AppSpacing.hLg,
          _buildCopyField('Invitation Link', link, context),
          AppSpacing.hXxxl,
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              label: 'Share Invitation',
              icon: Icons.share,
              onPressed: code == "---" ? null : () {
                Share.share("Join me on LSSC ONE! Use my code $code to get bonuses. Register here: $link");
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyField(String label, String value, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
        AppSpacing.hXs,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              AppSpacing.wMd,
              InkWell(
                onTap: value == "---" ? null : () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!')));
                },
                child: Icon(Icons.copy, size: 18, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeamMembersScreen extends ConsumerWidget {
  const TeamMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MY TEAM'),
          actions: const [NotificationBell()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Team A'),
              Tab(text: 'Team B'),
              Tab(text: 'Team C'),
            ],
          ),
        ),
        body: membersAsync.when(
          data: (members) {
            final teamA = members.where((m) => m.level == 1).toList();
            final teamB = members.where((m) => m.level == 2).toList();
            final teamC = members.where((m) => m.level == 3).toList();

            return TabBarView(
              children: [
                _TeamListView(members: teamA, emptyMessage: 'No level A members yet.'),
                _TeamListView(members: teamB, emptyMessage: 'No level B members yet.'),
                _TeamListView(members: teamC, emptyMessage: 'No level C members yet.'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _TeamListView extends StatelessWidget {
  final List<TeamMember> members;
  final String emptyMessage;
  const _TeamListView({required this.members, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Text(emptyMessage, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppColors.textMuted)),
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return AnimatedScaleIn(
          delay: index * 30,
          child: _TeamMemberTile(member: member),
        );
      },
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  final TeamMember member;
  const _TeamMemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getLevelColor(member.level).withValues(alpha: 0.1),
            child: Text(
              _getLevelLabel(member.level), 
              style: TextStyle(color: _getLevelColor(member.level), fontWeight: FontWeight.bold, fontSize: 12)
            ),
          ),
          AppSpacing.wLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.username, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                Text(member.email, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${member.depositAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.bold)),
              Text('Deposit', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level == 1) return AppColors.success;
    if (level == 2) return AppColors.accentBlue;
    return AppColors.accentPurple;
  }

  String _getLevelLabel(int level) {
    if (level == 1) return 'A';
    if (level == 2) return 'B';
    return 'C';
  }
}

class ReferralEarningsScreen extends ConsumerWidget {
  const ReferralEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(referralEarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EARNING HISTORY'),
        actions: const [NotificationBell()],
      ),
      body: earningsAsync.when(
        data: (earnings) {
          if (earnings.isEmpty) return Center(child: Text('No earnings yet.', style: GoogleFonts.poppins(color: AppColors.textMuted)));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: earnings.length,
            itemBuilder: (context, index) {
              final item = earnings[index];
              return AnimatedScaleIn(
                delay: index * 30,
                child: _EarningTile(item: item),
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

class _EarningTile extends StatelessWidget {
  final ReferralCommission item;
  const _EarningTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level ${item.level} Commission', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('From ${item.fromUsername}', style: GoogleFonts.poppins(color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+\$${item.commissionAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${item.percent}% of \$${item.depositAmount}', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TOP EARNERS'),
        actions: const [NotificationBell()],
      ),
      body: leaderboardAsync.when(
        data: (list) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final entry = list[index];
              return AnimatedScaleIn(
                delay: index * 30,
                child: _LeaderboardTile(entry: entry, rank: index + 1),
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

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  const _LeaderboardTile({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    bool isTop3 = rank <= 3;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      color: isTop3 ? AppColors.overlayGreen : null,
      borderColor: isTop3 ? AppColors.overlayGreenMedium : null,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('#$rank', style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, 
              color: isTop3 ? AppColors.success : AppColors.textMuted,
              fontSize: 16
            )),
          ),
          AppSpacing.wLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.username, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                Text('Team Size: ${entry.teamSize}', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text('\$${entry.totalEarnings.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.success)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surfaceCardAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            AppSpacing.hMd,
            Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceCardAlt,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
