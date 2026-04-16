<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

header('Content-Type: text/html; charset=UTF-8');

// Подключение к базе данных
$pdo = connectToDatabase();

// Get one commercial post
$sql = "SELECT 
            cp.id,
            cp.user_id,
            u.profile_image_url as user_profile_image,
            cp.image_url as preview
        FROM commercial_posts cp
        LEFT JOIN users u ON cp.user_id = u.id
        LIMIT 5";

$stmt = $pdo->prepare($sql);
$stmt->execute();
$posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "<h2>Raw data from database:</h2>";
echo "<pre>";
print_r($posts);
echo "</pre>";

echo "<h2>After API processing:</h2>";
foreach ($posts as &$post) {
    echo "<h3>Post ID: {$post['id']}</h3>";
    
    if ($post['user_profile_image']) {
        echo "Original user_profile_image: {$post['user_profile_image']}<br>";
        $cleanPath = ltrim($post['user_profile_image'], '/');
        echo "After ltrim: {$cleanPath}<br>";
        
        if (strpos($cleanPath, 'http://') === 0 || strpos($cleanPath, 'https://') === 0) {
            echo "Type: External URL<br>";
            $post['user_profile_image'] = $cleanPath;
        } else {
            echo "Type: Local file<br>";
            if (strpos($cleanPath, 'travel/') !== 0) {
                echo "Adding 'travel/' prefix<br>";
                $cleanPath = 'travel/' . $cleanPath;
            } else {
                echo "'travel/' already present<br>";
            }
            $post['user_profile_image'] = '../../' . $cleanPath;
        }
        echo "Final: {$post['user_profile_image']}<br><br>";
    }
    
    if ($post['preview']) {
        echo "Original preview: {$post['preview']}<br>";
        $cleanPath = ltrim($post['preview'], '/');
        echo "After ltrim: {$cleanPath}<br>";
        
        if (strpos($cleanPath, 'http://') === 0 || strpos($cleanPath, 'https://') === 0) {
            echo "Type: External URL<br>";
            $post['preview'] = $cleanPath;
        } else {
            echo "Type: Local file<br>";
            if (strpos($cleanPath, 'travel/') !== 0) {
                echo "Adding 'travel/' prefix<br>";
                $cleanPath = 'travel/' . $cleanPath;
            } else {
                echo "'travel/' already present<br>";
            }
            $post['preview'] = '../../' . $cleanPath;
        }
        echo "Final: {$post['preview']}<br><br>";
    }
}
