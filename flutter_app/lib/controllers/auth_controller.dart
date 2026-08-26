import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({AppUser? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({AuthState? initialState, bool loadStoredUser = true})
      : super(initialState ?? AuthState()) {
    if (loadStoredUser) _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    state = state.copyWith(user: user);
    if (user != null && !user.isGuest) {
      await AuthService.retryPendingProfileUpdate(user: user);
    }
  }

  Future<bool> register(
    String phone,
    String birthYear,
    String pin, {
    String secretWord = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await AuthService.register(
        phone,
        birthYear,
        pin,
        secretWord: secretWord,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login(String phone, String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await AuthService.login(phone, pin);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> resetPin(String phone, String secretWord, String newPin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await AuthService.resetPin(phone, secretWord, newPin);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> loginAsGuest() async {
    final user = await AuthService.loginAsGuest();
    state = state.copyWith(user: user);
  }

  Future<bool> updateProfile({
    required String displayName,
    required String phone,
    String? photoPath,
    bool removePhoto = false,
  }) async {
    final current = state.user;
    if (current == null || current.isGuest) {
      state = state.copyWith(error: 'A registered account is required');
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await AuthService.updateProfile(
        current,
        displayName: displayName,
        phone: phone,
        photoPath: photoPath,
        removePhoto: removePhoto,
      );
      state = state.copyWith(user: updated, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
