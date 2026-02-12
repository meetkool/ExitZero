import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import '../models/mock_interview.dart';
import 'api_config.dart';

import 'dart:async'; // Add async import

class InterviewService {
  // Global stream to notify listeners of changes
  static final StreamController<void> _interviewsUpdated = StreamController<void>.broadcast();
  static Stream<void> get onInterviewsUpdated => _interviewsUpdated.stream;

  Future<String?> _getToken() async {
    return TokenStorage.getToken();
  }
// ... existing methods ...

  Future<MockInterview> createInterview(MockInterview interview) async {
    final headers = await _getHeaders();
    final body = interview.toJson();
    body.remove('id');
    body.remove('status');

    // Add trailing slash
    final url = Uri.parse('${ApiConfig.interviews}/');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _interviewsUpdated.add(null); // Notify
      return MockInterview.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create interview: ${response.body}');
    }
  }

  Future<MockInterview> updateInterview(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final headers = await _getHeaders();
    // Remove trailing slash for ID-based route
    final url = Uri.parse('${ApiConfig.interviews}/$id');

    print('PUT $url');
    print('Headers: $headers');
    print('Body: ${jsonEncode(updates)}');

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(updates),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      _interviewsUpdated.add(null); // Notify
      return MockInterview.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update interview: ${response.body}');
    }
  }

  Future<void> deleteInterview(String id) async {
    final headers = await _getHeaders();
    // Remove trailing slash for ID-based route
    final url = Uri.parse('${ApiConfig.interviews}/$id');

    print('DELETE $url');
    print('Headers: $headers');

    final response = await http.delete(url, headers: headers);

    print('Response status: ${response.statusCode}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete interview: ${response.statusCode}');
    }
    _interviewsUpdated.add(null); // Notify
  }

  Future<MockInterview> checkIn(String id) async {
    final headers = await _getHeaders();
    // Remove trailing slash for ID-based route
    final url = Uri.parse('${ApiConfig.interviews}/$id/check-in');

    print('POST $url');
    print('Headers: $headers');

    final response = await http.post(url, headers: headers);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      _interviewsUpdated.add(null); // Notify
      try {
        return MockInterview.fromJson(jsonDecode(response.body));
      } catch (_) {
        return await getInterview(id);
      }
    } else {
      String error = 'Check-in failed';
      try {
        final body = jsonDecode(response.body);
        if (body['detail'] != null) error = body['detail'];
      } catch (_) {}
      throw Exception(error);
    }
  }
// ... rest of file ...

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<MockInterview>> getInterviews({String? status, String? date}) async {
    final headers = await _getHeaders();
    // Add trailing slash to avoid 307 redirect which strips Authorization header
    var url = Uri.parse('${ApiConfig.interviews}/');
    final Map<String, String> queryParams = {};
    if (status != null) queryParams['status'] = status;
    if (date != null) queryParams['date'] = date;
    
    if (queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }

    print('GET $url');
    print('Request Headers: $headers');

    final response = await http.get(url, headers: headers);

    print('Response status: ${response.statusCode}');
    print('Response headers: ${response.headers}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => MockInterview.fromJson(json)).toList();
    } else if (response.statusCode == 304) {
      print('Received 304 Not Modified. Body is likely empty.');
      // 304 means resource hasn't changed.
      // If we had local cache, we would use it here.
      // Since we don't implement caching yet, this is treated as an error or empty list?
      // For now, let's treat it as an empty list or throw to see what happens.
       throw Exception('Received 304 Not Modified from backend.');
    } else {
      throw Exception('Failed to load interviews: ${response.statusCode}');
    }
  }


  Future<MockInterview> updateInterviewStatus(String id, String status) async {
      return updateInterview(id, {'status': status});
  }


  Future<MockInterview> getInterview(String id) async {
    final headers = await _getHeaders();
    // Add trailing slash
    final url = Uri.parse('${ApiConfig.interviews}/$id/');

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return MockInterview.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch interview: ${response.statusCode}');
    }
  }
}
