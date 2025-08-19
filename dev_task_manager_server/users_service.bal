// users.bal
import ballerina/log;
import ballerina/regex as re;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

// List of valid timezones
final string[] validTimezones = [
    "UTC",
    "GMT",
    "EST",
    "CST",
    "MST",
    "PST",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Europe/Moscow",
    "Asia/Tokyo",
    "Asia/Shanghai",
    "Asia/Kolkata",
    "Asia/Dubai",
    "Australia/Sydney",
    "Pacific/Auckland"
];

# User Validation Helper Functions

# Validate email format
#
# + email - Email address to validate
# + return - Error if invalid, nil if valid
function validateEmail(string email) returns error? {
    string trimmedEmail = email.trim();

    if (trimmedEmail == "") {
        return error("Email cannot be empty");
    }

    if (trimmedEmail.length() < 5) {
        return error("Email must be at least 5 characters long");
    }

    if (trimmedEmail.length() > 254) {
        return error("Email cannot exceed 254 characters");
    }

    // Basic email format validation
    if (!trimmedEmail.includes("@")) {
        return error("Email must contain @ symbol");
    }

    string[] parts = re:split(trimmedEmail, "@");
    if (parts.length() != 2) {
        return error("Email format is invalid");
    }

    string localPart = parts[0];
    string domainPart = parts[1];

    if (localPart == "" || domainPart == "") {
        return error("Email format is invalid");
    }

    if (!domainPart.includes(".")) {
        return error("Email domain must contain a dot");
    }

    // Check for dangerous characters
    if (trimmedEmail.includes("<") || trimmedEmail.includes(">") ||
        trimmedEmail.includes("\"") || trimmedEmail.includes("'") ||
        trimmedEmail.includes(";") || trimmedEmail.includes(" ")) {
        return error("Email contains invalid characters");
    }

    // Convert to lowercase for consistency
    return ();
}

# Validate password strength
#
# + password - Password to validate
# + return - Error if invalid, nil if valid
function validatePassword(string password) returns error? {
    if (password == "") {
        return error("Password cannot be empty");
    }

    if (password.length() < 6) {
        return error("Password must be at least 6 characters long");
    }

    if (password.length() > 128) {
        return error("Password cannot exceed 128 characters");
    }

    // Check for at least one letter and one number (basic strength)
    boolean hasLetter = false;
    boolean hasNumber = false;

    foreach string:Char char in password {
        string charStr = char.toString();
        if ((charStr >= "a" && charStr <= "z") || (charStr >= "A" && charStr <= "Z")) {
            hasLetter = true;
        }
        if (charStr >= "0" && charStr <= "9") {
            hasNumber = true;
        }
    }

    if (!hasLetter) {
        return error("Password must contain at least one letter");
    }

    if (!hasNumber) {
        return error("Password must contain at least one number");
    }

    // Check for common weak passwords
    string lowercasePassword = password.toLowerAscii();
    string[] commonPasswords = ["password", "123456", "password123", "admin", "qwerty", "letmein"];

    foreach string common in commonPasswords {
        if (lowercasePassword == common) {
            return error("Password is too common. Please choose a stronger password");
        }
    }
}

# Validate user name
#
# + name - User name to validate
# + return - Error if invalid, nil if valid
function validateUserName(string name) returns error? {
    string trimmedName = name.trim();

    if (trimmedName == "") {
        return error("Name cannot be empty");
    }

    if (trimmedName.length() < 2) {
        return error("Name must be at least 2 characters long");
    }

    if (trimmedName.length() > 100) {
        return error("Name cannot exceed 100 characters");
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    foreach string:Char char in trimmedName {
        string charStr = char.toString();
        if (!(charStr >= "a" && charStr <= "z") &&
            !(charStr >= "A" && charStr <= "Z") &&
            charStr != " " && charStr != "-" && charStr != "'") {
            return error("Name contains invalid characters. Only letters, spaces, hyphens, and apostrophes allowed");
        }
    }

    // Check for multiple consecutive spaces
    if (trimmedName.includes("  ")) {
        return error("Name cannot contain multiple consecutive spaces");
    }
}

# Validate user role
#
# + role - Role to validate
# + return - Error if invalid, nil if valid
function validateUserRole(string role) returns error? {
    if (role != "USER" && role != "ADMIN") {
        return error("Role must be either USER or ADMIN");
    }
}

# Validate timezone
#
# + timezone - Timezone to validate
# + return - Error if invalid, nil if valid
function validateTimezone(string timezone) returns error? {
    if (validTimezones.indexOf(timezone) == -1) {
        return error("Invalid timezone: " + timezone + ". Must be one of: " + validTimezones.toString());
    }
}

# Validate user ID format
#
# + userId - User ID to validate
# + return - Error if invalid, nil if valid
function validateUserId(string userId) returns error? {
    if (userId.trim() == "") {
        return error("User ID cannot be empty");
    }

    if (userId.length() < 10) {
        return error("Invalid user ID format");
    }

    // Simple UUID-like validation
    foreach string:Char char in userId {
        string charStr = char.toString();
        if (!(charStr >= "0" && charStr <= "9") &&
            !(charStr >= "a" && charStr <= "f") &&
            !(charStr >= "A" && charStr <= "F") &&
            charStr != "-") {
            return error("User ID contains invalid characters");
        }
    }
}

# User service for managing user operations
public class UserService {
    private final mongodb:Collection userCollection;

    # Initialize user service
    #
    # + userCollection - MongoDB collection for user data
    public function init(mongodb:Collection userCollection) {
        self.userCollection = userCollection;
    }

    # Register a new user (WITH Enhanced Validation & Security Fix)
    #
    # + request - User registration data
    # + return - Authentication response with token and user info
    public function register(RegisterRequest request) returns AuthResponse|error {
        log:printInfo("Registration request received for email: " + request.email);

        // Enhanced validation
        check validateEmail(request.email);
        check validatePassword(request.password);
        check validateUserName(request.name);

        // Check if user exists (using normalized email)
        string normalizedEmail = request.email.trim().toLowerAscii();
        User[] existingUsers = check self.findUsersByEmail(normalizedEmail);

        if (existingUsers.length() > 0) {
            return error("Email already registered: " + request.email);
        }

        // 🔒 SECURITY FIX: Force all new registrations to be USER role only
        // Ignore any requested role and always set to USER
        string role = "USER";

        // Validate and determine timezone
        string timezone = "UTC";
        if (request.timezone is string) {
            string requestedTimezone = <string>request.timezone;
            check validateTimezone(requestedTimezone);
            timezone = requestedTimezone;
        }

        // Create user with validated and normalized data
        string id = uuid:createType1AsString();
        string hashedPassword = check hashPassword(request.password);

        User newUser = {
            id: id,
            email: normalizedEmail, // Store normalized email
            passwordHash: hashedPassword,
            name: request.name.trim(), // Store trimmed name
            role: role, // Always USER role
            timezone: timezone,
            createdAt: time:utcToString(time:utcNow())
        };

        // Save user
        check self.userCollection->insertOne(newUser);
        log:printInfo("User registered successfully: " + id + " with role: " + role + " and email: " + normalizedEmail);

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

    # Login existing user (WITH Enhanced Validation)
    #
    # + request - User login credentials
    # + return - Authentication response with token and user info
    public function login(LoginRequest request) returns AuthResponse|error {
        log:printInfo("Login request received for email: " + request.email);

        // Enhanced validation
        check validateEmail(request.email);

        if (request.password == "") {
            return error("Password cannot be empty");
        }

        // Normalize email for lookup
        string normalizedEmail = request.email.trim().toLowerAscii();

        // Find user
        User[] users = check self.findUsersByEmail(normalizedEmail);

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

    # Update user timezone (WITH Enhanced Validation)
    #
    # + userId - ID of the user to update
    # + timezone - New timezone
    # + return - Updated user or error
    public function updateUserTimezone(string userId, string timezone) returns UserResponse|error {
        log:printInfo("Updating timezone for user: " + userId);

        // Enhanced validation
        check validateUserId(userId);
        check validateTimezone(timezone);

        // Find user to update
        User? user = check self.findUserById(userId);

        if user is () {
            return error("User not found with ID: " + userId);
        }

        // Update timezone
        map<json> filter = {"id": userId};
        mongodb:Update update = {
            set: {"timezone": timezone}
        };

        _ = check self.userCollection->updateOne(filter, update);
        log:printInfo("Timezone updated successfully for user: " + userId + " to: " + timezone);

        // Return updated user profile
        return self.getUserProfile(userId);
    }

    # Get user by ID (WITH Enhanced Validation)
    #
    # + userId - User ID to find
    # + return - User profile information
    public function getUserProfile(string userId) returns UserResponse|error {
        // Enhanced validation
        check validateUserId(userId);

        User? user = check self.findUserById(userId);

        if user is () {
            return error("User not found with ID: " + userId);
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

    # Find users by email (WITH Enhanced Validation)
    #
    # + email - Email to search for
    # + return - Array of matching users
    public function findUsersByEmail(string email) returns User[]|error {
        // Normalize email for search
        string normalizedEmail = email.trim().toLowerAscii();

        map<json> filter = {"email": normalizedEmail};
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

    # Check if a user has admin role (WITH Enhanced Validation)
    #
    # + userId - User ID to check
    # + return - True if admin, error if not admin or user not found
    public function checkAdminRole(string userId) returns boolean|error {
        // Enhanced validation
        check validateUserId(userId);

        User? user = check self.findUserById(userId);

        if user is () {
            return error("User not found with ID: " + userId);
        }

        if user.role != "ADMIN" {
            return error("Admin privileges required. Current role: " + user.role);
        }

        return true;
    }
}
