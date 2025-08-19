// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: $enumDecode(_$TaskStatusEnumMap, json['status']),
      dueDate: json['dueDate'] as String,
      priority: $enumDecode(_$TaskPriorityEnumMap, json['priority']),
      createdBy: User.fromJson(json['createdBy'] as Map<String, dynamic>),
      assignedTo: json['assignedTo'] == null
          ? null
          : User.fromJson(json['assignedTo'] as Map<String, dynamic>),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      isOverdue: json['isOverdue'] as bool,
    );

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'dueDate': instance.dueDate,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'createdBy': instance.createdBy,
      'assignedTo': instance.assignedTo,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'isOverdue': instance.isOverdue,
    };

const _$TaskStatusEnumMap = {
  TaskStatus.TODO: 'TODO',
  TaskStatus.IN_PROGRESS: 'IN_PROGRESS',
  TaskStatus.DONE: 'DONE',
};

const _$TaskPriorityEnumMap = {
  TaskPriority.LOW: 'LOW',
  TaskPriority.MEDIUM: 'MEDIUM',
  TaskPriority.HIGH: 'HIGH',
};

CreateTaskRequest _$CreateTaskRequestFromJson(Map<String, dynamic> json) =>
    CreateTaskRequest(
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: json['dueDate'] as String,
      priority: $enumDecode(_$TaskPriorityEnumMap, json['priority']),
      assignedTo: json['assignedTo'] as String?,
    );

Map<String, dynamic> _$CreateTaskRequestToJson(CreateTaskRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'dueDate': instance.dueDate,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'assignedTo': instance.assignedTo,
    };

UpdateTaskRequest _$UpdateTaskRequestFromJson(Map<String, dynamic> json) =>
    UpdateTaskRequest(
      title: json['title'] as String?,
      description: json['description'] as String?,
      status: $enumDecodeNullable(_$TaskStatusEnumMap, json['status']),
      dueDate: json['dueDate'] as String?,
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']),
      assignedTo: json['assignedTo'] as String?,
    );

Map<String, dynamic> _$UpdateTaskRequestToJson(UpdateTaskRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'status': _$TaskStatusEnumMap[instance.status],
      'dueDate': instance.dueDate,
      'priority': _$TaskPriorityEnumMap[instance.priority],
      'assignedTo': instance.assignedTo,
    };

T $enumDecode<T>(
  Map<T, String> enumValues,
  Object? source, {
  T? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, source.toString());
    },
  ).key;
}

T? $enumDecodeNullable<T>(
  Map<T, String> enumValues,
  Object? source, {
  T? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return $enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}
