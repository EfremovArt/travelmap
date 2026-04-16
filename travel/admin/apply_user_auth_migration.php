<?php
require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/plain; charset=UTF-8');

echo "=== Применение миграции: Добавление полей авторизации ===\n\n";

try {
    $pdo = connectToDatabase();
    
    // Читаем SQL файл
    $sql = file_get_contents(__DIR__ . '/migrations/add_user_auth_fields.sql');
    
    // Разбиваем на отдельные запросы
    $queries = array_filter(array_map('trim', explode(';', $sql)));
    
    $success = 0;
    $errors = 0;
    
    foreach ($queries as $query) {
        // Пропускаем комментарии и пустые строки
        if (empty($query) || strpos($query, '--') === 0) {
            continue;
        }
        
        try {
            $pdo->exec($query);
            $success++;
            echo "✓ Запрос выполнен успешно\n";
        } catch (Exception $e) {
            $errors++;
            echo "✗ Ошибка: " . $e->getMessage() . "\n";
            echo "  Запрос: " . substr($query, 0, 100) . "...\n";
        }
    }
    
    echo "\n=== Результат ===\n";
    echo "Успешно: $success\n";
    echo "Ошибок: $errors\n";
    
    // Проверяем структуру таблицы
    echo "\n=== Проверка структуры таблицы users ===\n";
    $stmt = $pdo->query("DESCRIBE users");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $hasPhone = false;
    $hasDob = false;
    
    foreach ($columns as $column) {
        if ($column['Field'] === 'phone_number') {
            $hasPhone = true;
            echo "✓ Колонка phone_number существует\n";
        }
        if ($column['Field'] === 'date_of_birth') {
            $hasDob = true;
            echo "✓ Колонка date_of_birth существует\n";
        }
    }
    
    if (!$hasPhone) {
        echo "✗ Колонка phone_number НЕ существует\n";
    }
    if (!$hasDob) {
        echo "✗ Колонка date_of_birth НЕ существует\n";
    }
    
    if ($hasPhone && $hasDob) {
        echo "\n✓ Миграция применена успешно!\n";
    } else {
        echo "\n✗ Миграция применена частично или с ошибками\n";
    }
    
} catch (Exception $e) {
    echo "ОШИБКА: " . $e->getMessage() . "\n";
    echo "Файл: " . $e->getFile() . "\n";
    echo "Строка: " . $e->getLine() . "\n";
}
