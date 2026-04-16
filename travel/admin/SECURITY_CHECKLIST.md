# Security Implementation Checklist

Use this checklist to verify that all security features are properly implemented.

## Installation Checklist

- [ ] Database migration executed successfully
  ```bash
  php travel/admin/install_security.php
  ```

- [ ] Security tables created
  - [ ] `admin_logs` table exists
  - [ ] `login_attempts` table exists

- [ ] Security tests pass
  ```bash
  php travel/admin/test_security.php
  ```
  - [ ] All 10 tests pass

## Code Implementation Checklist

### API Endpoints

For each API endpoint, verify:

#### Authentication & Authorization
- [ ] `adminRequireAuth()` is called at the beginning
- [ ] Returns 401 for unauthenticated requests
- [ ] Returns 403 for unauthorized requests

#### CSRF Protection (for POST/DELETE/PUT operations)
- [ ] `requireCsrfToken()` is called after authentication
- [ ] Returns 403 for invalid CSRF tokens
- [ ] JavaScript includes CSRF token in requests

#### Input Validation
- [ ] All GET/POST parameters are validated
- [ ] Integer parameters use `validateInt()`
- [ ] String parameters use `validateString()`
- [ ] Email parameters use `validateEmail()`
- [ ] Returns 400 for invalid parameters
- [ ] No direct use of `$_GET` or `$_POST` without validation

#### Database Queries
- [ ] All queries use prepared statements
- [ ] No string concatenation in SQL queries
- [ ] Parameters are properly bound
- [ ] No SQL injection vulnerabilities

#### Output Handling
- [ ] All user-generated content is escaped
- [ ] Uses `escapeHtml()` or `htmlspecialchars()`
- [ ] No raw output of user data

#### Logging
- [ ] Important actions are logged
- [ ] Logs include relevant details
- [ ] Logs include target type and ID when applicable

#### Error Handling
- [ ] Uses `adminHandleError()` for errors
- [ ] Appropriate HTTP status codes
- [ ] No sensitive information in error messages
- [ ] Errors are logged appropriately

### JavaScript Files

For each JavaScript file with AJAX requests:

- [ ] CSRF token included in headers
  ```javascript
  headers: {
      'X-CSRF-Token': window.csrfToken
  }
  ```

- [ ] CSRF token included in request body
  ```javascript
  body: JSON.stringify({
      csrf_token: window.csrfToken,
      // other data
  })
  ```

- [ ] User input is escaped before display
  ```javascript
  element.textContent = escapeHtml(userInput);
  ```

- [ ] Error responses are handled properly

### PHP View Files

For each PHP view file:

- [ ] All output uses `escapeHtml()` or `htmlspecialchars()`
- [ ] No direct echo of user data
- [ ] CSRF token available via `window.csrfToken`
- [ ] Includes proper authentication check

## Functional Testing Checklist

### CSRF Protection Testing

- [ ] Test 1: Request without CSRF token is rejected
  ```bash
  curl -X POST http://localhost/travel/admin/api/comments/delete_comment.php \
    -H "Content-Type: application/json" \
    -d '{"commentId": 1}'
  # Expected: 403 Forbidden
  ```

- [ ] Test 2: Request with invalid CSRF token is rejected
  ```bash
  curl -X POST http://localhost/travel/admin/api/comments/delete_comment.php \
    -H "Content-Type: application/json" \
    -H "X-CSRF-Token: invalid_token" \
    -d '{"commentId": 1, "csrf_token": "invalid_token"}'
  # Expected: 403 Forbidden
  ```

- [ ] Test 3: Request with valid CSRF token succeeds
  - Login to admin panel
  - Use browser dev tools to get CSRF token
  - Make request with valid token
  - Expected: Success

### Input Validation Testing

- [ ] Test 1: Invalid integer parameter
  ```bash
  curl "http://localhost/travel/admin/api/likes/get_all_likes.php?page=invalid"
  # Expected: 400 Bad Request
  ```

- [ ] Test 2: Out of range parameter
  ```bash
  curl "http://localhost/travel/admin/api/likes/get_all_likes.php?per_page=1000"
  # Expected: Capped at 100
  ```

- [ ] Test 3: SQL injection attempt
  ```bash
  curl "http://localhost/travel/admin/api/users/get_user_details.php?user_id=1%20OR%201=1"
  # Expected: 400 Bad Request or safe handling
  ```

- [ ] Test 4: XSS attempt in search
  ```bash
  curl "http://localhost/travel/admin/api/likes/get_all_likes.php?search=<script>alert('xss')</script>"
  # Expected: Escaped in output
  ```

### Brute Force Protection Testing

- [ ] Test 1: Multiple failed login attempts
  - Attempt to login with wrong password 6 times
  - Expected: 6th attempt blocked with message about too many attempts

- [ ] Test 2: Successful login resets counter
  - Login successfully
  - Check that failed attempts are not blocking

- [ ] Test 3: Lockout expires after 15 minutes
  - Get locked out
  - Wait 15 minutes
  - Try again
  - Expected: Allowed to try again

### Admin Logging Testing

- [ ] Test 1: Login is logged
  - Login to admin panel
  - Check `admin_logs` table
  - Expected: Login action recorded

- [ ] Test 2: Delete action is logged
  - Delete a comment or photo
  - Check `admin_logs` table
  - Expected: Delete action recorded with details

- [ ] Test 3: Logout is logged
  - Logout from admin panel
  - Check `admin_logs` table
  - Expected: Logout action recorded

### Session Security Testing

- [ ] Test 1: Session regeneration after login
  - Note session ID before login
  - Login
  - Check session ID after login
  - Expected: Session ID changed

- [ ] Test 2: Session validation
  - Login to admin panel
  - Manually delete session cookie
  - Try to access admin page
  - Expected: Redirected to login

- [ ] Test 3: Session cleanup on logout
  - Login to admin panel
  - Logout
  - Try to use old session
  - Expected: Session invalid

## Security Audit Checklist

### Code Review

- [ ] No hardcoded credentials
- [ ] No sensitive data in logs
- [ ] No debug code in production
- [ ] No commented-out security checks
- [ ] All TODOs related to security are addressed

### Configuration Review

- [ ] Database credentials are secure
- [ ] Session configuration is secure
- [ ] Error reporting is appropriate for environment
- [ ] File permissions are correct

### Database Review

- [ ] All tables have proper indexes
- [ ] Foreign keys are properly defined
- [ ] No sensitive data in plain text
- [ ] Backup strategy is in place

### Documentation Review

- [ ] SECURITY.md is up to date
- [ ] SECURITY_QUICK_REFERENCE.md is accurate
- [ ] README.md includes security section
- [ ] Code comments explain security decisions

## Production Deployment Checklist

Before deploying to production:

- [ ] All security tests pass
- [ ] Change default admin password
- [ ] Configure secure session settings in php.ini
  ```ini
  session.cookie_httponly = 1
  session.cookie_secure = 1
  session.use_strict_mode = 1
  session.cookie_samesite = "Strict"
  ```

- [ ] Enable HTTPS
- [ ] Configure proper error logging
- [ ] Set up monitoring for admin_logs
- [ ] Set up alerts for failed login attempts
- [ ] Document incident response procedures
- [ ] Train admins on security best practices

## Ongoing Maintenance Checklist

### Daily
- [ ] Review failed login attempts
- [ ] Check for unusual admin activity

### Weekly
- [ ] Review admin_logs for suspicious activity
- [ ] Check for security updates

### Monthly
- [ ] Run security test suite
- [ ] Review and update security documentation
- [ ] Clean up old logs (optional)

### Quarterly
- [ ] Security audit
- [ ] Update dependencies
- [ ] Review and update security policies

## Compliance Checklist

### OWASP Top 10

- [ ] A01:2021 – Broken Access Control
  - ✅ Authentication required
  - ✅ Authorization checks in place

- [ ] A02:2021 – Cryptographic Failures
  - ✅ Passwords properly hashed
  - ✅ Secure session management

- [ ] A03:2021 – Injection
  - ✅ Prepared statements used
  - ✅ Input validation in place

- [ ] A04:2021 – Insecure Design
  - ✅ Security by design
  - ✅ Threat modeling considered

- [ ] A05:2021 – Security Misconfiguration
  - ✅ Secure defaults
  - ✅ Error handling configured

- [ ] A06:2021 – Vulnerable Components
  - ✅ Dependencies up to date
  - ✅ Regular updates planned

- [ ] A07:2021 – Authentication Failures
  - ✅ Brute force protection
  - ✅ Session management secure

- [ ] A08:2021 – Software and Data Integrity
  - ✅ CSRF protection
  - ✅ Input validation

- [ ] A09:2021 – Logging Failures
  - ✅ Admin actions logged
  - ✅ Security events logged

- [ ] A10:2021 – Server-Side Request Forgery
  - ✅ Input validation
  - ✅ URL validation where applicable

## Sign-off

### Developer Sign-off

- [ ] All code implemented according to specifications
- [ ] All tests pass
- [ ] Code reviewed
- [ ] Documentation complete

Signed: _________________ Date: _________

### Security Review Sign-off

- [ ] Security features verified
- [ ] Vulnerabilities addressed
- [ ] Compliance requirements met
- [ ] Ready for production

Signed: _________________ Date: _________

### Deployment Sign-off

- [ ] Production environment configured
- [ ] Monitoring in place
- [ ] Backup strategy confirmed
- [ ] Incident response plan ready

Signed: _________________ Date: _________
