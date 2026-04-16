<?php
// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    // Test parameters
    $search = 'art';
    
    echo "Testing search with: '$search'\n\n";
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    // Trim search and check if not empty
    $search = trim($search);
    if (!empty($search) && strlen($search) > 0) {
        $whereConditions[] = "(
            u.first_name LIKE :search 
            OR u.last_name LIKE :search 
            OR u.email LIKE :search 
            OR u.apple_id LIKE :search
            OR CONCAT(u.first_name, ' ', u.last_name) LIKE :search
        )";
        $params[':search'] = "%{$search}%";
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    echo "WHERE clause: $whereClause\n";
    echo "Params: " . print_r($params, true) . "\n\n";
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total FROM users u {$whereClause}";
    echo "Count SQL: $countSql\n\n";
    
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    echo "Total found: $total\n\n";
    
    // Get users with statistics
    $sql = "
        SELECT 
            u.id,
            u.first_name,
            u.last_name,
            u.email,
            u.apple_id,
            u.profile_image_url,
            u.created_at,
            (SELECT COUNT(*) FROM follows WHERE followed_id = u.id) as followers_count,
            (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) as following_count,
            (SELECT COUNT(*) FROM photos WHERE user_id = u.id) as posts_count,
            (SELECT COUNT(*) FROM likes WHERE user_id = u.id) as likes_count,
            (SELECT COUNT(*) FROM comments WHERE user_id = u.id) + 
            (SELECT COUNT(*) FROM album_comments WHERE user_id = u.id) as comments_count
        FROM users u
        {$whereClause}
        ORDER BY id DESC
        LIMIT 10
    ";
    
    echo "Main SQL:\n$sql\n\n";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind search parameters
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Users found: " . count($users) . "\n";
    echo json_encode($users, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . "\n";
    echo "Line: " . $e->getLine() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString();
}
