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

        // Validate date format and calendar validity
        DateValidationError? dateError = validateDate(request.dueDate);
        if (dateError is DateValidationError) {
            return error(dateError.message);
        }

        // Validate assignee if provided
        if (request.assignedTo is string) {
            string assigneeId = <string>request.assignedTo;
            User? assignee = check self.userService.findUserById(assigneeId);

            if assignee is () {
                return error("Assigned user not found");
            }
        }

        // Get user timezone or use provided timezone
        UserResponse userProfile = check self.userService.getUserProfile(userId);
        string taskTimezone = userProfile.timezone;
        
        if (request.timezone is string) {
            string requestedTimezone = <string>request.timezone;
            if (validTimezones.indexOf(requestedTimezone) != -1) {
                taskTimezone = requestedTimezone;
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
            updatedAt: currentTime,
            timezone: taskTimezone
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

        // Validate due date if provided
        if (request.dueDate is string) {
            string dueDate = <string>request.dueDate;
            
            // Validate date format and calendar validity
            DateValidationError? dateError = validateDate(dueDate);
            if (dateError is DateValidationError) {
                return error(dateError.message);
            }
            
            updateDoc["dueDate"] = dueDate;
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
        
        // Update timezone if provided
        if (request.timezone is string) {
            string requestedTimezone = <string>request.timezone;
            if (validTimezones.indexOf(requestedTimezone) != -1) {
                updateDoc["timezone"] = requestedTimezone;
            } else {
                return error("Invalid timezone specified");
            }
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

    # List tasks with pagination, filtering, and sorting
    #
    # + userId - ID of user listing tasks
    # + filters - Filter, pagination, and sorting options
    # + return - Paginated task response
    public function listTasks(string userId, TaskFilterOptions filters) returns PaginatedTaskResponse|error {
        log:printInfo("Listing tasks for user: " + userId + " with pagination");

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

        // Validate date range filters
        if (filters.startDate is string) {
            string startDate = <string>filters.startDate;
            DateValidationError? dateError = validateDate(startDate);
            if (dateError is DateValidationError) {
                return error("Invalid start date: " + dateError.message);
            }
        }
        
        if (filters.endDate is string) {
            string endDate = <string>filters.endDate;
            DateValidationError? dateError = validateDate(endDate);
            if (dateError is DateValidationError) {
                return error("Invalid end date: " + dateError.message);
            }
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

    # Batch delete multiple tasks
    #
    # + userId - ID of user performing the operation
    # + taskIds - Array of task IDs to delete
    # + return - Batch operation result
    public function batchDeleteTasks(string userId, string[] taskIds) returns BatchOperationResult|error {
        log:printInfo("Batch deleting tasks for user: " + userId);

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

    # Batch update status of multiple tasks
    #
    # + userId - ID of user performing the operation
    # + taskIds - Array of task IDs to update
    # + status - New status to apply
    # + return - Batch operation result
    public function batchUpdateTaskStatus(string userId, string[] taskIds, TaskStatus status) returns BatchOperationResult|error {
        log:printInfo("Batch updating task status for user: " + userId + " to status: " + <string>status);

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

    # Search tasks by text with pagination
    #
    # + userId - ID of user searching tasks
    # + query - Search query
    # + filters - Pagination and sorting options
    # + isAdmin - Whether the user is an admin
    # + return - Paginated search results
    public function searchTasks(string userId, string query, TaskFilterOptions filters, boolean isAdmin = false) returns PaginatedTaskResponse|error {
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
        string lowercaseQuery = query.toLowerAscii();

        check from Task task in allTasksStream
            do {
                // Check if title or description contains the search term (case-insensitive)
                if (task.title.toLowerAscii().includes(lowercaseQuery) ||
                task.description.toLowerAscii().includes(lowercaseQuery)) {

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
        
        foreach int i in 0..<n-1 {
            foreach int j in 0..<n-i-1 {
                boolean shouldSwap = false;
                
                match sortBy {
                    "title" => {
                        shouldSwap = (sortOrder == "asc") ? 
                            sortedTasks[j].title > sortedTasks[j+1].title :
                            sortedTasks[j].title < sortedTasks[j+1].title;
                    }
                    "dueDate" => {
                        shouldSwap = (sortOrder == "asc") ? 
                            sortedTasks[j].dueDate > sortedTasks[j+1].dueDate :
                            sortedTasks[j].dueDate < sortedTasks[j+1].dueDate;
                    }
                    "createdAt" => {
                        shouldSwap = (sortOrder == "asc") ? 
                            sortedTasks[j].createdAt > sortedTasks[j+1].createdAt :
                            sortedTasks[j].createdAt < sortedTasks[j+1].createdAt;
                    }
                    "updatedAt" => {
                        shouldSwap = (sortOrder == "asc") ? 
                            sortedTasks[j].updatedAt > sortedTasks[j+1].updatedAt :
                            sortedTasks[j].updatedAt < sortedTasks[j+1].updatedAt;
                    }
                    "priority" => {
                        int priority1 = self.getPriorityValue(sortedTasks[j].priority);
                        int priority2 = self.getPriorityValue(sortedTasks[j+1].priority);
                        shouldSwap = (sortOrder == "asc") ? 
                            priority1 > priority2 :
                            priority1 < priority2;
                    }
                    "status" => {
                        shouldSwap = (sortOrder == "asc") ? 
                            sortedTasks[j].status > sortedTasks[j+1].status :
                            sortedTasks[j].status < sortedTasks[j+1].status;
                    }
                }
                
                if (shouldSwap) {
                    TaskResponse temp = sortedTasks[j];
                    sortedTasks[j] = sortedTasks[j+1];
                    sortedTasks[j+1] = temp;
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
            "HIGH" => { return 3; }
            "MEDIUM" => { return 2; }
            "LOW" => { return 1; }
            _ => { return 0; }
        }
    }
}