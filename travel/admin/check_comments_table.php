<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once '../config.php';

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Comments Table Structure:</h2>";
    
    $stmt = $pdo->query("DESCRIBE comments");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>";
    foreach ($columns as $col) {
        echo "<tr>";
        echo "<td><strong>" . $col['Field'] . "</strong></td>";
        echo "<td>" . $col['Type'] . "</td>";
        echo "<td>" . $col['Null'] . "</td>";
        echo "<td>" . $col['Key'] . "</td>";
        echo "<td>" . ($col['Default'] ?? 'NULL') . "</td>";
        echo "<td>" . ($col['Extra'] ?? '') . "</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    echo "<h3>Sample Data:</h3>";
    $stmt = $pdo->query("SELECT * FROM comments LIMIT 3");
    $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($samples);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}
