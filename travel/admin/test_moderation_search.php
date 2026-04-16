<?php
require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    $userSearch = 'рус';
    
    echo "<h2>Тест поиска: '$userSearch'</h2>";
    
    // Test query
    $searchValue = '%' . $userSearch . '%';
    $sql = "SELECT 
                p.id,
                p.title,
                p.description,
                u.first_name,
                u.last_name,
                CONCAT(u.first_name, ' ', u.last_name) as full_name
            FROM photos p
            LEFT JOIN users u ON p.user_id = u.id
            WHERE (u.first_name LIKE :search1 
                   OR u.last_name LIKE :search2 
                   OR CONCAT(u.first_name, ' ', u.last_name) LIKE :search3
                   OR p.title LIKE :search4
                   OR p.description LIKE :search5)
            LIMIT 10";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':search1' => $searchValue,
        ':search2' => $searchValue,
        ':search3' => $searchValue,
        ':search4' => $searchValue,
        ':search5' => $searchValue
    ]);
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p>Найдено результатов: " . count($results) . "</p>";
    
    if (count($results) > 0) {
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Имя</th><th>Фамилия</th><th>Полное имя</th><th>Название</th><th>Описание</th></tr>";
        foreach ($results as $row) {
            echo "<tr>";
            echo "<td>" . htmlspecialchars($row['id']) . "</td>";
            echo "<td>" . htmlspecialchars($row['first_name'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars($row['last_name'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars($row['full_name'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars($row['title'] ?? '') . "</td>";
            echo "<td>" . htmlspecialchars(substr($row['description'] ?? '', 0, 50)) . "...</td>";
            echo "</tr>";
        }
        echo "</table>";
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "<pre>" . htmlspecialchars($e->getTraceAsString()) . "</pre>";
}
