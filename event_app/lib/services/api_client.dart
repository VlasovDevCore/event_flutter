import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  // Для Android-эмулятора: http://10.0.2.2:4001
  // Для реального девайса по USB: http://<IP_ПК>:4001
  // Пока оставим localhost, если тестируешь на десктопе/эмуляторе с пробросом.
  // static const String baseUrl = 'http://localhost:4006';
  // static const String baseUrl = 'http://localhost:4006';
  static const String baseUrl = 'http://192.168.0.223:4006';

  /// Без таймаута запрос к недоступному хосту на телефоне может «висеть» минутами.
  static const Duration requestTimeout = Duration(seconds: 20);

  static String? getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return imagePath;
    if (imagePath.startsWith('/uploads')) return '$baseUrl$imagePath';
    return '$baseUrl/uploads/$imagePath';
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<T> _withTimeout<T>(Future<T> future) async {
    try {
      return await future.timeout(requestTimeout);
    } on TimeoutException {
      throw ApiException(
        408,
        'Сервер не отвечает. Проверьте Wi‑Fi, адрес API ($baseUrl) и что бэкенд запущен.',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (withAuth) {
      final authBox = Hive.box('authBox');
      final token = authBox.get('token') as String?;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final res = await _withTimeout(
      http.post(_uri(path), headers: headers, body: jsonEncode(body ?? {})),
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

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (withAuth) {
      final authBox = Hive.box('authBox');
      final token = authBox.get('token') as String?;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final res = await _withTimeout(
      http.put(_uri(path), headers: headers, body: jsonEncode(body ?? {})),
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
    final res = await _withTimeout(
      http.get(_uri(path, query), headers: headers),
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

    final res = await _withTimeout(
      http.get(_uri(path, query), headers: headers),
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

  Future<Map<String, dynamic>> uploadImage(
    String path, {
    required Uint8List bytes,
    required String filename,
    String fieldName = 'avatar',
    bool withAuth = false,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    if (withAuth) {
      final token = Hive.box('authBox').get('token') as String?;
      if (token != null) {
        req.headers['Authorization'] = 'Bearer $token';
      }
    }

    req.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
    );

    final streamed = await _withTimeout(req.send());
    final res = await _withTimeout(http.Response.fromStream(streamed));
    final data = (() {
      if (res.body.isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // If backend returns HTML/text for some error (e.g. default Express 404/500),
        // jsonDecode() will throw. We still want to surface the response body.
        return <String, dynamic>{'error': res.body};
      }
    })();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }
    throw ApiException(
      res.statusCode,
      data['error']?.toString() ?? 'Request failed',
    );
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
