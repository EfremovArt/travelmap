<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Checking locations table structure</h2>";

try {
    $pdo = connectToDatabase();
    
    // Проверяем структуру таблицы locations
    $stmt = $pdo->query("DESCRIBE locations");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Columns in locations table:</h3>";
    echo "<pre>";
    print_r($columns);
    echo "</pre>";
    
    // Проверяем несколько записей
    $stmt = $pdo->query("SELECT * FROM locations LIMIT 3");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Sample data from locations:</h3>";
    echo "<pre>";
    print_r($rows);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<h3 style='color: red;'>Error: " . $e->getMessage() . "</h3>";
}
