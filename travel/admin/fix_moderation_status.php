<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();

echo "<h2>Исправление статусов модерации</h2>";

// 1. Проверяем, существует ли колонка moderation_status
echo "<h3>1. Проверка колонки moderation_status</h3>";
try {
    $stmt = $pdo->query("SHOW COLUMNS FROM photos LIKE 'moderation_status'");
    $column = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$column) {
        echo "<p style='color: orange;'>Колонка moderation_status не существует. Создаем...</p>";
        
        $pdo->exec("
            ALTER TABLE photos 
            ADD COLUMN moderation_status ENUM('pending', 'approved', 'rejected') DEFAULT 'approved' AFTER file_path
        ");
        
        echo "<p style='color: green;'>✓ Колонка moderation_status создана</p>";
    } else {
        echo "<p style='color: green;'>✓ Колонка moderation_status существует</p>";
        echo "<pre>";
        print_r($column);
        echo "</pre>";
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 2. Проверяем текущее распределение статусов
echo "<h3>2. Текущее распределение статусов</h3>";
try {
    $stmt = $pdo->query("
        SELECT 
            moderation_status,
            COUNT(*) as count
        FROM photos
        GROUP BY moderation_status
    ");
    $statuses = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Статус</th><th>Количество</th></tr>";
    foreach ($statuses as $status) {
        $statusText = $status['moderation_status'] ?? 'NULL';
        echo "<tr><td>{$statusText}</td><td>{$status['count']}</td></tr>";
    }
    echo "</table>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 3. Устанавливаем статус 'approved' для всех фото без статуса
echo "<h3>3. Установка статуса 'approved' для фото без статуса</h3>";
try {
    $stmt = $pdo->exec("
        UPDATE photos 
        SET moderation_status = 'approved' 
        WHERE moderation_status IS NULL
    ");
    
    echo "<p style='color: green;'>✓ Обновлено фото: <strong>$stmt</strong></p>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 4. Проверяем новое распределение
echo "<h3>4. Новое распределение статусов</h3>";
try {
    $stmt = $pdo->query("
        SELECT 
            moderation_status,
            COUNT(*) as count
        FROM photos
        GROUP BY moderation_status
    ");
    $statuses = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Статус</th><th>Количество</th></tr>";
    foreach ($statuses as $status) {
        $statusText = $status['moderation_status'] ?? 'NULL';
        echo "<tr><td>{$statusText}</td><td>{$status['count']}</td></tr>";
    }
    echo "</table>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 5. Создаем несколько тестовых фото с pending статусом (опционально)
echo "<h3>5. Создание тестовых фото с pending статусом</h3>";
echo "<form method='post'>";
echo "<p>Количество тестовых фото: <input type='number' name='test_count' value='3' min='1' max='10'></p>";
echo "<button type='submit' name='create_test'>Создать тестовые фото</button>";
echo "</form>";

if (isset($_POST['create_test'])) {
    $testCount = intval($_POST['test_count']);
    
    try {
        // Получаем случайного пользователя
        $stmt = $pdo->query("SELECT id FROM users ORDER BY RAND() LIMIT 1");
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user) {
            $userId = $user['id'];
            
            for ($i = 0; $i < $testCount; $i++) {
                $pdo->prepare("
                    INSERT INTO photos (user_id, file_path, title, description, moderation_status, created_at)
                    VALUES (:user_id, '/travel/uploads/test_pending.jpg', :title, :description, 'pending', NOW())
                ")->execute([
                    ':user_id' => $userId,
                    ':title' => 'Тестовое фото на модерации ' . ($i + 1),
                    ':description' => 'Это тестовое фото для проверки системы модерации'
                ]);
            }
            
            echo "<p style='color: green;'>✓ Создано тестовых фото: <strong>$testCount</strong></p>";
            echo "<p><a href='views/moderation.php'>Перейти к модерации</a></p>";
        } else {
            echo "<p style='color: red;'>Не найдено пользователей для создания тестовых фото</p>";
        }
    } catch (Exception $e) {
        echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
    }
}

echo "<hr>";
echo "<p><a href='views/moderation.php'>← Вернуться к модерации</a></p>";
?>
