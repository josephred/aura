import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  String? authToken;
  final VoidCallback? onUnauthorized;

  ApiService({
    required this.baseUrl,
    this.authToken,
    this.onUnauthorized,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Skip ngrok's browser interstitial so the API returns JSON, not HTML
        'ngrok-skip-browser-warning': 'true',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Future<http.Response> get(String path, {Duration timeout = const Duration(seconds: 4)}) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    ).timeout(timeout);

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return response;
  }

  Future<http.Response> post(String path, {dynamic body, Duration timeout = const Duration(seconds: 4), bool isRawBody = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: isRawBody ? body : (body != null ? json.encode(body) : null),
    ).timeout(timeout);

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return response;
  }

  Future<http.Response> put(String path, {dynamic body, Duration timeout = const Duration(seconds: 4), bool isRawBody = false}) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: isRawBody ? body : (body != null ? json.encode(body) : null),
    ).timeout(timeout);

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return response;
  }

  Future<http.Response> delete(String path, {dynamic body, Duration timeout = const Duration(seconds: 4)}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? json.encode(body) : null,
    ).timeout(timeout);

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return response;
  }
}
