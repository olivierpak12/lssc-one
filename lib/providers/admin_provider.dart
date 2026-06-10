import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final usersProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.listUsers();
  return response.data as List<dynamic>;
});

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getAdminStats();
  return response.data as Map<String, dynamic>;
});

final pendingWithdrawalsProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getPendingWithdrawals();
  return response.data as List<dynamic>;
});

final pendingAdminWithdrawalsProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getPendingAdminWithdrawals();
  return response.data as List<dynamic>;
});

final withdrawalsDisabledProvider = FutureProvider<bool>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getWithdrawalsDisabled();
  return response.data['disabled'] as bool;
});

final userReportProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, email) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getUserReport(email);
  return response.data as Map<String, dynamic>;
});

class AdminNotifier extends StateNotifier<bool> {
  final Ref ref;
  AdminNotifier(this.ref) : super(false);

  Future<void> updateUserRole(String userId, String role) async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.setUserRole(userId, role);
    ref.invalidate(usersProvider);
  }

  Future<void> processWithdrawal(String withdrawalId) async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.processWithdrawal(withdrawalId);
    ref.invalidate(pendingWithdrawalsProvider);
    ref.invalidate(adminStatsProvider);
  }

  Future<void> processAllWithdrawals() async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.processAllWithdrawals();
    ref.invalidate(pendingWithdrawalsProvider);
    ref.invalidate(adminStatsProvider);
  }
}

final adminNotifierProvider = StateNotifierProvider<AdminNotifier, bool>((ref) {
  return AdminNotifier(ref);
});
