<?php
session_start();
$_SESSION['admin_id'] = 1; // Simulate admin

require_once 'config/admin_config.php';
require_once '../config.php';

$pdo = connectToDatabase();

$sql = "SELECT 
            cp.user_id,
            u.profile_image_url
        FROM commercial_posts cp
        INNER JOIN users u ON cp.user_id = u.id
        WHERE u.profile_image_url LIKE '%google%'
        LIMIT 3";

$stmt = $pdo->query($sql);
$posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "<h2>Commercial Posts with Google URLs</h2>";
echo "<pre>";
print_r($posts);
echo "</pre>";

echo "<h3>After processing:</h3>";
foreach ($posts as $post) {
    $url = $post['profile_image_url'];
    $cleanPath = ltrim($url, '/');
    
    echo "Original: " . htmlspecialchars($url) . "<br>";
    echo "After ltrim: " . htmlspecialchars($cleanPath) . "<br>";
    echo "Starts with http: " . (strpos($cleanPath, 'http://') === 0 ? 'YES' : 'NO') . "<br>";
    echo "Starts with https: " . (strpos($cleanPath, 'https://') === 0 ? 'YES' : 'NO') . "<br>";
    
    if (strpos($cleanPath, 'http://') === 0 || strpos($cleanPath, 'https://') === 0) {
        echo "Result: " . htmlspecialchars($cleanPath) . " (external URL)<br>";
    } else {
        if (strpos($cleanPath, 'travel/') !== 0) {
            $cleanPath = 'travel/' . $cleanPath;
        }
        echo "Result: ../../" . htmlspecialchars($cleanPath) . " (local file)<br>";
    }
    echo "<br>";
}
