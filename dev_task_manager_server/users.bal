// users.bal
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

// List of valid timezones
final string[] validTimezones = [
    "UTC", "GMT", "EST", "CST", "MST", "PST",
    "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
    "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Moscow",
    "Asia/Tokyo", "Asia/Shanghai", "Asia/Kolkata", "Asia/Dubai",
    "Australia/Sydney", "Pacific/Auckland"
];

# User service for managing user operations
public class UserService {
    private final mongodb:Collection userCollection;
    
    # Initialize user service
    #
    # + userCollection - MongoDB collection for user data
    public function init(mongodb:Collection userCollection) {
        self.userCollection = userCollection;
    }
    
    # Register a new user
    #
    # + request - User registration data
    # + return - Authentication response with token and user info
    public function register(RegisterRequest request) returns AuthResponse|error {
        log:printInfo("Registration request received for email: " + request.email);

        // Validate request
        if (request.email == "") {
            return error("Email is required");
        }

        if (request.password == "" || request.password.length() < 6) {
            return error("Password must be at least 6 characters");
        }

        if (request.name == "") {
            return error("Name is required");
        }

        // Check if user exists
        User[] existingUsers = check self.findUsersByEmail(request.email);

        if (existingUsers.length() > 0) {
            return error("Email already registered");
        }

        // Determine role - default to USER if not specified or invalid
        string role = "USER";
        if (request.role is string) {
            string requestedRole = <string>request.role;
            // Only allow valid roles
            if (requestedRole == "ADMIN" || requestedRole == "USER") {
                role = requestedRole;
            }
        }
        
        // Validate timezone if provided
        string timezone = "UTC";
        if (request.timezone is string) {
            string requestedTimezone = <string>request.timezone;
            if (validTimezones.indexOf(requestedTimezone) != -1) {
                timezone = requestedTimezone;
            } else {
                log:printWarn("Invalid timezone provided: " + requestedTimezone + ". Defaulting to UTC");
            }
        }

        // Create user
        string id = uuid:createType1AsString();
        string hashedPassword = check hashPassword(request.password);

        User newUser = {
            id: id,
            email: request.email,
            passwordHash: hashedPassword,
            name: request.name,
            role: role,  // Use the determined role
            timezone: timezone, // Use validated timezone
            createdAt: time:utcToString(time:utcNow())
        };

        // Save user
        check self.userCollection->insertOne(newUser);
        log:printInfo("User registered successfully: " + id + " with role: " + role);

        // Generate JWT token
        string token = check generateJwt(newUser.id, newUser.email, newUser.name, newUser.role);

        // Return user info with token
        UserResponse userResponse = {
            id: newUser.id,
            email: newUser.email,
            name: newUser.name,
            role: newUser.role,
            timezone: newUser.timezone
        };

        return {
            token: token,
            user: userResponse
        };
    }
    
    # Login existing user
    #
    # + request - User login credentials
    # + return - Authentication response with token and user info
    public function login(LoginRequest request) returns AuthResponse|error {
        log:printInfo("Login request received for email: " + request.email);

        // Validate request
        if (request.email == "") {
            return error("Email is required");
        }

        if (request.password == "") {
            return error("Password is required");
        }

        // Find user
        User[] users = check self.findUsersByEmail(request.email);

        if (users.length() == 0) {
            return error("Invalid email or password");
        }

        User user = users[0];

        // Verify password
        boolean isPasswordValid = check verifyPassword(request.password, user.passwordHash);

        if (!isPasswordValid) {
            return error("Invalid email or password");
        }

        log:printInfo("User logged in successfully: " + user.id + " with role: " + user.role);

        // Generate JWT token
        string token = check generateJwt(user.id, user.email, user.name, user.role);

        // Return user info with token
        UserResponse userResponse = {
            id: user.id,
            email: user.email,
            name: user.name,
            role: user.role,
            timezone: user.timezone
        };

        return {
            token: token,
            user: userResponse
        };
    }
    
    # Update user timezone
    # 
    # + userId - ID of the user to update
    # + timezone - New timezone
    # + return - Updated user or error
    public function updateUserTimezone(string userId, string timezone) returns UserResponse|error {
        log:printInfo("Updating timezone for user: " + userId);
        
        // Validate timezone
        if (validTimezones.indexOf(timezone) == -1) {
            return error("Invalid timezone. Please use a standard timezone identifier");
        }
        
        // Find user to update
        User? user = check self.findUserById(userId);

        if user is () {
            return error("User not found");
        }

        // Use the findOneAndUpdate approach
        map<json> filter = {"id": userId};
        mongodb:Update update = {
            set: {"timezone": timezone}
        };

        _ = check self.userCollection->updateOne(filter, update);
        log:printInfo("Timezone updated for user: " + userId);

        // Return updated user profile
        return self.getUserProfile(userId);
    }
    
    # Get user by ID
    #
    # + userId - User ID to find
    # + return - User profile information
    public function getUserProfile(string userId) returns UserResponse|error {
        User? user = check self.findUserById(userId);
        
        if user is () {
            return error("User not found");
        }
        
        return {
            id: user.id,
            email: user.email,
            name: user.name,
            role: user.role,
            timezone: user.timezone
        };
    }
    
    # Find user by ID
    #
    # + id - User ID
    # + return - User record or nil
    public function findUserById(string id) returns User?|error {
        map<json> filter = {"id": id};
        return check self.userCollection->findOne(filter);
    }

    # Find users by email
    #
    # + email - Email to search for
    # + return - Array of matching users
    public function findUsersByEmail(string email) returns User[]|error {
        map<json> filter = {"email": email};
        stream<User, error?> userStream = check self.userCollection->find(filter);

        User[] users = [];
        check from User user in userStream
            do {
                users.push(user);
            };

        return users;
    }
    
    # Get all users (admin function)
    #
    # + return - Array of all users
    public function getAllUsers() returns UserResponse[]|error {
        stream<User, error?> userStream = check self.userCollection->find({});
        
        UserResponse[] users = [];
        check from User user in userStream
            do {
                users.push({
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    role: user.role,
                    timezone: user.timezone
                });
            };
        
        return users;
    }
    
    # Check if a user has admin role
    #
    # + userId - User ID to check
    # + return - True if admin, error if not admin or user not found
    public function checkAdminRole(string userId) returns boolean|error {
        User? user = check self.findUserById(userId);
        
        if user is () {
            return error("User not found");
        }
        
        if user.role != "ADMIN" {
            return error("Admin privileges required");
        }
        
        return true;
    }
}