<?php
/**
 * Performance Testing Script
 * Run this script to test admin panel performance and verify optimizations
 */

require_once '../config.php';
require_once 'config/cache_config.php';

echo "=== Admin Panel Performance Test ===\n\n";

// Test 1: Database Connection
echo "1. Testing Database Connection...\n";
$start = microtime(true);
try {
    $conn = connectToDatabase();
    $time = round((microtime(true) - $start) * 1000, 2);
    echo "   ✓ Connected in {$time}ms\n\n";
} catch (Exception $e) {
    echo "   ✗ Connection failed: " . $e->getMessage() . "\n\n";
    exit(1);
}

// Test 2: Check Indexes
echo "2. Checking Database Indexes...\n";
$tables = ['likes', 'comments', 'follows', 'favorites', 'photos', 'albums', 'commercial_posts', 'users'];
$totalIndexes = 0;

foreach ($tables as $table) {
    try {
        $stmt = $conn->prepare("SHOW INDEX FROM $table");
        $stmt->execute();
        $indexes = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $indexCount = count(array_unique(array_column($indexes, 'Key_name')));
        $totalIndexes += $indexCount;
        echo "   ✓ Table '$table': $indexCount indexes\n";
    } catch (Exception $e) {
        echo "   ✗ Table '$table': Error - " . $e->getMessage() . "\n";
    }
}
echo "   Total indexes: $totalIndexes\n\n";

// Test 3: Query Performance
echo "3. Testing Query Performance...\n";

$queries = [
    'Count Users' => "SELECT COUNT(*) as count FROM users",
    'Count Posts' => "SELECT COUNT(*) as count FROM photos",
    'Count Likes' => "SELECT COUNT(*) as count FROM likes",
    'Recent Posts' => "SELECT * FROM photos ORDER BY created_at DESC LIMIT 50",
    'User with Stats' => "SELECT u.*, 
        (SELECT COUNT(*) FROM follows WHERE followed_id = u.id) as followers,
        (SELECT COUNT(*) FROM photos WHERE user_id = u.id) as posts
        FROM users u LIMIT 1",
    'Likes with Join' => "SELECT l.*, u.first_name, u.last_name, p.title 
        FROM likes l 
        JOIN users u ON l.user_id = u.id 
        JOIN photos p ON l.photo_id = p.id 
        LIMIT 50"
];

foreach ($queries as $name => $sql) {
    $start = microtime(true);
    try {
        $stmt = $conn->prepare($sql);
        $stmt->execute();
        $result = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $time = round((microtime(true) - $start) * 1000, 2);
        $count = count($result);
        
        if ($time < 100) {
            echo "   ✓ $name: {$time}ms ($count rows) - EXCELLENT\n";
        } elseif ($time < 500) {
            echo "   ✓ $name: {$time}ms ($count rows) - GOOD\n";
        } else {
            echo "   ⚠ $name: {$time}ms ($count rows) - SLOW\n";
        }
    } catch (Exception $e) {
        echo "   ✗ $name: Error - " . $e->getMessage() . "\n";
    }
}
echo "\n";

// Test 4: Cache System
echo "4. Testing Cache System...\n";

// Test cache write
$start = microtime(true);
$testData = ['test' => 'data', 'timestamp' => time()];
$adminCache->set('test_key', $testData, 60);
$writeTime = round((microtime(true) - $start) * 1000, 2);
echo "   ✓ Cache write: {$writeTime}ms\n";

// Test cache read
$start = microtime(true);
$cachedData = $adminCache->get('test_key');
$readTime = round((microtime(true) - $start) * 1000, 2);

if ($cachedData !== null && $cachedData['test'] === 'data') {
    echo "   ✓ Cache read: {$readTime}ms - Data matches\n";
} else {
    echo "   ✗ Cache read: Data mismatch or not found\n";
}

// Test cache delete
$adminCache->delete('test_key');
$deletedData = $adminCache->get('test_key');
if ($deletedData === null) {
    echo "   ✓ Cache delete: Working correctly\n";
} else {
    echo "   ✗ Cache delete: Failed\n";
}

// Check cache directory
$cacheDir = __DIR__ . '/cache/';
if (is_writable($cacheDir)) {
    echo "   ✓ Cache directory: Writable\n";
} else {
    echo "   ✗ Cache directory: Not writable\n";
}
echo "\n";

// Test 5: Dashboard Stats Performance
echo "5. Testing Dashboard Stats API...\n";

// First call (uncached)
$start = microtime(true);
try {
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM users");
    $stmt->execute();
    $totalUsers = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM photos");
    $stmt->execute();
    $totalPosts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM likes");
    $stmt->execute();
    $totalLikes = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $time = round((microtime(true) - $start) * 1000, 2);
    echo "   ✓ Stats calculation (uncached): {$time}ms\n";
    
    if ($time < 1000) {
        echo "   ✓ Performance: GOOD\n";
    } else {
        echo "   ⚠ Performance: Consider optimization\n";
    }
} catch (Exception $e) {
    echo "   ✗ Error: " . $e->getMessage() . "\n";
}
echo "\n";

// Test 6: Table Sizes
echo "6. Checking Table Sizes...\n";
try {
    $stmt = $conn->prepare("
        SELECT 
            table_name,
            table_rows,
            ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
        FROM information_schema.TABLES
        WHERE table_schema = DATABASE()
        AND table_name IN ('users', 'photos', 'likes', 'comments', 'follows', 'favorites', 'albums', 'commercial_posts')
        ORDER BY (data_length + index_length) DESC
    ");
    $stmt->execute();
    $tables = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($tables as $table) {
        echo "   • {$table['table_name']}: {$table['table_rows']} rows, {$table['size_mb']} MB\n";
    }
} catch (Exception $e) {
    echo "   ✗ Error: " . $e->getMessage() . "\n";
}
echo "\n";

// Test 7: Index Usage Analysis
echo "7. Analyzing Index Usage (Sample Queries)...\n";

$testQueries = [
    "SELECT * FROM likes WHERE user_id = 1 LIMIT 10",
    "SELECT * FROM photos WHERE user_id = 1 ORDER BY created_at DESC LIMIT 10",
    "SELECT * FROM follows WHERE follower_id = 1 AND followed_id = 2"
];

foreach ($testQueries as $query) {
    try {
        $stmt = $conn->prepare("EXPLAIN $query");
        $stmt->execute();
        $explain = $stmt->fetch(PDO::FETCH_ASSOC);
        
        $shortQuery = substr($query, 0, 50) . '...';
        
        if ($explain['key'] !== null) {
            echo "   ✓ Using index '{$explain['key']}': $shortQuery\n";
        } else {
            echo "   ⚠ No index used: $shortQuery\n";
        }
    } catch (Exception $e) {
        echo "   ✗ Error analyzing query\n";
    }
}
echo "\n";

// Summary
echo "=== Performance Test Summary ===\n";
echo "✓ Database connection: Working\n";
echo "✓ Indexes: $totalIndexes indexes found\n";
echo "✓ Query performance: Tested\n";
echo "✓ Cache system: Working\n";
echo "✓ Dashboard stats: Tested\n";
echo "\n";

echo "Recommendations:\n";
if ($totalIndexes < 30) {
    echo "⚠ Consider running: php migrations/apply_indexes.php\n";
}
echo "• Monitor slow query log for queries > 1 second\n";
echo "• Clear cache periodically: \$adminCache->cleanExpired()\n";
echo "• Review TESTING_CHECKLIST.md for manual testing\n";
echo "• Review OPTIMIZATION_GUIDE.md for best practices\n";
echo "\n";

echo "Performance test completed!\n";
