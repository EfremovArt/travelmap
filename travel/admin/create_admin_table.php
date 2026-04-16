<?php
/**
 * Создание таблицы admin_users и первого администратора
 * Запустите этот файл один раз через браузер
 */

require_once '../config.php';

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Создание таблицы администраторов</title>";
echo "<style>body{font-family:Arial,sans-serif;max-width:800px;margin:50px auto;padding:20px;background:#f5f5f5;}";
echo ".box{background:white;padding:20px;margin:10px 0;border-radius:5px;box-shadow:0 2px 5px rgba(0,0,0,0.1);}";
echo ".success{color:green;}.error{color:red;}.warning{color:orange;}";
echo "pre{background:#f8f8f8;padding:10px;border-radius:3px;overflow-x:auto;}</style></head><body>";

echo "<h1>Создание таблицы администраторов</h1>";

try {
    $conn = connectToDatabase();
    echo "<div class='box'><p class='success'>✅ Подключение к базе данных успешно</p></div>";
    
    // Создание таблицы admin_users
    echo "<div class='box'>";
    echo "<h2>1. Создание таблицы admin_users</h2>";
    try {
        $sql = "CREATE TABLE IF NOT EXISTS admin_users (
            id INT PRIMARY KEY AUTO_INCREMENT,
            username VARCHAR(100) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_login TIMESTAMP NULL,
            INDEX idx_username (username),
            INDEX idx_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        $conn->exec($sql);
        echo "<p class='success'>✅ Таблица admin_users создана успешно</p>";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'already exists') !== false) {
            echo "<p class='warning'>⚠️ Таблица admin_users уже существует</p>";
        } else {
            echo "<p class='error'>❌ Ошибка создания таблицы: " . $e->getMessage() . "</p>";
            throw $e;
        }
    }
    echo "</div>";
    
    // Проверка существующих администраторов
    echo "<div class='box'>";
    echo "<h2>2. Проверка администраторов</h2>";
    $stmt = $conn->query("SELECT COUNT(*) FROM admin_users");
    $count = $stmt->fetchColumn();
    
    if ($count > 0) {
        echo "<p class='warning'>⚠️ В базе уже есть $count администратор(ов)</p>";
        
        // Показываем список
        $admins = $conn->query("SELECT id, username, email, created_at FROM admin_users")->fetchAll(PDO::FETCH_ASSOC);
        echo "<table border='1' cellpadding='5' style='border-collapse:collapse;width:100%;'>";
        echo "<tr><th>ID</th><th>Username</th><th>Email</th><th>Создан</th></tr>";
        foreach ($admins as $admin) {
            echo "<tr>";
            echo "<td>" . $admin['id'] . "</td>";
            echo "<td><strong>" . htmlspecialchars($admin['username']) . "</strong></td>";
            echo "<td>" . htmlspecialchars($admin['email']) . "</td>";
            echo "<td>" . $admin['created_at'] . "</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p>В базе нет администраторов. Создаём первого администратора...</p>";
        
        // Создаём первого администратора
        $username = 'admin';
        $password = 'admin123';
        $email = 'admin@travelmap.com';
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        
        try {
            $stmt = $conn->prepare("INSERT INTO admin_users (username, password_hash, email, created_at) VALUES (?, ?, ?, NOW())");
            $stmt->execute([$username, $passwordHash, $email]);
            
            echo "<p class='success'>✅ Администратор создан успешно!</p>";
            echo "<div style='background:#e8f5e9;padding:15px;border-radius:5px;margin:10px 0;'>";
            echo "<h3>Данные для входа:</h3>";
            echo "<p><strong>Имя пользователя:</strong> <code>$username</code></p>";
            echo "<p><strong>Пароль:</strong> <code>$password</code></p>";
            echo "<p><strong>Email:</strong> <code>$email</code></p>";
            echo "</div>";
            echo "<p class='warning'>⚠️ <strong>ВАЖНО:</strong> Измените пароль после первого входа!</p>";
        } catch (PDOException $e) {
            echo "<p class='error'>❌ Ошибка создания администратора: " . $e->getMessage() . "</p>";
        }
    }
    echo "</div>";
    
    // Проверка структуры таблицы
    echo "<div class='box'>";
    echo "<h2>3. Структура таблицы admin_users</h2>";
    $desc = $conn->query("DESCRIBE admin_users");
    echo "<table border='1' cellpadding='5' style='border-collapse:collapse;width:100%;'>";
    echo "<tr><th>Поле</th><th>Тип</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    while ($row = $desc->fetch(PDO::FETCH_ASSOC)) {
        echo "<tr>";
        echo "<td><strong>" . $row['Field'] . "</strong></td>";
        echo "<td>" . $row['Type'] . "</td>";
        echo "<td>" . $row['Null'] . "</td>";
        echo "<td>" . $row['Key'] . "</td>";
        echo "<td>" . ($row['Default'] ?? 'NULL') . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    echo "</div>";
    
    // Итоговая информация
    echo "<div class='box' style='background:#e3f2fd;'>";
    echo "<h2>✅ Готово!</h2>";
    echo "<p>Таблица admin_users создана и готова к использованию.</p>";
    echo "<h3>Следующие шаги:</h3>";
    echo "<ol>";
    echo "<li><a href='login.php' style='color:#1976d2;font-weight:bold;'>Войти в админ-панель</a></li>";
    echo "<li>Удалите этот файл для безопасности: <code>rm create_admin_table.php</code></li>";
    echo "<li>Удалите файл debug_login.php: <code>rm debug_login.php</code></li>";
    echo "<li>Измените пароль администратора после входа</li>";
    echo "</ol>";
    echo "</div>";
    
    echo "<hr>";
    echo "<p><strong>⚠️ ВАЖНО: Удалите этот файл после использования!</strong></p>";
    
} catch (Exception $e) {
    echo "<div class='box'>";
    echo "<p class='error'>❌ Критическая ошибка: " . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
    echo "</div>";
}

echo "</body></html>";
?>
