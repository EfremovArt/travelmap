# Admin Panel Testing Checklist

## Overview
This document provides a comprehensive testing checklist for the admin panel. Use this to verify all functionality works correctly.

## Pre-Testing Setup

### Database Preparation
- [ ] Database has test data (users, posts, comments, likes, etc.)
- [ ] Database indexes are applied (`php migrations/apply_indexes.php`)
- [ ] Security tables are created (`migrations/add_security_tables.sql`)
- [ ] Admin user account exists

### Environment Check
- [ ] PHP 7.4+ is installed
- [ ] MySQL/MariaDB is running
- [ ] Web server (Apache/Nginx) is configured
- [ ] File permissions are correct (cache directory writable)
- [ ] Config files are properly set up

## 1. Authentication Testing

### Login Page (`/admin/login.php`)
- [ ] Page loads without errors
- [ ] Login form displays correctly
- [ ] **Valid credentials**: Login succeeds and redirects to dashboard
- [ ] **Invalid credentials**: Shows error message
- [ ] **Empty fields**: Shows validation error
- [ ] **SQL injection attempt**: Blocked (try `' OR '1'='1`)
- [ ] **Rate limiting**: After 5 failed attempts, account is locked
- [ ] Session is created on successful login
- [ ] Remember me functionality (if implemented)

### Logout (`/admin/logout.php`)
- [ ] Logout clears session
- [ ] Redirects to login page
- [ ] Cannot access admin pages after logout

### Session Management
- [ ] Session expires after inactivity
- [ ] Cannot access admin pages without login
- [ ] Session hijacking protection (check session tokens)

## 2. Dashboard Testing (`/admin/views/dashboard.php`)

### Page Load
- [ ] Dashboard loads without errors
- [ ] All statistics cards display correctly
- [ ] Numbers are accurate (verify against database)
- [ ] Chart loads and displays data
- [ ] Responsive layout works on different screen sizes

### Statistics Verification
- [ ] **Total Users**: Matches `SELECT COUNT(*) FROM users`
- [ ] **Total Posts**: Matches `SELECT COUNT(*) FROM photos`
- [ ] **Total Likes**: Matches `SELECT COUNT(*) FROM likes`
- [ ] **Total Comments**: Matches sum of comments + album_comments
- [ ] **Total Follows**: Matches `SELECT COUNT(*) FROM follows`
- [ ] **Total Favorites**: Matches sum of all favorites tables
- [ ] **Total Albums**: Matches `SELECT COUNT(*) FROM albums`
- [ ] **Total Commercial Posts**: Matches `SELECT COUNT(*) FROM commercial_posts`

### Recent Activity
- [ ] New users count (last 7 days) is accurate
- [ ] New posts count (last 7 days) is accurate
- [ ] New comments count (last 7 days) is accurate

### Activity Chart
- [ ] Chart displays 7 days of data
- [ ] Data points are accurate
- [ ] Chart is interactive (hover shows values)
- [ ] Chart legend is visible

### Caching
- [ ] First load: `"cached": false` in API response
- [ ] Second load (within 5 min): `"cached": true` in API response
- [ ] Cache expires after 5 minutes
- [ ] Cache can be manually cleared

## 3. Likes Management (`/admin/views/likes.php`)

### Page Load
- [ ] Page loads without errors
- [ ] DataTable initializes correctly
- [ ] Likes list displays with all columns
- [ ] Pagination works

### Data Display
- [ ] User name displays correctly
- [ ] User profile image shows (or placeholder)
- [ ] Photo title displays
- [ ] Photo preview shows
- [ ] Created date is formatted correctly

### Filtering
- [ ] **Filter by user**: Dropdown populates with users
- [ ] **Filter by user**: Selecting user filters results
- [ ] **Filter by post**: Dropdown populates with posts
- [ ] **Filter by post**: Selecting post filters results
- [ ] **Clear filters**: Resets to show all likes

### Search
- [ ] Search by user name works
- [ ] Search is case-insensitive
- [ ] Search updates results in real-time (debounced)

### Sorting
- [ ] Sort by date (ascending/descending)
- [ ] Sort by user name
- [ ] Sort by post title

### Pagination
- [ ] Shows correct number of items per page (50 default)
- [ ] Page navigation works
- [ ] "Next" and "Previous" buttons work
- [ ] Jump to specific page works
- [ ] Total count is accurate

## 4. Comments Management (`/admin/views/comments.php`)

### Page Load
- [ ] Page loads without errors
- [ ] Comments table displays correctly
- [ ] Both photo and album comments are shown

### Data Display
- [ ] Author name displays
- [ ] Comment text displays (truncated if long)
- [ ] Post/Album title displays
- [ ] Created date displays
- [ ] Delete button shows for each comment

### Filtering
- [ ] Filter by user works
- [ ] Filter by post works
- [ ] Filter by album works
- [ ] Clear filters works

### Search
- [ ] Search by comment text works
- [ ] Search is case-insensitive
- [ ] Partial matches work

### Delete Functionality
- [ ] **Click delete**: Confirmation dialog appears
- [ ] **Confirm delete**: Comment is deleted from database
- [ ] **Cancel delete**: Comment remains
- [ ] **After delete**: Table refreshes automatically
- [ ] **Success message**: Shows after successful deletion
- [ ] **Error handling**: Shows error if deletion fails
- [ ] **CSRF protection**: Delete requires valid token

### Pagination & Sorting
- [ ] Pagination works correctly
- [ ] Sort by date works
- [ ] Sort by author works

## 5. Users Management (`/admin/views/users.php`)

### Users List
- [ ] Page loads without errors
- [ ] Users table displays all users
- [ ] Profile images display correctly
- [ ] Statistics columns show correct counts

### Data Display
- [ ] First name and last name display
- [ ] Email displays
- [ ] Profile image shows (or default avatar)
- [ ] Registration date displays
- [ ] Followers count is accurate
- [ ] Following count is accurate
- [ ] Posts count is accurate

### Search
- [ ] Search by name works
- [ ] Search by email works
- [ ] Search is case-insensitive

### Sorting
- [ ] Sort by name works
- [ ] Sort by registration date works
- [ ] Sort by followers count works

### User Details Page
- [ ] **Click user**: Navigates to user details page
- [ ] **User info**: All basic info displays correctly
- [ ] **Statistics**: All stats are accurate

### User Details - Followers Section
- [ ] Followers list displays
- [ ] Shows up to 50 followers
- [ ] Each follower has name, email, profile image
- [ ] Follow date displays

### User Details - Following Section
- [ ] Following list displays
- [ ] Shows up to 50 following
- [ ] Each user has name, email, profile image
- [ ] Follow date displays

### User Details - Favorite Posts
- [ ] Favorite posts list displays
- [ ] Shows post title, description, image
- [ ] Location name displays
- [ ] Favorited date displays

### User Details - Favorite Albums
- [ ] Favorite albums list displays
- [ ] Shows album title, description, cover photo
- [ ] Favorited date displays

### User Details - Commented Posts
- [ ] Commented posts list displays
- [ ] Shows posts user has commented on
- [ ] Comment count displays

### User Details - Posts with Comments
- [ ] Posts with comments list displays
- [ ] Shows user's posts that have received comments
- [ ] Comment count displays

## 6. Follows Management (`/admin/views/follows.php`)

### Page Load
- [ ] Page loads without errors
- [ ] Follows table displays correctly

### Data Display
- [ ] Follower name displays
- [ ] Follower profile image shows
- [ ] Followed user name displays
- [ ] Followed user profile image shows
- [ ] Follow date displays

### Filtering
- [ ] Filter by user (as follower) works
- [ ] Filter by user (as followed) works
- [ ] Clear filters works

### Search
- [ ] Search by follower name works
- [ ] Search by followed user name works

### Pagination & Sorting
- [ ] Pagination works
- [ ] Sort by date works
- [ ] Sort by follower name works

## 7. Favorites Management (`/admin/views/favorites.php`)

### Page Load
- [ ] Page loads without errors
- [ ] Tabs display correctly (Photos, Albums, Commercial)

### Photo Favorites Tab
- [ ] Photo favorites list displays
- [ ] User name displays
- [ ] Photo title and preview show
- [ ] Favorited date displays
- [ ] Pagination works

### Album Favorites Tab
- [ ] Album favorites list displays
- [ ] User name displays
- [ ] Album title and cover photo show
- [ ] Favorited date displays
- [ ] Pagination works

### Commercial Favorites Tab
- [ ] Commercial post favorites list displays
- [ ] User name displays
- [ ] Commercial post title and preview show
- [ ] Favorited date displays
- [ ] Pagination works

### Tab Switching
- [ ] Switching tabs loads correct data
- [ ] Tab state is maintained
- [ ] Each tab has independent pagination

### Filtering
- [ ] Filter by user works on all tabs
- [ ] Clear filters works

### Search
- [ ] Search works on all tabs
- [ ] Search by user name works
- [ ] Search by content title works

## 8. Posts Management (`/admin/views/posts.php`)

### Page Load
- [ ] Page loads without errors
- [ ] Tabs display correctly (Posts, Albums, Commercial Posts)

### Posts Tab
- [ ] Posts list displays
- [ ] Photo preview shows
- [ ] Title and description display
- [ ] Author name displays
- [ ] Location name displays
- [ ] Created date displays
- [ ] Likes and comments count display

### Albums Tab
- [ ] Albums list displays
- [ ] Cover photo shows
- [ ] Title and description display
- [ ] Owner name displays
- [ ] Photos count displays
- [ ] Public/Private status shows
- [ ] Created date displays
- [ ] **Click album**: Shows album photos modal/page

### Album Photos View
- [ ] Album photos list displays
- [ ] All photos in album show
- [ ] Photo titles display
- [ ] Photo previews show
- [ ] Position/order is correct

### Commercial Posts Tab
- [ ] Commercial posts list displays
- [ ] Title and description display
- [ ] Author name displays
- [ ] Type (album/photo/standalone) displays
- [ ] Location displays
- [ ] Active status shows
- [ ] Created date displays
- [ ] **Click commercial post**: Navigates to details page

### Commercial Post Details Page
- [ ] Page loads without errors
- [ ] Commercial post info displays
- [ ] Type is shown correctly
- [ ] **If type=album**: Related album info shows
- [ ] **If type=album**: Album photos list displays
- [ ] **If type=photo**: Related photo info shows
- [ ] **If type=standalone**: Location info shows
- [ ] Related posts list displays (if any)

### Filtering (All Tabs)
- [ ] Filter by author works
- [ ] Clear filters works

### Search (All Tabs)
- [ ] Search by title works
- [ ] Search by location works
- [ ] Search is case-insensitive

### Pagination & Sorting
- [ ] Pagination works on all tabs
- [ ] Sort by date works
- [ ] Sort by author works

## 9. Moderation (`/admin/views/moderation.php`)

### Page Load
- [ ] Page loads without errors
- [ ] Photo gallery displays
- [ ] Photos load with lazy loading

### Photo Display
- [ ] Photo thumbnails display
- [ ] Author name displays
- [ ] Upload date displays
- [ ] Checkbox for selection shows
- [ ] **Hover**: Full-size preview shows (if implemented)

### Filtering
- [ ] Filter by author works
- [ ] Filter by date range works
- [ ] Clear filters works

### Single Photo Delete
- [ ] **Click delete**: Confirmation dialog appears
- [ ] **Confirm**: Photo is deleted from database
- [ ] **Confirm**: Photo file is deleted from filesystem
- [ ] **After delete**: Gallery refreshes
- [ ] **Success message**: Shows after deletion
- [ ] **Error handling**: Shows error if deletion fails

### Bulk Delete
- [ ] **Select multiple photos**: Checkboxes work
- [ ] **Select all**: Selects all photos on page
- [ ] **Bulk delete button**: Appears when photos selected
- [ ] **Click bulk delete**: Confirmation shows count
- [ ] **Confirm bulk delete**: All selected photos deleted
- [ ] **After bulk delete**: Gallery refreshes
- [ ] **Success message**: Shows count of deleted photos

### CSRF Protection
- [ ] Delete operations require valid CSRF token
- [ ] Invalid token is rejected

### Pagination
- [ ] Pagination works
- [ ] Photos per page setting works
- [ ] Total count is accurate

## 10. Security Testing

### SQL Injection
- [ ] **Login form**: Try `' OR '1'='1` - should be blocked
- [ ] **Search fields**: Try SQL injection - should be blocked
- [ ] **Filter parameters**: Try SQL injection - should be blocked
- [ ] All queries use prepared statements

### XSS (Cross-Site Scripting)
- [ ] **Comment text**: Try `<script>alert('XSS')</script>` - should be escaped
- [ ] **User names**: Try XSS - should be escaped
- [ ] **Post titles**: Try XSS - should be escaped
- [ ] All output is escaped with `htmlspecialchars()`

### CSRF (Cross-Site Request Forgery)
- [ ] Delete operations require CSRF token
- [ ] Invalid CSRF token is rejected
- [ ] CSRF token expires after use
- [ ] CSRF token is unique per session

### Authentication & Authorization
- [ ] Cannot access admin pages without login
- [ ] Session expires after inactivity
- [ ] Logout clears session completely
- [ ] Direct URL access requires authentication

### Rate Limiting
- [ ] Login attempts are limited (5 attempts)
- [ ] Account locks after failed attempts
- [ ] Lockout duration is enforced (15 minutes)
- [ ] Successful login resets attempt counter

### File Operations
- [ ] Photo deletion removes file from filesystem
- [ ] File paths are validated
- [ ] Cannot delete files outside uploads directory
- [ ] File operations are logged

## 11. Performance Testing

### Response Times
- [ ] **Dashboard (cached)**: < 200ms
- [ ] **Dashboard (uncached)**: < 1s
- [ ] **List pages**: < 500ms
- [ ] **Detail pages**: < 1s
- [ ] **Delete operations**: < 300ms

### Database Performance
- [ ] Indexes are applied (check with `SHOW INDEX`)
- [ ] Queries use indexes (check with `EXPLAIN`)
- [ ] No N+1 query patterns
- [ ] Pagination limits results

### Caching
- [ ] Dashboard stats are cached
- [ ] Cache expires after 5 minutes
- [ ] Cache can be cleared manually
- [ ] Cache directory is writable

### Load Testing
- [ ] Test with 100+ users in database
- [ ] Test with 1000+ posts in database
- [ ] Test with 10000+ likes in database
- [ ] Pagination still works with large datasets

## 12. Responsive Design Testing

### Desktop (1920x1080)
- [ ] Layout displays correctly
- [ ] All elements are visible
- [ ] Tables fit on screen
- [ ] No horizontal scrolling (except tables)

### Laptop (1366x768)
- [ ] Layout displays correctly
- [ ] Sidebar is accessible
- [ ] Tables are scrollable if needed

### Tablet (1024x768)
- [ ] Layout adapts correctly
- [ ] Sidebar collapses or adapts
- [ ] Tables are scrollable
- [ ] Touch interactions work

### Mobile (Not primary target, but check)
- [ ] Basic functionality works
- [ ] Can login
- [ ] Can view data (with scrolling)

## 13. Browser Compatibility

### Chrome (Latest)
- [ ] All features work
- [ ] No console errors
- [ ] UI displays correctly

### Firefox (Latest)
- [ ] All features work
- [ ] No console errors
- [ ] UI displays correctly

### Safari (Latest)
- [ ] All features work
- [ ] No console errors
- [ ] UI displays correctly

### Edge (Latest)
- [ ] All features work
- [ ] No console errors
- [ ] UI displays correctly

## 14. Error Handling

### Network Errors
- [ ] **API timeout**: Shows error message
- [ ] **API error**: Shows user-friendly message
- [ ] **Network offline**: Shows appropriate error

### Database Errors
- [ ] **Connection failed**: Shows error message
- [ ] **Query failed**: Shows error message
- [ ] **No results**: Shows "No data" message

### Validation Errors
- [ ] **Invalid input**: Shows validation message
- [ ] **Missing required fields**: Shows error
- [ ] **Invalid format**: Shows format error

### File Errors
- [ ] **File not found**: Shows error message
- [ ] **Permission denied**: Shows error message
- [ ] **Disk full**: Shows error message

## 15. Logging & Monitoring

### Admin Actions Logging
- [ ] Login attempts are logged
- [ ] Successful logins are logged
- [ ] Failed logins are logged
- [ ] Delete operations are logged
- [ ] Bulk operations are logged

### Error Logging
- [ ] PHP errors are logged
- [ ] Database errors are logged
- [ ] File operation errors are logged

### Log Review
- [ ] Logs are readable
- [ ] Logs contain useful information
- [ ] Logs don't contain sensitive data (passwords)

## Testing Sign-Off

### Tester Information
- **Tester Name**: _______________
- **Date**: _______________
- **Environment**: _______________

### Test Results
- **Total Tests**: _______________
- **Passed**: _______________
- **Failed**: _______________
- **Blocked**: _______________

### Critical Issues Found
1. _______________
2. _______________
3. _______________

### Notes
_______________________________________________
_______________________________________________
_______________________________________________

### Approval
- [ ] All critical tests passed
- [ ] All security tests passed
- [ ] Performance meets requirements
- [ ] Ready for production

**Approved by**: _______________
**Date**: _______________
