<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

echo "<h2>Применение миграции: Отслеживание просмотров</h2>";

try {
    $pdo = connectToDatabase();
    
    // SQL для создания таблицы (встроенный)
    $sql = "CREATE TABLE IF NOT EXISTS admin_views (
        id INT AUTO_INCREMENT PRIMARY KEY,
        admin_id INT NOT NULL,
        view_type ENUM('photos', 'comments') NOT NULL,
        last_viewed_at DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_admin_view (admin_id, view_type),
        INDEX idx_admin_id (admin_id),
        INDEX idx_view_type (view_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    
    // Выполняем SQL
    $pdo->exec($sql);
    
    echo "<p style='color: green;'>✓ Таблица admin_views успешно создана!</p>";
    
    // Проверяем структуру
    echo "<h3>Структура таблицы admin_views:</h3>";
    $stmt = $pdo->query("DESCRIBE admin_views");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th></tr>";
    foreach ($columns as $col) {
        echo "<tr>";
        echo "<td>{$col['Field']}</td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    echo "<hr>";
    echo "<p><a href='views/moderation.php'>Перейти к модерации</a></p>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>✗ Ошибка: " . $e->getMessage() . "</p>";
}
