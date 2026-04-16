# Admin Panel Optimization Guide

## Overview
This document describes the performance optimizations implemented in the admin panel and how to maintain optimal performance.

## Database Indexes

### Applied Indexes
The following indexes have been added to improve query performance:

#### Core Tables
- **likes**: `user_id`, `photo_id`, `created_at`, composite `(user_id, photo_id)`
- **comments**: `user_id`, `photo_id`, `created_at`, composite `(photo_id, created_at)`
- **album_comments**: `user_id`, `album_id`, `created_at`
- **follows**: `follower_id`, `followed_id`, `created_at`, composite `(follower_id, followed_id)`
- **favorites**: `user_id`, `photo_id`, `created_at`
- **album_favorites**: `user_id`, `album_id`, `created_at`
- **commercial_favorites**: `user_id`, `commercial_post_id`, `created_at`
- **photos**: `user_id`, `location_id`, `created_at`, composite `(user_id, created_at)`
- **albums**: `owner_id`, `created_at`, `is_public`
- **album_photos**: `album_id`, `photo_id`
- **commercial_posts**: `user_id`, `type`, `album_id`, `photo_id`, `is_active`, `created_at`, composite `(type, is_active)`
- **users**: `email`, `created_at`
- **locations**: `name`

### How to Apply Indexes

Run the migration script:
```bash
cd travel/admin/migrations
php apply_indexes.php
```

Or manually execute the SQL file:
```bash
mysql -u username -p database_name < add_performance_indexes.sql
```

### Index Maintenance

Check index usage:
```sql
-- Show indexes for a table
SHOW INDEX FROM table_name;

-- Check index statistics
SELECT * FROM information_schema.STATISTICS 
WHERE table_schema = 'your_database' 
AND table_name = 'your_table';
```

## Caching System

### Cache Configuration
The admin panel uses a file-based caching system located in `travel/admin/config/cache_config.php`.

**Default Settings:**
- Cache directory: `travel/admin/cache/`
- Default TTL: 300 seconds (5 minutes)
- Storage format: JSON files

### Cached Endpoints

#### Dashboard Statistics
- **Endpoint**: `/admin/api/dashboard/get_stats.php`
- **Cache Key**: `dashboard_stats`
- **TTL**: 300 seconds (5 minutes)
- **Reason**: Dashboard stats are expensive to calculate and don't need real-time accuracy

### Cache Management

**Clear all cache:**
```php
require_once 'config/cache_config.php';
$adminCache->clear();
```

**Clear specific cache:**
```php
$adminCache->delete('dashboard_stats');
```

**Clean expired cache:**
```php
$adminCache->cleanExpired();
```

### Cache Invalidation Strategy

The cache should be invalidated when:
1. Major data changes occur (bulk operations)
2. Manual refresh is requested
3. Cache expires naturally (TTL)

**Note**: For most admin operations, stale data for 5 minutes is acceptable. If real-time data is needed, add a "Refresh" button that bypasses cache.

## Query Optimization

### Best Practices

1. **Use Indexes**: All foreign keys and frequently filtered columns have indexes
2. **Limit Results**: All list endpoints use pagination (default 50 items per page)
3. **Avoid N+1 Queries**: Use JOINs or separate optimized queries instead of loops
4. **Use EXPLAIN**: Test complex queries with EXPLAIN to verify index usage

### Optimized Query Patterns

#### Good: Using Indexes
```sql
SELECT * FROM likes 
WHERE user_id = ? 
ORDER BY created_at DESC 
LIMIT 50;
```

#### Good: Composite Index Usage
```sql
SELECT * FROM follows 
WHERE follower_id = ? AND followed_id = ?;
```

#### Bad: Full Table Scan
```sql
SELECT * FROM photos 
WHERE YEAR(created_at) = 2025;  -- Doesn't use index
```

#### Better: Index-Friendly Date Filter
```sql
SELECT * FROM photos 
WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01';
```

### Query Performance Testing

Test query performance:
```sql
EXPLAIN SELECT * FROM your_query;
```

Look for:
- `type: ALL` = Full table scan (BAD)
- `type: index` = Index scan (GOOD)
- `type: ref` = Index lookup (BEST)
- `key: NULL` = No index used (BAD)

## Performance Monitoring

### Key Metrics to Monitor

1. **Response Times**
   - Dashboard load: < 1 second (with cache)
   - List endpoints: < 500ms
   - Detail endpoints: < 1 second

2. **Database Performance**
   - Query execution time: < 100ms for most queries
   - Connection pool usage
   - Slow query log

3. **Cache Hit Rate**
   - Target: > 80% for dashboard stats
   - Monitor cache file sizes

### Monitoring Tools

**Check slow queries:**
```sql
-- Enable slow query log in MySQL
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;  -- Log queries > 1 second
```

**Check table sizes:**
```sql
SELECT 
    table_name,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS "Size (MB)"
FROM information_schema.TABLES
WHERE table_schema = 'your_database'
ORDER BY (data_length + index_length) DESC;
```

## Optimization Checklist

### Database Level
- [x] Indexes added for all foreign keys
- [x] Indexes added for frequently filtered columns
- [x] Composite indexes for common query patterns
- [x] All queries use prepared statements (prevents SQL injection and improves performance)

### Application Level
- [x] Caching implemented for expensive operations
- [x] Pagination implemented for all list endpoints
- [x] Query results limited to reasonable amounts
- [x] Separate queries instead of N+1 patterns

### Frontend Level
- [x] DataTables for client-side sorting/filtering
- [x] Lazy loading for images
- [x] Debounced search inputs
- [x] Minimal DOM manipulation

## Troubleshooting

### Slow Dashboard Load
1. Check if cache is working: Look for `"cached": true` in response
2. Clear and rebuild cache: `$adminCache->clear()`
3. Check database connection pool
4. Verify indexes are applied: `php migrations/apply_indexes.php`

### Slow List Pages
1. Verify pagination is working (check LIMIT in queries)
2. Check if indexes are being used: `EXPLAIN` the query
3. Reduce per_page limit if needed
4. Check for N+1 query patterns

### High Database Load
1. Check slow query log
2. Verify all indexes are applied
3. Consider increasing cache TTL for dashboard
4. Review and optimize complex JOIN queries

## Future Optimization Opportunities

### Short Term
1. Add Redis/Memcached for distributed caching
2. Implement query result caching for user lists
3. Add database connection pooling
4. Implement lazy loading for user detail sections

### Long Term
1. Consider read replicas for reporting queries
2. Implement full-text search indexes for text searches
3. Add database query profiling in development
4. Consider materialized views for complex statistics

## Maintenance Schedule

### Daily
- Monitor slow query log
- Check cache directory size

### Weekly
- Clean expired cache files: `$adminCache->cleanExpired()`
- Review slow queries and optimize

### Monthly
- Analyze table statistics: `ANALYZE TABLE table_name`
- Review and update indexes based on query patterns
- Check database size and plan for growth

## Performance Targets

### Response Times
- Dashboard (cached): < 200ms
- Dashboard (uncached): < 1s
- List endpoints: < 500ms
- Detail endpoints: < 1s
- Delete operations: < 300ms

### Database
- Query execution: < 100ms (95th percentile)
- Connection time: < 50ms
- Index usage: > 95% of queries

### Cache
- Hit rate: > 80% for dashboard
- Storage: < 100MB
- Cleanup: Automatic on expired items

## Contact

For performance issues or optimization questions, refer to this guide or consult the development team.
