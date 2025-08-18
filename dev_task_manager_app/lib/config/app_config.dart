class AppConfig {
  static const String baseUrl = 'http://192.168.43.187:9090';

  // API Endpoints matching your Ballerina server routes
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String profileEndpoint = '/profile';
  static const String tasksEndpoint = '/tasks';
  static const String adminUsersEndpoint = '/admin/users';
  static const String adminTasksEndpoint = '/admin/tasks';
  static const String adminStatsEndpoint = '/admin/stats/tasks';

  // API timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
