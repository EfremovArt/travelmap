<?php
require_once 'config/admin_config.php';
require_once '../config.php';

$userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 27;

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "=== Проверка даты рождения пользователя ID: $userId ===\n\n";
    
    // Проверяем структуру таблицы
    echo "1. Структура таблицы users:\n";
    $stmt = $pdo->query("DESCRIBE users");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $hasDateOfBirth = false;
    foreach ($columns as $column) {
        if ($column['Field'] === 'date_of_birth') {
            $hasDateOfBirth = true;
            echo "   ✓ Колонка date_of_birth существует: {$column['Type']}\n";
        }
    }
    
    if (!$hasDateOfBirth) {
        echo "   ✗ Колонка date_of_birth НЕ существует!\n";
    }
    
    echo "\n2. Данные пользователя:\n";
    
    // Пробуем получить данные
    try {
        $stmt = $pdo->prepare("SELECT id, first_name, last_name, email, date_of_birth, created_at FROM users WHERE id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user) {
            echo "   ID: {$user['id']}\n";
            echo "   Имя: {$user['first_name']} {$user['last_name']}\n";
            echo "   Email: {$user['email']}\n";
            echo "   Дата рождения: " . ($user['date_of_birth'] ?? 'NULL') . "\n";
            echo "   Дата регистрации: {$user['created_at']}\n";
        } else {
            echo "   Пользователь не найден\n";
        }
    } catch (Exception $e) {
        echo "   Ошибка при получении данных: " . $e->getMessage() . "\n";
        
        // Пробуем без date_of_birth
        echo "\n   Пробуем без date_of_birth:\n";
        $stmt = $pdo->prepare("SELECT id, first_name, last_name, email, created_at FROM users WHERE id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user) {
            echo "   ID: {$user['id']}\n";
            echo "   Имя: {$user['first_name']} {$user['last_name']}\n";
            echo "   Email: {$user['email']}\n";
            echo "   Дата регистрации: {$user['created_at']}\n";
        }
    }
    
    echo "\n3. Проверка API:\n";
    echo "   Откройте: api/users/get_user_details.php?user_id=$userId\n";
    echo "   И проверьте поле 'dateOfBirth' в ответе\n";
    
} catch (Exception $e) {
    echo "ОШИБКА: " . $e->getMessage() . "\n";
}
