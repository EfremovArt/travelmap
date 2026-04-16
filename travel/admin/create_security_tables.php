<?php
/**
 * Быстрое создание таблиц безопасности
 * Запустите этот файл один раз через браузер или командную строку
 */

require_once '../config.php';

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Создание таблиц безопасности</title>";
echo "<style>body{font-family:Arial,sans-serif;max-width:800px;margin:50px auto;padding:20px;}";
echo ".success{color:green;}.error{color:red;}.warning{color:orange;}</style></head><body>";

echo "<h1>Создание таблиц безопасности</h1>";

try {
    $conn = connectToDatabase();
    echo "<p>✅ Подключение к базе данных успешно</p>";
    
    // Создание таблицы admin_logs
    echo "<h2>1. Создание таблицы admin_logs</h2>";
    try {
        $sql1 = "CREATE TABLE IF NOT EXISTS admin_logs (
            id INT PRIMARY KEY AUTO_INCREMENT,
            admin_id INT,
            action VARCHAR(100) NOT NULL,
            details TEXT,
            target_type VARCHAR(50),
            target_id INT,
            ip_address VARCHAR(45),
            user_agent TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_admin_id (admin_id),
            INDEX idx_action (action),
            INDEX idx_created_at (created_at),
            INDEX idx_target (target_type, target_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        $conn->exec($sql1);
        echo "<p class='success'>✅ Таблица admin_logs создана успешно</p>";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'already exists') !== false) {
            echo "<p class='warning'>⚠️ Таблица admin_logs уже существует</p>";
        } else {
            echo "<p class='error'>❌ Ошибка создания admin_logs: " . $e->getMessage() . "</p>";
        }
    }
    
    // Создание таблицы login_attempts
    echo "<h2>2. Создание таблицы login_attempts</h2>";
    try {
        $sql2 = "CREATE TABLE IF NOT EXISTS login_attempts (
            id INT PRIMARY KEY AUTO_INCREMENT,
            username VARCHAR(100) NOT NULL,
            ip_address VARCHAR(45) NOT NULL,
            success BOOLEAN DEFAULT FALSE,
            attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_username (username),
            INDEX idx_ip_address (ip_address),
            INDEX idx_attempted_at (attempted_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        $conn->exec($sql2);
        echo "<p class='success'>✅ Таблица login_attempts создана успешно</p>";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'already exists') !== false) {
            echo "<p class='warning'>⚠️ Таблица login_attempts уже существует</p>";
        } else {
            echo "<p class='error'>❌ Ошибка создания login_attempts: " . $e->getMessage() . "</p>";
        }
    }
    
    // Проверка созданных таблиц
    echo "<h2>3. Проверка таблиц</h2>";
    
    $stmt = $conn->query("SHOW TABLES LIKE 'admin_logs'");
    if ($stmt->rowCount() > 0) {
        echo "<p class='success'>✅ Таблица admin_logs существует</p>";
        
        // Показываем структуру
        $desc = $conn->query("DESCRIBE admin_logs");
        echo "<details><summary>Структура таблицы admin_logs</summary><pre>";
        while ($row = $desc->fetch(PDO::FETCH_ASSOC)) {
            echo $row['Field'] . " - " . $row['Type'] . "\n";
        }
        echo "</pre></details>";
    } else {
        echo "<p class='error'>❌ Таблица admin_logs не найдена</p>";
    }
    
    $stmt = $conn->query("SHOW TABLES LIKE 'login_attempts'");
    if ($stmt->rowCount() > 0) {
        echo "<p class='success'>✅ Таблица login_attempts существует</p>";
        
        // Показываем структуру
        $desc = $conn->query("DESCRIBE login_attempts");
        echo "<details><summary>Структура таблицы login_attempts</summary><pre>";
        while ($row = $desc->fetch(PDO::FETCH_ASSOC)) {
            echo $row['Field'] . " - " . $row['Type'] . "\n";
        }
        echo "</pre></details>";
    } else {
        echo "<p class='error'>❌ Таблица login_attempts не найдена</p>";
    }
    
    echo "<hr>";
    echo "<h2>✅ Готово!</h2>";
    echo "<p>Таблицы безопасности созданы. Теперь вы можете:</p>";
    echo "<ul>";
    echo "<li><a href='login.php'>Войти в админ-панель</a></li>";
    echo "<li>Удалить этот файл (create_security_tables.php) для безопасности</li>";
    echo "</ul>";
    
    echo "<hr>";
    echo "<p><strong>⚠️ ВАЖНО: Удалите этот файл после использования!</strong></p>";
    echo "<p>Для удаления выполните: <code>rm " . __FILE__ . "</code></p>";
    
} catch (Exception $e) {
    echo "<p class='error'>❌ Ошибка: " . $e->getMessage() . "</p>";
    echo "<p>Проверьте настройки подключения к базе данных в файле config.php</p>";
}

echo "</body></html>";
?>
