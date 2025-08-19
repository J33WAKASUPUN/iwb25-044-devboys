// dateutil.bal
import ballerina/regex;
import ballerina/time;

// Define current date as configurable - can be overridden at runtime
configurable string currentSystemDate = ?;

# Check if a date string is in valid YYYY-MM-DD format
#
# + dateString - The date string to validate
# + return - True if valid, false otherwise
public function isValidDateFormat(string dateString) returns boolean {
    if (dateString.length() != 10) {
        return false;
    }
    
    boolean matchesFormat = regex:matches(dateString, "^\\d{4}-\\d{2}-\\d{2}$");
    if (!matchesFormat) {
        return false;
    }
    
    return true;
}

# Validate a date string as a proper calendar date
#
# + dateString - The date string to validate (YYYY-MM-DD)
# + return - True if valid date, false otherwise
public function isValidCalendarDate(string dateString) returns boolean {
    if (!isValidDateFormat(dateString)) {
        return false;
    }
    
    do {
        string[] parts = regex:split(dateString, "-");
        if (parts.length() != 3) {
            return false;
        }
        
        int year = check int:fromString(parts[0]);
        int month = check int:fromString(parts[1]);
        int day = check int:fromString(parts[2]);
        
        if (year < 2000 || year > 2100) {
            return false; // Reasonable range check
        }
        
        if (month < 1 || month > 12) {
            return false;
        }
        
        // Check days based on month
        int daysInMonth = 31; // Default for most months
        
        if (month == 4 || month == 6 || month == 9 || month == 11) {
            daysInMonth = 30;
        } else if (month == 2) {
            // February - leap year check
            if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
                daysInMonth = 29; // Leap year
            } else {
                daysInMonth = 28; // Non-leap year
            }
        }
        
        if (day < 1 || day > daysInMonth) {
            return false;
        }
        
        return true;
    } on fail {
        return false;
    }
}

# Comprehensive date validation with detailed error reporting
#
# + dateString - The date string to validate (YYYY-MM-DD)
# + return - Error description if invalid, nil if valid
public function validateDate(string dateString) returns DateValidationError? {
    // Check basic format
    if (dateString.length() != 10) {
        return {
            message: "Invalid date format",
            fieldName: "dueDate",
            validation: "Date must be in YYYY-MM-DD format"
        };
    }
    
    boolean matchesFormat = regex:matches(dateString, "^\\d{4}-\\d{2}-\\d{2}$");
    if (!matchesFormat) {
        return {
            message: "Invalid date format",
            fieldName: "dueDate",
            validation: "Date must be in YYYY-MM-DD format"
        };
    }
    
    do {
        string[] parts = regex:split(dateString, "-");
        int year = check int:fromString(parts[0]);
        int month = check int:fromString(parts[1]);
        int day = check int:fromString(parts[2]);
        
        // Year validation
        if (year < 2000 || year > 2100) {
            return {
                message: "Invalid year",
                fieldName: "dueDate",
                validation: "Year must be between 2000 and 2100"
            };
        }
        
        // Month validation
        if (month < 1 || month > 12) {
            return {
                message: "Invalid month",
                fieldName: "dueDate",
                validation: "Month must be between 1 and 12"
            };
        }
        
        // Day validation with month-specific logic
        int daysInMonth = 31; // Default
        
        if (month == 4 || month == 6 || month == 9 || month == 11) {
            daysInMonth = 30;
        } else if (month == 2) {
            // February leap year calculation
            if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
                daysInMonth = 29;
            } else {
                daysInMonth = 28;
            }
        }
        
        if (day < 1 || day > daysInMonth) {
            return {
                message: "Invalid day for month",
                fieldName: "dueDate",
                validation: string `Day must be between 1 and ${daysInMonth} for month ${month}`
            };
        }
        
        // All checks passed
        return ();
    } on fail {
        return {
            message: "Invalid date",
            fieldName: "dueDate",
            validation: "Could not parse date components"
        };
    }
}

# Check if a task is overdue based on current system date
#
# + dueDate - The due date string in YYYY-MM-DD format
# + status - The task status
# + return - True if task is overdue, false otherwise
public function isTaskOverdue(string dueDate, string status) returns boolean {
    if (status == "DONE") {
        return false; // Completed tasks are never overdue
    }
    
    // Use configured current date or default to system date
    string currentDate;
    
    if (currentSystemDate != "") {
        currentDate = currentSystemDate;
    } else {
        currentDate = time:utcToString(time:utcNow()).substring(0, 10); // YYYY-MM-DD
    }
    
    // Simple string comparison works with YYYY-MM-DD format
    return dueDate < currentDate;
}

# Format a date for display with optional timezone conversion
#
# + dateString - ISO date string
# + timezone - Target timezone (not implemented yet)
# + return - Formatted date string
public function formatDate(string dateString, string timezone = "UTC") returns string {
    // For now, just return the original date string
    // In a future implementation, this would perform timezone conversion
    return dateString;
}