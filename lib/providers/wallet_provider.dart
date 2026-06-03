import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final networksProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final activeResponse = await apiService.getActiveNetworks();
  if (activeResponse.data is List) {
    final activeNetworks = activeResponse.data as List<dynamic>;
    if (activeNetworks.isNotEmpty) {
      return activeNetworks;
    }
  }

  try {
    final fallbackResponse = await apiService.getAllNetworks();
    if (fallbackResponse.data is List) {
      return fallbackResponse.data as List<dynamic>;
    }
  } catch (e) {
    // Ignore fallback failure, we'll expose an empty list and let UI handle it.
    print('networksProvider fallback failed: $e');
  }

  return [];
});

final withdrawableBalanceProvider = FutureProvider.family<String, String>((ref, userId) async {
  if (userId.isEmpty) return "0";
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getWithdrawableBalance(userId);
    if (response.data is Map && response.data['balance'] != null) {
      return response.data['balance'].toString();
    }
    return "0";
  } catch (e) {
    return "0";
  }
});

final balanceProvider = FutureProvider.family<String, String>((ref, userId) async {
  if (userId.isEmpty) return "0";
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getBalance(userId);
    if (response.data is Map && response.data['balance'] != null) {
      return response.data['balance'].toString();
    }
    return "0";
  } catch (e) {
    print("Error fetching balance: $e");
    return "0";
  }
});

final walletProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) throw Exception("User not logged in");
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getWallet(userId);
    if (response.data != null && response.data is Map && response.data['address'] != null) {
      return response.data;
    }
  } catch (e) {
    print("Error fetching wallet: $e");
  }
  try {
    final genResponse = await apiService.generateWallet(userId);
    if (genResponse.data != null && genResponse.data is Map && genResponse.data['address'] != null) {
      return genResponse.data;
    }
    throw Exception("Generation returned empty data");
  } catch (e) {
    print("Error generating wallet: $e");
    try {
      final retryResponse = await apiService.getWallet(userId);
      if (retryResponse.data != null && retryResponse.data is Map && retryResponse.data['address'] != null) {
        return retryResponse.data;
      }
    } catch (_) {}
    throw Exception("Failed to generate wallet: $e");
  }
});

final transactionsProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  if (userId.isEmpty) return [];
  final apiService = ref.read(apiServiceProvider);
  try {
    await apiService.syncDeposits(userId).timeout(const Duration(seconds: 60));
  } catch (e) {
    print("Background sync issue: $e");
  }
  ref.invalidate(balanceProvider(userId));

  try {
    final response = await apiService.getTransactions(userId);
    return (response.data is List) ? response.data as List<dynamic> : [];
  } catch (e) {
    print("Error fetching transactions: $e");
    return [];
  }
});

final withdrawalsProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  if (userId.isEmpty) return [];
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getWithdrawals(userId);
    return (response.data is List) ? response.data as List<dynamic> : [];
  } catch (e) {
    print("Error fetching withdrawals: $e");
    return [];
  }
});

// Combined provider for "Activity"
final activityProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  final txs = await ref.watch(transactionsProvider(userId).future);
  final withdrawals = await ref.watch(withdrawalsProvider(userId).future);
  
  // Tag them to distinguish
  final formattedTxs = txs.map((e) => {...e, 'type': 'deposit'}).toList();
  final formattedWithdrawals = withdrawals.map((e) => {...e, 'type': 'withdrawal'}).toList();
  
  final combined = [...formattedTxs, ...formattedWithdrawals];
  // Sort by createdAt / timestamp desc
  combined.sort((a, b) {
    final timeA = a['createdAt'] ?? a['timestamp'] ?? 0;
    final timeB = b['createdAt'] ?? b['timestamp'] ?? 0;
    return timeB.compareTo(timeA);
  });
  
  return combined;
});

final messagesProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  if (userId.isEmpty) return [];
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getMessages(userId);
    return (response.data is List) ? response.data as List<dynamic> : [];
  } catch (e) {
    print("Error fetching messages: $e");
    return [];
  }
});

final unreadCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  if (userId.isEmpty) return 0;
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getUnreadCount(userId);
    if (response.data is List) {
      return (response.data as List).length;
    }
    return 0;
  } catch (e) {
    return 0;
  }
});

final syncProvider = FutureProvider.family<int, String>((ref, userId) async {
  if (userId.isEmpty) return 0;
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.syncDeposits(userId).timeout(const Duration(seconds: 60));
    ref.invalidate(balanceProvider(userId));
    if (response.data is Map && response.data['foundNew'] != null) {
      return response.data['foundNew'] as int;
    }
    return 0;
  } catch (e) {
    print("Manual sync failed: $e");
    ref.invalidate(balanceProvider(userId));
    return 0;
  }
});
