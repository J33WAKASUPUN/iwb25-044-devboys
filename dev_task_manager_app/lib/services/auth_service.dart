// filepath: lib/services/auth_service.dart
import 'dart:developer' as developer;
import '../models/user.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<User> login(String email, String password) async {
    try {
      developer.log('🔐 Attempting login for: $email');

      final response = await _api.post(
        AppConfig.loginEndpoint,
        data: LoginRequest(email: email, password: password).toJson(),
      );

      developer.log('📥 Login response: ${response.data}');
      developer.log('📋 Login status code: ${response.statusCode}');

      // Handle both new error format and success format
      if (response.data is Map) {
        // Check for error response
        if (response.data['error'] == true) {
          final errorMessage = response.data['message'] ?? 'Login failed';
          developer.log('❌ Login failed: $errorMessage');
          throw Exception(errorMessage);
        }

        // Check for success response
        if (response.data['success'] == true ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final data = response.data['data'];
          if (data != null) {
            final token = data['token'];
            final user = User.fromJson(data['user']);

            await _storage.saveToken(token);
            await _storage.saveUser(user);

            developer.log('✅ Login successful, user saved: ${user.name}');
            return user;
          }
        }
      }

      throw Exception('Invalid response format');
    } catch (e) {
      developer.log('💥 Login error: $e');
      rethrow;
    }
  }

  Future<User> register(String name, String email, String password) async {
    try {
      developer.log('🔐 Attempting registration for: $email');

      final response = await _api.post(
        AppConfig.registerEndpoint,
        data: RegisterRequest(name: name, email: email, password: password)
            .toJson(),
      );

      developer.log('📥 Register response: ${response.data}');
      developer.log('📋 Register status code: ${response.statusCode}');

      // Handle both new error format and success format
      if (response.data is Map) {
        // Check for error response
        if (response.data['error'] == true) {
          final errorMessage =
              response.data['message'] ?? 'Registration failed';
          developer.log('❌ Registration failed: $errorMessage');
          throw Exception(errorMessage);
        }

        // Check for success response
        if (response.data['success'] == true ||
            response.statusCode == 200 ||
            response.statusCode == 201) {
          final data = response.data['data'];
          if (data != null) {
            final token = data['token'];
            final user = User.fromJson(data['user']);

            await _storage.saveToken(token);
            await _storage.saveUser(user);

            developer
                .log('✅ Registration successful, user saved: ${user.name}');
            return user;
          }
        }
      }

      throw Exception('Invalid response format');
    } catch (e) {
      developer.log('💥 Registration error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<User?> getCurrentUser() async {
    return await _storage.getUser();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }
}
