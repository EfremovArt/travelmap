<?php
/**
 * Тестирование всех API endpoints
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Запускаем сессию и авторизуемся
session_start();
$_SESSION['admin_id'] = 1;
$_SESSION['admin_username'] = 'admin';

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Тест API</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;font-size:12px;}";
echo ".success{color:green;}.error{color:red;}.box{background:white;padding:10px;margin:10px 0;border-radius:5px;}";
echo "pre{background:#f8f8f8;padding:10px;overflow-x:auto;max-height:300px;}</style></head><body>";

echo "<h1>Тестирование API Endpoints</h1>";

$apis = [
    'Comments' => '/travel/admin/api/comments/get_all_comments.php',
    'Likes' => '/travel/admin/api/likes/get_all_likes.php',
    'Users' => '/travel/admin/api/users/get_all_users.php',
    'Follows' => '/travel/admin/api/follows/get_all_follows.php',
    'Posts' => '/travel/admin/api/posts/get_all_posts.php',
];

foreach ($apis as $name => $path) {
    echo "<div class='box'>";
    echo "<h3>$name</h3>";
    
    $fullPath = $_SERVER['DOCUMENT_ROOT'] . $path;
    
    if (!file_exists($fullPath)) {
        echo "<p class='error'>❌ Файл не найден</p>";
        echo "</div>";
        continue;
    }
    
    ob_start();
    try {
        include $fullPath;
        $output = ob_get_clean();
        
        $json = json_decode($output, true);
        
        if ($json !== null) {
            if (isset($json['success']) && $json['success']) {
                echo "<p class='success'>✅ Работает</p>";
            } else {
                echo "<p class='error'>❌ Ошибка: " . ($json['message'] ?? 'Unknown') . "</p>";
            }
            echo "<details><summary>Показать ответ</summary>";
            echo "<pre>" . htmlspecialchars(json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) . "</pre>";
            echo "</details>";
        } else {
            echo "<p class='error'>❌ Не валидный JSON</p>";
            echo "<pre>" . htmlspecialchars(substr($output, 0, 1000)) . "</pre>";
        }
    } catch (Exception $e) {
        ob_end_clean();
        echo "<p class='error'>❌ Exception: " . htmlspecialchars($e->getMessage()) . "</p>";
        echo "<pre>" . htmlspecialchars($e->getTraceAsString()) . "</pre>";
    }
    
    echo "</div>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после проверки!</strong></p>";

echo "</body></html>";
?>
