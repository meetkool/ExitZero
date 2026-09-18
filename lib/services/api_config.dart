/// Central configuration for all API endpoints.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the Bizniz backend.
  static const String baseUrl = 'https://biznuz.mockpeer.me/api/v1';
  // static const String baseUrl = 'https://backend_test.mockpeer.me/api/v1';
  // static const String baseUrl = 'http://localhost:8000/api/v1';



  // ── Interviews ──
  static const String interviews = '$baseUrl/interviews';
}
