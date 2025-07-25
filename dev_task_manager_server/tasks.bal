import ballerina/log;
import ballerina/regex as re;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

# Validation Helper Functions

# Validate task title
#
# + title - Task title to validate
# + return - Error if invalid, nil if valid
function validateTaskTitle(string title) returns error? {
    if (title.trim() == "") {
        return error("Title cannot be empty");
    }

    if (title.length() < 3) {
        return error("Title must be at least 3 characters long");
    }

    if (title.length() > 200) {
        return error("Title cannot exceed 200 characters");
    }

    // Check for invalid characters using string.includes()
    if (title.includes("<") || title.includes(">") || title.includes("\"") ||
        title.includes("'") || title.includes("&")) {
        return error("Title contains invalid characters (< > \" ' &)");
    }
}

# Validate task description
#
# + description - Task description to validate
# + return - Error if invalid, nil if valid
function validateTaskDescription(string description) returns error? {
    if (description.length() > 2000) {
        return error("Description cannot exceed 2000 characters");
    }

    // Check for invalid characters using string.includes()
    if (description.includes("<") || description.includes(">") || description.includes("\"") ||
        description.includes("'") || description.includes("&")) {
        return error("Description contains invalid characters (< > \" ' &)");
    }
}

# Validate due date with enhanced checks
#
# + dueDate - Due date string to validate
# + return - Error if invalid, nil if valid
function validateEnhancedDate(string dueDate) returns error? {
    // First check basic format
    DateValidationError? basicError = validateDate(dueDate);
    if (basicError is DateValidationError) {
        return error(basicError.message);
    }

    // Enhanced validation: Check if date is not too far in past
    string currentDate = time:utcToString(time:utcNow()).substring(0, 10); // YYYY-MM-DD

    // Allow tasks to be created with past due dates (for importing old tasks)
    // but warn if it's more than 1 year in the past
    if (dueDate < currentDate) {
        // Parse dates to check the difference
        string[] dueParts = re:split(dueDate, "-");
        string[] currentParts = re:split(currentDate, "-");

        if (dueParts.length() == 3 && currentParts.length() == 3) {
            int|error dueYear = int:fromString(dueParts[0]);
            int|error currentYear = int:fromString(currentParts[0]);

            if (dueYear is int && currentYear is int) {
                if (currentYear - dueYear > 1) {
                    return error("Due date cannot be more than 1 year in the past");
                }
            }
        }
    }

    // Check if date is not too far in future (10 years)
    string[] dueParts = re:split(dueDate, "-");
    string[] currentParts = re:split(currentDate, "-");

    if (dueParts.length() == 3 && currentParts.length() == 3) {
        int|error dueYear = int:fromString(dueParts[0]);
        int|error currentYear = int:fromString(currentParts[0]);

        if (dueYear is int && currentYear is int) {
            if (dueYear - currentYear > 10) {
                return error("Due date cannot be more than 10 years in the future");
            }
        }
    }
}

# Validate task ID format
#
# + taskId - Task ID to validate
# + return - Error if invalid, nil if valid
function validateTaskId(string taskId) returns error? {
    if (taskId.trim() == "") {
        return error("Task ID cannot be empty");
    }

    if (taskId.length() < 10) {
        return error("Invalid task ID format");
    }

    // Simple UUID-like validation using character iteration
    foreach string:Char char in taskId {
        string charStr = char.toString();
        if (!(charStr >= "0" && charStr <= "9") &&
            !(charStr >= "a" && charStr <= "f") &&
            !(charStr >= "A" && charStr <= "F") &&
            charStr != "-") {
            return error("Task ID contains invalid characters");
        }
    }
}

# Validate pagination parameters
#
# + page - Page number
# + pageSize - Page size
# + return - Error if invalid, nil if valid
function validatePagination(int page, int pageSize) returns error? {
    if (page < 1) {
        return error("Page number must be greater than 0");
    }

    if (pageSize < 1) {
        return error("Page size must be greater than 0");
    }

    if (pageSize > 100) {
        return error("Page size cannot exceed 100 items");
    }
}

# Validate search query
#
# + query - Search query to validate
# + return - Error if invalid, nil if valid
function validateSearchQuery(string query) returns error? {
    string trimmedQuery = query.trim();

    if (trimmedQuery == "") {
        return error("Search query cannot be empty");
    }

    if (trimmedQuery.length() < 2) {
        return error("Search query must be at least 2 characters long");
    }

    if (trimmedQuery.length() > 100) {
        return error("Search query cannot exceed 100 characters");
    }

    // Check for dangerous patterns using string.includes()
    string lowercaseQuery = trimmedQuery.toLowerAscii();
    string[] dangerousPatterns = ["'", "\"", ";", "--", "/*", "*/", "drop", "delete", "insert", "update", "select"];

    foreach string pattern in dangerousPatterns {
        if (lowercaseQuery.includes(pattern)) {
            return error("Search query contains invalid characters or SQL keywords");
        }
    }
}

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

    # Create a new task (WITH Enhanced Validation)
    #
    # + userId - ID of user creating the task
    # + request - Task creation data
    # + return - Created task data
    public function createTask(string userId, CreateTaskRequest request) returns TaskResponse|error {
        log:printInfo("Creating new task: " + request.title);

        // ✅ Enhanced validation
        check validateTaskTitle(request.title);
        check validateTaskDescription(request.description);
        check validateEnhancedDate(request.dueDate);

        // Validate assignee if provided
        if (request.assignedTo is string) {
            string assigneeId = <string>request.assignedTo;

            // Basic ID format validation
            if (assigneeId.trim() == "") {
                return error("Assigned user ID cannot be empty");
            }

            User? assignee = check self.userService.findUserById(assigneeId);

            if assignee is () {
                return error("Assigned user not found with ID: " + assigneeId);
            }
        }

        // Get user timezone or use provided timezone
        UserResponse userProfile = check self.userService.getUserProfile(userId);
        string taskTimezone = userProfile.timezone;

        if (request.timezone is string) {
            string requestedTimezone = <string>request.timezone;
            if (validTimezones.indexOf(requestedTimezone) != -1) {
                taskTimezone = requestedTimezone;
            } else {
                return error("Invalid timezone: " + requestedTimezone + ". Must be one of: " + validTimezones.toString());
            }
        }

        // Create task
        string id = uuid:createType1AsString();
        string currentTime = time:utcToString(time:utcNow());

        Task newTask = {
            id: id,
            title: request.title.trim(), // Trim whitespace
            description: request.description.trim(), // Trim whitespace
            status: TODO,
            dueDate: request.dueDate,
            priority: request.priority,
            createdBy: userId,
            assignedTo: request.assignedTo,
            createdAt: currentTime,
            updatedAt: currentTime,
            timezone: taskTimezone
        };

        // Save task
        check self.taskCollection->insertOne(newTask);
        log:printInfo("Task created successfully: " + id);

        // Return enriched task data
        return check self.getTaskResponseById(id);
    }

    # Update an existing task (WITH Enhanced Validation)
    #
    # + userId - ID of user updating the task
    # + taskId - ID of task to update
    # + request - Task update data
    # + return - Updated task data
    public function updateTask(string userId, string taskId, UpdateTaskRequest request) returns TaskResponse|error {
        log:printInfo("Updating task: " + taskId);

        // ✅ Validate task ID format
        check validateTaskId(taskId);

        // Find task
        Task? existingTask = check self.findTaskById(taskId);

        if existingTask is () {
            return error("Task not found with ID: " + taskId);
        }

        // Check permissions (only creator or assignee can update)
        if (existingTask.createdBy != userId && existingTask.assignedTo != userId) {
            return error("Not authorized to update this task. Only creator or assignee can update.");
        }

        // Build update document with validation
        map<json> updateDoc = {};

        if (request.title is string) {
            string title = <string>request.title;
            check validateTaskTitle(title);
            updateDoc["title"] = title.trim();
        }

        if (request.description is string) {
            string description = <string>request.description;
            check validateTaskDescription(description);
            updateDoc["description"] = description.trim();
        }

        if (request.status is TaskStatus) {
            updateDoc["status"] = <string>request.status;
        }

        // Validate due date if provided
        if (request.dueDate is string) {
            string dueDate = <string>request.dueDate;
            check validateEnhancedDate(dueDate);
            updateDoc["dueDate"] = dueDate;
        }

        if (request.priority is TaskPriority) {
            updateDoc["priority"] = <string>request.priority;
        }

        if (request.assignedTo is string) {
            // Validate assignee
            string assigneeId = <string>request.assignedTo;

            if (assigneeId.trim() == "") {
                return error("Assigned user ID cannot be empty");
            }

            User? assignee = check self.userService.findUserById(assigneeId);

            if assignee is () {
                return error("Assigned user not found with ID: " + assigneeId);
            }

            updateDoc["assignedTo"] = assigneeId;
        }

        // Update timezone if provided
        if (request.timezone is string) {
            string requestedTimezone = <string>request.timezone;
            if (validTimezones.indexOf(requestedTimezone) != -1) {
                updateDoc["timezone"] = requestedTimezone;
            } else {
                return error("Invalid timezone: " + requestedTimezone + ". Must be one of: " + validTimezones.toString());
            }
        }

        // Ensure we have something to update
        if (updateDoc.length() == 0) {
            return error("No valid fields provided for update");
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

    # Delete a task (WITH Enhanced Validation)
    #
    # + userId - ID of user deleting the task
    # + taskId - ID of task to delete
    # + return - Success or error
    public function deleteTask(string userId, string taskId) returns boolean|error {
        log:printInfo("Deleting task: " + taskId);

        // ✅ Validate task ID format
        check validateTaskId(taskId);

        // Find task
        Task? task = check self.findTaskById(taskId);

        if task is () {
            return error("Task not found with ID: " + taskId);
        }

        // Check permissions (only creator can delete)
        if (task.createdBy != userId) {
            return error("Not authorized to delete this task. Only the creator can delete tasks.");
        }

        // Delete task
        map<json> filter = {"id": taskId};
        _ = check self.taskCollection->deleteOne(filter);

        log:printInfo("Task deleted successfully: " + taskId);
        return true;
    }

    # Get a task by ID (WITH Enhanced Validation)
    #
    # + taskId - Task ID to retrieve
    # + return - Task response or error
    public function getTaskById(string taskId) returns TaskResponse|error {
        // ✅ Validate task ID format
        check validateTaskId(taskId);

        return self.getTaskResponseById(taskId);
    }

    # List tasks with pagination, filtering, and sorting (WITH Enhanced Validation)
    #
    # + userId - ID of user listing tasks
    # + filters - Filter, pagination, and sorting options
    # + return - Paginated task response
    public function listTasks(string userId, TaskFilterOptions filters) returns PaginatedTaskResponse|error {
        log:printInfo("Listing tasks for user: " + userId + " with pagination");

        // ✅ Validate pagination parameters
        check validatePagination(filters.page, filters.pageSize);

        // Build filter
        map<json> filter = {};

        // Base filter - tasks are visible to creator or assignee
        json[] accessConditions = [
            {"createdBy": userId},
            {"assignedTo": userId}
        ];
        filter["$or"] = accessConditions;

        // Apply additional filters with validation
        if (filters.status is TaskStatus) {
            filter["status"] = <string>filters.status;
        }

        if (filters.priority is TaskPriority) {
            filter["priority"] = <string>filters.priority;
        }

        if (filters.assignedTo is string) {
            string assignedTo = <string>filters.assignedTo;
            if (assignedTo.trim() != "") {
                filter["assignedTo"] = assignedTo;
            }
        }

        if (filters.createdBy is string) {
            string createdBy = <string>filters.createdBy;
            if (createdBy.trim() != "") {
                filter["createdBy"] = createdBy;
            }
        }

        // Validate date range filters
        if (filters.startDate is string) {
            string startDate = <string>filters.startDate;
            check validateEnhancedDate(startDate);
        }

        if (filters.endDate is string) {
            string endDate = <string>filters.endDate;
            check validateEnhancedDate(endDate);
        }

        // Date range filter with logical validation
        if (filters.startDate is string && filters.endDate is string) {
            string startDate = <string>filters.startDate;
            string endDate = <string>filters.endDate;

            // Ensure start date is before end date
            if (startDate > endDate) {
                return error("Start date (" + startDate + ") must be before end date (" + endDate + ")");
            }

            filter["dueDate"] = {
                "$gte": startDate,
                "$lte": endDate
            };
        } else if (filters.startDate is string) {
            filter["dueDate"] = {"$gte": <string>filters.startDate};
        } else if (filters.endDate is string) {
            filter["dueDate"] = {"$lte": <string>filters.endDate};
        }

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

        // Handle priority sorting with custom order
        if (sortField == "priority") {
            // For priority, we'll sort by a mapped value where HIGH=3, MEDIUM=2, LOW=1
            // This requires aggregation pipeline, but for simplicity, we'll use string sort
            sortOptions[sortField] = sortDirection;
        } else {
            sortOptions[sortField] = sortDirection;
        }

        log:printInfo(string `Querying tasks: page=${page}, pageSize=${pageSize}, sortBy=${sortField}, order=${<string>filters.sortOrder}`);

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
                TaskResponse response = check self.convertTaskToResponse(task);
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

    # Batch delete multiple tasks (WITH Enhanced Validation)
    #
    # + userId - ID of user performing the operation
    # + taskIds - Array of task IDs to delete
    # + return - Batch operation result
    public function batchDeleteTasks(string userId, string[] taskIds) returns BatchOperationResult|error {
        log:printInfo("Batch deleting tasks for user: " + userId);

        // ✅ Enhanced validation
        if (taskIds.length() == 0) {
            return error("Task IDs array cannot be empty");
        }

        if (taskIds.length() > 50) {
            return error("Cannot delete more than 50 tasks at once. Provided: " + taskIds.length().toString());
        }

        // Validate each task ID format
        foreach string taskId in taskIds {
            check validateTaskId(taskId);
        }

        // Check for duplicates
        map<boolean> uniqueIds = {};
        foreach string taskId in taskIds {
            if (uniqueIds.hasKey(taskId)) {
                return error("Duplicate task ID found: " + taskId);
            }
            uniqueIds[taskId] = true;
        }

        int successful = 0;
        int failed = 0;
        map<string> errors = {};
        string[] successfulIds = [];
        string[] failedIds = [];

        foreach string taskId in taskIds {
            do {
                boolean|error result = self.deleteTask(userId, taskId);
                if (result is boolean && result) {
                    successful += 1;
                    successfulIds.push(taskId);
                    log:printInfo("Successfully deleted task: " + taskId);
                } else {
                    failed += 1;
                    failedIds.push(taskId);
                    string errorMsg = result is error ? result.message() : "Failed to delete";
                    errors[taskId] = errorMsg;
                    log:printError("Failed to delete task " + taskId + ": " + errorMsg);
                }
            } on fail error e {
                failed += 1;
                failedIds.push(taskId);
                errors[taskId] = e.message();
                log:printError("Error deleting task " + taskId + ": " + e.message());
            }
        }

        return {
            successful: successful,
            failed: failed,
            errors: errors,
            successfulIds: successfulIds,
            failedIds: failedIds
        };
    }

    # Batch update status of multiple tasks (WITH Enhanced Validation)
    #
    # + userId - ID of user performing the operation
    # + taskIds - Array of task IDs to update
    # + status - New status to apply
    # + return - Batch operation result
    public function batchUpdateTaskStatus(string userId, string[] taskIds, TaskStatus status) returns BatchOperationResult|error {
        log:printInfo("Batch updating task status for user: " + userId + " to status: " + <string>status);

        // ✅ Enhanced validation
        if (taskIds.length() == 0) {
            return error("Task IDs array cannot be empty");
        }

        if (taskIds.length() > 50) {
            return error("Cannot update more than 50 tasks at once. Provided: " + taskIds.length().toString());
        }

        // Validate each task ID format
        foreach string taskId in taskIds {
            check validateTaskId(taskId);
        }

        // Check for duplicates
        map<boolean> uniqueIds = {};
        foreach string taskId in taskIds {
            if (uniqueIds.hasKey(taskId)) {
                return error("Duplicate task ID found: " + taskId);
            }
            uniqueIds[taskId] = true;
        }

        int successful = 0;
        int failed = 0;
        map<string> errors = {};
        string[] successfulIds = [];
        string[] failedIds = [];

        foreach string taskId in taskIds {
            do {
                // Create update request with only status
                UpdateTaskRequest updateRequest = {
                    status: status
                };

                TaskResponse|error result = self.updateTask(userId, taskId, updateRequest);
                if (result is TaskResponse) {
                    successful += 1;
                    successfulIds.push(taskId);
                    log:printInfo("Successfully updated task status: " + taskId);
                } else {
                    failed += 1;
                    failedIds.push(taskId);
                    errors[taskId] = result.message();
                    log:printError("Failed to update task " + taskId + ": " + result.message());
                }
            } on fail error e {
                failed += 1;
                failedIds.push(taskId);
                errors[taskId] = e.message();
                log:printError("Error updating task " + taskId + ": " + e.message());
            }
        }

        return {
            successful: successful,
            failed: failed,
            errors: errors,
            successfulIds: successfulIds,
            failedIds: failedIds
        };
    }

    # Search tasks by text with pagination (WITH Enhanced Validation)
    #
    # + userId - ID of user searching tasks
    # + query - Search query
    # + filters - Pagination and sorting options
    # + isAdmin - Whether the user is an admin
    # + return - Paginated search results
    public function searchTasks(string userId, string query, TaskFilterOptions filters, boolean isAdmin = false) returns PaginatedTaskResponse|error {
        log:printInfo("Searching tasks with query: " + query);

        // ✅ Enhanced validation
        check validateSearchQuery(query);
        check validatePagination(filters.page, filters.pageSize);

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

        // Validate and setup pagination
        int page = filters.page < 1 ? 1 : filters.page;
        int pageSize = filters.pageSize < 1 ? 10 : (filters.pageSize > 100 ? 100 : filters.pageSize);
        int skip = (page - 1) * pageSize;

        // Setup sorting
        map<json> sortOptions = {};
        string sortField = <string>filters.sortBy;
        int sortDirection = <string>filters.sortOrder == "desc" ? -1 : 1;
        sortOptions[sortField] = sortDirection;

        // Query all matching tasks first (for search)
        stream<Task, error?> allTasksStream = check self.taskCollection->find(filter);

        // Filter tasks in memory based on search query
        TaskResponse[] allResponses = [];
        string lowercaseQuery = query.toLowerAscii().trim();

        check from Task task in allTasksStream
            do {
                // Check if title or description contains the search term (case-insensitive)
                boolean matchesTitle = task.title.toLowerAscii().includes(lowercaseQuery);
                boolean matchesDescription = task.description.toLowerAscii().includes(lowercaseQuery);

                if (matchesTitle || matchesDescription) {
                    TaskResponse response = check self.convertTaskToResponse(task);
                    allResponses.push(response);
                }
            };

        // Sort the results based on sort options
        TaskResponse[] sortedResponses = self.sortTaskResponses(allResponses, <string>filters.sortBy, <string>filters.sortOrder);

        // Apply pagination to sorted results
        int totalCount = sortedResponses.length();
        int totalPages = totalCount == 0 ? 1 : ((totalCount - 1) / pageSize) + 1;

        TaskResponse[] paginatedResponses = [];
        int endIndex = skip + pageSize;
        if (skip < totalCount) {
            endIndex = endIndex > totalCount ? totalCount : endIndex;
            paginatedResponses = sortedResponses.slice(skip, endIndex);
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
            tasks: paginatedResponses,
            pagination: pagination
        };
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
            return error("Task not found with ID: " + id);
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

        // Check if task is overdue based on current date
        boolean overdue = isTaskOverdue(task.dueDate, <string>task.status);

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
            updatedAt: task.updatedAt,
            timezone: task.timezone,
            isOverdue: overdue
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

        // Get current date for overdue calculation
        string currentDate;
        if (currentSystemDate != "") {
            currentDate = currentSystemDate;
        } else {
            currentDate = time:utcToString(time:utcNow()).substring(0, 10); // YYYY-MM-DD
        }

        log:printInfo("Using current date for statistics: " + currentDate);

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

    # Sort task responses in memory
    #
    # + tasks - Array of task responses to sort
    # + sortBy - Field to sort by
    # + sortOrder - Sort order (asc/desc)
    # + return - Sorted array of task responses
    private function sortTaskResponses(TaskResponse[] tasks, string sortBy, string sortOrder) returns TaskResponse[] {
        // Simple bubble sort implementation for demonstration
        // In production, you might want to use a more efficient sorting algorithm

        TaskResponse[] sortedTasks = tasks.clone();
        int n = sortedTasks.length();

        foreach int i in 0 ..< n - 1 {
            foreach int j in 0 ..< n - i - 1 {
                boolean shouldSwap = false;

                match sortBy {
                    "title" => {
                        shouldSwap = (sortOrder == "asc") ?
                            sortedTasks[j].title > sortedTasks[j + 1].title :
                            sortedTasks[j].title < sortedTasks[j + 1].title;
                    }
                    "dueDate" => {
                        shouldSwap = (sortOrder == "asc") ?
                            sortedTasks[j].dueDate > sortedTasks[j + 1].dueDate :
                            sortedTasks[j].dueDate < sortedTasks[j + 1].dueDate;
                    }
                    "createdAt" => {
                        shouldSwap = (sortOrder == "asc") ?
                            sortedTasks[j].createdAt > sortedTasks[j + 1].createdAt :
                            sortedTasks[j].createdAt < sortedTasks[j + 1].createdAt;
                    }
                    "updatedAt" => {
                        shouldSwap = (sortOrder == "asc") ?
                            sortedTasks[j].updatedAt > sortedTasks[j + 1].updatedAt :
                            sortedTasks[j].updatedAt < sortedTasks[j + 1].updatedAt;
                    }
                    "priority" => {
                        int priority1 = self.getPriorityValue(sortedTasks[j].priority);
                        int priority2 = self.getPriorityValue(sortedTasks[j + 1].priority);
                        shouldSwap = (sortOrder == "asc") ?
                            priority1 > priority2 :
                            priority1 < priority2;
                    }
                    "status" => {
                        shouldSwap = (sortOrder == "asc") ?
                            sortedTasks[j].status > sortedTasks[j + 1].status :
                            sortedTasks[j].status < sortedTasks[j + 1].status;
                    }
                }

                if (shouldSwap) {
                    TaskResponse temp = sortedTasks[j];
                    sortedTasks[j] = sortedTasks[j + 1];
                    sortedTasks[j + 1] = temp;
                }
            }
        }

        return sortedTasks;
    }

    # Get numeric value for priority for sorting
    #
    # + priority - Priority string
    # + return - Numeric value (HIGH=3, MEDIUM=2, LOW=1)
    private function getPriorityValue(string priority) returns int {
        match priority {
            "HIGH" => {
                return 3;
            }
            "MEDIUM" => {
                return 2;
            }
            "LOW" => {
                return 1;
            }
            _ => {
                return 0;
            }
        }
    }
}
