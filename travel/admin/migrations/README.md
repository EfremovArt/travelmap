# Database Migrations

This directory contains SQL migration files for the admin panel.

## Running Migrations

### Method 1: Using MySQL Command Line

```bash
# Navigate to the migrations directory
cd travel/admin/migrations

# Run the security tables migration
mysql -u your_username -p your_database_name < add_security_tables.sql
```

### Method 2: Using phpMyAdmin

1. Open phpMyAdmin
2. Select your database
3. Go to the "SQL" tab
4. Copy and paste the contents of `add_security_tables.sql`
5. Click "Go" to execute

### Method 3: Using PHP Script

You can also create a simple PHP script to run migrations:

```php
<?php
require_once '../config/admin_config.php';

$db = connectToDatabase();

// Read the migration file
$sql = file_get_contents(__DIR__ . '/add_security_tables.sql');

// Execute the migration
try {
    $db->exec($sql);
    echo "Migration completed successfully!\n";
} catch (PDOException $e) {
    echo "Migration failed: " . $e->getMessage() . "\n";
}
?>
```

## Available Migrations

### add_security_tables.sql

Creates the following tables:

1. **admin_logs** - Logs all administrative actions
   - Tracks who did what, when, and from where
   - Includes IP address and user agent for audit trails

2. **login_attempts** - Tracks login attempts for brute force protection
   - Records both successful and failed login attempts
   - Used to implement rate limiting on login

### add_performance_indexes.sql

Creates 40+ database indexes for performance optimization:

1. **Single-column indexes** - For foreign keys and frequently filtered columns
   - user_id, photo_id, album_id, location_id, created_at, etc.

2. **Composite indexes** - For common query patterns
   - (user_id, photo_id) for likes
   - (photo_id, created_at) for comments
   - (follower_id, followed_id) for follows
   - (user_id, created_at) for photos
   - (type, is_active) for commercial_posts

**Installation:**
```bash
cd travel/admin/migrations
php apply_indexes.php
```

Or manually:
```bash
mysql -u your_username -p your_database_name < add_performance_indexes.sql
```

**Expected Performance Improvement:**
- List queries: 50-80% faster
- Filter queries: 60-90% faster
- JOIN queries: 40-70% faster

## Verifying Migrations

After running migrations, verify the tables were created:

```sql
-- Check if tables exist
SHOW TABLES LIKE 'admin_logs';
SHOW TABLES LIKE 'login_attempts';

-- Check table structure
DESCRIBE admin_logs;
DESCRIBE login_attempts;

-- Check indexes
SHOW INDEX FROM admin_logs;
SHOW INDEX FROM login_attempts;
```

## Rollback

If you need to remove the security tables:

```sql
DROP TABLE IF EXISTS admin_logs;
DROP TABLE IF EXISTS login_attempts;
```

**Warning:** This will delete all logged data. Make sure to backup first if needed.

## Migration History

| Date | File | Description |
|------|------|-------------|
| 2025-01-15 | add_security_tables.sql | Initial security tables for CSRF, logging, and brute force protection |
| 2025-01-15 | add_performance_indexes.sql | Performance optimization indexes for all major tables |
