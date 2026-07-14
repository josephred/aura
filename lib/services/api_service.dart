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

  /// Sends a `multipart/form-data` POST, used for real file uploads (e.g. the
  /// medical prescription image/PDF). Unlike [post], the request body is not
  /// JSON: [fields] are sent as form fields and [files] carry the actual bytes.
  /// The `Content-Type` header is left unset so `http` can add the multipart
  /// boundary itself; the auth and ngrok headers are still forwarded.
  Future<http.Response> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers.addAll({
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    });
    request.fields.addAll(fields);
    request.files.addAll(files);

    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);

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
