import ballerina/http;
import ballerina/log;
import ballerinax/mongodb;

// MongoDB configuration using configurable values
configurable string mongodb_uri = ?;
configurable string db_name = ?;
configurable string jwt_secret = ?;

// Define variables used throughout the code
final string mongoUri = mongodb_uri;
final string dbName = db_name;

// Service configuration
service / on new http:Listener(9090) {
    private final mongodb:Client mongoClient;
    private final mongodb:Database db;
    private final mongodb:Collection userCollection;
    private final mongodb:Collection taskCollection;
    private final UserService userService;
    private final TaskService taskService;

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
            // Initialize MongoDB with proper connection config
            self.mongoClient = check new mongodb:Client({
                connection: mongoUri
            });

            log:printInfo("MongoDB client initialized successfully");

            self.db = check self.mongoClient->getDatabase(dbName);
            self.userCollection = check self.db->getCollection("users");
            self.taskCollection = check self.db->getCollection("tasks");

            // Create index for unique email - fixed format
            check self.userCollection->createIndex({
                email: 1
            }, {
                unique: true
            });

            // Initialize services
            self.userService = new UserService(self.userCollection);
            self.taskService = new TaskService(self.taskCollection, self.userService);

            log:printInfo("MongoDB connected successfully");
            log:printInfo("Server running on http://localhost:9090");
        } on fail error e {
            log:printError("Failed to initialize MongoDB: " + e.message());
            return e;
        }
    }

    # User registration endpoint
    #
    # + request - Registration request
    # + return - Response with user info and token
    resource function post auth/register(@http:Payload RegisterRequest request) returns AuthResponse|error {
        return self.userService.register(request);
    }

    # User login endpoint
    #
    # + request - Login request
    # + return - Response with user info and token
    resource function post auth/login(@http:Payload LoginRequest request) returns AuthResponse|error {
        return self.userService.login(request);
    }

    # Protected endpoint - Get user profile
    #
    # + req - HTTP request
    # + return - User profile or error response
    resource function get profile(http:Request req) returns json|error {
        // Check authentication using middleware
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return <json>{
                "error": true,
                "message": userId.message()
            };
        }

        // Get user profile
        UserResponse|error profile = self.userService.getUserProfile(userId);

        if profile is error {
            return <json>{
                "error": true,
                "message": profile.message()
            };
        }

        // Get user's tasks with basic pagination
        TaskFilterOptions filters = {
            createdBy: userId,
            page: 1,
            pageSize: 5
        };

        PaginatedTaskResponse|error tasks = self.taskService.listTasks(userId, filters);

        if tasks is error {
            return <json>{
                "error": true,
                "message": tasks.message()
            };
        }

        // Return user profile with tasks
        return <json>{
            "id": profile.id,
            "email": profile.email,
            "name": profile.name,
            "role": profile.role,
            "timezone": profile.timezone,
            "tasks": tasks.tasks,
            "tasksPagination": tasks.pagination
        };
    }

    # Create a new task
    #
    # + req - HTTP request with auth token
    # + request - Task creation request
    # + return - Created task or error
    resource function post tasks(http:Request req, @http:Payload CreateTaskRequest request) returns TaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        return self.taskService.createTask(userId, request);
    }

    # Update an existing task
    #
    # + req - HTTP request with auth token
    # + taskId - ID of task to update
    # + request - Task update request
    # + return - Updated task or error
    resource function put tasks/[string taskId](http:Request req, @http:Payload UpdateTaskRequest request) returns TaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        return self.taskService.updateTask(userId, taskId, request);
    }

    # Delete a task
    #
    # + req - HTTP request with auth token
    # + taskId - ID of task to delete
    # + return - Success message or error
    resource function delete tasks/[string taskId](http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        boolean|error result = self.taskService.deleteTask(userId, taskId);

        if result is error {
            return error(result.message());
        }

        return {
            "success": true,
            "message": "Task deleted successfully"
        };
    }

    # Get a task by ID
    #
    # + req - HTTP request with auth token
    # + taskId - ID of task to retrieve
    # + return - Task details or error
    resource function get tasks/[string taskId](http:Request req) returns TaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        return self.taskService.getTaskById(taskId);
    }

    # List tasks with pagination, filtering, and sorting
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
    ) returns PaginatedTaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Convert query parameters to filter options
        TaskFilterOptions filters = {
            page: page,
            pageSize: pageSize
        };

        // Parse and validate sortBy parameter
        match sortBy.toLowerAscii() {
            "duedate" => { filters.sortBy = DUE_DATE; }
            "priority" => { filters.sortBy = PRIORITY; }
            "status" => { filters.sortBy = STATUS; }
            "createdat" => { filters.sortBy = CREATED_AT; }
            "updatedat" => { filters.sortBy = UPDATED_AT; }
            "title" => { filters.sortBy = TITLE; }
            _ => { filters.sortBy = DUE_DATE; } // Default
        }

        // Parse and validate sortOrder parameter
        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // Parse status filter
        if (status is string) {
            match status.toUpperAscii() {
                "TODO" => { filters.status = TODO; }
                "IN_PROGRESS" => { filters.status = IN_PROGRESS; }
                "DONE" => { filters.status = DONE; }
            }
        }

        // Parse priority filter
        if (priority is string) {
            match priority.toUpperAscii() {
                "LOW" => { filters.priority = LOW; }
                "MEDIUM" => { filters.priority = MEDIUM; }
                "HIGH" => { filters.priority = HIGH; }
            }
        }

        // Set other filters
        filters.startDate = startDate;
        filters.endDate = endDate;
        filters.assignedTo = assignedTo;
        filters.createdBy = createdBy;

        return self.taskService.listTasks(userId, filters);
    }

    # Get tasks assigned to the authenticated user
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
    ) returns PaginatedTaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        TaskFilterOptions filters = {
            assignedTo: userId,
            page: page,
            pageSize: pageSize
        };

        // Parse sort parameters
        match sortBy.toLowerAscii() {
            "duedate" => { filters.sortBy = DUE_DATE; }
            "priority" => { filters.sortBy = PRIORITY; }
            "status" => { filters.sortBy = STATUS; }
            "createdat" => { filters.sortBy = CREATED_AT; }
            "updatedat" => { filters.sortBy = UPDATED_AT; }
            "title" => { filters.sortBy = TITLE; }
            _ => { filters.sortBy = DUE_DATE; }
        }

        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        return self.taskService.listTasks(userId, filters);
    }

    # Batch delete multiple tasks
    #
    # + req - HTTP request with auth token
    # + request - Batch delete request with task IDs
    # + return - Batch operation result
    resource function delete tasks/batch(http:Request req, @http:Payload BatchDeleteTasksRequest request) returns BatchOperationResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Validate request
        if (request.taskIds.length() == 0) {
            return error("At least one task ID must be provided");
        }

        if (request.taskIds.length() > 50) {
            return error("Cannot delete more than 50 tasks at once");
        }

        // Perform batch delete
        BatchOperationResult result = check self.taskService.batchDeleteTasks(userId, request.taskIds);

        // Create response
        string message = string `Batch delete completed: ${result.successful} successful, ${result.failed} failed`;
        
        return {
            success: result.failed == 0,
            message: message,
            result: result
        };
    }

    # Batch update status of multiple tasks
    #
    # + req - HTTP request with auth token
    # + request - Batch update request with task IDs and new status
    # + return - Batch operation result
    resource function put tasks/batch/status(http:Request req, @http:Payload BatchUpdateStatusRequest request) returns BatchOperationResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Validate request
        if (request.taskIds.length() == 0) {
            return error("At least one task ID must be provided");
        }

        if (request.taskIds.length() > 50) {
            return error("Cannot update more than 50 tasks at once");
        }

        // Perform batch status update
        BatchOperationResult result = check self.taskService.batchUpdateTaskStatus(userId, request.taskIds, request.status);

        // Create response
        string statusStr = <string>request.status;
        string message = string `Batch status update to ${statusStr} completed: ${result.successful} successful, ${result.failed} failed`;
        
        return {
            success: result.failed == 0,
            message: message,
            result: result
        };
    }

    # Search tasks by text with pagination
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
    ) returns PaginatedTaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Validate search query
        if (query.trim() == "") {
            return error("Search query cannot be empty");
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
            "duedate" => { filters.sortBy = DUE_DATE; }
            "priority" => { filters.sortBy = PRIORITY; }
            "status" => { filters.sortBy = STATUS; }
            "createdat" => { filters.sortBy = CREATED_AT; }
            "updatedat" => { filters.sortBy = UPDATED_AT; }
            "title" => { filters.sortBy = TITLE; }
            _ => { filters.sortBy = DUE_DATE; }
        }

        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // Search tasks with appropriate permissions
        return self.taskService.searchTasks(userId, query, filters, isAdmin);
    }

    # Admin endpoint: Get all users (admin only)
    #
    # + req - HTTP request with auth token
    # + return - List of all users or error
    resource function get admin/users(http:Request req) returns UserResponse[]|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return error(isAdmin.message());
        }

        // Get all users
        return self.userService.getAllUsers();
    }

    # Admin endpoint: Get all tasks with pagination (admin only)
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
    ) returns PaginatedTaskResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return error(isAdmin.message());
        }

        // Setup filter options for admin view (no access restrictions)
        TaskFilterOptions filters = {
            page: page,
            pageSize: pageSize
        };

        // Parse sort parameters
        match sortBy.toLowerAscii() {
            "duedate" => { filters.sortBy = DUE_DATE; }
            "priority" => { filters.sortBy = PRIORITY; }
            "status" => { filters.sortBy = STATUS; }
            "createdat" => { filters.sortBy = CREATED_AT; }
            "updatedat" => { filters.sortBy = UPDATED_AT; }
            "title" => { filters.sortBy = TITLE; }
            _ => { filters.sortBy = DUE_DATE; }
        }

        filters.sortOrder = sortOrder.toLowerAscii() == "desc" ? DESC : ASC;

        // For admin, we need to modify the listTasks method or create a separate admin method
        // For now, let's use a workaround by getting all tasks without user restrictions
        return self.getAdminTasks(filters);
    }

    # Admin endpoint: Change user role (admin only)
    #
    # + req - HTTP request with auth token
    # + userId - ID of user to update
    # + role - New role (USER or ADMIN)
    # + return - Updated user or error
    resource function put admin/users/[string userId]/role(http:Request req, string role) returns UserResponse|error {
        // Check authentication
        string|error adminId = extractUserIdFromToken(req);

        if adminId is error {
            return error("Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(adminId);

        if isAdmin is error {
            return error(isAdmin.message());
        }

        // Validate role
        if (role != "USER" && role != "ADMIN") {
            return error("Invalid role: must be USER or ADMIN");
        }

        // Find user to update
        User? user = check self.userService.findUserById(userId);

        if user is () {
            return error("User not found");
        }

        // Use the findOneAndUpdate approach instead
        map<json> filter = {"id": userId};
        mongodb:Update update = {
            set: {"role": role}
        };

        // Fetch the collection and DB directly
        mongodb:Collection usersCollection = check self.db->getCollection("users");
        _ = check usersCollection->updateOne(filter, update);

        // Return updated user
        return self.userService.getUserProfile(userId);
    }

    # Get task statistics
    #
    # + req - HTTP request with auth token
    # + return - Task statistics or error
    resource function get stats/tasks(http:Request req) returns TaskStatistics|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Check if user is admin
        boolean isAdmin = false;
        boolean|error adminCheck = self.userService.checkAdminRole(userId);
        if adminCheck is boolean {
            isAdmin = true;
        }

        // Get statistics with appropriate permissions
        return self.taskService.getTaskStatistics(userId, isAdmin);
    }

    # Admin endpoint: Get detailed task statistics (admin only)
    #
    # + req - HTTP request with auth token
    # + return - Task statistics or error
    resource function get admin/stats/tasks(http:Request req) returns json|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Check admin role
        boolean|error isAdmin = self.userService.checkAdminRole(userId);

        if isAdmin is error {
            return error(isAdmin.message());
        }

        // Get base statistics
        TaskStatistics stats = check self.taskService.getTaskStatistics(userId, true);

        // Get all users for additional statistics
        UserResponse[] users = check self.userService.getAllUsers();

        // Count tasks per user
        map<json> tasksPerUser = {};

        foreach UserResponse user in users {
            TaskFilterOptions filters = {
                createdBy: user.id,
                page: 1,
                pageSize: 1000 // Get all tasks for counting
            };

            PaginatedTaskResponse userTasks = check self.taskService.listTasks(user.id, filters);
            tasksPerUser[user.name] = userTasks.pagination.totalItems;
        }

        // Return enhanced statistics
        return {
            "basicStats": stats,
            "tasksPerUser": tasksPerUser
        };
    }

    # Update user timezone
    #
    # + req - HTTP request with auth token
    # + timezone - New timezone value
    # + return - Updated user profile or error
    resource function put profile/timezone(http:Request req, string timezone) returns UserResponse|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Update the timezone
        return self.userService.updateUserTimezone(userId, timezone);
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
}