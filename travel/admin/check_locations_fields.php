<?php
require_once '../config.php';

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Locations table structure:</h2>";
    $stmt = $pdo->query('DESCRIBE locations');
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    foreach ($columns as $col) {
        echo $col['Field'] . " - " . $col['Type'] . "\n";
    }
    echo "</pre>";
    
    echo "<h2>Sample data:</h2>";
    $stmt = $pdo->query('SELECT * FROM locations LIMIT 3');
    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($data);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}
