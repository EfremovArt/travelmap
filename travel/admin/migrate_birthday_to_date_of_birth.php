<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();

echo "<h2>Миграция данных birthday → date_of_birth</h2>";

// 1. Проверяем данные в обеих колонках
echo "<h3>1. Текущее состояние данных</h3>";
try {
    $stmt = $pdo->query("
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN birthday IS NOT NULL THEN 1 ELSE 0 END) as has_birthday,
            SUM(CASE WHEN date_of_birth IS NOT NULL THEN 1 ELSE 0 END) as has_date_of_birth,
            SUM(CASE WHEN birthday IS NOT NULL AND date_of_birth IS NULL THEN 1 ELSE 0 END) as need_migration
        FROM users
    ");
    $stats = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Показатель</th><th>Значение</th></tr>";
    echo "<tr><td>Всего пользователей</td><td><strong>{$stats['total']}</strong></td></tr>";
    echo "<tr><td>Имеют birthday</td><td><strong>{$stats['has_birthday']}</strong></td></tr>";
    echo "<tr><td>Имеют date_of_birth</td><td><strong>{$stats['has_date_of_birth']}</strong></td></tr>";
    echo "<tr><td>Нужна миграция</td><td><strong style='color: orange;'>{$stats['need_migration']}</strong></td></tr>";
    echo "</table>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 2. Показываем примеры пользователей, которым нужна миграция
echo "<h3>2. Пользователи, которым нужна миграция</h3>";
try {
    $stmt = $pdo->query("
        SELECT id, first_name, last_name, email, birthday, date_of_birth
        FROM users
        WHERE birthday IS NOT NULL AND date_of_birth IS NULL
        LIMIT 10
    ");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (count($users) > 0) {
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Имя</th><th>Email</th><th>birthday</th><th>date_of_birth</th></tr>";
        foreach ($users as $user) {
            echo "<tr>";
            echo "<td>{$user['id']}</td>";
            echo "<td>{$user['first_name']} {$user['last_name']}</td>";
            echo "<td>{$user['email']}</td>";
            echo "<td style='color: green;'><strong>{$user['birthday']}</strong></td>";
            echo "<td style='color: red;'>NULL</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p style='color: green;'>✓ Нет пользователей, которым нужна миграция</p>";
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 3. Кнопка миграции
echo "<h3>3. Выполнить миграцию</h3>";
echo "<form method='post'>";
echo "<p>Это действие скопирует все значения из колонки <code>birthday</code> в колонку <code>date_of_birth</code> для пользователей, у которых <code>date_of_birth</code> пустая.</p>";
echo "<button type='submit' name='migrate' style='padding: 10px 20px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer;'>Выполнить миграцию</button>";
echo "</form>";

if (isset($_POST['migrate'])) {
    echo "<h4>Результаты миграции:</h4>";
    
    try {
        $pdo->beginTransaction();
        
        // Выполняем миграцию
        $stmt = $pdo->exec("
            UPDATE users 
            SET date_of_birth = birthday 
            WHERE birthday IS NOT NULL AND date_of_birth IS NULL
        ");
        
        $pdo->commit();
        
        echo "<p style='color: green; font-size: 18px;'><strong>✓ Успешно! Обновлено записей: $stmt</strong></p>";
        
        // Показываем обновленную статистику
        $stmt = $pdo->query("
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN birthday IS NOT NULL THEN 1 ELSE 0 END) as has_birthday,
                SUM(CASE WHEN date_of_birth IS NOT NULL THEN 1 ELSE 0 END) as has_date_of_birth,
                SUM(CASE WHEN birthday IS NOT NULL AND date_of_birth IS NULL THEN 1 ELSE 0 END) as need_migration
            FROM users
        ");
        $stats = $stmt->fetch(PDO::FETCH_ASSOC);
        
        echo "<h4>Обновленная статистика:</h4>";
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>Показатель</th><th>Значение</th></tr>";
        echo "<tr><td>Всего пользователей</td><td><strong>{$stats['total']}</strong></td></tr>";
        echo "<tr><td>Имеют birthday</td><td><strong>{$stats['has_birthday']}</strong></td></tr>";
        echo "<tr><td>Имеют date_of_birth</td><td><strong style='color: green;'>{$stats['has_date_of_birth']}</strong></td></tr>";
        echo "<tr><td>Нужна миграция</td><td><strong>{$stats['need_migration']}</strong></td></tr>";
        echo "</table>";
        
        echo "<p><a href='views/users.php'>Перейти к списку пользователей</a></p>";
        
    } catch (Exception $e) {
        $pdo->rollBack();
        echo "<p style='color: red; font-size: 18px;'><strong>✗ Ошибка миграции: " . $e->getMessage() . "</strong></p>";
    }
}

echo "<hr>";
echo "<p><strong>Примечание:</strong> После миграции все пользователи, у которых была заполнена дата рождения в приложении, увидят её в админке.</p>";
echo "<p><a href='test_birth_date_api.php'>← Вернуться к тесту даты рождения</a></p>";
echo "<p><a href='views/users.php'>← Вернуться к списку пользователей</a></p>";
?>
