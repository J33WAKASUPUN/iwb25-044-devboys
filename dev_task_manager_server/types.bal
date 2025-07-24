// types.bal

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

# Task filter options
#
# + status - Filter by status
# + priority - Filter by priority
# + startDate - Filter by due date range (start)
# + endDate - Filter by due date range (end)
# + assignedTo - Filter by assignee
# + createdBy - Filter by creator
public type TaskFilterOptions record {|
    TaskStatus? status = ();
    TaskPriority? priority = ();
    string? startDate = ();
    string? endDate = ();
    string? assignedTo = ();
    string? createdBy = ();
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