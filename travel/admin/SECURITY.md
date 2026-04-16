# Security Features Documentation

This document describes the security features implemented in the TravelMap Admin Panel.

## Overview

The admin panel implements multiple layers of security to protect against common web vulnerabilities and unauthorized access.

## Security Features

### 1. CSRF Protection

**Implementation:**
- CSRF tokens are generated using cryptographically secure random bytes
- Tokens are stored in the session and validated on all state-changing operations
- Tokens are included in both HTTP headers (`X-CSRF-Token`) and request body

**Functions:**
- `generateCsrfToken()` - Generates a new CSRF token or returns existing one
- `verifyCsrfToken($token)` - Verifies a CSRF token using timing-safe comparison
- `requireCsrfToken()` - Middleware function that validates CSRF token or returns 403 error

**Usage:**
```php
// In API endpoints that modify data
requireCsrfToken();
```

```javascript
// In JavaScript requests
fetch('/api/endpoint', {
    method: 'POST',
    headers: {
        'X-CSRF-Token': window.csrfToken
    },
    body: JSON.stringify({
        csrf_token: window.csrfToken,
        // other data
    })
});
```

### 2. Input Validation

**Implementation:**
- All user inputs are validated before processing
- Type-safe validation functions for common data types
- Length and range validation for strings and numbers

**Functions:**
- `validateInt($value, $min, $max)` - Validates integer values with optional min/max
- `validateString($value, $minLength, $maxLength)` - Validates string length
- `validateEmail($email)` - Validates email format
- `validateDate($date, $format)` - Validates date format
- `getParam($name, $default, $type)` - Safely retrieves and validates request parameters

**Usage:**
```php
// Validate integer parameter
$userId = validateInt($_GET['user_id'], 1);
if ($userId === false) {
    adminHandleError('Invalid user ID', 400, 'INVALID_PARAMETERS');
}

// Validate string parameter
$search = validateString($_GET['search'], 0, 255);
```

### 3. Output Escaping

**Implementation:**
- All user-generated content is escaped before output
- HTML special characters are converted to entities
- JavaScript also includes client-side escaping

**Functions:**
- `escapeHtml($value)` - Escapes HTML special characters using `htmlspecialchars()`

**Usage:**
```php
// In PHP views
echo escapeHtml($userInput);

// In JavaScript
function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.toString().replace(/[&<>"']/g, m => map[m]);
}
```

### 4. Admin Action Logging

**Implementation:**
- All administrative actions are logged to the database
- Logs include admin ID, action type, details, IP address, and user agent
- Logs can be used for audit trails and security investigations

**Database Schema:**
```sql
CREATE TABLE admin_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    admin_id INT,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    target_type VARCHAR(50),
    target_id INT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Functions:**
- `logAdminAction($action, $details, $targetType, $targetId)` - Logs an admin action

**Usage:**
```php
// Log a delete action
logAdminAction('delete_photo', [
    'photo_id' => $photoId,
    'file_path' => $filePath
], 'photo', $photoId);

// Log a login
logAdminAction('login', ['username' => $username]);
```

### 5. Brute Force Protection

**Implementation:**
- Login attempts are tracked in the database
- Maximum 5 failed attempts allowed within 15 minutes
- Automatic lockout after exceeding limit
- Old attempts are cleaned up automatically

**Database Schema:**
```sql
CREATE TABLE login_attempts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL,
    success TINYINT(1) NOT NULL DEFAULT 0,
    ip_address VARCHAR(45),
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Functions:**
- `checkLoginAttempts($username)` - Checks if login is allowed
- `recordLoginAttempt($username, $success, $ipAddress)` - Records a login attempt
- `cleanupOldLoginAttempts()` - Removes old login attempts (24+ hours)

**Configuration:**
- Maximum attempts: 5
- Lockout duration: 15 minutes
- Cleanup interval: 24 hours

### 6. Session Security

**Implementation:**
- Session ID regeneration after successful login (prevents session fixation)
- Secure session configuration
- Session validation on every request

**Features:**
- Session regeneration: `session_regenerate_id(true)` after login
- Session timeout: Handled by PHP session configuration
- Secure cookies: Should be configured in php.ini for production

**Recommended php.ini settings:**
```ini
session.cookie_httponly = 1
session.cookie_secure = 1  # For HTTPS only
session.use_strict_mode = 1
session.cookie_samesite = "Strict"
```

### 7. SQL Injection Prevention

**Implementation:**
- All database queries use PDO prepared statements
- No direct string concatenation in SQL queries
- Parameter binding for all user inputs

**Usage:**
```php
// Always use prepared statements
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = :id");
$stmt->execute([':id' => $userId]);

// Never do this:
// $query = "SELECT * FROM users WHERE id = " . $userId;
```

### 8. Authentication & Authorization

**Implementation:**
- Separate admin_users table for administrators
- Password hashing using `password_hash()` with bcrypt
- Session-based authentication
- Authorization check on every request

**Functions:**
- `adminRequireAuth()` - Validates admin session or returns 401
- `adminLogin($username, $password)` - Authenticates admin user
- `adminLogout()` - Destroys admin session

## Database Migration

To enable security features, run the migration:

```bash
mysql -u username -p database_name < travel/admin/migrations/add_security_tables.sql
```

This creates:
- `admin_logs` table for action logging
- `login_attempts` table for brute force protection

## Security Best Practices

### For Developers

1. **Always validate input:**
   ```php
   $id = validateInt($_GET['id'], 1);
   if ($id === false) {
       adminHandleError('Invalid ID', 400, 'INVALID_PARAMETERS');
   }
   ```

2. **Always escape output:**
   ```php
   echo escapeHtml($userInput);
   ```

3. **Always use CSRF protection for state-changing operations:**
   ```php
   requireCsrfToken();
   ```

4. **Always log important actions:**
   ```php
   logAdminAction('delete_user', ['user_id' => $userId], 'user', $userId);
   ```

5. **Always use prepared statements:**
   ```php
   $stmt = $pdo->prepare("SELECT * FROM table WHERE id = :id");
   $stmt->execute([':id' => $id]);
   ```

### For System Administrators

1. **Configure secure sessions in php.ini**
2. **Use HTTPS in production**
3. **Regularly review admin_logs for suspicious activity**
4. **Keep PHP and dependencies updated**
5. **Use strong passwords for admin accounts**
6. **Limit admin panel access by IP if possible**
7. **Regular database backups**

## Testing Security Features

### Test CSRF Protection
```bash
# This should fail with 403
curl -X POST http://localhost/travel/admin/api/comments/delete_comment.php \
  -H "Content-Type: application/json" \
  -d '{"commentId": 1}'
```

### Test Input Validation
```bash
# This should fail with 400
curl "http://localhost/travel/admin/api/likes/get_all_likes.php?page=invalid"
```

### Test Brute Force Protection
```bash
# Try logging in 6 times with wrong password
# The 6th attempt should be blocked
```

## Monitoring & Maintenance

### Regular Tasks

1. **Review admin logs:**
   ```sql
   SELECT * FROM admin_logs 
   WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
   ORDER BY created_at DESC;
   ```

2. **Check failed login attempts:**
   ```sql
   SELECT username, COUNT(*) as attempts, MAX(attempted_at) as last_attempt
   FROM login_attempts 
   WHERE success = 0 
   AND attempted_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
   GROUP BY username
   ORDER BY attempts DESC;
   ```

3. **Clean up old logs (optional):**
   ```sql
   DELETE FROM admin_logs 
   WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
   ```

## Incident Response

If suspicious activity is detected:

1. Review admin_logs for the affected time period
2. Check login_attempts for brute force attacks
3. Verify all admin accounts are legitimate
4. Change admin passwords if compromise is suspected
5. Review and restore from backups if necessary

## Future Enhancements

Potential security improvements for future versions:

- Two-factor authentication (2FA)
- IP whitelisting for admin access
- Rate limiting on API endpoints
- Content Security Policy (CSP) headers
- Automated security scanning
- Admin session timeout warnings
- Password complexity requirements
- Account lockout after multiple failed attempts
