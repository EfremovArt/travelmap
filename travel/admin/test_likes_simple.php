<?php
// Простой тест API лайков с отображением ошибок
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

echo "<h2>Простой тест API лайков</h2>";

try {
    $pdo = connectToDatabase();
    
    echo "<h3>1. Проверка подключения к БД</h3>";
    echo "<p style='color: green;'>✓ Подключение успешно</p>";
    
    echo "<h3>2. Проверка таблицы likes</h3>";
    $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM likes");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    echo "<p>Всего лайков в БД: {$count}</p>";
    
    if ($count == 0) {
        echo "<p style='color: orange;'>⚠ В таблице нет данных!</p>";
        exit;
    }
    
    echo "<h3>3. Проверка структуры locations</h3>";
    try {
        $stmt = $pdo->query("SHOW COLUMNS FROM locations");
        $locColumns = $stmt->fetchAll(PDO::FETCH_COLUMN);
        echo "<p>Поля в locations: " . implode(', ', $locColumns) . "</p>";
    } catch (Exception $e) {
        echo "<p style='color: orange;'>Таблица locations не существует</p>";
    }
    
    echo "<h3>4. Тестовый SQL запрос (без локации)</h3>";
    $sql = "SELECT 
                l.id,
                l.user_id as userId,
                CONCAT(u.first_name, ' ', u.last_name) as userName,
                u.email as userEmail,
                u.profile_image_url as userProfileImage,
                l.photo_id as photoId,
                p.title as photoTitle,
                p.file_path as photoPreview,
                p.location_id,
                l.created_at as createdAt
            FROM likes l
            INNER JOIN users u ON l.user_id = u.id
            INNER JOIN photos p ON l.photo_id = p.id
            ORDER BY l.created_at DESC
            LIMIT 5";
    
    $stmt = $pdo->query($sql);
    $likes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p style='color: green;'>✓ SQL запрос выполнен успешно</p>";
    echo "<p>Получено записей: " . count($likes) . "</p>";
    
    echo "<h3>5. Данные:</h3>";
    echo "<pre>";
    print_r($likes);
    echo "</pre>";
    
    echo "<h3>6. Проверка функции normalizeImageUrl</h3>";
    if (function_exists('normalizeImageUrl')) {
        echo "<p style='color: green;'>✓ Функция существует</p>";
        $testUrl = $likes[0]['photoPreview'] ?? 'test.jpg';
        $normalized = normalizeImageUrl($testUrl);
        echo "<p>Тест: {$testUrl} → {$normalized}</p>";
    } else {
        echo "<p style='color: red;'>✗ Функция normalizeImageUrl не найдена!</p>";
    }
    
    echo "<h3>7. Проверка функций валидации</h3>";
    if (function_exists('validateInt')) {
        echo "<p style='color: green;'>✓ validateInt существует</p>";
    } else {
        echo "<p style='color: red;'>✗ validateInt не найдена!</p>";
    }
    
    if (function_exists('getParam')) {
        echo "<p style='color: green;'>✓ getParam существует</p>";
    } else {
        echo "<p style='color: red;'>✗ getParam не найдена!</p>";
    }
    
    echo "<hr>";
    echo "<h3>Все проверки пройдены! Теперь проверьте API напрямую:</h3>";
    echo "<p><a href='api/likes/get_all_likes.php?page=1&per_page=10' target='_blank'>api/likes/get_all_likes.php?page=1&per_page=10</a></p>";
    
} catch (Exception $e) {
    echo "<div style='color: red; border: 2px solid red; padding: 10px; margin: 10px 0;'>";
    echo "<h3>ОШИБКА:</h3>";
    echo "<p><strong>Сообщение:</strong> " . $e->getMessage() . "</p>";
    echo "<p><strong>Файл:</strong> " . $e->getFile() . "</p>";
    echo "<p><strong>Строка:</strong> " . $e->getLine() . "</p>";
    echo "<h4>Stack trace:</h4>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
    echo "</div>";
}
