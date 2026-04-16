<?php
/**
 * Исправление путей в базе данных
 * Убирает /travel/ из начала путей
 */

require_once '../config.php';

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Исправление путей в БД</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".success{color:green;}.error{color:red;}.warning{color:orange;}</style></head><body>";

echo "<h1>Исправление путей к изображениям в базе данных</h1>";

try {
    $conn = connectToDatabase();
    
    // Проверяем текущие пути
    echo "<h2>Текущие пути (примеры):</h2>";
    
    $stmt = $conn->query("SELECT id, profile_image_url FROM users WHERE profile_image_url IS NOT NULL LIMIT 5");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Users (profile_image_url):</h3><ul>";
    foreach ($users as $user) {
        echo "<li>ID {$user['id']}: <code>" . htmlspecialchars($user['profile_image_url']) . "</code></li>";
    }
    echo "</ul>";
    
    $stmt = $conn->query("SELECT id, file_path FROM photos LIMIT 5");
    $photos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Photos (file_path):</h3><ul>";
    foreach ($photos as $photo) {
        echo "<li>ID {$photo['id']}: <code>" . htmlspecialchars($photo['file_path']) . "</code></li>";
    }
    echo "</ul>";
    
    $stmt = $conn->query("SELECT id, image_url FROM commercial_posts WHERE image_url IS NOT NULL LIMIT 5");
    $commercial = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Commercial Posts (image_url):</h3><ul>";
    foreach ($commercial as $post) {
        echo "<li>ID {$post['id']}: <code>" . htmlspecialchars($post['image_url']) . "</code></li>";
    }
    echo "</ul>";
    
    echo "<hr>";
    echo "<h2>Исправление путей:</h2>";
    
    // Исправляем пути в users
    echo "<h3>1. Таблица users:</h3>";
    $stmt = $conn->exec("
        UPDATE users 
        SET profile_image_url = REPLACE(profile_image_url, '/travel/', '') 
        WHERE profile_image_url LIKE '/travel/%'
        AND profile_image_url NOT LIKE 'http%'
    ");
    echo "<p class='success'>✅ Обновлено записей: $stmt</p>";
    
    // Исправляем пути в photos
    echo "<h3>2. Таблица photos:</h3>";
    $stmt = $conn->exec("
        UPDATE photos 
        SET file_path = REPLACE(file_path, '/travel/', '') 
        WHERE file_path LIKE '/travel/%'
    ");
    echo "<p class='success'>✅ Обновлено записей: $stmt</p>";
    
    // Исправляем пути в commercial_posts
    echo "<h3>3. Таблица commercial_posts:</h3>";
    $stmt = $conn->exec("
        UPDATE commercial_posts 
        SET image_url = REPLACE(image_url, '/travel/', '') 
        WHERE image_url LIKE '/travel/%'
        AND image_url NOT LIKE 'http%'
    ");
    echo "<p class='success'>✅ Обновлено записей: $stmt</p>";
    
    echo "<hr>";
    echo "<h2>Проверка после исправления:</h2>";
    
    $stmt = $conn->query("SELECT id, profile_image_url FROM users WHERE profile_image_url IS NOT NULL LIMIT 5");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Users (после):</h3><ul>";
    foreach ($users as $user) {
        echo "<li>ID {$user['id']}: <code>" . htmlspecialchars($user['profile_image_url']) . "</code></li>";
    }
    echo "</ul>";
    
    echo "<hr>";
    echo "<h2>✅ Готово!</h2>";
    echo "<p>Пути в базе данных исправлены!</p>";
    echo "<p><a href='views/posts.php'>Проверить публикации</a></p>";
    echo "<p><a href='index.php'>Перейти в админ-панель</a></p>";
    
} catch (Exception $e) {
    echo "<p class='error'>❌ Ошибка: " . htmlspecialchars($e->getMessage()) . "</p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после использования!</strong></p>";

echo "</body></html>";
?>
