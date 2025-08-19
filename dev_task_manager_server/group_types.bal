// Group related types

# Group role enum
public enum GroupRole {
    GROUP_ADMIN = "GROUP_ADMIN",
    GROUP_MEMBER = "GROUP_MEMBER"
}

# Group record structure - simplified for better MongoDB compatibility
#
# + id - Unique group identifier  
# + name - Group name  
# + description - Group description  
# + createdBy - User ID of group creator (auto-assigned as admin)  
# + members - Array of member user IDs  
# + createdAt - Group creation timestamp  
# + updatedAt - Last update timestamp  
public type Group record {|
    string id;
    string name;
    string description;
    string createdBy;
    string[] members;
    string createdAt;
    string updatedAt;
|};

# Group membership record - simplified for better MongoDB compatibility
#
# + userId - User ID of the group member
# + groupId - Group ID the user belongs to
# + role - Role in the group (GROUP_ADMIN or GROUP_MEMBER)
# + joinedAt - When user joined the group
public type GroupMembership record {|
    string userId;
    string groupId;
    string role; // Using string instead of enum for better MongoDB compatibility
    string joinedAt;
|};

# Group response type for API
#
# + id - Unique group identifier
# + name - Group name
# + description - Group description
# + creator - User who created the group
# + members - Array of group members with details
# + memberCount - Number of members in group
# + createdAt - Group creation timestamp
# + updatedAt - Last update timestamp
public type GroupResponse record {|
    string id;
    string name;
    string description;
    UserResponse creator;
    UserResponse[] members;
    int memberCount;
    string createdAt;
    string updatedAt;
|};

# Create group request
#
# + name - Group name
# + description - Group description
public type CreateGroupRequest record {|
    string name;
    string description;
|};

# Update group request
#
# + name - New group name (optional)
# + description - New group description (optional)
public type UpdateGroupRequest record {|
    string? name = ();
    string? description = ();
|};

# Add member request
#
# + userId - User ID to add to group
# + role - Role to assign (defaults to GROUP_MEMBER)
public type AddGroupMemberRequest record {|
    string userId;
    GroupRole role = GROUP_MEMBER;
|};