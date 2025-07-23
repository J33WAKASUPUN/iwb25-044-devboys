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
    private final UserService userService;

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

            // Create index for unique email - fixed format
            check self.userCollection->createIndex({
                email: 1
            }, {
                unique: true
            });

            // Initialize user service
            self.userService = new UserService(self.userCollection);

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

    # Protected endpoint example - requires authentication
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
        
        // Return user profile
        return <json>{
            "id": profile.id,
            "email": profile.email,
            "name": profile.name,
            "role": profile.role
        };
    }
}