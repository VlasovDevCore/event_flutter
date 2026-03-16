import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  // Для Android-эмулятора: http://10.0.2.2:4001
  // Для реального девайса по USB: http://<IP_ПК>:4001
  // Пока оставим localhost, если тестируешь на десктопе/эмуляторе с пробросом.
  static const String baseUrl = 'http://localhost:4006';

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (withAuth) {
      final authBox = Hive.box('authBox');
      final token = authBox.get('token') as String?;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final res = await http.post(
      _uri(path),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    final data = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    throw ApiException(
      res.statusCode,
      data['error']?.toString() ?? 'Request failed',
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool withAuth = false,
  }) async {
    final headers = <String, String>{};
    if (withAuth) {
      final authBox = Hive.box('authBox');
      final token = authBox.get('token') as String?;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    final res = await http.get(
      _uri(path, query),
      headers: headers,
    );
    final data = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }
    if (data is Map && data['error'] != null) {
      throw ApiException(res.statusCode, data['error'].toString());
    }
    throw ApiException(res.statusCode, 'Request failed');
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
    bool withAuth = false,
  }) async {
    final headers = <String, String>{};
    if (withAuth) {
      final authBox = Hive.box('authBox');
      final token = authBox.get('token') as String?;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final res = await http.get(
      _uri(path, query),
      headers: headers,
    );
    final data = res.body.isNotEmpty ? jsonDecode(res.body) : [];
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data as List<dynamic>;
    }
    if (data is Map && data['error'] != null) {
      throw ApiException(res.statusCode, data['error'].toString());
    }
    throw ApiException(res.statusCode, 'Request failed');
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

