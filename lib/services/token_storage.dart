import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage wrapper for JWT tokens and cached user data.
class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';

  // ── Token ──

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ── User data cache ──

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    await _storage.write(key: _userKey, value: jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> deleteUserData() async {
    await _storage.delete(key: _userKey);
  }

  /// Clear everything (logout).
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
