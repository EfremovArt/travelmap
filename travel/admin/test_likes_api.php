<?php
// Тест API лайков
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

// Проверяем авторизацию
session_start();
if (!isset($_SESSION['admin_logged_in'])) {
    echo "<p style='color: red;'>Вы не авторизованы. <a href='login.php'>Войти</a></p>";
    exit;
}

echo "<h2>Тест API лайков</h2>";

try {
    $pdo = connectToDatabase();
    
    // Проверяем структуру таблицы likes
    echo "<h3>1. Структура таблицы likes</h3>";
    $stmt = $pdo->query("DESCRIBE likes");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($columns);
    echo "</pre>";
    
    // Проверяем данные в таблице
    echo "<h3>2. Данные в таблице likes</h3>";
    $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM likes");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    echo "<p>Всего лайков: {$count}</p>";
    
    if ($count > 0) {
        // Получаем несколько записей
        $sql = "SELECT 
                    l.id,
                    l.user_id,
                    CONCAT(u.first_name, ' ', u.last_name) as user_name,
                    u.email,
                    l.photo_id,
                    p.title as photo_title,
                    p.file_path,
                    loc.name as location_name,
                    l.created_at
                FROM likes l
                INNER JOIN users u ON l.user_id = u.id
                INNER JOIN photos p ON l.photo_id = p.id
                LEFT JOIN locations loc ON p.location_id = loc.id
                LIMIT 5";
        
        $stmt = $pdo->query($sql);
        $likes = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "<table border='1' cellpadding='5'>";
        echo "<tr>
                <th>ID</th>
                <th>Пользователь</th>
                <th>Email</th>
                <th>Пост</th>
                <th>Локация</th>
                <th>Дата</th>
              </tr>";
        
        foreach ($likes as $like) {
            echo "<tr>";
            echo "<td>{$like['id']}</td>";
            echo "<td>{$like['user_name']}</td>";
            echo "<td>{$like['email']}</td>";
            echo "<td>{$like['photo_title']}</td>";
            echo "<td>" . ($like['location_name'] ?? 'Не указана') . "</td>";
            echo "<td>{$like['created_at']}</td>";
            echo "</tr>";
        }
        
        echo "</table>";
    }
    
    // Тест API вызова
    echo "<h3>3. Тест API вызова</h3>";
    echo "<p>URL: <a href='api/likes/get_all_likes.php?page=1&per_page=10' target='_blank'>api/likes/get_all_likes.php?page=1&per_page=10</a></p>";
    
    echo "<p style='color: green;'>✓ Все запросы выполнены успешно!</p>";
    echo "<p>Теперь попробуйте открыть: <a href='views/likes.php' target='_blank'>views/likes.php</a></p>";
    
} catch (Exception $e) {
    echo "<div style='color: red;'>";
    echo "<h3>Ошибка:</h3>";
    echo "<p>" . $e->getMessage() . "</p>";
    echo "<p>Файл: " . $e->getFile() . "</p>";
    echo "<p>Строка: " . $e->getLine() . "</p>";
    echo "</div>";
}
