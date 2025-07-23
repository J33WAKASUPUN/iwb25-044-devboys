// main.bal
import ballerina/http;
import ballerina/log;
import ballerina/os;
import ballerinax/mongodb;

// MongoDB configuration
final string mongoUri = os:getEnv("MONGODB_URI");
final string dbName = os:getEnv("DB_NAME");

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

        // Get user's tasks
        TaskFilterOptions filters = {
            createdBy: userId
        };

        TaskResponse[]|error tasks = self.taskService.listTasks(userId, filters);

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
            "tasks": tasks
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

    # List tasks with optional filtering
    #
    # + req - HTTP request with auth token
    # + status - Filter by status
    # + priority - Filter by priority
    # + startDate - Filter by due date range (start)
    # + endDate - Filter by due date range (end)
    # + assignedTo - Filter by assignee
    # + createdBy - Filter by creator
    # + return - List of tasks or error
    resource function get tasks(
            http:Request req,
            string? status = (),
            string? priority = (),
            string? startDate = (),
            string? endDate = (),
            string? assignedTo = (),
            string? createdBy = ()
) returns TaskResponse[]|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        // Convert query parameters to filter options
        TaskFilterOptions filters = {};

        if (status is string) {
            match status {
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

        if (priority is string) {
            match priority {
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

        filters.startDate = startDate;
        filters.endDate = endDate;
        filters.assignedTo = assignedTo;
        filters.createdBy = createdBy;

        return self.taskService.listTasks(userId, filters);
    }

    # Get tasks assigned to the authenticated user
    #
    # + req - HTTP request with auth token
    # + return - List of assigned tasks or error
    resource function get tasks/assigned(http:Request req) returns TaskResponse[]|error {
        // Check authentication
        string|error userId = extractUserIdFromToken(req);

        if userId is error {
            return error("Authentication required");
        }

        TaskFilterOptions filters = {
            assignedTo: userId
        };

        return self.taskService.listTasks(userId, filters);
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

    # Admin endpoint: Get all tasks (admin only)
    #
    # + req - HTTP request with auth token
    # + return - List of all tasks or error
    resource function get admin/tasks(http:Request req) returns TaskResponse[]|error {
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

        // Directly fetch all tasks from the database without filtering
        stream<Task, error?> taskStream = check self.taskCollection->find({});

        TaskResponse[] tasks = [];
        check from Task task in taskStream
            do {
                // Convert each task to a response
                TaskResponse response = check self.taskService.getTaskById(task.id);
                tasks.push(response);
            };

        return tasks;
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
                createdBy: user.id
            };

            TaskResponse[] userTasks = check self.taskService.listTasks(userId, filters);
            tasksPerUser[user.name] = userTasks.length();
        }

        // Return enhanced statistics
        return {
            "basicStats": stats,
            "tasksPerUser": tasksPerUser
        };
    }

    # Search tasks by text
    #
    # + req - HTTP request with auth token
    # + query - Search query
    # + return - Matching tasks or error
    resource function get tasks/search(http:Request req, string query) returns TaskResponse[]|error {
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

        // Search tasks with appropriate permissions
        return self.taskService.searchTasks(userId, query, isAdmin);
    }
}