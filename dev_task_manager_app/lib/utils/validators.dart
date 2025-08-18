class Validators {
  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  /// Validate password strength
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  /// Validate task title
  static String? validateTaskTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Task title is required';
    }

    if (value.trim().length < 3) {
      return 'Task title must be at least 3 characters';
    }

    if (value.trim().length > 100) {
      return 'Task title must be less than 100 characters';
    }

    return null;
  }

  /// Validate task description
  static String? validateTaskDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Task description is required';
    }

    if (value.trim().length < 10) {
      return 'Task description must be at least 10 characters';
    }

    if (value.trim().length > 500) {
      return 'Task description must be less than 500 characters';
    }

    return null;
  }

  /// Validate name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }

    return null;
  }

  /// Validate due date
  static String? validateDueDate(DateTime? date) {
    if (date == null) {
      return 'Due date is required';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);

    if (selectedDate.isBefore(today)) {
      return 'Due date cannot be in the past';
    }

    return null;
  }
}
