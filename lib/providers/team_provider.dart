import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

final selectedPeriodProvider = StateProvider<String>((ref) => 'today');

final teamStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final auth = ref.watch(authProvider);
  final period = ref.watch(selectedPeriodProvider);

  if (auth.userId == null) throw Exception('Not logged in');

  final response = await apiService.getTeamStats(auth.userId!, period);
  return response.data as Map<String, dynamic>;
});
