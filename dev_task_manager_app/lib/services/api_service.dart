import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final StorageService _storage = StorageService();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        developer.log('📤 API Request: ${options.method} ${options.path}');
        developer.log('📊 Request data: ${options.data}');
        developer.log('🔗 Query params: ${options.queryParameters}');

        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          developer.log('🔑 Authorization header added');
        } else {
          developer.log('⚠️ No authentication token found');
        }

        developer.log('📋 Request headers: ${options.headers}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        developer.log('📥 API Response: ${response.statusCode}');
        developer.log('📦 Response data: ${response.data}');
        handler.next(response);
      },
      onError: (error, handler) {
        developer.log('💥 API Error: ${error.message}');
        developer.log('📋 Error response: ${error.response?.data}');
        developer.log('🔍 Error type: ${error.type}');
        handler.next(error);
      },
    ));

    developer
        .log('🌐 ApiService initialized with base URL: ${AppConfig.baseUrl}');
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    developer.log('🔍 ApiService.get: $path');
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) {
    developer.log('📤 ApiService.post: $path');
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    developer.log('🔄 ApiService.put: $path');
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    developer.log('🗑️ ApiService.delete: $path');
    return _dio.delete(path);
  }
}
