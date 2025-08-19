import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

# Validate group name
#
# + name - Group name to validate
# + return - Error if invalid, nil if valid
function validateGroupName(string name) returns error? {
    string trimmedName = name.trim();

    if (trimmedName == "") {
        return error("Group name cannot be empty");
    }

    if (trimmedName.length() < 3) {
        return error("Group name must be at least 3 characters long");
    }

    if (trimmedName.length() > 100) {
        return error("Group name cannot exceed 100 characters");
    }

    // Check for invalid characters
    if (trimmedName.includes("<") || trimmedName.includes(">") || trimmedName.includes("\"") ||
        trimmedName.includes("'") || trimmedName.includes("&")) {
        return error("Group name contains invalid characters (< > \" ' &)");
    }
}

# Validate group description
#
# + description - Group description to validate
# + return - Error if invalid, nil if valid
function validateGroupDescription(string description) returns error? {
    if (description.length() > 500) {
        return error("Group description cannot exceed 500 characters");
    }

    // Check for invalid characters
    if (description.includes("<") || description.includes(">") || description.includes("\"") ||
        description.includes("'") || description.includes("&")) {
        return error("Group description contains invalid characters (< > \" ' &)");
    }
}

# Group service for managing group operations
public class GroupService {
    private final mongodb:Collection groupCollection;
    private final mongodb:Collection membershipCollection;
    private final UserService userService;

    # Initialize group service
    #
    # + groupCollection - MongoDB collection for group data
    # + membershipCollection - MongoDB collection for membership data
    # + userService - User service for user operations
    public function init(mongodb:Collection groupCollection, mongodb:Collection membershipCollection, UserService userService) {
        self.groupCollection = groupCollection;
        self.membershipCollection = membershipCollection;
        self.userService = userService;
    }

    # Create a new group
    #
    # + userId - ID of user creating the group
    # + request - Group creation data
    # + return - Created group data
    public function createGroup(string userId, CreateGroupRequest request) returns GroupResponse|error {
        log:printInfo("Creating new group: " + request.name + " by user: " + userId);

        // Validate inputs
        check validateGroupName(request.name);
        check validateGroupDescription(request.description);

        // Check if user exists
        _ = check self.userService.getUserProfile(userId);

        // Create group
        string id = uuid:createType1AsString();
        string currentTime = time:utcToString(time:utcNow());

        Group newGroup = {
            id: id,
            name: request.name.trim(),
            description: request.description.trim(),
            createdBy: userId,
            members: [userId], // Creator is automatically a member
            createdAt: currentTime,
            updatedAt: currentTime
        };

        // Save group
        check self.groupCollection->insertOne(newGroup);

        // Create membership record for creator (as GROUP_ADMIN)
        GroupMembership creatorMembership = {
            userId: userId,
            groupId: id,
            role: GROUP_ADMIN,
            joinedAt: currentTime
        };

        check self.membershipCollection->insertOne(creatorMembership);

        log:printInfo("Group created successfully: " + id + " with creator: " + userId);

        // Return group with member details - with better error handling
        GroupResponse|error response = self.getGroupResponseById(id);
        if response is error {
            log:printError("Error creating group response: " + response.message());
            return error("Group created but failed to generate response: " + response.message());
        }

        return response;
    }

    # Update an existing group
    #
    # + userId - ID of user updating the group
    # + groupId - ID of group to update
    # + request - Group update data
    # + return - Updated group data
    public function updateGroup(string userId, string groupId, UpdateGroupRequest request) returns GroupResponse|error {
        log:printInfo("Updating group: " + groupId + " by user: " + userId);

        // Check if user can update the group (must be GROUP_ADMIN)
        boolean isAdmin = check self.isGroupAdmin(userId, groupId);

        if (!isAdmin) {
            return error("Not authorized to update this group. Only group admin can update.");
        }

        // Build update document with validation
        map<json> updateDoc = {};

        if (request.name is string) {
            string name = <string>request.name;
            check validateGroupName(name);
            updateDoc["name"] = name.trim();
        }

        if (request.description is string) {
            string description = <string>request.description;
            check validateGroupDescription(description);
            updateDoc["description"] = description.trim();
        }

        // Ensure we have something to update
        if (updateDoc.length() == 0) {
            return error("No valid fields provided for update");
        }

        // Add updated timestamp
        updateDoc["updatedAt"] = time:utcToString(time:utcNow());

        // Perform update
        map<json> filter = {"id": groupId};
        mongodb:Update update = {
            set: updateDoc
        };

        _ = check self.groupCollection->updateOne(filter, update);
        log:printInfo("Group updated successfully: " + groupId);

        // Return updated group
        return check self.getGroupResponseById(groupId);
    }

    # Add a member to a group
    #
    # + adminId - ID of user adding the member (must be GROUP_ADMIN)
    # + groupId - ID of group
    # + request - Member details to add
    # + return - Updated group data
    public function addGroupMember(string adminId, string groupId, AddGroupMemberRequest request) returns GroupResponse|error {
        log:printInfo("Adding member to group: " + groupId);

        // Check if admin can add members (must be GROUP_ADMIN)
        boolean isAdmin = check self.isGroupAdmin(adminId, groupId);

        if (!isAdmin) {
            return error("Not authorized to add members. Only group admin can add members.");
        }

        // Check if user to add exists
        _ = check self.userService.getUserProfile(request.userId);

        // Check if user is already a member
        boolean isMember = check self.isGroupMember(request.userId, groupId);

        if (isMember) {
            return error("User is already a member of this group: " + request.userId);
        }

        // Add user to group members array
        map<json> filter = {"id": groupId};
        mongodb:Update groupUpdate = {
            "push": {"members": request.userId}
        };

        _ = check self.groupCollection->updateOne(filter, groupUpdate);

        // Create membership record
        string currentTime = time:utcToString(time:utcNow());
        GroupMembership membership = {
            userId: request.userId,
            groupId: groupId,
            role: request.role,
            joinedAt: currentTime
        };

        check self.membershipCollection->insertOne(membership);

        log:printInfo("Member added successfully to group: " + groupId + ", user: " + request.userId);

        // Return updated group
        return check self.getGroupResponseById(groupId);
    }

    # Remove a member from a group (soft delete - marks as inactive)
    #
    # + adminId - ID of user removing the member (must be GROUP_ADMIN)
    # + groupId - ID of group
    # + memberId - ID of member to remove
    # + return - Updated group data
    public function removeGroupMember(string adminId, string groupId, string memberId) returns GroupResponse|error {
        log:printInfo("Removing member from group: " + groupId);

        // Check if admin can remove members (must be GROUP_ADMIN)
        boolean isAdmin = check self.isGroupAdmin(adminId, groupId);

        if (!isAdmin) {
            return error("Not authorized to remove members. Only group admin can remove members.");
        }

        // Check if user is a member
        boolean isMember = check self.isGroupMember(memberId, groupId);

        if (!isMember) {
            return error("User is not a member of this group: " + memberId);
        }

        // Prevent removing the group creator
        Group? group = check self.findGroupById(groupId);

        if group is () {
            return error("Group not found: " + groupId);
        }

        if (group.createdBy == memberId) {
            return error("Cannot remove the group creator");
        }

        // Remove user from group members array (still remove from active members)
        map<json> filter = {"id": groupId};
        mongodb:Update groupUpdate = {
            "pull": {"members": memberId}
        };

        _ = check self.groupCollection->updateOne(filter, groupUpdate);

        // Mark membership record as inactive instead of deleting
        map<json> membershipFilter = {"userId": memberId, "groupId": groupId};
        mongodb:Update membershipUpdate = {
            set: {
                "status": "INACTIVE",
                "removedAt": time:utcToString(time:utcNow()),
                "removedBy": adminId
            }
        };

        _ = check self.membershipCollection->updateOne(membershipFilter, membershipUpdate);

        log:printInfo("Member marked as inactive in group: " + groupId + ", user: " + memberId);

        // Return updated group
        return check self.getGroupResponseById(groupId);
    }

    # Get a group by ID
    #
    # + groupId - Group ID to retrieve
    # + return - Group response or error
    public function getGroupById(string groupId) returns GroupResponse|error {
        log:printInfo("Getting group by ID: " + groupId);
        return self.getGroupResponseById(groupId);
    }

    # List groups for a user (groups user is a member of)
    #
    # + userId - User ID to list groups for
    # + return - Array of groups
    public function listUserGroups(string userId) returns GroupResponse[]|error {
        log:printInfo("Listing groups for user: " + userId);
        // Find all groups where user is a member
        map<json> filter = {"members": userId};
        stream<map<json>, error?> groupJsonStream = check self.groupCollection->find(filter);
        GroupResponse[] responses = [];
        while true {
            var next = groupJsonStream.next();
            if next is map<json> {
                map<json> groupJson = next;
                // Defensive extraction for all fields (same as in findGroupById)
                string groupId = "";
                string groupName = "";
                string groupDescription = "";
                string groupCreatedBy = "";
                string groupCreatedAt = "";
                string groupUpdatedAt = "";
                string[] memberIds = [];

                if groupJson.hasKey("id") {
                    json val = groupJson["id"];
                    if val is string {
                        groupId = val;
                    } else if val is int {
                        groupId = val.toString();
                    }
                }
                if groupJson.hasKey("name") {
                    json val = groupJson["name"];
                    if val is string {
                        groupName = val;
                    }
                }
                if groupJson.hasKey("description") {
                    json val = groupJson["description"];
                    if val is string {
                        groupDescription = val;
                    }
                }
                if groupJson.hasKey("createdBy") {
                    json val = groupJson["createdBy"];
                    if val is string {
                        groupCreatedBy = val;
                    }
                }
                if groupJson.hasKey("createdAt") {
                    json val = groupJson["createdAt"];
                    if val is string {
                        groupCreatedAt = val;
                    }
                }
                if groupJson.hasKey("updatedAt") {
                    json val = groupJson["updatedAt"];
                    if val is string {
                        groupUpdatedAt = val;
                    }
                }
                // Handle members array robustly
                if groupJson.hasKey("members") {
                    json membersVal = groupJson["members"];
                    if membersVal is json[] {
                        foreach json member in membersVal {
                            if member is string {
                                memberIds.push(member);
                            } else if member is int {
                                memberIds.push(member.toString());
                            }
                        }
                    } else if membersVal is string[] {
                        memberIds = membersVal;
                    } else if membersVal is string {
                        memberIds = [membersVal];
                    }
                }
                Group group = {
                    id: groupId,
                    name: groupName,
                    description: groupDescription,
                    createdBy: groupCreatedBy,
                    members: memberIds,
                    createdAt: groupCreatedAt,
                    updatedAt: groupUpdatedAt
                };
                // Now get GroupResponse, log errors but continue
                var resp = self.getGroupResponseById(group.id);
                if resp is GroupResponse {
                    responses.push(resp);
                } else if resp is error {
                    log:printError("Error getting GroupResponse for group id: " + group.id + ": " + resp.message());
                }
            } else if next is error { // Stream error
                return next;
            } else { // End of stream
                break;
            }
        }
        return responses;
    }

    # Check if user is a group admin
    #
    # + userId - User ID to check
    # + groupId - Group ID to check
    # + return - True if admin, false otherwise
    public function isGroupAdmin(string userId, string groupId) returns boolean|error {
        log:printInfo("Checking if user is group admin: " + userId + " in group: " + groupId);

        // First check if the user is the group creator (creators are always admins)
        Group? group = check self.findGroupById(groupId);
        if group is Group && group.createdBy == userId {
            log:printInfo("User is group creator, therefore admin: " + userId);
            return true;
        }

        // Then check membership collection
        map<json> filter = {"userId": userId, "groupId": groupId, "role": "GROUP_ADMIN"};
        map<json>? result = check self.membershipCollection->findOne(filter);
        
        boolean isAdmin = result is map<json>;
        log:printInfo("User admin status from membership: " + isAdmin.toString());
        return isAdmin;
    }

    # Check if user is a group member
    #
    # + userId - User ID to check
    # + groupId - Group ID to check
    # + return - True if member, false otherwise
    public function isGroupMember(string userId, string groupId) returns boolean|error {
        log:printInfo("Checking if user is group member: " + userId + " in group: " + groupId);

        // First check the group's members array (primary source of truth for active members)
        Group? group = check self.findGroupById(groupId);
        if group is Group {
            foreach string memberId in group.members {
                if memberId == userId {
                    log:printInfo("User found in group members array: " + userId);
                    return true;
                }
            }
        }

        // Fallback: check membership collection for active status
        map<json> filter = {"userId": userId, "groupId": groupId, "status": {"$ne": "INACTIVE"}};
        map<json>? result = check self.membershipCollection->findOne(filter);
        
        boolean isMember = result is map<json>;
        log:printInfo("User member status from membership collection: " + isMember.toString());
        return isMember;
    }

    # Find group by ID
    #
    # + id - Group ID
    # + return - Group or nil
    public function findGroupById(string id) returns Group?|error {
        map<json> filter = {"id": id};
        map<json>? result = check self.groupCollection->findOne(filter);
        if result is () {
            log:printInfo("Group not found with ID: " + id);
            return ();
        }

        map<json> groupJson = result;

        // Enhanced defensive extraction with better error handling
        string groupId = "";
        string groupName = "";
        string groupDescription = "";
        string groupCreatedBy = "";
        string groupCreatedAt = "";
        string groupUpdatedAt = "";
        string[] memberIds = [];

        // Safe extraction with type checking
        if groupJson.hasKey("id") {
            json idVal = groupJson["id"];
            if idVal is string {
                groupId = idVal;
            } else {
                groupId = idVal.toString();
            }
        }

        if groupJson.hasKey("name") {
            json nameVal = groupJson["name"];
            if nameVal is string {
                groupName = nameVal;
            } else {
                groupName = nameVal.toString();
            }
        }

        if groupJson.hasKey("description") {
            json descVal = groupJson["description"];
            if descVal is string {
                groupDescription = descVal;
            } else {
                groupDescription = descVal.toString();
            }
        }

        if groupJson.hasKey("createdBy") {
            json createdByVal = groupJson["createdBy"];
            if createdByVal is string {
                groupCreatedBy = createdByVal;
            } else {
                groupCreatedBy = createdByVal.toString();
            }
        }

        if groupJson.hasKey("createdAt") {
            json createdAtVal = groupJson["createdAt"];
            if createdAtVal is string {
                groupCreatedAt = createdAtVal;
            } else {
                groupCreatedAt = createdAtVal.toString();
            }
        }

        if groupJson.hasKey("updatedAt") {
            json updatedAtVal = groupJson["updatedAt"];
            if updatedAtVal is string {
                groupUpdatedAt = updatedAtVal;
            } else {
                groupUpdatedAt = updatedAtVal.toString();
            }
        }

        // Enhanced members array handling
        if groupJson.hasKey("members") {
            json membersVal = groupJson["members"];
            if membersVal is json[] {
                foreach json member in membersVal {
                    if member is string {
                        memberIds.push(member);
                    } else if member is int {
                        memberIds.push(member.toString());
                    } else {
                        // Handle any other type by converting to string
                        memberIds.push(member.toString());
                    }
                }
            } else if membersVal is string {
                memberIds = [membersVal];
            } else {
                // Fallback for unexpected types
                memberIds = [membersVal.toString()];
            }
        }

        Group group = {
            id: groupId,
            name: groupName,
            description: groupDescription,
            createdBy: groupCreatedBy,
            members: memberIds,
            createdAt: groupCreatedAt,
            updatedAt: groupUpdatedAt
        };

        return group;
    }

    # Get group name by ID (lightweight method for task responses)
    #
    # + groupId - Group ID
    # + return - Group name or error
    public function getGroupNameById(string groupId) returns string|error {
        log:printInfo("Getting group name for ID: " + groupId);

        // Use the existing findGroupById method which works
        Group? group = check self.findGroupById(groupId);

        if group is () {
            log:printError("Group not found with ID: " + groupId);
            return error("Group not found with ID: " + groupId);
        }

        log:printInfo("Successfully found group name: " + group.name);
        return group.name;
    }

    # Get full group response by ID with member details
    #
    # + id - Group ID
    # + return - Group response with member details
    private function getGroupResponseById(string id) returns GroupResponse|error {
        Group? group = check self.findGroupById(id);

        if group is () {
            return error("Group not found with ID: " + id);
        }

        // Get creator info
        UserResponse creator = check self.userService.getUserProfile(group.createdBy);

        // Get all member details
        UserResponse[] members = [];

        foreach string memberId in group.members {
            do {
                UserResponse member = check self.userService.getUserProfile(memberId);
                members.push(member);
            } on fail error e {
                log:printError("Error fetching member: " + memberId + ": " + e.message());
                // Continue with other members if one fails
            }
        }

        return {
            id: group.id,
            name: group.name,
            description: group.description,
            creator: creator,
            members: members,
            memberCount: members.length(),
            createdAt: group.createdAt,
            updatedAt: group.updatedAt
        };
    }
}
