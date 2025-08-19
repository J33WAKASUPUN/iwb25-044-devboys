import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerinax/mongodb;

// MongoDB configuration using configurable values
configurable string mongodb_uri = ?;
configurable string db_name = ?;
configurable string jwt_secret = ?;

// Define variables used throughout the code
final string mongoUri = mongodb_uri;
final string dbName = db_name;

// Better Error Response Helper Functions
# Create standardized error response
#
# + code - Error code
# + message - Error message
# + details - Optional additional details
# + return - Standardized error JSON
public function createErrorResponse(string code, string message, json? details = ()) returns json {
    return {
        "error": true,
        "code": code,
        "message": message,
        "details": details,
        "timestamp": time:utcToString(time:utcNow())
    };
}

# Create success response
#
# + data - Response data
# + message - Optional success message
# + return - Standardized success JSON
public function createSuccessResponse(json data, string? message = ()) returns json {
    json response = {
        "success": true,
        "data": data,
        "timestamp": time:utcToString(time:utcNow())
    };

    if (message is string) {
        response = {
            "success": true,
            "message": message,
            "data": data,
            "timestamp": time:utcToString(time:utcNow())
        };
    }

    return response;
}

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],  // Allow all origins for development
        allowCredentials: false,
        allowHeaders: [
            "CORELATION_ID",
            "Authorization", 
            "Content-Type",
            "Accept",
            "Origin",
            "X-Requested-With",
            "Access-Control-Allow-Origin",
            "Access-Control-Allow-Headers",
            "Access-Control-Allow-Methods"
        ],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"],
        maxAge: 84900,
        exposeHeaders: ["*"]
    }
}

// Service configuration
service / on new http:Listener(9090, {
    host: "192.168.1.159" // This allows connections from any IP
}) {
    private final mongodb:Client mongoClient;
    private final mongodb:Database db;
    private final mongodb:Collection userCollection;
    private final mongodb:Collection taskCollection;
    private final UserService userService;
    private final TaskService taskService;
    private final mongodb:Collection groupCollection;
    private final mongodb:Collection membershipCollection;
    private final GroupService groupService;

    function init() returns error? {
        log:printInfo("Initializing Dev Tasks Manager API Server...");

        // Log the connection parameters (mask password for security)
        string maskedUri;
        int? atIndex = mongoUri.indexOf("@");
        if (atIndex is int) {
            int? protocolIndex = mongoUri.indexOf("://");
            if (protocolIndex is int) {
                maskedUri = mongoUri.substring(0, protocolIndex + 3) + "***:***@" + mongoUri.substring(atIndex);
            } else {
                maskedUri = "***:***@" + mongoUri.substring(atIndex);
            }
        } else {
            maskedUri = mongoUri;
        }

        log:printInfo("MongoDB URI: " + maskedUri);
        log:printInfo("Database name: " + dbName);

        do {
            // Initialize MongoDB
            self.mongoClient = check new mongodb:Client({
                connection: mongoUri
            });

            log:printInfo("MongoDB client initialized successfully");

            // Get collections
            self.db = check self.mongoClient->getDatabase(dbName);
            self.userCollection = check self.db->getCollection("users");
            self.taskCollection = check self.db->getCollection("tasks");
            self.groupCollection = check self.db->getCollection("groups");
            self.membershipCollection = check self.db->getCollection("memberships");

            // Create indices
            check self.userCollection->createIndex({
                email: 1
            }, {
                unique: true
            });

            // Create index for unique membership
            check self.membershipCollection->createIndex({
                userId: 1,
                groupId: 1
            }, {
                unique: true
            });

            // Initialize services in correct order
            self.userService = new UserService(self.userCollection);
            self.groupService = new GroupService(self.groupCollection, self.membershipCollection, self.userService);
            self.taskService = new TaskService(self.taskCollection, self.userService, self.groupService);

            log:printInfo("MongoDB connected successfully");
            log:printInfo("Server running on http://localhost:9090");
        } on fail error e {
            log:printError("Failed to initialize MongoDB: " + e.message());
            return e;
        }
    }

    # Health check endpoint - Basic server health
    #
    # + return - Server health status
    resource function get health() returns json {
        string currentTime = time:utcToString(time:utcNow());

        // Test MongoDB connection
        boolean dbHealthy = true;
        string dbStatus = "connected";
        int userCount = 0;
        int taskCount = 0;

        do {
            // Simple ping to check if DB is responsive
            userCount = check self.userCollection->countDocuments({});
            taskCount = check self.taskCollection->countDocuments({});
        } on fail error e {
            dbHealthy = false;
            dbStatus = "disconnected: " + e.message();
        }

        return {
            "status": dbHealthy ? "healthy" : "degraded",
            "timestamp": currentTime,
            "server": {
                "name": "Dev Task Manager API",
                "version": "1.0.0",
                "environment": "development"
            },
            "database": {
                "status": dbStatus,
                "type": "MongoDB",
                "collections": {
                    "users": userCount,
                    "tasks": taskCount
                }
            },
            "uptime": currentTime, // Simple uptime for now
            "features": [
                "user-authentication",
                "task-management",
                "admin-panel",
                "health-monitoring"
            ]
        };
    }

    # ⚡ Detailed health check for admins
    #
    # + req - HTTP request with auth token
    # + return - Detailed system health or error
    resource function get health/detailed(http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required", {"reason": "Missing or invalid token"});
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return createErrorResponse("ADMIN_REQUIRED", "Admin access required", {"userRole": "USER"});
        }

        string currentTime = time:utcToString(time:utcNow());

        // Test all collections and get detailed stats
        map<json> dbDetails = {};
        map<json> systemHealth = {};

        do {
            int userCount = check self.userCollection->countDocuments({});
            int taskCount = check self.taskCollection->countDocuments({});

            // Get task statistics
            TaskStatistics stats = check self.taskService.getTaskStatistics(userId, true);

            dbDetails = {
                "users_total": userCount,
                "tasks_total": taskCount,
                "tasks_by_status": stats.byStatus,
                "tasks_by_priority": stats.byPriority,
                "overdue_tasks": stats.overdue,
                "last_checked": currentTime
            };

            systemHealth = {
                "database_responsive": true,
                "collections_accessible": true,
                "indexes_working": true
            };

        } on fail error e {
            dbDetails = {
                "error": e.message(),
                "last_checked": currentTime
            };
            systemHealth = {
                "database_responsive": false,
                "error": e.message()
            };
        }

        return createSuccessResponse({
                                         "server": {
                                             "name": "Dev Task Manager API",
                                             "version": "1.0.0",
                                             "environment": "development",
                                             "uptime": currentTime
                                         },
                                         "database": {
                                             "status": "connected",
                                             "details": dbDetails
                                         },
                                         "system": systemHealth,
                                         "endpoints": {
                                             "total": 16,
                                             "categories": {
                                                 "auth": 2,
                                                 "tasks": 8,
                                                 "admin": 4,
                                                 "health": 2
                                             }
                                         }
                                     }, "System health check completed successfully");
    }

    # User registration endpoint (WITH Better Error Handling)
    #
    # + request - Registration request
    # + return - Response with user info and token
    resource function post auth/register(@http:Payload RegisterRequest request) returns json|error {
        AuthResponse|error result = self.userService.register(request);

        if result is error {
            string errorMsg = result.message();

            // Categorize different types of errors
            if (errorMsg.includes("Email already registered")) {
                return createErrorResponse("EMAIL_EXISTS", errorMsg, {"field": "email"});
            } else if (errorMsg.includes("Password must be")) {
                return createErrorResponse("INVALID_PASSWORD", errorMsg, {"field": "password", "requirement": "minimum 6 characters"});
            } else if (errorMsg.includes("Email is required")) {
                return createErrorResponse("MISSING_FIELD", errorMsg, {"field": "email"});
            } else if (errorMsg.includes("Name is required")) {
                return createErrorResponse("MISSING_FIELD", errorMsg, {"field": "name"});
            } else {
                return createErrorResponse("REGISTRATION_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "User registered successfully");
    }

    # User login endpoint (WITH Better Error Handling)
    #
    # + request - Login request
    # + return - Response with user info and token
    resource function post auth/login(@http:Payload LoginRequest request) returns json|error {
        AuthResponse|error result = self.userService.login(request);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Invalid email or password")) {
                return createErrorResponse("INVALID_CREDENTIALS", "Invalid email or password", {"field": "credentials"});
            } else if (errorMsg.includes("Email is required")) {
                return createErrorResponse("MISSING_FIELD", "Email is required", {"field": "email"});
            } else if (errorMsg.includes("Password is required")) {
                return createErrorResponse("MISSING_FIELD", "Password is required", {"field": "password"});
            } else {
                return createErrorResponse("LOGIN_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Login successful");
    }

    # Protected endpoint - Get user profile (WITH Better Error Handling)
    #
    # + req - HTTP request
    # + return - User profile or error response
    resource function get profile(http:Request req) returns json|error {
        // Check authentication using middleware
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", userId.message(), {"action": "provide valid Bearer token"});
        }

        // Get user profile
        UserResponse|error profile = self.userService.getUserProfile(userId);

        if profile is error {
            return createErrorResponse("USER_NOT_FOUND", profile.message(), {"userId": userId});
        }

        // Get user's tasks with basic pagination
        TaskFilterOptions filters = {
            createdBy: userId,
            page: 1,
            pageSize: 5
        };

        PaginatedTaskResponse|error tasks = self.taskService.listTasks(userId, filters);

        if tasks is error {
            return createErrorResponse("TASKS_FETCH_FAILED", tasks.message());
        }

        // Return user profile with tasks
        return createSuccessResponse({
                                         "profile": profile,
                                         "recent_tasks": tasks.tasks,
                                         "tasks_pagination": tasks.pagination
                                     }, "Profile retrieved successfully");
    }

    # Create a new task (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + request - Task creation request
    # + return - Created task or error
    resource function post tasks(http:Request req, @http:Payload CreateTaskRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        TaskResponse|error result = self.taskService.createTask(userId, request);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Title is required")) {
                return createErrorResponse("MISSING_FIELD", errorMsg, {"field": "title"});
            } else if (errorMsg.includes("Due date is required")) {
                return createErrorResponse("MISSING_FIELD", errorMsg, {"field": "dueDate"});
            } else if (errorMsg.includes("Invalid date")) {
                return createErrorResponse("INVALID_DATE", errorMsg, {"field": "dueDate"});
            } else if (errorMsg.includes("Assigned user not found")) {
                return createErrorResponse("USER_NOT_FOUND", errorMsg, {"field": "assignedTo"});
            } else {
                return createErrorResponse("TASK_CREATION_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Task created successfully");
    }

    # Update an existing task (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + taskId - ID of task to update
    # + request - Task update request
    # + return - Updated task or error
    resource function put tasks/[string taskId](http:Request req, @http:Payload UpdateTaskRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        TaskResponse|error result = self.taskService.updateTask(userId, taskId, request);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Task not found")) {
                return createErrorResponse("TASK_NOT_FOUND", errorMsg, {"taskId": taskId});
            } else if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"action": "only creator or assignee can update"});
            } else if (errorMsg.includes("Invalid date")) {
                return createErrorResponse("INVALID_DATE", errorMsg, {"field": "dueDate"});
            } else if (errorMsg.includes("Assigned user not found")) {
                return createErrorResponse("USER_NOT_FOUND", errorMsg, {"field": "assignedTo"});
            } else {
                return createErrorResponse("TASK_UPDATE_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Task updated successfully");
    }

    # Delete a task (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + taskId - ID of task to delete
    # + return - Success message or error
    resource function delete tasks/[string taskId](http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        boolean|error result = self.taskService.deleteTask(userId, taskId);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Task not found")) {
                return createErrorResponse("TASK_NOT_FOUND", errorMsg, {"taskId": taskId});
            } else if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"action": "only creator can delete"});
            } else {
                return createErrorResponse("TASK_DELETE_FAILED", errorMsg);
            }
        }

        return createSuccessResponse({"taskId": taskId}, "Task deleted successfully");
    }

    # Get a task by ID (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + taskId - ID of task to retrieve
    # + return - Task details or error
    resource function get tasks/[string taskId](http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        TaskResponse|error result = self.taskService.getTaskById(taskId);

        if result is error {
            return createErrorResponse("TASK_NOT_FOUND", result.message(), {"taskId": taskId});
        }

        return createSuccessResponse(result, "Task retrieved successfully");
    }

    # List tasks with pagination, filtering, and sorting (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + status - Filter by status
    # + priority - Filter by priority
    # + startDate - Filter by due date range (start)
    # + endDate - Filter by due date range (end)
    # + assignedTo - Filter by assignee
    # + createdBy - Filter by creator
    # + page - Page number (default: 1)
    # + pageSize - Number of items per page (default: 10, max: 100)
    # + sortBy - Field to sort by (default: dueDate)
    # + sortOrder - Sort order (default: asc)
    # + return - Paginated list of tasks
    resource function get tasks(
            http:Request req,
            string? status = (),
            string? priority = (),
            string? startDate = (),
            string? endDate = (),
            string? assignedTo = (),
            string? createdBy = (),
            int page = 1,
            int pageSize = 10,
            string sortBy = "dueDate",
            string sortOrder = "asc"
    ) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Convert query parameters to filter options
        TaskFilterOptions filters = {
            page: page,
            pageSize: pageSize
        };

        // Parse and validate sortBy parameter
        match sortBy.toLowerAscii() {
            "duedate" => {
                filters.sortBy = DUE_DATE;
            }
            "priority" => {
                filters.sortBy = PRIORITY;
            }
            "status" => {
                filters.sortBy = STATUS;
            }
            "createdat" => {
                filters.sortBy = CREATED_AT;
            }
            "updatedat" => {
                filters.sortBy = UPDATED_AT;
            }
            "title" => {
                filters.sortBy = TITLE;
            }
            _ => {
                filters.sortBy = DUE_DATE;
            } // Default
        }

        // Parse and validate sortOrder parameter
        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // Parse status filter
        if (status is string) {
            match status.toUpperAscii() {
                "TODO" => {
                    filters.status = TODO;
                }
                "IN_PROGRESS" => {
                    filters.status = IN_PROGRESS;
                }
                "DONE" => {
                    filters.status = DONE;
                }
            }
        }

        // Parse priority filter
        if (priority is string) {
            match priority.toUpperAscii() {
                "LOW" => {
                    filters.priority = LOW;
                }
                "MEDIUM" => {
                    filters.priority = MEDIUM;
                }
                "HIGH" => {
                    filters.priority = HIGH;
                }
            }
        }

        // Set other filters
        filters.startDate = startDate;
        filters.endDate = endDate;
        filters.assignedTo = assignedTo;
        filters.createdBy = createdBy;

        PaginatedTaskResponse|error result = self.taskService.listTasks(userId, filters);

        if result is error {
            return createErrorResponse("TASK_LIST_FAILED", result.message());
        }

        return createSuccessResponse(result, "Tasks retrieved successfully");
    }

    # Get tasks assigned to the authenticated user (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + page - Page number (default: 1)
    # + pageSize - Number of items per page (default: 10)
    # + sortBy - Field to sort by (default: dueDate)
    # + sortOrder - Sort order (default: asc)
    # + return - Paginated list of assigned tasks
    resource function get tasks/assigned(
            http:Request req,
            int page = 1,
            int pageSize = 10,
            string sortBy = "dueDate",
            string sortOrder = "asc"
    ) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        TaskFilterOptions filters = {
            assignedTo: userId,
            page: page,
            pageSize: pageSize
        };

        // Parse sort parameters
        match sortBy.toLowerAscii() {
            "duedate" => {
                filters.sortBy = DUE_DATE;
            }
            "priority" => {
                filters.sortBy = PRIORITY;
            }
            "status" => {
                filters.sortBy = STATUS;
            }
            "createdat" => {
                filters.sortBy = CREATED_AT;
            }
            "updatedat" => {
                filters.sortBy = UPDATED_AT;
            }
            "title" => {
                filters.sortBy = TITLE;
            }
            _ => {
                filters.sortBy = DUE_DATE;
            }
        }

        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        PaginatedTaskResponse|error result = self.taskService.listTasks(userId, filters);

        if result is error {
            return createErrorResponse("ASSIGNED_TASKS_FAILED", result.message());
        }

        return createSuccessResponse(result, "Assigned tasks retrieved successfully");
    }

    # Batch delete multiple tasks (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + request - Batch delete request with task IDs
    # + return - Batch operation result
    resource function delete tasks/batch(http:Request req, @http:Payload BatchDeleteTasksRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Validate request
        if (request.taskIds.length() == 0) {
            return createErrorResponse("INVALID_REQUEST", "At least one task ID must be provided", {"field": "taskIds"});
        }

        if (request.taskIds.length() > 50) {
            return createErrorResponse("REQUEST_TOO_LARGE", "Cannot delete more than 50 tasks at once", {"limit": 50, "provided": request.taskIds.length()});
        }

        // Perform batch delete
        BatchOperationResult|error result = self.taskService.batchDeleteTasks(userId, request.taskIds);

        if result is error {
            return createErrorResponse("BATCH_DELETE_FAILED", result.message());
        }

        // Create response
        string message = string `Batch delete completed: ${result.successful} successful, ${result.failed} failed`;

        return createSuccessResponse({
                                         "operation": "batch_delete",
                                         "result": result
                                     }, message);
    }

    # Batch update status of multiple tasks (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + request - Batch update request with task IDs and new status
    # + return - Batch operation result
    resource function put tasks/batch/status(http:Request req, @http:Payload BatchUpdateStatusRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Validate request
        if (request.taskIds.length() == 0) {
            return createErrorResponse("INVALID_REQUEST", "At least one task ID must be provided", {"field": "taskIds"});
        }

        if (request.taskIds.length() > 50) {
            return createErrorResponse("REQUEST_TOO_LARGE", "Cannot update more than 50 tasks at once", {"limit": 50, "provided": request.taskIds.length()});
        }

        // Perform batch status update
        BatchOperationResult|error result = self.taskService.batchUpdateTaskStatus(userId, request.taskIds, request.status);

        if result is error {
            return createErrorResponse("BATCH_UPDATE_FAILED", result.message());
        }

        // Create response
        string statusStr = <string>request.status;
        string message = string `Batch status update to ${statusStr} completed: ${result.successful} successful, ${result.failed} failed`;

        return createSuccessResponse({
                                         "operation": "batch_status_update",
                                         "new_status": statusStr,
                                         "result": result
                                     }, message);
    }

    # Search tasks by text with pagination (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + query - Search query
    # + page - Page number (default: 1)
    # + pageSize - Number of items per page (default: 10)
    # + sortBy - Field to sort by (default: dueDate)
    # + sortOrder - Sort order (default: asc)
    # + return - Paginated matching tasks
    resource function get tasks/search(
            http:Request req,
            string query,
            int page = 1,
            int pageSize = 10,
            string sortBy = "dueDate",
            string sortOrder = "asc"
    ) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Validate search query
        if (query.trim() == "") {
            return createErrorResponse("INVALID_QUERY", "Search query cannot be empty", {"field": "query"});
        }

        // Check if user is admin
        boolean isAdmin = false;
        boolean|error adminCheck = self.userService.checkAdminRole(userId);
        if adminCheck is boolean {
            isAdmin = true;
        }

        // Setup filter options for search
        TaskFilterOptions filters = {
            page: page,
            pageSize: pageSize
        };

        // Parse sort parameters
        match sortBy.toLowerAscii() {
            "duedate" => {
                filters.sortBy = DUE_DATE;
            }
            "priority" => {
                filters.sortBy = PRIORITY;
            }
            "status" => {
                filters.sortBy = STATUS;
            }
            "createdat" => {
                filters.sortBy = CREATED_AT;
            }
            "updatedat" => {
                filters.sortBy = UPDATED_AT;
            }
            "title" => {
                filters.sortBy = TITLE;
            }
            _ => {
                filters.sortBy = DUE_DATE;
            }
        }

        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // Search tasks with appropriate permissions
        PaginatedTaskResponse|error result = self.taskService.searchTasks(userId, query, filters, isAdmin);

        if result is error {
            return createErrorResponse("SEARCH_FAILED", result.message(), {"query": query});
        }

        return createSuccessResponse({
                                         "search_query": query,
                                         "results": result
                                     }, "Search completed successfully");
    }

    # Admin endpoint: Get all users (admin only) (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + return - List of all users or error
    resource function get admin/users(http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return createErrorResponse("ADMIN_REQUIRED", isAdmin.message(), {"required_role": "ADMIN"});
        }

        // Get all users
        UserResponse[]|error result = self.userService.getAllUsers();

        if result is error {
            return createErrorResponse("USERS_FETCH_FAILED", result.message());
        }

        return createSuccessResponse({
                                         "users": result,
                                         "total_count": result.length()
                                     }, "All users retrieved successfully");
    }

    # Admin endpoint: Get all tasks with pagination (admin only) (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + page - Page number (default: 1)
    # + pageSize - Number of items per page (default: 10)
    # + sortBy - Field to sort by (default: dueDate)
    # + sortOrder - Sort order (default: asc)
    # + return - Paginated list of all tasks
    resource function get admin/tasks(
            http:Request req,
            int page = 1,
            int pageSize = 10,
            string sortBy = "dueDate",
            string sortOrder = "asc"
    ) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return createErrorResponse("ADMIN_REQUIRED", isAdmin.message(), {"required_role": "ADMIN"});
        }

        // Setup filter options for admin view (no access restrictions)
        TaskFilterOptions filters = {
            page: page,
            pageSize: pageSize
        };

        // Parse sort parameters
        match sortBy.toLowerAscii() {
            "duedate" => {
                filters.sortBy = DUE_DATE;
            }
            "priority" => {
                filters.sortBy = PRIORITY;
            }
            "status" => {
                filters.sortBy = STATUS;
            }
            "createdat" => {
                filters.sortBy = CREATED_AT;
            }
            "updatedat" => {
                filters.sortBy = UPDATED_AT;
            }
            "title" => {
                filters.sortBy = TITLE;
            }
            _ => {
                filters.sortBy = DUE_DATE;
            }
        }

        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // For admin, we need to modify the listTasks method or create a separate admin method
        // For now, let's use a workaround by getting all tasks without user restrictions
        PaginatedTaskResponse|error result = self.getAdminTasks(filters);

        if result is error {
            return createErrorResponse("ADMIN_TASKS_FAILED", result.message());
        }

        return createSuccessResponse(result, "Admin tasks retrieved successfully");
    }

    # Admin endpoint: Change user role (admin only) (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + userId - ID of user to update
    # + role - New role (USER or ADMIN)
    # + return - Updated user or error
    resource function put admin/users/[string userId]/role(http:Request req, string role) returns json|error {
        // Check authentication
        string|error adminId = extractUserIdFromToken(req);

        if adminId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(adminId);

        if isAdmin is error {
            return createErrorResponse("ADMIN_REQUIRED", isAdmin.message(), {"required_role": "ADMIN"});
        }

        // Validate role
        if (role != "USER" && role != "ADMIN") {
            return createErrorResponse("INVALID_ROLE", "Invalid role: must be USER or ADMIN", {"valid_roles": ["USER", "ADMIN"], "provided": role});
        }

        // Find user to update
        User?|error user = self.userService.findUserById(userId);

        if user is error {
            return createErrorResponse("USER_LOOKUP_FAILED", user.message());
        }

        if user is () {
            return createErrorResponse("USER_NOT_FOUND", "User not found", {"userId": userId});
        }

        // Use the findOneAndUpdate approach instead
        map<json> filter = {"id": userId};
        mongodb:Update update = {
            set: {"role": role}
        };

        // Fetch the collection and DB directly
        do {
            mongodb:Collection usersCollection = check self.db->getCollection("users");
            _ = check usersCollection->updateOne(filter, update);
        } on fail error e {
            return createErrorResponse("ROLE_UPDATE_FAILED", "Failed to update user role: " + e.message());
        }

        // Return updated user
        UserResponse|error updatedUser = self.userService.getUserProfile(userId);

        if updatedUser is error {
            return createErrorResponse("USER_FETCH_FAILED", updatedUser.message());
        }

        return createSuccessResponse(updatedUser, string `User role updated to ${role} successfully`);
    }

    # Get task statistics (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + return - Task statistics or error
    resource function get stats/tasks(http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Check if user is admin
        boolean isAdmin = false;
        boolean|error adminCheck = self.userService.checkAdminRole(userId);
        if adminCheck is boolean {
            isAdmin = true;
        }

        // Get statistics with appropriate permissions
        TaskStatistics|error result = self.taskService.getTaskStatistics(userId, isAdmin);

        if result is error {
            return createErrorResponse("STATS_FAILED", result.message());
        }

        return createSuccessResponse(result, "Task statistics retrieved successfully");
    }

    # Admin endpoint: Get detailed task statistics (admin only) (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + return - Task statistics or error
    resource function get admin/stats/tasks(http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return createErrorResponse("ADMIN_REQUIRED", isAdmin.message(), {"required_role": "ADMIN"});
        }

        // Get base statistics
        TaskStatistics|error stats = self.taskService.getTaskStatistics(userId, true);

        if stats is error {
            return createErrorResponse("STATS_FAILED", stats.message());
        }

        // Get all users for additional statistics
        UserResponse[]|error users = self.userService.getAllUsers();

        if users is error {
            return createErrorResponse("USERS_FETCH_FAILED", users.message());
        }

        // Count tasks per user
        map<json> tasksPerUser = {};

        foreach UserResponse user in users {
            TaskFilterOptions filters = {
                createdBy: user.id,
                page: 1,
                pageSize: 1000 // Get all tasks for counting
            };

            PaginatedTaskResponse|error userTasks = self.taskService.listTasks(user.id, filters);
            if userTasks is PaginatedTaskResponse {
                tasksPerUser[user.name] = userTasks.pagination.totalItems;
            } else {
                tasksPerUser[user.name] = 0;
            }
        }

        // Return enhanced statistics
        return createSuccessResponse({
                                         "basic_stats": stats,
                                         "tasks_per_user": tasksPerUser,
                                         "total_users": users.length()
                                     }, "Detailed task statistics retrieved successfully");
    }

    # Update user timezone (WITH Better Error Handling)
    #
    # + req - HTTP request with auth token
    # + timezone - New timezone value
    # + return - Updated user profile or error
    resource function put profile/timezone(http:Request req, string timezone) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Update the timezone
        UserResponse|error result = self.userService.updateUserTimezone(userId, timezone);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Invalid timezone")) {
                return createErrorResponse("INVALID_TIMEZONE", errorMsg, {"field": "timezone", "provided": timezone});
            } else if (errorMsg.includes("User not found")) {
                return createErrorResponse("USER_NOT_FOUND", errorMsg, {"userId": userId});
            } else {
                return createErrorResponse("TIMEZONE_UPDATE_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Timezone updated successfully");
    }

    # Helper method to get admin tasks (all tasks without user restrictions)
    #
    # + filters - Pagination and sorting options
    # + return - Paginated task response
    private function getAdminTasks(TaskFilterOptions filters) returns PaginatedTaskResponse|error {
        // Build empty filter to get all tasks
        map<json> filter = {};

        // Validate and setup pagination
        int page = filters.page < 1 ? 1 : filters.page;
        int pageSize = filters.pageSize < 1 ? 10 : (filters.pageSize > 100 ? 100 : filters.pageSize);
        int skip = (page - 1) * pageSize;

        // Get total count for pagination
        int totalCount = check self.taskCollection->countDocuments(filter);
        int totalPages = totalCount == 0 ? 1 : ((totalCount - 1) / pageSize) + 1;

        // Setup sorting
        map<json> sortOptions = {};
        string sortField = <string>filters.sortBy;
        int sortDirection = <string>filters.sortOrder == "desc" ? -1 : 1;
        sortOptions[sortField] = sortDirection;

        // Query tasks with pagination and sorting
        stream<Task, error?> taskStream = check self.taskCollection->find(filter, {
            "limit": pageSize,
            "skip": skip,
            "sort": sortOptions
        });

        // Convert tasks to responses
        TaskResponse[] responses = [];
        error? err = from Task task in taskStream
            do {
                TaskResponse response = check self.taskService.convertTaskToResponse(task);
                responses.push(response);
            };

        if (err is error) {
            return err;
        }

        // Create pagination info
        PaginationInfo pagination = {
            page: page,
            pageSize: pageSize,
            totalItems: totalCount,
            totalPages: totalPages,
            hasNext: page < totalPages,
            hasPrevious: page > 1
        };

        return {
            tasks: responses,
            pagination: pagination
        };
    }

    // Add these endpoints to your main.bal file inside the service block

    # Create a new group
    #
    # + req - HTTP request with auth token
    # + request - Group creation request
    # + return - Created group or error
    resource function post groups(http:Request req, @http:Payload CreateGroupRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        GroupResponse|error result = self.groupService.createGroup(userId, request);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Group name")) {
                return createErrorResponse("INVALID_GROUP_NAME", errorMsg, {"field": "name"});
            } else if (errorMsg.includes("Group description")) {
                return createErrorResponse("INVALID_DESCRIPTION", errorMsg, {"field": "description"});
            } else {
                return createErrorResponse("GROUP_CREATION_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Group created successfully");
    }

    # Update an existing group
    #
    # + req - HTTP request with auth token
    # + groupId - ID of group to update
    # + request - Group update request
    # + return - Updated group or error
    resource function put groups/[string groupId](http:Request req, @http:Payload UpdateGroupRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        GroupResponse|error result = self.groupService.updateGroup(userId, groupId, request);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"action": "only group admin can update"});
            } else if (errorMsg.includes("Group name")) {
                return createErrorResponse("INVALID_GROUP_NAME", errorMsg, {"field": "name"});
            } else if (errorMsg.includes("Group description")) {
                return createErrorResponse("INVALID_DESCRIPTION", errorMsg, {"field": "description"});
            } else {
                return createErrorResponse("GROUP_UPDATE_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Group updated successfully");
    }

    # Get a group by ID
    #
    # + req - HTTP request with auth token
    # + groupId - ID of group to retrieve
    # + return - Group details or error
    resource function get groups/[string groupId](http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Check if user is a member of the group
        boolean|error isMember = self.groupService.isGroupMember(userId, groupId);

        if isMember is error || !(isMember is boolean && isMember) {
            return createErrorResponse("UNAUTHORIZED", "Not authorized to view this group. Only members can view.");
        }

        GroupResponse|error result = self.groupService.getGroupById(groupId);

        if result is error {
            return createErrorResponse("GROUP_NOT_FOUND", result.message(), {"groupId": groupId});
        }

        return createSuccessResponse(result, "Group retrieved successfully");
    }

    # List groups for the current user
    #
    # + req - HTTP request with auth token
    # + return - List of groups or error
    resource function get groups(http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        GroupResponse[]|error result = self.groupService.listUserGroups(userId);

        if result is error {
            return createErrorResponse("GROUPS_FETCH_FAILED", result.message());
        }

        return createSuccessResponse({
                                         "groups": result,
                                         "count": result.length()
                                     }, "Groups retrieved successfully");
    }

    # Add a member to a group
    #
    # + req - HTTP request with auth token
    # + groupId - ID of group
    # + request - Member details to add
    # + return - Updated group or error
    resource function post groups/[string groupId]/members(http:Request req, @http:Payload AddGroupMemberRequest request) returns json|error {
        // Check authentication
        string|error adminId = extractUserIdFromToken(req);

        if adminId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        GroupResponse|error result = self.groupService.addGroupMember(adminId, groupId, request);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"action": "only group admin can add members"});
            } else if (errorMsg.includes("User is already a member")) {
                return createErrorResponse("MEMBER_EXISTS", errorMsg, {"userId": request.userId});
            } else if (errorMsg.includes("User not found")) {
                return createErrorResponse("USER_NOT_FOUND", errorMsg, {"userId": request.userId});
            } else {
                return createErrorResponse("ADD_MEMBER_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Member added to group successfully");
    }

    # Remove a member from a group
    #
    # + req - HTTP request with auth token
    # + groupId - ID of group
    # + memberId - ID of member to remove
    # + return - Updated group or error
    resource function delete groups/[string groupId]/members/[string memberId](http:Request req) returns json|error {
        // Check authentication
        string|error adminId = extractUserIdFromToken(req);

        if adminId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        GroupResponse|error result = self.groupService.removeGroupMember(adminId, groupId, memberId);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"action": "only group admin can remove members"});
            } else if (errorMsg.includes("User is not a member")) {
                return createErrorResponse("NOT_A_MEMBER", errorMsg, {"userId": memberId});
            } else if (errorMsg.includes("Cannot remove the group creator")) {
                return createErrorResponse("CANNOT_REMOVE_CREATOR", errorMsg, {"userId": memberId});
            } else {
                return createErrorResponse("REMOVE_MEMBER_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Member removed from group successfully");
    }

    # List tasks for a specific group
    #
    # + req - HTTP request with auth token
    # + groupId - ID of group to list tasks for
    # + status - Filter by status
    # + priority - Filter by priority
    # + page - Page number (default: 1)
    # + pageSize - Number of items per page (default: 10)
    # + sortBy - Field to sort by (default: dueDate)
    # + sortOrder - Sort order (default: asc)
    # + return - Paginated list of group tasks
    resource function get groups/[string groupId]/tasks(
            http:Request req,
            string? status = (),
            string? priority = (),
            int page = 1,
            int pageSize = 10,
            string sortBy = "dueDate",
            string sortOrder = "asc"
) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Convert query parameters to filter options
        TaskFilterOptions filters = {
            groupId: groupId, // Set group ID filter
            page: page,
            pageSize: pageSize
        };

        // Parse and validate sortBy parameter
        match sortBy.toLowerAscii() {
            "duedate" => {
                filters.sortBy = DUE_DATE;
            }
            "priority" => {
                filters.sortBy = PRIORITY;
            }
            "status" => {
                filters.sortBy = STATUS;
            }
            "createdat" => {
                filters.sortBy = CREATED_AT;
            }
            "updatedat" => {
                filters.sortBy = UPDATED_AT;
            }
            "title" => {
                filters.sortBy = TITLE;
            }
            _ => {
                filters.sortBy = DUE_DATE;
            } // Default
        }

        // Parse and validate sortOrder parameter
        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // Parse status filter
        if (status is string) {
            match status.toUpperAscii() {
                "TODO" => {
                    filters.status = TODO;
                }
                "IN_PROGRESS" => {
                    filters.status = IN_PROGRESS;
                }
                "DONE" => {
                    filters.status = DONE;
                }
            }
        }

        // Parse priority filter
        if (priority is string) {
            match priority.toUpperAscii() {
                "LOW" => {
                    filters.priority = LOW;
                }
                "MEDIUM" => {
                    filters.priority = MEDIUM;
                }
                "HIGH" => {
                    filters.priority = HIGH;
                }
            }
        }

        PaginatedTaskResponse|error result = self.taskService.listGroupTasks(userId, groupId, filters);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"groupId": groupId});
            } else {
                return createErrorResponse("GROUP_TASKS_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Group tasks retrieved successfully");
    }

    # Create a task in a group
    #
    # + req - HTTP request with auth token
    # + groupId - ID of group to create task in
    # + request - Task creation request
    # + return - Created task or error
    resource function post groups/[string groupId]/tasks(http:Request req, @http:Payload CreateTaskRequest request) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return createErrorResponse("AUTH_REQUIRED", "Authentication required");
        }

        // Set the group ID in the request
        CreateTaskRequest groupTaskRequest = request.clone();
        groupTaskRequest.groupId = groupId;

        TaskResponse|error result = self.taskService.createTask(userId, groupTaskRequest);

        if result is error {
            string errorMsg = result.message();

            if (errorMsg.includes("Not authorized")) {
                return createErrorResponse("UNAUTHORIZED", errorMsg, {"groupId": groupId});
            } else if (errorMsg.includes("Title is required")) {
                return createErrorResponse("MISSING_FIELD", errorMsg, {"field": "title"});
            } else if (errorMsg.includes("Due date is required")) {
                return createErrorResponse("MISSING_FIELD", errorMsg, {"field": "dueDate"});
            } else if (errorMsg.includes("Invalid date")) {
                return createErrorResponse("INVALID_DATE", errorMsg, {"field": "dueDate"});
            } else if (errorMsg.includes("Assigned user not found")) {
                return createErrorResponse("USER_NOT_FOUND", errorMsg, {"field": "assignedTo"});
            } else if (errorMsg.includes("Cannot assign task to a user who is not a member")) {
                return createErrorResponse("NOT_GROUP_MEMBER", errorMsg, {"field": "assignedTo"});
            } else {
                return createErrorResponse("TASK_CREATION_FAILED", errorMsg);
            }
        }

        return createSuccessResponse(result, "Group task created successfully");
    }
}
