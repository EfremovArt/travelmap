<?php
/**
 * Проверка структуры таблиц базы данных
 */

require_once '../config.php';

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Структура БД</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo "table{border-collapse:collapse;width:100%;background:white;margin:10px 0;}";
echo "th,td{border:1px solid #ddd;padding:8px;text-align:left;}";
echo "th{background:#2196F3;color:white;}</style></head><body>";

echo "<h1>Структура таблиц базы данных</h1>";

try {
    $conn = connectToDatabase();
    
    $tables = ['users', 'photos', 'likes', 'comments', 'follows', 'favorites', 'albums', 'commercial_posts'];
    
    foreach ($tables as $tableName) {
        echo "<h2>Таблица: $tableName</h2>";
        
        try {
            $stmt = $conn->query("DESCRIBE $tableName");
            $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo "<table>";
            echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>";
            
            foreach ($columns as $col) {
                echo "<tr>";
                echo "<td><strong>" . htmlspecialchars($col['Field']) . "</strong></td>";
                echo "<td>" . htmlspecialchars($col['Type']) . "</td>";
                echo "<td>" . htmlspecialchars($col['Null']) . "</td>";
                echo "<td>" . htmlspecialchars($col['Key']) . "</td>";
                echo "<td>" . htmlspecialchars($col['Default'] ?? 'NULL') . "</td>";
                echo "<td>" . htmlspecialchars($col['Extra']) . "</td>";
                echo "</tr>";
            }
            
            echo "</table>";
            
        } catch (Exception $e) {
            echo "<p style='color:red;'>❌ Ошибка: " . htmlspecialchars($e->getMessage()) . "</p>";
        }
    }
    
} catch (Exception $e) {
    echo "<p style='color:red;'>❌ Ошибка подключения: " . htmlspecialchars($e->getMessage()) . "</p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после проверки!</strong></p>";

echo "</body></html>";
?>
