<?php
// Проверка существующих таблиц
require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Проверка таблиц в БД</h2>";
    
    $tables = [
        'users',
        'photos',
        'albums',
        'follows',
        'likes',
        'comments',
        'album_comments',
        'favorites',
        'album_favorites',
        'commercial_posts',
        'commercial_favorites',
        'locations'
    ];
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Таблица</th><th>Существует</th><th>Кол-во записей</th></tr>";
    
    foreach ($tables as $table) {
        try {
            $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM `{$table}`");
            $count = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
            echo "<tr><td>{$table}</td><td style='color: green;'>✓ Да</td><td>{$count}</td></tr>";
        } catch (Exception $e) {
            echo "<tr><td>{$table}</td><td style='color: red;'>✗ Нет</td><td>-</td></tr>";
        }
    }
    
    echo "</table>";
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage();
}
