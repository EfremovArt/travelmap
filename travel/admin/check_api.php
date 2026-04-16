<?php
/**
 * Проверка API endpoints
 * Показывает что именно возвращают API
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Проверка API</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".box{background:white;padding:15px;margin:10px 0;border-radius:5px;border-left:4px solid #2196F3;}";
echo ".error{border-left-color:#f44336;background:#ffebee;}";
echo ".success{border-left-color:#4caf50;background:#e8f5e9;}";
echo "pre{background:#f8f8f8;padding:10px;overflow-x:auto;border-radius:3px;}</style></head><body>";

echo "<h1>Проверка API Endpoints</h1>";

$endpoints = [
    'Dashboard Stats' => '/travel/admin/api/dashboard/get_stats.php',
    'All Likes' => '/travel/admin/api/likes/get_all_likes.php',
    'All Comments' => '/travel/admin/api/comments/get_all_comments.php',
    'All Users' => '/travel/admin/api/users/get_all_users.php',
    'All Follows' => '/travel/admin/api/follows/get_all_follows.php',
    'All Favorites' => '/travel/admin/api/favorites/get_all_favorites.php',
    'All Posts' => '/travel/admin/api/posts/get_all_posts.php',
    'All Albums' => '/travel/admin/api/posts/get_all_albums.php',
    'All Commercial Posts' => '/travel/admin/api/posts/get_all_commercial_posts.php',
    'All Photos (Moderation)' => '/travel/admin/api/moderation/get_all_photos.php',
];

// Запускаем сессию для авторизации
session_start();
$_SESSION['admin_id'] = 1; // Временно устанавливаем ID администратора
$_SESSION['admin_username'] = 'admin';

foreach ($endpoints as $name => $path) {
    echo "<div class='box'>";
    echo "<h3>$name</h3>";
    echo "<p>Путь: <code>$path</code></p>";
    
    $fullPath = $_SERVER['DOCUMENT_ROOT'] . $path;
    
    if (!file_exists($fullPath)) {
        echo "<p style='color:red;'>❌ Файл не найден: $fullPath</p>";
        echo "</div>";
        continue;
    }
    
    // Захватываем вывод
    ob_start();
    try {
        include $fullPath;
        $output = ob_get_clean();
        
        // Проверяем, является ли вывод валидным JSON
        $json = json_decode($output, true);
        
        if ($json !== null) {
            echo "<p style='color:green;'>✅ Валидный JSON</p>";
            echo "<details><summary>Показать ответ</summary>";
            echo "<pre>" . htmlspecialchars(json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) . "</pre>";
            echo "</details>";
        } else {
            echo "<p style='color:red;'>❌ НЕ валидный JSON</p>";
            echo "<p>Первые 500 символов ответа:</p>";
            echo "<pre>" . htmlspecialchars(substr($output, 0, 500)) . "</pre>";
            
            if (strlen($output) > 500) {
                echo "<details><summary>Показать полный ответ</summary>";
                echo "<pre>" . htmlspecialchars($output) . "</pre>";
                echo "</details>";
            }
        }
    } catch (Exception $e) {
        ob_end_clean();
        echo "<p style='color:red;'>❌ Ошибка: " . htmlspecialchars($e->getMessage()) . "</p>";
        echo "<pre>" . htmlspecialchars($e->getTraceAsString()) . "</pre>";
    }
    
    echo "</div>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после проверки!</strong></p>";

echo "</body></html>";
?>
