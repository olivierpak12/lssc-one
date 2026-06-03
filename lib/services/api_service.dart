import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';

class ApiService {
  final Dio _dio = Dio();

  ApiService() {
    try {
      _dio.options.baseUrl = AppConfig.resolvedConvexUrl;
    } on ArgumentError {
      _dio.options.baseUrl = '';
    }
  }

  // --- Auth Methods ---

  Future<Response> login(String email, String password) async {
    return await _dio.post('/run/users:login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> checkReferralCode(String code) async {
    return await _dio.get('/run/users:checkReferralCode', queryParameters: {'code': code});
  }

  Future<Response> register({
    required String email,
    required String password,
    required String transactionPassword,
    String? invitationCode,
  }) async {
    final data = {
      'email': email,
      'password': password,
      'transactionPassword': transactionPassword,
      if (invitationCode != null) 'invitationCode': invitationCode,
    };

    return await _dio.post('/mutation/users:register', data: data);
  }

  Future<Response> verifyEmail(String userId) async {
    return await _dio.post('/mutation/users:verifyEmail', data: {
      'userId': userId,
    });
  }

  Future<Response> getUser(String userId) async {
    return await _dio.get('/run/users:getUser', queryParameters: {'userId': userId});
  }

  // --- Referral Methods ---

  Future<Response> getReferralStats(String userId) async {
    return await _dio.get('/run/referrals:getTeamStats', queryParameters: {'userId': userId});
  }

  Future<Response> getTeamMembers(String userId) async {
    return await _dio.get('/run/referrals:getTeamMembers', queryParameters: {'userId': userId});
  }

  Future<Response> getReferralEarnings(String userId) async {
    return await _dio.get('/run/referrals:getReferralEarningsHistory', queryParameters: {'userId': userId});
  }

  Future<Response> getLeaderboard() async {
    return await _dio.get('/run/referrals:getLeaderboard');
  }

  // --- Admin Methods ---

  Future<Response> listUsers() async {
    return await _dio.get('/run/users:listUsers');
  }

  Future<Response> setUserRole(String userId, String role) async {
    return await _dio.post('/mutation/users:setRole', data: {
      'userId': userId,
      'role': role,
    });
  }

  Future<Response> getAdminStats() async {
    return await _dio.get('/run/admin:getStats');
  }

  Future<Response> getPendingWithdrawals() async {
    return await _dio.get('/run/admin:getPendingWithdrawals');
  }

  Future<Response> processWithdrawal(String withdrawalId) async {
    return await _dio.post('/action/withdrawalActions:processWithdrawal', data: {'withdrawalId': withdrawalId});
  }

  Future<Response> processAllWithdrawals() async {
    return await _dio.post('/action/withdrawalActions:processAllPending');
  }

  Future<Response> getWithdrawableBalance(String userId) async {
    return await _dio.get('/run/balances:getWithdrawableBalance', queryParameters: {'userId': userId});
  }

  // --- Data Methods ---

  Future<Response> getBalance(String userId) async {
    return await _dio.get('/run/balances:getTotalUsdtBalance', queryParameters: {'userId': userId});
  }

  Future<Response> getTransactions(String userId) async {
    return await _dio.get('/run/deposits:listDeposits', queryParameters: {'userId': userId});
  }

  Future<Response> getWithdrawals(String userId) async {
    return await _dio.get('/run/withdrawals:getWithdrawals', queryParameters: {'userId': userId});
  }

  Future<Response> requestWithdrawal(Map<String, dynamic> data) async {
    return await _dio.post('/mutation/withdrawals:requestWithdrawal', data: data);
  }

  Future<Response> getWallet(String userId) async {
    return await _dio.get('/run/wallets:getWallet', queryParameters: {'userId': userId});
  }

  Future<Response> generateWallet(String userId) async {
    return await _dio.post('/action/walletActions:generateWallet', data: {'userId': userId});
  }

  Future<Response> syncDeposits(String userId) async {
    return await _dio.post('/action/etherscanActions:syncUserDeposits', data: {'userId': userId});
  }

  // --- Bike Methods ---

  Future<Response> buyBike(String userId, String bikeId, String amount) async {
    return await _dio.post('/mutation/bikes:buyBike', data: {
      'userId': userId,
      'bikeId': bikeId,
      'amount': amount,
    });
  }

  // --- Password Reset Methods ---

  Future<Response> requestPasswordReset(String email) async {
    return await _dio.post('/mutation/users:requestPasswordReset', data: {
      'email': email,
    });
  }

  Future<Response> resetPassword(String token, String newPassword) async {
    return await _dio.post('/mutation/users:resetPassword', data: {
      'token': token,
      'newPassword': newPassword,
    });
  }

  // --- Transaction Password Reset Methods ---

  Future<Response> requestTransactionPasswordReset(String email) async {
    return await _dio.post('/mutation/users:requestTransactionPasswordReset', data: {
      'email': email,
    });
  }

  Future<Response> resetTransactionPassword(String token, String newPassword) async {
    return await _dio.post('/mutation/users:resetTransactionPassword', data: {
      'token': token,
      'newPassword': newPassword,
    });
  }

  // --- Purchases Methods ---

  Future<Response> getUserPurchases(String userId) async {
    return await _dio.get('/run/bikes:getUserPurchases', queryParameters: {'userId': userId});
  }

  Future<Response> claimDailyEarnings(String userId, String purchaseId) async {
    return await _dio.post('/mutation/bikes:claimDailyEarnings', data: {
      'userId': userId,
      'purchaseId': purchaseId,
    });
  }

  // --- Network Methods ---

  Future<Response> getActiveNetworks() async {
    return await _dio.get('/run/networks:getActiveNetworks');
  }

  Future<Response> getAllNetworks() async {
    return await _dio.get('/run/networks:getAllNetworks');
  }

  // --- Message Methods ---

  Future<Response> getMessages(String userId) async {
    return await _dio.get('/run/messages:list', queryParameters: {'userId': userId});
  }

  Future<Response> getUnreadCount(String userId) async {
    return await _dio.get('/run/messages:unreadCount', queryParameters: {'userId': userId});
  }

  Future<Response> markMessageRead(String messageId) async {
    return await _dio.post('/mutation/messages:markRead', data: {'messageId': messageId});
  }

  Future<Response> markAllMessagesRead(String userId) async {
    return await _dio.post('/mutation/messages:markAllRead', data: {'userId': userId});
  }

  // --- Team Methods ---

  Future<Response> getTeamStats(String userId, String period) async {
    return await _dio.get('/run/teams:getTeamStats', queryParameters: {
      'userId': userId,
      'period': period,
    });
  }
}

final apiServiceProvider = Provider((ref) => ApiService());
