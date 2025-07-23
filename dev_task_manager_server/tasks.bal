// tasks.bal
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

# Task service for managing task operations
public class TaskService {
    private final mongodb:Collection taskCollection;
    private final UserService userService;

    # Initialize task service
    #
    # + taskCollection - MongoDB collection for task data
    # + userService - User service for user operations
    public function init(mongodb:Collection taskCollection, UserService userService) {
        self.taskCollection = taskCollection;
        self.userService = userService;
    }

    # Create a new task
    #
    # + userId - ID of user creating the task
    # + request - Task creation data
    # + return - Created task data
    public function createTask(string userId, CreateTaskRequest request) returns TaskResponse|error {
        log:printInfo("Creating new task: " + request.title);

        // Validate request
        if (request.title == "") {
            return error("Title is required");
        }

        if (request.dueDate == "") {
            return error("Due date is required");
        }

        // Validate assignee if provided
        if (request.assignedTo is string) {
            string assigneeId = <string>request.assignedTo;
            User? assignee = check self.userService.findUserById(assigneeId);

            if assignee is () {
                return error("Assigned user not found");
            }
        }

        // Create task
        string id = uuid:createType1AsString();
        string currentTime = time:utcToString(time:utcNow());

        Task newTask = {
            id: id,
            title: request.title,
            description: request.description,
            status: TODO,
            dueDate: request.dueDate,
            priority: request.priority,
            createdBy: userId,
            assignedTo: request.assignedTo,
            createdAt: currentTime,
            updatedAt: currentTime
        };

        // Save task
        check self.taskCollection->insertOne(newTask);
        log:printInfo("Task created successfully: " + id);

        // Return enriched task data
        return check self.getTaskResponseById(id);
    }

    # Update an existing task
    #
    # + userId - ID of user updating the task
    # + taskId - ID of task to update
    # + request - Task update data
    # + return - Updated task data
    public function updateTask(string userId, string taskId, UpdateTaskRequest request) returns TaskResponse|error {
        log:printInfo("Updating task: " + taskId);

        // Find task
        Task? existingTask = check self.findTaskById(taskId);

        if existingTask is () {
            return error("Task not found");
        }

        // Check permissions (only creator or assignee can update)
        if (existingTask.createdBy != userId && existingTask.assignedTo != userId) {
            return error("Not authorized to update this task");
        }

        // Build update document
        map<json> updateDoc = {};

        if (request.title is string) {
            updateDoc["title"] = <string>request.title;
        }

        if (request.description is string) {
            updateDoc["description"] = <string>request.description;
        }

        if (request.status is TaskStatus) {
            updateDoc["status"] = <string>request.status;
        }

        if (request.dueDate is string) {
            updateDoc["dueDate"] = <string>request.dueDate;
        }

        if (request.priority is TaskPriority) {
            updateDoc["priority"] = <string>request.priority;
        }

        if (request.assignedTo is string) {
            // Validate assignee
            string assigneeId = <string>request.assignedTo;
            User? assignee = check self.userService.findUserById(assigneeId);

            if assignee is () {
                return error("Assigned user not found");
            }

            updateDoc["assignedTo"] = assigneeId;
        }

        // Add updated timestamp
        updateDoc["updatedAt"] = time:utcToString(time:utcNow());

        // Perform update
        map<json> filter = {"id": taskId};
        mongodb:Update update = {
            set: updateDoc
        };

        _ = check self.taskCollection->updateOne(filter, update);
        log:printInfo("Task updated successfully: " + taskId);

        // Return updated task
        return check self.getTaskResponseById(taskId);
    }

    # Delete a task
    #
    # + userId - ID of user deleting the task
    # + taskId - ID of task to delete
    # + return - Success or error
    public function deleteTask(string userId, string taskId) returns boolean|error {
        log:printInfo("Deleting task: " + taskId);

        // Find task
        Task? task = check self.findTaskById(taskId);

        if task is () {
            return error("Task not found");
        }

        // Check permissions (only creator can delete)
        if (task.createdBy != userId) {
            return error("Not authorized to delete this task");
        }

        // Delete task
        map<json> filter = {"id": taskId};
        _ = check self.taskCollection->deleteOne(filter);

        log:printInfo("Task deleted successfully: " + taskId);
        return true;
    }

    # Get a task by ID
    #
    # + taskId - Task ID to retrieve
    # + return - Task response or error
    public function getTaskById(string taskId) returns TaskResponse|error {
        return self.getTaskResponseById(taskId);
    }

    # List tasks with optional filtering
    #
    # + userId - ID of user listing tasks
    # + filters - Optional filters to apply
    # + return - Array of task responses
    public function listTasks(string userId, TaskFilterOptions filters) returns TaskResponse[]|error {
        log:printInfo("Listing tasks for user: " + userId);

        // Build filter
        map<json> filter = {};

        // Base filter - tasks are visible to creator or assignee
        json[] accessConditions = [
            {"createdBy": userId},
            {"assignedTo": userId}
        ];
        filter["$or"] = accessConditions;

        // Apply additional filters
        if (filters.status is TaskStatus) {
            filter["status"] = <string>filters.status;
        }

        if (filters.priority is TaskPriority) {
            filter["priority"] = <string>filters.priority;
        }

        if (filters.assignedTo is string) {
            filter["assignedTo"] = <string>filters.assignedTo;
        }

        if (filters.createdBy is string) {
            filter["createdBy"] = <string>filters.createdBy;
        }

        // Date range filter
        if (filters.startDate is string && filters.endDate is string) {
            filter["dueDate"] = {
                "$gte": <string>filters.startDate,
                "$lte": <string>filters.endDate
            };
        } else if (filters.startDate is string) {
            filter["dueDate"] = {"$gte": <string>filters.startDate};
        } else if (filters.endDate is string) {
            filter["dueDate"] = {"$lte": <string>filters.endDate};
        }

        // Query tasks
        stream<Task, error?> taskStream = check self.taskCollection->find(filter);

        // Convert tasks to responses
        TaskResponse[] responses = [];
        error? err = from Task task in taskStream
            do {
                TaskResponse response = check self.convertTaskToResponse(task);
                responses.push(response);
            };

        if (err is error) {
            return err;
        }

        return responses;
    }

    # Find task by ID
    #
    # + id - Task ID
    # + return - Task or nil
    private function findTaskById(string id) returns Task?|error {
        map<json> filter = {"id": id};
        return check self.taskCollection->findOne(filter);
    }

    # Get full task response by ID
    #
    # + id - Task ID
    # + return - Task response with user details
    private function getTaskResponseById(string id) returns TaskResponse|error {
        Task? task = check self.findTaskById(id);

        if task is () {
            return error("Task not found");
        }

        return self.convertTaskToResponse(task);
    }

    # Convert task to response with user details
    #
    # + task - Task record
    # + return - Task response
    public function convertTaskToResponse(Task task) returns TaskResponse|error {
        // Get creator info
        UserResponse creator = check self.userService.getUserProfile(task.createdBy);

        // Get assignee info if present
        UserResponse? assignee = ();
        if (task.assignedTo is string) {
            assignee = check self.userService.getUserProfile(<string>task.assignedTo);
        }

        return {
            id: task.id,
            title: task.title,
            description: task.description,
            status: <string>task.status,
            dueDate: task.dueDate,
            priority: <string>task.priority,
            createdBy: creator,
            assignedTo: assignee,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt
        };
    }

    # Get task statistics
    #
    # + userId - ID of user requesting statistics
    # + isAdmin - Whether the user is an admin
    # + return - Task statistics
    public function getTaskStatistics(string userId, boolean isAdmin = false) returns TaskStatistics|error {
        log:printInfo("Getting task statistics for user: " + userId);

        // Build filter based on user role
        map<json> filter = {};
        if (!isAdmin) {
            // Regular users only see their own tasks
            json[] accessConditions = [
                {"createdBy": userId},
                {"assignedTo": userId}
            ];
            filter["$or"] = accessConditions;
        }

        // Query tasks
        stream<Task, error?> taskStream = check self.taskCollection->find(filter);

        // Initialize counters
        int todoCount = 0;
        int inProgressCount = 0;
        int doneCount = 0;

        int highPriorityCount = 0;
        int mediumPriorityCount = 0;
        int lowPriorityCount = 0;

        int overdueCount = 0;
        string currentDate = time:utcToString(time:utcNow()).substring(0, 10); // YYYY-MM-DD

        // Process tasks
        error? err = from Task task in taskStream
            do {
                // Count by status
                if (task.status == TODO) {
                    todoCount += 1;
                } else if (task.status == IN_PROGRESS) {
                    inProgressCount += 1;
                } else if (task.status == DONE) {
                    doneCount += 1;
                }

                // Count by priority
                if (task.priority == HIGH) {
                    highPriorityCount += 1;
                } else if (task.priority == MEDIUM) {
                    mediumPriorityCount += 1;
                } else if (task.priority == LOW) {
                    lowPriorityCount += 1;
                }

                // Check if task is overdue
                if (task.status != DONE && task.dueDate < currentDate) {
                    overdueCount += 1;
                }
            };

        if (err is error) {
            return err;
        }

        return {
            total: todoCount + inProgressCount + doneCount,
            byStatus: {
                TODO: todoCount,
                IN_PROGRESS: inProgressCount,
                DONE: doneCount
            },
            byPriority: {
                LOW: lowPriorityCount,
                MEDIUM: mediumPriorityCount,
                HIGH: highPriorityCount
            },
            overdue: overdueCount
        };
    }

    # Search tasks by text
    #
    # + userId - ID of user searching tasks
    # + query - Search query
    # + isAdmin - Whether the user is an admin
    # + return - Matching tasks
    public function searchTasks(string userId, string query, boolean isAdmin = false) returns TaskResponse[]|error {
        log:printInfo("Searching tasks with query: " + query);

        // Build the base filter
        map<json> filter = {};

        // Only admins can see all tasks
        if (!isAdmin) {
            // Regular users only see their own tasks
            json[] accessConditions = [
                {"createdBy": userId},
                {"assignedTo": userId}
            ];
            filter["$or"] = accessConditions;
        }

        // Query tasks directly as Task objects
        stream<Task, error?> taskStream = check self.taskCollection->find(filter);

        // Filter tasks in memory based on search query
        TaskResponse[] responses = [];
        string lowercaseQuery = query.toLowerAscii();

        check from Task task in taskStream
            do {
                // Check if title or description contains the search term (case-insensitive)
                if (task.title.toLowerAscii().includes(lowercaseQuery) ||
                task.description.toLowerAscii().includes(lowercaseQuery)) {

                    // Get creator info
                    UserResponse creator = check self.userService.getUserProfile(task.createdBy);

                    // Get assignee info if present
                    UserResponse? assignee = ();
                    if (task.assignedTo is string) {
                        assignee = check self.userService.getUserProfile(<string>task.assignedTo);
                    }

                    TaskResponse response = {
                        id: task.id,
                        title: task.title,
                        description: task.description,
                        status: <string>task.status,
                        dueDate: task.dueDate,
                        priority: <string>task.priority,
                        createdBy: creator,
                        assignedTo: assignee,
                        createdAt: task.createdAt,
                        updatedAt: task.updatedAt
                    };

                    responses.push(response);
                }
            };

        return responses;
    }
}
