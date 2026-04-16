<?php
// Тестовый файл для проверки данных пользователей
require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Проверка данных пользователей</h2>";
    
    // Получаем пользователя с ID, который показывает неправильную дату
    $sql = "
        SELECT 
            u.id,
            u.first_name,
            u.last_name,
            u.email,
            u.created_at,
            (SELECT COUNT(*) FROM likes WHERE user_id = u.id) as likes_count,
            (SELECT MAX(created_at) FROM likes WHERE user_id = u.id) as last_like_date,
            (SELECT COUNT(*) FROM comments WHERE user_id = u.id) as comments_count
        FROM users u
        ORDER BY u.created_at DESC
        LIMIT 10
    ";
    
    $stmt = $pdo->query($sql);
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr>
            <th>ID</th>
            <th>Имя</th>
            <th>Email</th>
            <th>Дата регистрации</th>
            <th>Кол-во лайков</th>
            <th>Последний лайк</th>
            <th>Кол-во комментариев</th>
          </tr>";
    
    foreach ($users as $user) {
        echo "<tr>";
        echo "<td>{$user['id']}</td>";
        echo "<td>{$user['first_name']} {$user['last_name']}</td>";
        echo "<td>{$user['email']}</td>";
        echo "<td>{$user['created_at']}</td>";
        echo "<td>{$user['likes_count']}</td>";
        echo "<td>" . ($user['last_like_date'] ?? 'Нет лайков') . "</td>";
        echo "<td>{$user['comments_count']}</td>";
        echo "</tr>";
    }
    
    echo "</table>";
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage();
}
