import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/app_card.dart';
import '../../components/app_button.dart';
import '../../components/notification_bell.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});
  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Users',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: const [NotificationBell()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users by email...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceCardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final filtered = _searchQuery.isEmpty
                    ? users
                    : users.where((u) {
                        final email = (u['email'] ?? '').toString().toLowerCase();
                        return email.contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No users found' : 'No matches for "$_searchQuery"',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(usersProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final user = filtered[i];
                      return _UserTile(
                        user: user,
                        index: i,
                        onRoleChanged: (newRole) async {
                          await ref.read(adminNotifierProvider.notifier).updateUserRole(user['_id'], newRole);
                          if (user['_id'] == ref.read(authProvider).userId) {
                            await ref.read(authProvider.notifier).refreshUser();
                          }
                        },
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
                        'Failed to load users',
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
                        onPressed: () => ref.invalidate(usersProvider),
                        fullWidth: false,
                        height: 44,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final dynamic user;
  final int index;
  final Function(String) onRoleChanged;

  const _UserTile({
    required this.user,
    required this.index,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentRole = (user['role'] ?? 'user') as String;
    final isAdmin = currentRole == 'admin';
    final email = (user['email'] ?? 'Unknown').toString();

    return AnimatedEntry(
      delay: index * 30,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.surfaceCardAlt,
          border: Border.all(
            color: isAdmin ? AppColors.primary.withValues(alpha: 0.1) : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isAdmin ? AppColors.overlayGreen : AppColors.surfaceElevated,
              ),
              alignment: Alignment.center,
              child: Text(
                email[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isAdmin ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/admin/user-detail?email=${Uri.encodeComponent(email)}'),
                    child: Text(
                      email,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.overlayGreen,
                        borderRadius: BorderRadius.circular(4),
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
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<String>(
                value: currentRole,
                underline: const SizedBox(),
                dropdownColor: AppColors.surfaceElevated,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                items: ['user', 'admin'].map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: role == 'admin' ? AppColors.primary : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newRole) {
                  if (newRole != null && newRole != currentRole) {
                    onRoleChanged(newRole);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated $email to $newRole'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.surfaceElevated,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
