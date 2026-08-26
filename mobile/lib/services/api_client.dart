import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) print('[API REQ] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) print('[API RES] ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          print('[API ERR] type=${error.type} msg=${error.message} status=${error.response?.statusCode} uri=${error.requestOptions.uri}');
          if (error.error != null) print('[API ERR] detail=${error.error}');
          if (error.error is Exception) {
            final e = error.error as Exception;
            if (e is TlsException) {
              print('[API ERR] SSL/TLS error: ${e.message}');
            } else if (e is SocketException) {
              print('[API ERR] Socket error: ${e.message}');
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  Future<void> setToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }
}
