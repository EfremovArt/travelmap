# Security Quick Reference Guide

Quick reference for developers working on the admin panel.

## For API Endpoints

### 1. Always require authentication
```php
<?php
require_once '../../config/admin_config.php';
adminRequireAuth();
```

### 2. Add CSRF protection for state-changing operations (POST, DELETE, PUT)
```php
// Add after authentication check
requireCsrfToken();
```

### 3. Validate all input parameters
```php
// Validate integers
$userId = validateInt(getParam('user_id'), 1);
if ($userId === false) {
    adminHandleError('Invalid user ID', 400, 'INVALID_PARAMETERS');
}

// Validate strings
$search = validateString(getParam('search', '', 'string'), 0, 255);
if ($search === false) {
    $search = '';
}

// Validate emails
$email = validateEmail(getParam('email'));
if ($email === false) {
    adminHandleError('Invalid email', 400, 'INVALID_PARAMETERS');
}
```

### 4. Log important actions
```php
// After successful operation
logAdminAction('delete_photo', [
    'photo_id' => $photoId,
    'file_path' => $filePath
], 'photo', $photoId);
```

### 5. Use prepared statements for database queries
```php
// Always use prepared statements
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = :id");
$stmt->execute([':id' => $userId]);

// NEVER do this:
// $query = "SELECT * FROM users WHERE id = " . $userId;
```

## For JavaScript/Frontend

### 1. Include CSRF token in requests
```javascript
// For fetch API
fetch('/api/endpoint', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': window.csrfToken
    },
    body: JSON.stringify({
        csrf_token: window.csrfToken,
        // other data
    })
});

// For jQuery
$.ajax({
    url: '/api/endpoint',
    type: 'POST',
    headers: {
        'X-CSRF-Token': window.csrfToken
    },
    data: JSON.stringify({
        csrf_token: window.csrfToken,
        // other data
    })
});
```

### 2. Escape user input before displaying
```javascript
function escapeHtml(text) {
    if (!text) return '';
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.toString().replace(/[&<>"']/g, m => map[m]);
}

// Use it
element.textContent = escapeHtml(userInput);
```

## For PHP Views

### 1. Always escape output
```php
<!-- Use escapeHtml for all user-generated content -->
<p><?php echo escapeHtml($userName); ?></p>

<!-- Or use htmlspecialchars directly -->
<p><?php echo htmlspecialchars($userName, ENT_QUOTES, 'UTF-8'); ?></p>
```

### 2. CSRF token is available globally
```php
<!-- Token is already exposed in header.php -->
<script>
    // window.csrfToken is available
    console.log(window.csrfToken);
</script>
```

## Common Validation Patterns

### Pagination parameters
```php
$page = validateInt(getParam('page', 1, 'int'), 1);
$perPage = validateInt(getParam('per_page', 50, 'int'), 1, 100);

if ($page === false || $perPage === false) {
    adminHandleError('Invalid pagination parameters', 400, 'INVALID_PARAMETERS');
}
```

### Sort parameters
```php
$sortBy = getParam('sort_by', 'created_at', 'string');
$sortOrder = strtoupper(getParam('sort_order', 'DESC', 'string'));

// Whitelist allowed sort fields
$allowedSortFields = ['id', 'name', 'created_at'];
if (!in_array($sortBy, $allowedSortFields)) {
    $sortBy = 'created_at';
}

// Validate sort order
if (!in_array($sortOrder, ['ASC', 'DESC'])) {
    $sortOrder = 'DESC';
}
```

### Search parameter
```php
$search = validateString(getParam('search', '', 'string'), 0, 255);
if ($search === false) {
    $search = '';
}
```

### ID parameter
```php
$id = validateInt(getParam('id'), 1);
if ($id === false) {
    adminHandleError('Invalid ID', 400, 'INVALID_PARAMETERS');
}
```

## Error Handling

### Standard error response
```php
adminHandleError('Error message', 400, 'ERROR_CODE');
```

### Common error codes
- `AUTH_REQUIRED` - Authentication required
- `INVALID_CSRF_TOKEN` - CSRF token validation failed
- `INVALID_PARAMETERS` - Invalid input parameters
- `NOT_FOUND` - Resource not found
- `DATABASE_ERROR` - Database operation failed
- `PERMISSION_DENIED` - Insufficient permissions

## Testing Checklist

Before committing code, verify:

- [ ] Authentication check is present
- [ ] CSRF protection is enabled for state-changing operations
- [ ] All input parameters are validated
- [ ] All database queries use prepared statements
- [ ] All output is escaped
- [ ] Important actions are logged
- [ ] Error handling is implemented
- [ ] No sensitive data in error messages

## Security Testing

Run the security test suite:
```bash
php test_security.php
```

## Need Help?

- See [SECURITY.md](SECURITY.md) for detailed documentation
- Check existing API endpoints for examples
- Ask the team if unsure about security implementation
