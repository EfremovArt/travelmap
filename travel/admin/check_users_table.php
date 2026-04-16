<?php
require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/plain; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "=== Структура таблицы users ===\n\n";
    
    $stmt = $pdo->query("DESCRIBE users");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($columns as $column) {
        echo "{$column['Field']} - {$column['Type']} - {$column['Null']} - {$column['Key']}\n";
    }
    
    echo "\n=== Пример данных пользователя ===\n\n";
    
    $stmt = $pdo->query("SELECT * FROM users LIMIT 1");
    $example = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($example) {
        foreach ($example as $key => $value) {
            echo "$key: " . ($value ?? 'NULL') . "\n";
        }
    } else {
        echo "Нет данных в таблице\n";
    }
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
}
