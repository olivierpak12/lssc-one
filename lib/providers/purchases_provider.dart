import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

final purchasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final auth = ref.watch(authProvider);

  if (auth.userId == null) throw Exception('Not logged in');

  final response = await apiService.getUserPurchases(auth.userId!);
  final data = response.data;
  if (data is List) {
    return data.cast<Map<String, dynamic>>();
  }
  return [];
});
