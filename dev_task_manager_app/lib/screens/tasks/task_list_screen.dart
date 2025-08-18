import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../utils/constants.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/task_card.dart';
import '../../models/task.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/task/task_event.dart';
import '../../blocs/task/task_state.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Load tasks when screen initializes
    context.read<TaskBloc>().add(LoadTasks());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tasks',
          style: AppConstants.headerStyle,
        ),
        backgroundColor: AppConstants.whiteColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: AppConstants.secondaryColor,
            ),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: AppConstants.secondaryColor,
            ),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppConstants.primaryColor,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: AppConstants.secondaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'To Do'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
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
          } else if (state is TaskError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppConstants.errorColor,
              ),
            );
          }
        },
        child: BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) {
              return const LoadingWidget(message: 'Loading tasks...');
            } else if (state is TaskError) {
              return ErrorDisplayWidget(
                message: state.message,
                onRetry: () => context.read<TaskBloc>().add(LoadTasks()),
              );
            } else if (state is TaskLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(state.filteredTasks),
                  _buildTaskList(
                      _getTasksByStatus(state.filteredTasks, TaskStatus.TODO)),
                  _buildTaskList(_getTasksByStatus(
                      state.filteredTasks, TaskStatus.IN_PROGRESS)),
                  _buildTaskList(_getTasksByStatus(
                      state.filteredTasks, TaskStatus.COMPLETED)),
                ],
              );
            }

            // Initial state - show empty
            return TabBarView(
              controller: _tabController,
              children: [
                _buildEmptyState(),
                _buildEmptyState(),
                _buildEmptyState(),
                _buildEmptyState(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tasks/create'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: AppConstants.whiteColor,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TaskBloc>().add(LoadTasks());
      },
      color: AppConstants.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskCard(
            task: task,
            onTap: () {
              print(
                  'Navigating to task detail with ID: ${task.id}'); // Debug print
              context.go('/tasks/${task.id}');
            },
            onEdit: () {
              print(
                  'Navigating to task edit with ID: ${task.id}'); // Debug print
              context.go('/tasks/${task.id}/edit');
            },
            onDelete: () => _showDeleteDialog(task),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No tasks found',
              style: AppConstants.subHeaderStyle.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Create your first task to get started',
              style: AppConstants.bodyStyle.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.largePadding),
            ElevatedButton.icon(
              onPressed: () => context.go('/tasks/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: AppConstants.whiteColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.largePadding,
                  vertical: AppConstants.defaultPadding,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Task> _getTasksByStatus(List<Task> tasks, TaskStatus status) {
    return tasks.where((task) => task.status == status).toList();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter search query...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TaskBloc>().add(SearchTasks(query: _searchQuery));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    TaskStatus? selectedStatus;
    TaskPriority? selectedPriority;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TaskStatus?>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem<TaskStatus?>(
                    value: null,
                    child: Text('All Statuses'),
                  ),
                  ...TaskStatus.values.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.name.replaceAll('_', ' ')),
                      )),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedStatus = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority?>(
                value: selectedPriority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  const DropdownMenuItem<TaskPriority?>(
                    value: null,
                    child: Text('All Priorities'),
                  ),
                  ...TaskPriority.values.map((priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.name),
                      )),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedPriority = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<TaskBloc>().add(LoadTasks()); // Clear filters
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<TaskBloc>().add(FilterTasks(
                      status: selectedStatus,
                      priority: selectedPriority,
                    ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TaskBloc>().add(DeleteTask(taskId: task.id));
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
}
