class AppConfig {
  // Update this to your actual IP address
  static const String baseUrl = 'http://192.168.1.159:9090';

  // Keep the rest unchanged...
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String profileEndpoint = '/profile';
  static const String tasksEndpoint = '/tasks';
  static const String adminUsersEndpoint = '/admin/users';
  static const String adminTasksEndpoint = '/admin/tasks';
  static const String adminStatsEndpoint = '/admin/stats/tasks';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
