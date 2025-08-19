import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../models/task.dart';
import '../../blocs/task/task_bloc.dart';
import '../../blocs/task/task_event.dart';
import '../../blocs/task/task_state.dart';
import '../../widgets/loading_widget.dart';

class TaskFormScreen extends StatefulWidget {
  final String? taskId;

  const TaskFormScreen({super.key, this.taskId});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TaskStatus _selectedStatus = TaskStatus.TODO;
  TaskPriority _selectedPriority = TaskPriority.MEDIUM;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  bool _isLoading = false;
  Task? _existingTask;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    if (widget.taskId != null) {
      _loadTask();
    }
    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    setState(() => _isLoading = true);

    try {
      final taskBloc = context.read<TaskBloc>();
      final task = taskBloc.getTaskById(widget.taskId!);

      if (task != null) {
        _fillForm(task);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: AppConstants.whiteColor),
                const SizedBox(width: 8),
                Text(
                  'Error loading task: $e',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _fillForm(Task task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _selectedStatus = task.status;
    _selectedPriority = task.priority;
    _selectedDate = DateTime.parse(task.dueDate);
    _existingTask = task;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskId != null;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppConstants.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: BlocListener<TaskBloc, TaskState>(
            listener: (context, state) {
              if (state is TaskOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppConstants.whiteColor),
                        const SizedBox(width: 8),
                        Text(
                          state.message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    backgroundColor: AppConstants.successColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/tasks');
                }
              } else if (state is TaskError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppConstants.whiteColor),
                        const SizedBox(width: 8),
                        Text(
                          state.message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    backgroundColor: AppConstants.errorColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: _isLoading
                ? _buildLoadingState()
                : _buildFormContent(isEditing),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppConstants.borderColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppConstants.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading task...',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isEditing) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBar(isEditing),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTaskInfoSection(),
                      const SizedBox(height: 20),
                      _buildTaskDetailsSection(isEditing),
                      const SizedBox(height: 32),
                      _buildActionButtons(isEditing),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isEditing) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppConstants.borderColor.withOpacity(0.3),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/tasks');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: AppConstants.textColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Task' : 'Create Task',
                  style: AppConstants.headerStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isEditing ? 'Update task details' : 'Add new development task',
                  style: AppConstants.bodyStyle.copyWith(
                    color: AppConstants.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isEditing)
            Container(
              decoration: BoxDecoration(
                color: AppConstants.surfaceColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConstants.borderColor.withOpacity(0.3),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showModernDeleteDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppConstants.errorColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppConstants.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Task Information',
                style: AppConstants.subHeaderStyle.copyWith(
                  color: AppConstants.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildModernTextField(
            controller: _titleController,
            label: 'Task Title',
            hint: 'Enter a descriptive task title',
            icon: Icons.title,
            validator: Validators.validateTaskTitle,
          ),
          const SizedBox(height: 20),
          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe what needs to be done',
            icon: Icons.description_outlined,
            maxLines: 4,
            validator: Validators.validateTaskDescription,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetailsSection(bool isEditing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Task Details',
                style: AppConstants.subHeaderStyle.copyWith(
                  color: AppConstants.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (isEditing) ...[
            _buildModernDropdown<TaskStatus>(
              label: 'Status',
              value: _selectedStatus,
              icon: Icons.flag_outlined,
              items: TaskStatus.values.map((status) {
                Color statusColor = AppConstants.statusColors[status.name] ?? AppConstants.textSecondaryColor;
                return DropdownMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.name.replaceAll('_', ' '),
                        style: TextStyle(color: AppConstants.textColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            const SizedBox(height: 20),
          ],

          _buildModernDropdown<TaskPriority>(
            label: 'Priority',
            value: _selectedPriority,
            icon: Icons.priority_high_outlined,
            items: TaskPriority.values.map((priority) {
              Color priorityColor = AppConstants.priorityColors[priority.name] ?? AppConstants.textSecondaryColor;
              return DropdownMenuItem(
                value: priority,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      priority.name,
                      style: TextStyle(color: AppConstants.textColor),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPriority = value!;
              });
            },
          ),

          const SizedBox(height: 20),

          _buildDatePicker(),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppConstants.textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppConstants.textSecondaryColor),
            prefixIcon: Icon(
              icon,
              color: AppConstants.textSecondaryColor,
              size: 20,
            ),
            filled: true,
            fillColor: AppConstants.cardColor.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppConstants.borderColor.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.errorColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildModernDropdown<T>({
    required String label,
    required T value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: AppConstants.textSecondaryColor,
              size: 20,
            ),
            filled: true,
            fillColor: AppConstants.cardColor.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppConstants.borderColor.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppConstants.primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          dropdownColor: AppConstants.surfaceColor,
          style: TextStyle(color: AppConstants.textColor),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppConstants.cardColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.borderColor.withOpacity(0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppConstants.textSecondaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: AppConstants.bodyStyle.copyWith(
                          color: AppConstants.textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppConstants.textSecondaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        final isProcessing = state is TaskLoading;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : _saveTask,
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(isEditing ? Icons.save_outlined : Icons.add_rounded),
                label: Text(
                  isEditing ? 'Update Task' : 'Create Task',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ).decorated(
                decoration: BoxDecoration(
                  gradient: isProcessing ? null : const LinearGradient(
                    colors: AppConstants.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : _handleCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text(
                  'Cancel',
                                    style: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppConstants.textSecondaryColor),
                  foregroundColor: AppConstants.textSecondaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleCancel() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/tasks');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: AppConstants.surfaceColor,
              onSurface: AppConstants.textColor,
            ), dialogTheme: DialogThemeData(backgroundColor: AppConstants.surfaceColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final taskBloc = context.read<TaskBloc>();

    if (widget.taskId != null) {
      // Update existing task
      taskBloc.add(UpdateTask(
        taskId: widget.taskId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        status: _selectedStatus,
        priority: _selectedPriority,
        dueDate: _selectedDate,
      ));
    } else {
      // Create new task
      taskBloc.add(CreateTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        dueDate: _selectedDate,
      ));
    }
  }

  void _showModernDeleteDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                color: AppConstants.errorColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Delete Task',
              style: AppConstants.subHeaderStyle.copyWith(
                color: AppConstants.textColor,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete this task? This action cannot be undone.',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppConstants.textSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteTask();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTask() {
    if (widget.taskId != null) {
      final taskBloc = context.read<TaskBloc>();
      taskBloc.add(DeleteTask(taskId: widget.taskId!));
    }
  }
}

// Extension for decorated widgets
extension DecoratedWidget on Widget {
  Widget decorated({required Decoration decoration}) {
    return DecoratedBox(
      decoration: decoration,
      child: this,
    );
  }
}