import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Exception thrown when an API call fails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service that wraps all auth & user API calls.
class AuthService {
  AuthService._();

  // ─────────────────────────── Auth ───────────────────────────

  /// Register a new user. Returns the user map on success.
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.register),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  /// Login with email + password.
  /// Returns `{ "access_token": "...", "token_type": "bearer" }`.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // The token endpoint expects form-urlencoded with field "username".
    final response = await http.post(
      Uri.parse(ApiConfig.token),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': email,
        'password': password,
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  // ─────────────────────────── Users ──────────────────────────

  /// Get the current user's profile.
  static Future<Map<String, dynamic>> getMe(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.usersMe),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  /// Update current user's name.
  static Future<Map<String, dynamic>> updateName({
    required String token,
    required String name,
  }) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.usersMe),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  /// Upload avatar image.
  static Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required String filePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.usersMeAvatar),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('avatar_file', filePath),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  // ─────────────────────── Password Reset ────────────────────

  /// Request a password-reset email.
  static Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse(ApiConfig.forgotPassword),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) return;
    final data = jsonDecode(response.body);
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  /// Reset password using the token from the email.
  static Future<void> resetPassword({
    required String resetToken,
    required String password,
    required String passwordConfirm,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.resetPassword),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': resetToken,
        'password': password,
        'password_confirm': passwordConfirm,
      }),
    );
    if (response.statusCode == 200) return;
    final data = jsonDecode(response.body);
    throw ApiException(
      _extractError(data),
      statusCode: response.statusCode,
    );
  }

  // ──────────────────────── Helpers ──────────────────────────

  static String _extractError(dynamic data) {
    if (data is Map) {
      // FastAPI validation errors
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
        return detail.toString();
      }
      if (data.containsKey('msg')) return data['msg'].toString();
    }
    return 'Something went wrong. Please try again.';
  }
}
