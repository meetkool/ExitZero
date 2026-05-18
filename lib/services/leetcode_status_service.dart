import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/leetcode_status.dart';

class LeetCodeStatusException implements Exception {
  final String message;

  const LeetCodeStatusException(this.message);

  @override
  String toString() => message;
}

class LeetCodeStatusService {
  static final Uri _statusUri = Uri.parse('http://leetcode.mockpeer.me/status');

  Future<LeetCodeStatus> fetchStatus() async {
    final response = await http
        .get(_statusUri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw LeetCodeStatusException(
        'LeetCode status request failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const LeetCodeStatusException(
        'LeetCode status payload was not valid JSON.',
      );
    }

    try {
      return LeetCodeStatus.fromJson(decoded);
    } on FormatException catch (error) {
      throw LeetCodeStatusException(
        'LeetCode status payload was missing fields: $error',
      );
    }
  }
}
