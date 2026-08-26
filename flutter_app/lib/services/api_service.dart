import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';

class ApiService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static final http.Client _client = http.Client();
  static const String _tokenKey = 'arrive_alive_api_token';

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final token = (await SharedPreferences.getInstance()).getString(_tokenKey);
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> setSessionToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  static void _requireBackend() {
    if (!AppConfig.hasBackend) {
      throw const BackendUnavailableException();
    }
  }

  static Future<dynamic> get(String path) async {
    _requireBackend();
    final res = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    _requireBackend();
    final res = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        ...await _headers(json: true),
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    _requireBackend();
    final res = await _client.patch(
      Uri.parse('$_baseUrl$path'),
      headers: {
        ...await _headers(json: true),
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<dynamic> delete(String path) async {
    _requireBackend();
    final res = await _client.delete(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static dynamic _parse(http.Response res) {
    if (res.statusCode >= 400) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}

class BackendUnavailableException implements Exception {
  const BackendUnavailableException();

  @override
  String toString() =>
      'Backend unavailable: set API_BASE_URL to enable server synchronization';
}
