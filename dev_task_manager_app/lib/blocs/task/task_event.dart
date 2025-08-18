import 'package:equatable/equatable.dart';
import '../../models/task.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {}

class CreateTask extends TaskEvent {
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime dueDate;

  const CreateTask({
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
  });

  @override
  List<Object> get props => [title, description, priority, dueDate];
}

class UpdateTask extends TaskEvent {
  final String taskId;
  final String? title;
  final String? description;
  final TaskStatus? status;
  final TaskPriority? priority;
  final DateTime? dueDate;

  const UpdateTask({
    required this.taskId,
    this.title,
    this.description,
    this.status,
    this.priority,
    this.dueDate,
  });

  @override
  List<Object?> get props => [taskId, title, description, status, priority, dueDate];
}

class DeleteTask extends TaskEvent {
  final String taskId;

  const DeleteTask({required this.taskId});

  @override
  List<Object> get props => [taskId];
}

class UpdateTaskStatus extends TaskEvent {
  final String taskId;
  final TaskStatus status;

  const UpdateTaskStatus({
    required this.taskId,
    required this.status,
  });

  @override
  List<Object> get props => [taskId, status];
}

class SearchTasks extends TaskEvent {
  final String query;

  const SearchTasks({required this.query});

  @override
  List<Object> get props => [query];
}

class FilterTasks extends TaskEvent {
  final TaskStatus? status;
  final TaskPriority? priority;

  const FilterTasks({this.status, this.priority});

  @override
  List<Object?> get props => [status, priority];
}