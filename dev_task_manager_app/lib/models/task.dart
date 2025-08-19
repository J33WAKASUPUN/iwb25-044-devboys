import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'task.g.dart';

enum TaskStatus { TODO, IN_PROGRESS, DONE }

enum TaskPriority { LOW, MEDIUM, HIGH }

@JsonSerializable()
class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final String dueDate;
  final TaskPriority priority;
  final User createdBy;
  final User? assignedTo;
  final String createdAt;
  final String updatedAt;
  final bool isOverdue;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.priority,
    required this.createdBy,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    required this.isOverdue,
  });

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}

@JsonSerializable()
class CreateTaskRequest {
  final String title;
  final String description;
  final String dueDate;
  final TaskPriority priority;
  final String? assignedTo;

  CreateTaskRequest({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    this.assignedTo,
  });

  factory CreateTaskRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateTaskRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateTaskRequestToJson(this);
}

@JsonSerializable()
class UpdateTaskRequest {
  final String? title;
  final String? description;
  final TaskStatus? status;
  final String? dueDate;
  final TaskPriority? priority;
  final String? assignedTo;

  UpdateTaskRequest({
    this.title,
    this.description,
    this.status,
    this.dueDate,
    this.priority,
    this.assignedTo,
  });

  factory UpdateTaskRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateTaskRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateTaskRequestToJson(this);
}
