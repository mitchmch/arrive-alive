import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../core/config.dart';
import 'api_service.dart';

class AuthService {
  static const _key = 'arrive_alive_user';
  static const _usersKey = 'arrive_alive_users';
  static const _profilesKey = 'arrive_alive_profiles';
  static const _pendingProfileKey = 'arrive_alive_pending_profile_update';

  static Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return null;
    return AppUser.fromJson(jsonDecode(str));
  }

  static Future<void> retryPendingProfileUpdate({AppUser? user}) async {
    if (!AppConfig.hasBackend) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingProfileKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final pending = jsonDecode(raw) as Map<String, dynamic>;
      final current = user ?? await getCurrentUser();
      if (current == null ||
          pending['userId']?.toString() != current.id.toString()) {
        return;
      }
      await ApiService.patch('/api/profile', {
        'displayName': pending['displayName'],
        'phone': pending['phone'],
      });
      await prefs.remove(_pendingProfileKey);
    } catch (_) {
      // Keep the operation for the next authenticated startup or login.
    }
  }

  static Future<void> _saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toJson()));
  }

  static String _profileKey(AppUser user) => '${user.role}:${user.id}';

  static AppUser _applyStoredProfile(
    AppUser user,
    SharedPreferences prefs,
  ) {
    final profiles = _getLocalUsers(prefs.getString(_profilesKey) ?? '');
    final stored = profiles[_profileKey(user)];
    if (stored is! Map<String, dynamic>) return user;
    return user.copyWith(
      displayName: stored['displayName']?.toString() ?? user.displayName,
      phone: stored['phone']?.toString() ?? user.phone,
      photoPath: stored['photoPath']?.toString() ?? user.photoPath,
    );
  }

  static Future<void> _clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Local user store for offline fallback
  static Map<String, dynamic> _getLocalUsers(String jsonStr) {
    if (jsonStr.isEmpty) return {};
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<AppUser> register(
    String phone,
    String birthYear,
    String pin, {
    String secretWord = '',
  }) async {
    try {
      final data = await ApiService.post('/api/auth/register', {
        'phone': phone,
        'birthYear': birthYear,
        'pin': pin,
        'secretWord': secretWord,
      });
      await ApiService.setSessionToken(data['token']?.toString());
      final user = AppUser(
        id: data['id'],
        phone: data['phone'],
        role: data['role'],
        displayName: data['displayName']?.toString() ?? '',
      );
      await _saveUser(user);
      await retryPendingProfileUpdate(user: user);
      return user;
    } catch (_) {
      if (AppConfig.hasBackend) rethrow;
      // Offline fallback: store locally
      final prefs = await SharedPreferences.getInstance();
      final users = _getLocalUsers(prefs.getString(_usersKey) ?? '');
      if (users.containsKey(phone)) {
        throw Exception('An account with this phone already exists');
      }
      final id = DateTime.now().millisecondsSinceEpoch;
      users[phone] = {
        'phone': phone,
        'pin': pin,
        'birthYear': birthYear,
        'role': 'user',
        'displayName': '',
        'id': id,
        'secret': secretWord,
      };
      await prefs.setString(_usersKey, jsonEncode(users));
      final user = AppUser(
        id: id,
        phone: phone,
        role: 'user',
        birthYear: birthYear,
      );
      await _saveUser(user);
      return user;
    }
  }

  static Future<AppUser> login(String phone, String pin) async {
    // Admin login
    if (!AppConfig.hasBackend && phone == 'admin' && pin == '1234') {
      final prefs = await SharedPreferences.getInstance();
      final user = _applyStoredProfile(
        AppUser(id: 0, phone: 'admin', role: 'admin'),
        prefs,
      );
      await _saveUser(user);
      return user;
    }
    try {
      final data = await ApiService.post('/api/auth/login', {
        'phone': phone,
        'pin': pin,
      });
      await ApiService.setSessionToken(data['token']?.toString());
      final prefs = await SharedPreferences.getInstance();
      final user = _applyStoredProfile(
        AppUser(
          id: data['id'],
          phone: data['phone'],
          role: data['role'],
          displayName: data['displayName']?.toString() ?? '',
          birthYear: data['birthYear'],
        ),
        prefs,
      );
      await _saveUser(user);
      return user;
    } catch (_) {
      if (AppConfig.hasBackend) rethrow;
      // Offline fallback: check local store
      final prefs = await SharedPreferences.getInstance();
      final users = _getLocalUsers(prefs.getString(_usersKey) ?? '');
      if (!users.containsKey(phone)) {
        throw Exception('No account found. Please register first.');
      }
      final userData = users[phone] as Map<String, dynamic>;
      if (userData['pin'] != pin) {
        throw Exception('Incorrect PIN');
      }
      final user = _applyStoredProfile(
        AppUser(
          id: userData['id'] ?? 0,
          phone: phone,
          role: userData['role'] ?? 'user',
          displayName: userData['displayName']?.toString() ?? '',
          birthYear: userData['birthYear']?.toString(),
        ),
        prefs,
      );
      await _saveUser(user);
      return user;
    }
  }

  static Future<void> resetPin(
    String phone,
    String secretWord,
    String newPin,
  ) async {
    try {
      await ApiService.post('/api/auth/reset-pin', {
        'phone': phone,
        'secretWord': secretWord,
        'newPin': newPin,
      });
    } catch (_) {
      if (AppConfig.hasBackend) rethrow;
      // Offline fallback: verify secret word and reset PIN
      final prefs = await SharedPreferences.getInstance();
      final users = _getLocalUsers(prefs.getString(_usersKey) ?? '');
      final user = users[phone];
      if (user == null) {
        throw Exception('No account found with this phone number');
      }
      final userData = user as Map<String, dynamic>;
      final storedSecret = userData['secret'] as String? ?? '';
      if (storedSecret.isEmpty) {
        throw Exception('No secret word set for this account');
      }
      if (storedSecret.toLowerCase() != secretWord.toLowerCase()) {
        throw Exception('Secret word does not match');
      }
      userData['pin'] = newPin;
      users[phone] = userData;
      await prefs.setString(_usersKey, jsonEncode(users));
    }
  }

  static Future<AppUser> loginAsGuest() async {
    final user = AppUser(id: 0, phone: 'guest', role: 'guest', isGuest: true);
    await _saveUser(user);
    return user;
  }

  static Future<AppUser> updateProfile(
    AppUser current, {
    required String displayName,
    required String phone,
    String? photoPath,
    bool removePhoto = false,
  }) async {
    if (current.isGuest) {
      throw Exception('Guest profiles cannot be edited');
    }

    final trimmedName = displayName.trim();
    final trimmedPhone = phone.trim();
    if (trimmedName.length < 2 || trimmedName.length > 50) {
      throw Exception('Display name must be between 2 and 50 characters');
    }
    final digits = trimmedPhone.replaceAll(RegExp(r'\D'), '');
    final isUnchangedAdminPhone =
        current.role == 'admin' && trimmedPhone == current.phone;
    if (!isUnchangedAdminPhone &&
        (digits.length < 8 ||
            digits.length > 15 ||
            !RegExp(r'^\+?[\d\s()-]+$').hasMatch(trimmedPhone))) {
      throw Exception('Enter a valid phone number');
    }

    final prefs = await SharedPreferences.getInstance();
    final users = _getLocalUsers(prefs.getString(_usersKey) ?? '');
    if (trimmedPhone != current.phone && users.containsKey(trimmedPhone)) {
      throw Exception('An account with this phone already exists');
    }

    final localRecord = users.remove(current.phone);
    if (localRecord is Map<String, dynamic>) {
      localRecord['phone'] = trimmedPhone;
      localRecord['displayName'] = trimmedName;
      users[trimmedPhone] = localRecord;
      await prefs.setString(_usersKey, jsonEncode(users));
    }

    final updated = current.copyWith(
      displayName: trimmedName,
      phone: trimmedPhone,
      photoPath: photoPath,
      clearPhoto: removePhoto,
    );
    final profiles = _getLocalUsers(prefs.getString(_profilesKey) ?? '');
    profiles[_profileKey(current)] = {
      'displayName': trimmedName,
      'phone': trimmedPhone,
      'photoPath': updated.photoPath,
    };
    await prefs.setString(_profilesKey, jsonEncode(profiles));
    await _saveUser(updated);

    if (AppConfig.hasBackend) {
      final pending = {
        'userId': current.id,
        'displayName': trimmedName,
        'phone': trimmedPhone,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString(_pendingProfileKey, jsonEncode(pending));
      try {
        await ApiService.patch('/api/profile', {
          'displayName': trimmedName,
          'phone': trimmedPhone,
        });
        await prefs.remove(_pendingProfileKey);
      } catch (_) {
        // The local edit is complete. The persisted operation retries later.
      }
    }
    return updated;
  }

  static Future<void> logout() async {
    if (AppConfig.hasBackend) {
      try {
        await ApiService.post('/api/auth/logout', {});
      } catch (_) {
        // Local logout still clears a stale or unreachable remote session.
      }
    }
    await ApiService.setSessionToken(null);
    await _clearUser();
  }
}
