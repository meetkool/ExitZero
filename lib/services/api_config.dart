/// Central configuration for all API endpoints.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the Bizniz backend.
  static const String baseUrl = 'https://biznuz.mockpeer.me/api/v1';

  // ── Auth ──
  static const String register = '$baseUrl/auth/register';
  static const String token = '$baseUrl/auth/token';
  static const String forgotPassword = '$baseUrl/auth/password/forgot';
  static const String resetPassword = '$baseUrl/auth/password/reset-confirm';

  // ── Users ──
  static const String usersMe = '$baseUrl/users/me';
  static const String usersMeAvatar = '$baseUrl/users/me/avatar';
}
