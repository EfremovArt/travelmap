<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Testing Users API</h2>";

try {
    $pdo = connectToDatabase();
    echo "✓ Database connection successful<br>";
    
    // Test users table
    echo "<h3>Testing users table:</h3>";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM users");
    $count = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Users count: " . $count['count'] . "<br>";
    
    // Test main query
    echo "<h3>Testing main query:</h3>";
    $sql = "
        SELECT 
            u.id,
            u.first_name,
            u.last_name,
            u.email,
            u.profile_image_url,
            u.created_at,
            (SELECT COUNT(*) FROM follows WHERE followed_id = u.id) as followers_count,
            (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) as following_count,
            (SELECT COUNT(*) FROM photos WHERE user_id = u.id) as posts_count,
            (SELECT COUNT(*) FROM likes WHERE user_id = u.id) as likes_count,
            (SELECT COUNT(*) FROM comments WHERE user_id = u.id) + 
            (SELECT COUNT(*) FROM album_comments WHERE user_id = u.id) as comments_count
        FROM users u
        ORDER BY u.id DESC
        LIMIT 5
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($users) . " users<br>";
    echo "<pre>";
    print_r($users);
    echo "</pre>";
    
    echo "<h3>✓ All tests passed!</h3>";
    
} catch (Exception $e) {
    echo "<h3 style='color: red;'>✗ Error: " . $e->getMessage() . "</h3>";
    echo "<pre>";
    echo $e->getTraceAsString();
    echo "</pre>";
}
