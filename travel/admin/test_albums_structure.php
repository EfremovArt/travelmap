<?php
require_once '../config.php';

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Albums table structure:</h2>";
    $stmt = $pdo->query('DESCRIBE albums');
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    foreach ($columns as $col) {
        echo $col['Field'] . " - " . $col['Type'] . "\n";
    }
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}
