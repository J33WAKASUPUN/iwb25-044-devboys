import 'dart:developer' as developer;
import '../models/task.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class TaskService {
  final ApiService _api = ApiService();

  Future<List<Task>> getTasks({
    String? status,
    String? priority,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      developer.log(
          '🔍 TaskService.getTasks called with filters: status=$status, priority=$priority, page=$page, pageSize=$pageSize');

      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (priority != null) queryParams['priority'] = priority;

      developer.log('📡 Making API call to: ${AppConfig.tasksEndpoint}');
      developer.log('📊 Query params: $queryParams');

      final response = await _api.get(
        AppConfig.tasksEndpoint,
        queryParams: queryParams,
      );

      developer.log('📥 Raw API Response: ${response.data}');
      developer.log('📋 Response status code: ${response.statusCode}');

      if (response.data == null) {
        developer.log('❌ Response data is null');
        return [];
      }

      // Check if response is successful - handle both success formats
      bool isSuccess = false;
      if (response.data is Map) {
        isSuccess = response.data['success'] == true ||
            (response.data['error'] != true && response.statusCode == 200);
      }

      if (isSuccess) {
        developer.log('✅ API call successful');

        final responseData = response.data['data'];
        developer.log('📦 Response data structure: $responseData');

        if (responseData is Map && responseData['tasks'] is List) {
          final List<dynamic> tasksData = responseData['tasks'];
          developer.log('📝 Found ${tasksData.length} tasks in response');

          final tasks = tasksData.map((json) {
            developer.log('🔄 Converting task JSON: $json');
            return Task.fromJson(json);
          }).toList();

          developer.log('✅ Successfully converted ${tasks.length} tasks');
          return tasks;
        } else {
          developer.log('⚠️ Unexpected data structure in response');
          return [];
        }
      } else {
        final errorMessage = response.data is Map
            ? (response.data['message'] ?? 'Unknown error')
            : 'Unknown error';
        developer.log('❌ API call failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      developer.log('💥 Error in TaskService.getTasks: $e');
      developer.log('🔍 Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<Task> createTask(CreateTaskRequest request) async {
    try {
      developer.log('🆕 TaskService.createTask called');
      developer.log('📝 Task data: ${request.toJson()}');

      final response = await _api.post(
        AppConfig.tasksEndpoint,
        data: request.toJson(),
      );

      developer.log('📥 Create task response: ${response.data}');
      developer.log('📋 Response status: ${response.statusCode}');

      if (response.data == null) {
        developer.log('❌ Create task response data is null');
        throw Exception('No response data received');
      }

      // Handle both success and error response formats
      if (response.data is Map) {
        if (response.data['error'] == true) {
          final errorMessage =
              response.data['message'] ?? 'Failed to create task';
          developer.log('❌ Failed to create task: $errorMessage');
          throw Exception(errorMessage);
        }

        if (response.data['success'] == true || response.statusCode == 201) {
          developer.log('✅ Task created successfully');
          final taskData = response.data['data'];
          developer.log('📦 Task data from API: $taskData');

          final task = Task.fromJson(taskData);
          developer.log('✅ Task object created: ${task.toJson()}');
          return task;
        }
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      developer.log('💥 Error in TaskService.createTask: $e');
      rethrow;
    }
  }

  Future<Task> getTask(String id) async {
    try {
      developer.log('🔍 TaskService.getTask called with ID: $id');

      final response = await _api.get('${AppConfig.tasksEndpoint}/$id');
      developer.log('📥 Get task response: ${response.data}');

      if (response.data is Map) {
        if (response.data['error'] == true) {
          throw Exception(response.data['message'] ?? 'Failed to fetch task');
        }

        if (response.data['success'] == true || response.statusCode == 200) {
          return Task.fromJson(response.data['data']);
        }
      }

      throw Exception('Failed to fetch task');
    } catch (e) {
      developer.log('💥 Error fetching task: $e');
      rethrow;
    }
  }

  Future<Task> updateTask(String id, UpdateTaskRequest request) async {
    try {
      developer.log('🔄 TaskService.updateTask called with ID: $id');
      developer.log('📝 Update data: ${request.toJson()}');

      final response = await _api.put(
        '${AppConfig.tasksEndpoint}/$id',
        data: request.toJson(),
      );

      developer.log('📥 Update task response: ${response.data}');

      if (response.data is Map) {
        if (response.data['error'] == true) {
          throw Exception(response.data['message'] ?? 'Failed to update task');
        }

        if (response.data['success'] == true || response.statusCode == 200) {
          return Task.fromJson(response.data['data']);
        }
      }

      throw Exception('Failed to update task');
    } catch (e) {
      developer.log('💥 Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      developer.log('🗑️ TaskService.deleteTask called with ID: $id');

      final response = await _api.delete('${AppConfig.tasksEndpoint}/$id');
      developer.log('📥 Delete task response: ${response.data}');

      if (response.data is Map && response.data['error'] == true) {
        throw Exception(response.data['message'] ?? 'Failed to delete task');
      }
    } catch (e) {
      developer.log('💥 Error deleting task: $e');
      rethrow;
    }
  }

  Future<Task> updateTaskStatus(String id, TaskStatus status) async {
    try {
      developer.log(
          '🔄 TaskService.updateTaskStatus called with ID: $id, status: $status');

      final request = UpdateTaskRequest(status: status);
      return await updateTask(id, request);
    } catch (e) {
      developer.log('💥 Error updating task status: $e');
      rethrow;
    }
  }

  Future<List<Task>> searchTasks(
    String query, {
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      developer.log('🔍 TaskService.searchTasks called with query: $query');

      final response = await _api.get(
        '${AppConfig.tasksEndpoint}/search',
        queryParams: {
          'q': query,
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        },
      );

      developer.log('📥 Search tasks response: ${response.data}');

      if (response.data is Map) {
        if (response.data['error'] == true) {
          throw Exception(response.data['message'] ?? 'Failed to search tasks');
        }

        if (response.data['success'] == true) {
          final List<dynamic> tasksData = response.data['data']['tasks'];
          return tasksData.map((json) => Task.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      developer.log('💥 Error searching tasks: $e');
      rethrow;
    }
  }
}
