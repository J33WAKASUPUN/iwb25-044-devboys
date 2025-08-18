import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../utils/constants.dart';
import '../../models/task.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/task/task_event.dart';
import '../../blocs/task/task_state.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _task;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get task from TaskBloc
      final taskBloc = context.read<TaskBloc>();
      final task = taskBloc.getTaskById(widget.taskId);

      if (task != null) {
        setState(() {
          _task = task;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Task not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          _task?.title ?? 'Task Details',
          style: AppConstants.headerStyle,
        ),
        backgroundColor: AppConstants.whiteColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/tasks');
            }
          },
        ),
        actions: [
          if (_task != null) ...[
            IconButton(
              icon: Icon(Icons.edit, color: AppConstants.primaryColor),
              onPressed: () => context.go('/tasks/${widget.taskId}/edit'),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: AppConstants.errorColor),
              onPressed: _showDeleteDialog,
            ),
          ],
        ],
      ),
      body: BlocListener<TaskBloc, TaskState>(
        listener: (context, state) {
          if (state is TaskOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppConstants.primaryColor,
              ),
            );
            // Reload task data after successful operation
            _loadTask();
          } else if (state is TaskError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppConstants.errorColor,
              ),
            );
          }
        },
        child: _isLoading
            ? const LoadingWidget(message: 'Loading task details...')
            : _error != null
                ? ErrorDisplayWidget(
                    message: _error!,
                    onRetry: _loadTask,
                  )
                : _buildTaskDetails(),
      ),
    );
  }

  Widget _buildTaskDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: AppConstants.defaultPadding),
          _buildDetailsCard(),
          const SizedBox(height: AppConstants.defaultPadding),
          _buildStatusCard(),
          const SizedBox(height: AppConstants.defaultPadding),
          _buildMetadataCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _task!.title,
                    style: AppConstants.headerStyle.copyWith(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPriorityBadge(),
              ],
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              _task!.description,
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Details',
              style: AppConstants.subHeaderStyle,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildDetailRow('Due Date', _task!.dueDate, Icons.calendar_today),
            _buildDetailRow(
              'Created By',
              _task!.createdBy.name,
              Icons.person,
            ),
            if (_task!.assignedTo != null)
              _buildDetailRow(
                'Assigned To',
                _task!.assignedTo!.name,
                Icons.assignment_ind,
              ),
            _buildDetailRow(
              'Created',
              _formatDate(_task!.createdAt),
              Icons.access_time,
            ),
            _buildDetailRow(
              'Last Updated',
              _formatDate(_task!.updatedAt),
              Icons.update,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: AppConstants.subHeaderStyle,
                ),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showStatusUpdateDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Update Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: AppConstants.whiteColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: AppConstants.subHeaderStyle,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            _buildDetailRow(
              'Task ID',
              _task!.id.substring(0, 8),
              Icons.fingerprint,
            ),
            _buildDetailRow(
              'Overdue',
              _task!.isOverdue ? 'Yes' : 'No',
              _task!.isOverdue ? Icons.warning : Icons.check_circle,
              _task!.isOverdue
                  ? AppConstants.errorColor
                  : AppConstants.successColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      [Color? textColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: textColor ?? Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: AppConstants.bodyStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            AppConstants.statusColors[_task!.status.name]?.withOpacity(0.1) ??
                Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _task!.status.name.replaceAll('_', ' '),
        style: TextStyle(
          color: AppConstants.statusColors[_task!.status.name] ?? Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.smallPadding,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppConstants.priorityColors[_task!.priority.name]
                ?.withOpacity(0.1) ??
            Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _task!.priority.name,
        style: TextStyle(
          color:
              AppConstants.priorityColors[_task!.priority.name] ?? Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  void _showStatusUpdateDialog() {
    TaskStatus selectedStatus = _task!.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: TaskStatus.values.map((status) {
              return RadioListTile<TaskStatus>(
                title: Text(status.name.replaceAll('_', ' ')),
                value: status,
                groupValue: selectedStatus,
                onChanged: (value) {
                  setDialogState(() {
                    selectedStatus = value!;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateTaskStatus(selectedStatus);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTaskStatus(TaskStatus newStatus) async {
    try {
      // Use TaskBloc to update status
      final taskBloc = context.read<TaskBloc>();
      taskBloc.add(UpdateTaskStatus(
        taskId: widget.taskId,
        status: newStatus,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${_task!.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTask();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask() async {
    try {
      // Use TaskBloc to delete task
      final taskBloc = context.read<TaskBloc>();
      taskBloc.add(DeleteTask(taskId: widget.taskId));

      // Navigate back to tasks list
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/tasks');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting task: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }
}
