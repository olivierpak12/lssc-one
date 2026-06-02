import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthState {
  final String? userId;
  final String? email;
  final String? role; 
  final String? referralCode;
  final String? referralLink;
  final bool isEmailVerified;
  final bool isLoading;
  final String? error;
  final bool skippedVerification;
  final bool sessionRestored;
  final String? teamRewardsBalance;
  final String? teamRewardsTotalEarned;
  final String? myInviteCode;

  AuthState({
    this.userId,
    this.email,
    this.role,
    this.referralCode,
    this.referralLink,
    this.isEmailVerified = false,
    this.isLoading = false,
    this.error,
    this.skippedVerification = false,
    this.sessionRestored = false,
    this.teamRewardsBalance,
    this.teamRewardsTotalEarned,
    this.myInviteCode,
  });

  bool get isAdmin => role == 'admin';

  AuthState copyWith({
    String? userId,
    String? email,
    String? role,
    String? referralCode,
    String? referralLink,
    bool? isEmailVerified,
    bool? isLoading,
    String? error,
    bool? skippedVerification,
    bool? sessionRestored,
    String? teamRewardsBalance,
    String? teamRewardsTotalEarned,
    String? myInviteCode,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      referralCode: referralCode ?? this.referralCode,
      referralLink: referralLink ?? this.referralLink,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      skippedVerification: skippedVerification ?? this.skippedVerification,
      sessionRestored: sessionRestored ?? this.sessionRestored,
      teamRewardsBalance: teamRewardsBalance,
      teamRewardsTotalEarned: teamRewardsTotalEarned,
      myInviteCode: myInviteCode,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final email = prefs.getString('email');
      final role = prefs.getString('role');
      final refCode = prefs.getString('referralCode');
      final refLink = prefs.getString('referralLink');
      final verified = prefs.getBool('emailVerified') ?? false;

      if (userId != null) {
        state = AuthState(
          userId: userId,
          email: email,
          role: role,
          referralCode: refCode,
          referralLink: refLink,
          isEmailVerified: verified,
          sessionRestored: true,
        );
        await refreshUser();
      } else {
        state = state.copyWith(sessionRestored: true);
      }
    } catch (_) {
      state = state.copyWith(sessionRestored: true);
    }
  }

  Future<void> refreshUser() async {
    if (state.userId == null) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getUser(state.userId!);
      final userData = response.data;

      if (userData != null) {
        final newRole = userData['role'] ?? 'user';
        final isVerified = userData['emailVerified'] ?? false;
        final refCode = userData['referralCode'];
        final refLink = userData['referralLink'];
        final rewardsBalance = userData['teamRewardsBalance'] ?? "0";
        final rewardsTotal = userData['teamRewardsTotalEarned'] ?? "0";
        final inviteCode = userData['myInviteCode'] as String?;

        if (newRole != state.role || isVerified != state.isEmailVerified ||
            refCode != state.referralCode || refLink != state.referralLink ||
            rewardsBalance != state.teamRewardsBalance || rewardsTotal != state.teamRewardsTotalEarned ||
            inviteCode != state.myInviteCode) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', newRole);
          await prefs.setBool('emailVerified', isVerified);
          if (refCode != null) await prefs.setString('referralCode', refCode);
          if (refLink != null) await prefs.setString('referralLink', refLink);
          state = state.copyWith(
            role: newRole,
            isEmailVerified: isVerified,
            referralCode: refCode,
            referralLink: refLink,
            teamRewardsBalance: rewardsBalance,
            teamRewardsTotalEarned: rewardsTotal,
            myInviteCode: inviteCode,
          );
        }
      }
    } catch (e) {
      // Silent fail — session data from storage is sufficient for offline
    }
  }

  String _handleError(dynamic e) {
    String raw = '';
    if (e is DioException) {
      if (e.response?.data != null) {
        raw = e.response!.data.toString().replaceAll('"', '');
      } else {
        raw = e.message?.replaceFirst(RegExp(r'^DioException\s*\[.*?\]\s*'), '') ?? '';
      }
    } else if (e is ArgumentError) {
      raw = 'Missing configuration: ${e.message}';
    } else {
      raw = e.toString();
    }

    final display = raw
        .replaceFirst(RegExp(r'\[CONVEX.*?\]\s*'), '')
        .replaceFirst('Uncaught Error: ', '')
        .trim();

    final message = display.toLowerCase();

    if (message.contains('already exists') || message.contains('email already in use') || message.contains('duplicate')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (message.contains('invalid credentials') || message.contains('wrong password') || message.contains('invalid email')) {
      return 'Invalid email or password. Please try again.';
    }
    if (message.contains('not found') || message.contains('user not found') || message.contains('account not found')) {
      return 'No account found with this email. Please register first.';
    }
    if (message.contains('password') && (message.contains('weak') || message.contains('too short') || message.contains('invalid'))) {
      return 'Password must be at least 8 characters with letters and numbers.';
    }
    if (message.contains('referral') || message.contains('invitation') || message.contains('invalid code')) {
      return 'Invalid referral code. Please check and try again.';
    }
    if (message.contains('rate limit') || message.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    if (message.contains('unreachable') || message.contains('connection') || message.contains('timeout') || message.contains('dns')) {
      return 'Cannot reach the server. Check your internet connection and ensure the backend URL is configured.';
    }
    if (message.contains('email') && (message.contains('verify') || message.contains('not verified'))) {
      return 'Please verify your email address before continuing.';
    }

    if (display.isEmpty) {
      return 'An unknown error occurred. Please try again.';
    }
    return 'Error: $display';
  }

  Future<bool> checkReferralCode(String code) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.checkReferralCode(code);
      return response.data['isValid'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.login(email, password);

      final userId = response.data['_id'];
      final userEmail = response.data['email'];
      final userRole = response.data['role'] ?? 'user';
      final isVerified = response.data['emailVerified'] ?? false;
      final refCode = response.data['referralCode'];
      final refLink = response.data['referralLink'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('email', userEmail);
      await prefs.setString('role', userRole);
      await prefs.setBool('emailVerified', isVerified);
      if (refCode != null) await prefs.setString('referralCode', refCode);
      if (refLink != null) await prefs.setString('referralLink', refLink);

      state = AuthState(
        userId: userId,
        email: userEmail,
        role: userRole,
        isEmailVerified: isVerified,
        referralCode: refCode,
        referralLink: refLink,
        sessionRestored: true,

      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _handleError(e));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String transactionPassword,
    String? invitationCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.register(
        email: email,
        password: password,
        transactionPassword: transactionPassword,
        invitationCode: invitationCode,
      );

      return await login(email, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _handleError(e));
      return false;
    }
  }

  void skipVerification() {
    state = state.copyWith(skippedVerification: true);
  }

  Future<void> verifyEmail() async {
    if (state.userId == null) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.verifyEmail(state.userId!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('emailVerified', true);
      state = state.copyWith(isEmailVerified: true);
    } catch (e) {
      state = state.copyWith(error: _handleError(e));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('emailVerified');
    state = AuthState(sessionRestored: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
