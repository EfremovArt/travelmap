<?php
require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/plain; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "=== Структура таблицы comments ===\n\n";
    
    $stmt = $pdo->query("DESCRIBE comments");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($columns as $column) {
        echo "{$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']}\n";
    }
    
    echo "\n=== Пример данных ===\n\n";
    
    $stmt = $pdo->query("SELECT * FROM comments LIMIT 1");
    $example = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($example) {
        print_r($example);
    } else {
        echo "Нет данных в таблице\n";
    }
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
}
