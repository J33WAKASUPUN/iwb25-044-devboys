import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'config/app_config.dart';

Future<void> testApiConnection() async {
  try {
    developer.log('Testing API connection to: ${AppConfig.baseUrl}');

    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Test health endpoint
    final response = await dio.get('/health');
    developer.log('Health check response: ${response.data}');

    if (response.statusCode == 200) {
      developer.log('✅ API connection successful!');
    } else {
      developer
          .log('❌ API connection failed with status: ${response.statusCode}');
    }
  } catch (e) {
    developer.log('❌ API connection error: $e');

    if (e is DioException) {
      developer.log('DioException type: ${e.type}');
      developer.log('DioException message: ${e.message}');
      if (e.response != null) {
        developer.log('Response status: ${e.response?.statusCode}');
        developer.log('Response data: ${e.response?.data}');
      }
    }
  }
}
