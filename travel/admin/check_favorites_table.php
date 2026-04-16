<?php
require_once '../config.php';

echo "<h2>Checking favorites table structure</h2>";

try {
    $pdo = connectToDatabase();
    
    // Check table structure
    echo "<h3>Table structure:</h3>";
    $stmt = $pdo->query('DESCRIBE favorites');
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($columns);
    echo "</pre>";
    
    // Check sample data
    echo "<h3>Sample data (first 5 rows):</h3>";
    $stmt = $pdo->query('SELECT * FROM favorites LIMIT 5');
    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($data);
    echo "</pre>";
    
    // Check for user_id = 20
    echo "<h3>Favorites for user_id = 20:</h3>";
    $stmt = $pdo->prepare('SELECT * FROM favorites WHERE user_id = :user_id');
    $stmt->execute([':user_id' => 20]);
    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<p>Found: " . count($data) . " records</p>";
    echo "<pre>";
    print_r($data);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}
