// types.bal

# User registration request
#
# + email - User email address
# + password - User password (min 6 characters)
# + name - User's full name
public type RegisterRequest record {|
    string email;
    string password;
    string name;
|};

# Login request
#
# + email - User email address
# + password - User password
public type LoginRequest record {|
    string email;
    string password;
|};

# User record
#
# + id - Unique user identifier
# + email - User email address
# + passwordHash - Hashed password
# + name - User's full name
# + role - User role (USER, ADMIN, etc.)
# + createdAt - Account creation timestamp
public type User record {|
    readonly string id;
    string email;
    string passwordHash;
    string name;
    string role;
    string createdAt;
|};

# User response
#
# + id - Unique user identifier
# + email - User email address
# + name - User's full name
# + role - User role
public type UserResponse record {|
    string id;
    string email;
    string name;
    string role;
|};

# Authentication response
#
# + token - JWT authentication token
# + user - User information
public type AuthResponse record {|
    string token;
    UserResponse user;
|};