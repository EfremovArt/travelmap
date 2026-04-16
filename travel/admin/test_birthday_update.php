<?php
require_once '../config.php';

// Тестовый скрипт для проверки обновления даты рождения

$pdo = connectToDatabase();

// Получаем тестового пользователя (замените ID на реальный)
$userId = 1; // Замените на ID тестового пользователя

echo "<h2>Проверка даты рождения пользователя ID: $userId</h2>";

// Проверяем текущие значения
$stmt = $pdo->prepare("SELECT id, first_name, last_name, email, birthday, date_of_birth FROM users WHERE id = :user_id");
$stmt->execute([':user_id' => $userId]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if ($user) {
    echo "<h3>Текущие данные:</h3>";
    echo "<pre>";
    print_r($user);
    echo "</pre>";
    
    // Проверяем структуру таблицы
    echo "<h3>Структура колонок birthday и date_of_birth:</h3>";
    $stmt = $pdo->query("DESCRIBE users");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>";
    foreach ($columns as $col) {
        if ($col['Field'] === 'birthday' || $col['Field'] === 'date_of_birth') {
            echo "<tr>";
            echo "<td><strong>{$col['Field']}</strong></td>";
            echo "<td>{$col['Type']}</td>";
            echo "<td>{$col['Null']}</td>";
            echo "<td>{$col['Key']}</td>";
            echo "<td>{$col['Default']}</td>";
            echo "<td>{$col['Extra']}</td>";
            echo "</tr>";
        }
    }
    echo "</table>";
    
    // Тестируем обновление
    echo "<h3>Тестируем обновление даты рождения:</h3>";
    $testDate = '1990-05-15';
    
    try {
        $stmt = $pdo->prepare("
            UPDATE users 
            SET birthday = :birthday,
                date_of_birth = :birthday
            WHERE id = :user_id
        ");
        $stmt->bindParam(':birthday', $testDate);
        $stmt->bindParam(':user_id', $userId);
        $result = $stmt->execute();
        
        echo "<p>Обновление выполнено: " . ($result ? "✓ Успешно" : "✗ Ошибка") . "</p>";
        
        // Проверяем результат
        $stmt = $pdo->prepare("SELECT birthday, date_of_birth FROM users WHERE id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $updated = $stmt->fetch(PDO::FETCH_ASSOC);
        
        echo "<p>После обновления:</p>";
        echo "<pre>";
        print_r($updated);
        echo "</pre>";
        
    } catch (Exception $e) {
        echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
    }
    
} else {
    echo "<p style='color: red;'>Пользователь не найден</p>";
}
