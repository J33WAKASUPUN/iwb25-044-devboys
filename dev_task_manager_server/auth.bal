// auth.bal
import ballerina/crypto;
import ballerina/http;
import ballerina/jwt;
import ballerina/os;

// JWT configuration
public final string jwtSecret = os:getEnv("JWT_SECRET") != "" ? os:getEnv("JWT_SECRET") : "dev-tasks-manager-secret-key-change-in-production";
public final int jwtExpirySeconds = 86400; // 24 hours

# Hash password
#
# + password - Plain text password
# + return - Hashed password
public function hashPassword(string password) returns string|error {
    byte[] hashedBytes = crypto:hashSha256(password.toBytes());
    return hashedBytes.toBase16();
}

# Verify password
#
# + password - Plain text password
# + hash - Stored hash
# + return - true if password matches
public function verifyPassword(string password, string hash) returns boolean|error {
    string hashedInput = check hashPassword(password);
    return hashedInput == hash;
}

# Generate JWT token using HMAC
#
# + userId - User ID
# + email - User email
# + name - User name
# + role - User role
# + return - JWT token
public function generateJwt(string userId, string email, string name, string role) returns string|error {
    jwt:IssuerConfig issuerConfig = {
        username: userId,
        issuer: "dev-tasks-manager",
        audience: ["dev-tasks-app"],
        expTime: <decimal>jwtExpirySeconds,
        customClaims: {
            "email": email,
            "name": name,
            "role": role
        },
        // Use HMAC algorithm with secret
        signatureConfig: {
            algorithm: jwt:HS256,
            config: jwtSecret
        }
    };

    return jwt:issue(issuerConfig);
}

# Validate JWT token using HMAC SHA256
#
# + token - JWT token to validate
# + return - JWT payload or error
public function validateJwt(string token) returns jwt:Payload|error {
    jwt:ValidatorConfig validatorConfig = {
        issuer: "dev-tasks-manager",
        audience: ["dev-tasks-app"],
        "clockSkewInSeconds": 60,  // Note the quotes around the key name
        // Use HMAC SHA256 algorithm with secret
        signatureConfig: {
            secret: jwtSecret
        }
    };

    return jwt:validate(token, validatorConfig);
}

# Extract user ID from JWT token in request
#
# + req - HTTP request
# + return - User ID or error
public function extractUserIdFromToken(http:Request req) returns string|error {
    string|http:HeaderNotFoundError authHeader = req.getHeader("Authorization");
    
    if authHeader is http:HeaderNotFoundError {
        return error("Authentication required");
    }
    
    if !authHeader.startsWith("Bearer ") {
        return error("Invalid authentication format");
    }
    
    string token = authHeader.substring(7);
    jwt:Payload|error validationResult = validateJwt(token);
    
    if validationResult is error {
        return error("Invalid or expired token");
    }
    
    return validationResult.sub ?: "";
}