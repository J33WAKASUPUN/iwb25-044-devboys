import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;
import '../../models/task.dart';
import '../../services/task_service.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];

  TaskBloc() : super(TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<CreateTask>(_onCreateTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<SearchTasks>(_onSearchTasks);
    on<FilterTasks>(_onFilterTasks);

    developer.log('🎯 TaskBloc initialized');
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    developer.log('📋 TaskBloc.LoadTasks event received');
    emit(TaskLoading());

    try {
      developer.log('📡 Calling TaskService.getTasks()');
      final tasks = await _taskService.getTasks();

      developer.log('✅ Received ${tasks.length} tasks from service');
      _tasks = tasks;

      for (int i = 0; i < tasks.length; i++) {
        developer.log('📄 Task $i: ${tasks[i].title} - ${tasks[i].status}');
      }

      emit(TaskLoaded(
        tasks: List.from(_tasks),
        filteredTasks: List.from(_tasks),
      ));

      developer.log('✅ TaskLoaded state emitted with ${_tasks.length} tasks');
    } catch (e) {
      developer.log('💥 Error loading tasks: $e');
      emit(TaskError(message: 'Failed to load tasks: $e'));
    }
  }

  Future<void> _onCreateTask(CreateTask event, Emitter<TaskState> emit) async {
    developer.log('🆕 TaskBloc.CreateTask event received');
    developer.log('📝 Creating task: ${event.title}');

    try {
      final createRequest = CreateTaskRequest(
        title: event.title,
        description: event.description,
        dueDate: event.dueDate.toIso8601String().split('T')[0],
        priority: event.priority,
      );

      developer.log('📤 Sending create request: ${createRequest.toJson()}');

      final newTask = await _taskService.createTask(createRequest);

      developer.log('✅ Task created successfully: ${newTask.id}');
      _tasks.add(newTask);

      developer.log('📋 Local tasks list now has ${_tasks.length} tasks');

      // Emit success message first
      emit(TaskOperationSuccess(message: 'Task created successfully!'));

      // Then emit updated task list
      emit(TaskLoaded(
        tasks: List.from(_tasks),
        filteredTasks: List.from(_tasks),
      ));

      developer.log('✅ TaskLoaded state emitted after creation');
    } catch (e) {
      developer.log('💥 Error creating task: $e');
      emit(TaskError(message: 'Failed to create task: $e'));
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    developer
        .log('🔄 TaskBloc.UpdateTask event received for task: ${event.taskId}');

    try {
      final updateRequest = UpdateTaskRequest(
        title: event.title,
        description: event.description,
        status: event.status,
        priority: event.priority,
        dueDate: event.dueDate?.toIso8601String().split('T')[0],
      );

      developer.log('📤 Sending update request: ${updateRequest.toJson()}');

      final updatedTask =
          await _taskService.updateTask(event.taskId, updateRequest);

      developer.log('✅ Task updated successfully: ${updatedTask.id}');

      // Update local list
      final taskIndex = _tasks.indexWhere((task) => task.id == event.taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex] = updatedTask;
        developer.log('📋 Updated task in local list at index $taskIndex');
      } else {
        developer.log('⚠️ Task not found in local list, adding it');
        _tasks.add(updatedTask);
      }

      emit(TaskOperationSuccess(message: 'Task updated successfully!'));
      emit(TaskLoaded(
        tasks: List.from(_tasks),
        filteredTasks: List.from(_tasks),
      ));

      developer.log('✅ TaskLoaded state emitted after update');
    } catch (e) {
      developer.log('💥 Error updating task: $e');
      emit(TaskError(message: 'Failed to update task: $e'));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    developer.log(
        '🗑️ TaskBloc.DeleteTask event received for task: ${event.taskId}');

    try {
      await _taskService.deleteTask(event.taskId);

      developer.log('✅ Task deleted successfully from API');

      // Remove from local list
      final removedCount = _tasks.length;
      _tasks.removeWhere((task) => task.id == event.taskId);

      developer.log(
          '📋 Removed from local list. Tasks count: $removedCount -> ${_tasks.length}');

      emit(TaskOperationSuccess(message: 'Task deleted successfully!'));
      emit(TaskLoaded(
        tasks: List.from(_tasks),
        filteredTasks: List.from(_tasks),
      ));

      developer.log('✅ TaskLoaded state emitted after deletion');
    } catch (e) {
      developer.log('💥 Error deleting task: $e');
      emit(TaskError(message: 'Failed to delete task: $e'));
    }
  }

  Future<void> _onUpdateTaskStatus(
      UpdateTaskStatus event, Emitter<TaskState> emit) async {
    developer.log(
        '🔄 TaskBloc.UpdateTaskStatus event received for task: ${event.taskId}, status: ${event.status}');

    try {
      final updatedTask =
          await _taskService.updateTaskStatus(event.taskId, event.status);

      developer.log('✅ Task status updated successfully');

      // Update local list
      final taskIndex = _tasks.indexWhere((task) => task.id == event.taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex] = updatedTask;
        developer.log('📋 Updated task status in local list');
      }

      emit(TaskOperationSuccess(message: 'Task status updated successfully!'));
      emit(TaskLoaded(
        tasks: List.from(_tasks),
        filteredTasks: List.from(_tasks),
      ));
    } catch (e) {
      developer.log('💥 Error updating task status: $e');
      emit(TaskError(message: 'Failed to update task status: $e'));
    }
  }

  Future<void> _onSearchTasks(
      SearchTasks event, Emitter<TaskState> emit) async {
    developer.log(
        '🔍 TaskBloc.SearchTasks event received with query: ${event.query}');

    if (state is TaskLoaded) {
      final currentState = state as TaskLoaded;

      try {
        List<Task> filteredTasks;
        if (event.query.isNotEmpty) {
          filteredTasks = await _taskService.searchTasks(event.query);
          developer.log('📋 Search returned ${filteredTasks.length} tasks');
        } else {
          filteredTasks = List.from(_tasks);
          developer
              .log('📋 Empty query, showing all ${filteredTasks.length} tasks');
        }

        emit(currentState.copyWith(
          filteredTasks: filteredTasks,
          searchQuery: event.query.isEmpty ? null : event.query,
        ));
      } catch (e) {
        developer.log('💥 Error searching tasks: $e');
        emit(TaskError(message: 'Failed to search tasks: $e'));
      }
    }
  }

  Future<void> _onFilterTasks(
      FilterTasks event, Emitter<TaskState> emit) async {
    developer.log('🔍 TaskBloc.FilterTasks event received');

    if (state is TaskLoaded) {
      final currentState = state as TaskLoaded;

      try {
        final filteredTasks = await _taskService.getTasks(
          status: event.status?.name,
          priority: event.priority?.name,
        );

        developer.log('📋 Filter returned ${filteredTasks.length} tasks');

        emit(currentState.copyWith(
          filteredTasks: filteredTasks,
          statusFilter: event.status,
          priorityFilter: event.priority,
        ));
      } catch (e) {
        developer.log('⚠️ API filter failed, falling back to local filtering');

        List<Task> filteredTasks = List.from(_tasks);

        if (event.status != null) {
          filteredTasks = filteredTasks
              .where((task) => task.status == event.status)
              .toList();
        }

        if (event.priority != null) {
          filteredTasks = filteredTasks
              .where((task) => task.priority == event.priority)
              .toList();
        }

        developer.log('📋 Local filter returned ${filteredTasks.length} tasks');

        emit(currentState.copyWith(
          filteredTasks: filteredTasks,
          statusFilter: event.status,
          priorityFilter: event.priority,
        ));
      }
    }
  }

  Task? getTaskById(String id) {
    developer.log('🔍 TaskBloc.getTaskById called with ID: $id');

    try {
      final task = _tasks.firstWhere((task) => task.id == id);
      developer.log('✅ Found task: ${task.title}');
      return task;
    } catch (e) {
      developer.log('❌ Task not found with ID: $id');
      return null;
    }
  }

  List<Task> getAllTasks() {
    developer.log(
        '📋 TaskBloc.getAllTasks called, returning ${_tasks.length} tasks');
    return List.from(_tasks);
  }

  List<Task> getTasksByStatus(TaskStatus status) {
    final filtered = _tasks.where((task) => task.status == status).toList();
    developer.log(
        '📋 TaskBloc.getTasksByStatus($status) returning ${filtered.length} tasks');
    return filtered;
  }

  Future<void> refreshTasks() async {
    developer.log('🔄 TaskBloc.refreshTasks called');
    add(LoadTasks());
  }
}
