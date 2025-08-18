import 'dart:developer' as developer;
import '../config/app_config.dart';
import 'api_service.dart';

class TaskStatistics {
  final int total;
  final Map<String, int> byStatus;
  final Map<String, int> byPriority;
  final int overdue;

  TaskStatistics({
    required this.total,
    required this.byStatus,
    required this.byPriority,
    required this.overdue,
  });

  factory TaskStatistics.fromJson(Map<String, dynamic> json) {
    return TaskStatistics(
      total: json['total'] ?? 0,
      byStatus: Map<String, int>.from(json['byStatus'] ?? {}),
      byPriority: Map<String, int>.from(json['byPriority'] ?? {}),
      overdue: json['overdue'] ?? 0,
    );
  }
}

class StatsService {
  final ApiService _api = ApiService();

  Future<TaskStatistics> getTaskStatistics() async {
    try {
      developer.log('📊 StatsService.getTaskStatistics called');

      final response = await _api.get('/stats/tasks');

      developer.log('📥 Stats response: ${response.data}');
      developer.log('📋 Response status: ${response.statusCode}');

      if (response.data == null) {
        developer.log('❌ Stats response data is null');
        throw Exception('No response data received');
      }

      // Handle both success and error response formats
      if (response.data is Map) {
        // Check for error response
        if (response.data['error'] == true) {
          final errorMessage =
              response.data['message'] ?? 'Failed to fetch statistics';
          developer.log('❌ Failed to fetch stats: $errorMessage');
          throw Exception(errorMessage);
        }

        // Check for success response
        if (response.data['success'] == true || response.statusCode == 200) {
          final statsData = response.data['data'];
          developer.log('📦 Stats data from API: $statsData');

          final stats = TaskStatistics.fromJson(statsData);
          developer.log(
              '✅ Stats object created: Total: ${stats.total}, Overdue: ${stats.overdue}');
          return stats;
        }
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      developer.log('💥 Error in StatsService.getTaskStatistics: $e');
      rethrow;
    }
  }
}
