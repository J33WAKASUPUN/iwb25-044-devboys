import 'package:equatable/equatable.dart';
import '../../models/task.dart';

abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoading extends TaskState {}

class TaskLoaded extends TaskState {
  final List<Task> tasks;
  final List<Task> filteredTasks;
  final TaskStatus? statusFilter;
  final TaskPriority? priorityFilter;
  final String? searchQuery;

  const TaskLoaded({
    required this.tasks,
    required this.filteredTasks,
    this.statusFilter,
    this.priorityFilter,
    this.searchQuery,
  });

  @override
  List<Object?> get props =>
      [tasks, filteredTasks, statusFilter, priorityFilter, searchQuery];

  TaskLoaded copyWith({
    List<Task>? tasks,
    List<Task>? filteredTasks,
    TaskStatus? statusFilter,
    TaskPriority? priorityFilter,
    String? searchQuery,
    bool clearFilters = false,
  }) {
    return TaskLoaded(
      tasks: tasks ?? this.tasks,
      filteredTasks: filteredTasks ?? this.filteredTasks,
      statusFilter: clearFilters ? null : (statusFilter ?? this.statusFilter),
      priorityFilter:
          clearFilters ? null : (priorityFilter ?? this.priorityFilter),
      searchQuery: clearFilters ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

class TaskOperationSuccess extends TaskState {
  final String message;

  const TaskOperationSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

class TaskError extends TaskState {
  final String message;

  const TaskError({required this.message});

  @override
  List<Object> get props => [message];
}
