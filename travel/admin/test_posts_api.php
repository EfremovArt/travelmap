<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Testing Posts API</h2>";

try {
    $pdo = connectToDatabase();
    echo "✓ Database connection successful<br>";
    
    // Test query
    echo "<h3>Testing posts query:</h3>";
    $sql = "SELECT 
                p.id,
                p.user_id,
                CONCAT(u.first_name, ' ', u.last_name) as user_name,
                u.email as user_email,
                u.profile_image_url as user_profile_image,
                p.location_id,
                l.title as location_name,
                p.title,
                p.file_path as preview
            FROM photos p
            LEFT JOIN users u ON p.user_id = u.id
            LEFT JOIN locations l ON p.location_id = l.id
            LIMIT 3";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($posts) . " posts<br>";
    echo "<pre>";
    print_r($posts);
    echo "</pre>";
    
    echo "<h3>✓ All tests passed!</h3>";
    
} catch (Exception $e) {
    echo "<h3 style='color: red;'>✗ Error: " . $e->getMessage() . "</h3>";
    echo "<pre>";
    echo $e->getTraceAsString();
    echo "</pre>";
}
