// User management types
# User registration request
#
# + email - User email address
# + password - User password (min 6 characters)
# + name - User's full name
# + role - User role (optional, defaults to USER)
# + timezone - User's timezone (optional, defaults to UTC)
public type RegisterRequest record {|
    string email;
    string password;
    string name;
    string? role = (); // Added optional role field
    string? timezone = (); // Added optional timezone field
|};

# Login request
#
# + email - User email address
# + password - User password
public type LoginRequest record {|
    string email;
    string password;
|};

# User record
#
# + id - Unique user identifier
# + email - User email address
# + passwordHash - Hashed password
# + name - User's full name
# + role - User role (USER, ADMIN, etc.)
# + createdAt - Account creation timestamp
# + timezone - User's timezone
public type User record {|
    readonly string id;
    string email;
    string passwordHash;
    string name;
    string role;
    string createdAt;
    string timezone = "UTC"; // Default timezone
|};

# User response
#
# + id - Unique user identifier
# + email - User email address
# + name - User's full name
# + role - User role
# + timezone - User's timezone
public type UserResponse record {|
    string id;
    string email;
    string name;
    string role;
    string timezone;
|};

# Authentication response
#
# + token - JWT authentication token
# + user - User information
public type AuthResponse record {|
    string token;
    UserResponse user;
|};

// Task management types

# Task status enum
public enum TaskStatus {
    TODO = "TODO",
    IN_PROGRESS = "IN_PROGRESS",
    DONE = "DONE"
}

# Task priority enum
public enum TaskPriority {
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH"
}

# Task sorting options enum
public enum TaskSortBy {
    DUE_DATE = "dueDate",
    PRIORITY = "priority",
    STATUS = "status",
    CREATED_AT = "createdAt",
    UPDATED_AT = "updatedAt",
    TITLE = "title"
}

# Sort order enum
public enum SortOrder {
    ASC = "asc",
    DESC = "desc"
}

# Task record
#
# + id - Unique task identifier
# + title - Task title
# + description - Task description
# + status - Current task status
# + dueDate - Due date in ISO format (YYYY-MM-DD)
# + priority - Task priority level
# + createdBy - User ID who created the task
# + assignedTo - User ID task is assigned to (optional)
# + createdAt - Task creation timestamp
# + updatedAt - Last update timestamp
# + timezone - Timezone for date interpretation
public type Task record {|
    readonly string id;
    string title;
    string description;
    TaskStatus status;
    string dueDate;
    TaskPriority priority;
    string createdBy;
    string? assignedTo = ();
    string createdAt;
    string updatedAt;
    string timezone = "UTC"; // Added timezone field
|};

# Task response type
#
# + id - Unique task identifier
# + title - Task title
# + description - Task description
# + status - Current task status
# + dueDate - Due date in ISO format
# + priority - Task priority level
# + createdBy - User who created the task
# + assignedTo - User task is assigned to (optional)
# + createdAt - Task creation timestamp
# + updatedAt - Last update timestamp
# + timezone - Timezone for date interpretation
# + isOverdue - Whether task is overdue based on current date
public type TaskResponse record {|
    string id;
    string title;
    string description;
    string status;
    string dueDate;
    string priority;
    UserResponse createdBy;
    UserResponse? assignedTo = ();
    string createdAt;
    string updatedAt;
    string timezone;
    boolean isOverdue;
|};

# Create task request
#
# + title - Task title
# + description - Task description
# + dueDate - Due date in ISO format (YYYY-MM-DD)
# + priority - Task priority level
# + assignedTo - User ID task is assigned to (optional)
# + timezone - Timezone for date interpretation (optional)
public type CreateTaskRequest record {|
    string title;
    string description;
    string dueDate;
    TaskPriority priority;
    string? assignedTo = ();
    string? timezone = (); // Added timezone field
|};

# Update task request
#
# + title - Task title (optional)
# + description - Task description (optional)
# + status - Current task status (optional)
# + dueDate - Due date in ISO format (optional)
# + priority - Task priority level (optional)
# + assignedTo - User ID task is assigned to (optional)
# + timezone - Timezone for date interpretation (optional)
public type UpdateTaskRequest record {|
    string? title = ();
    string? description = ();
    TaskStatus? status = ();
    string? dueDate = ();
    TaskPriority? priority = ();
    string? assignedTo = ();
    string? timezone = (); // Added timezone field
|};

# Pagination information
#
# + page - Current page number (1-based)
# + pageSize - Number of items per page
# + totalItems - Total number of items available
# + totalPages - Total number of pages
# + hasNext - Whether there are more pages after current
# + hasPrevious - Whether there are pages before current
public type PaginationInfo record {|
    int page;
    int pageSize;
    int totalItems;
    int totalPages;
    boolean hasNext;
    boolean hasPrevious;
|};

# Task filter options with pagination and sorting
#
# + status - Filter by status
# + priority - Filter by priority
# + startDate - Filter by due date range (start)
# + endDate - Filter by due date range (end)
# + assignedTo - Filter by assignee
# + createdBy - Filter by creator
# + page - Page number for pagination (1-based, default: 1)
# + pageSize - Number of items per page (default: 10, max: 100)
# + sortBy - Field to sort by (default: dueDate)
# + sortOrder - Sort order (default: asc)
public type TaskFilterOptions record {|
    TaskStatus? status = ();
    TaskPriority? priority = ();
    string? startDate = ();
    string? endDate = ();
    string? assignedTo = ();
    string? createdBy = ();
    int page = 1;
    int pageSize = 10;
    TaskSortBy sortBy = DUE_DATE;
    SortOrder sortOrder = ASC;
|};

# Paginated task list response
#
# + tasks - Array of task responses
# + pagination - Pagination information
public type PaginatedTaskResponse record {|
    TaskResponse[] tasks;
    PaginationInfo pagination;
|};

# Task statistics response
#
# + total - Total number of tasks
# + byStatus - Task counts by status
# + byPriority - Task counts by priority
# + overdue - Number of overdue tasks
public type TaskStatistics record {|
    int total;
    record {|
        int TODO;
        int IN_PROGRESS;
        int DONE;
    |} byStatus;
    record {|
        int LOW;
        int MEDIUM;
        int HIGH;
    |} byPriority;
    int overdue;
|};

# Date validation error response
#
# + isError - Whether this is an error
# + message - Error message
# + fieldName - Field with the error
# + validation - Specific validation error details
public type DateValidationError record {|
    boolean isError = true;
    string message;
    string fieldName;
    string validation;
|};

# Batch operations types

# Batch delete tasks request
#
# + taskIds - Array of task IDs to delete
public type BatchDeleteTasksRequest record {|
    string[] taskIds;
|};

# Batch update task status request
#
# + taskIds - Array of task IDs to update
# + status - New status to apply to all tasks
public type BatchUpdateStatusRequest record {|
    string[] taskIds;
    TaskStatus status;
|};

# Batch operation result
#
# + successful - Number of successfully processed items
# + failed - Number of failed items
# + errors - Map of task IDs to error messages for failed operations
# + successfulIds - Array of successfully processed task IDs
# + failedIds - Array of failed task IDs
public type BatchOperationResult record {|
    int successful;
    int failed;
    map<string> errors;
    string[] successfulIds;
    string[] failedIds;
|};

# Batch operation response
#
# + success - Whether the overall operation was successful
# + message - Operation summary message
# + result - Detailed operation results
public type BatchOperationResponse record {|
    boolean success;
    string message;
    BatchOperationResult result;
|};