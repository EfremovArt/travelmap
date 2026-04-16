<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

try {
    $pdo = connectToDatabase();
    echo "✓ Database connected<br>";
    
    // Check table structure
    $stmt = $pdo->query("DESCRIBE photos");
    echo "<h3>Photos table structure:</h3>";
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "<tr>";
        echo "<td>{$row['Field']}</td>";
        echo "<td>{$row['Type']}</td>";
        echo "<td>{$row['Null']}</td>";
        echo "<td>{$row['Key']}</td>";
        echo "<td>{$row['Default']}</td>";
        echo "</tr>";
    }
    echo "</table><br>";
    
    // Test simple query
    $sql = "SELECT * FROM photos LIMIT 5";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    
    echo "✓ Query executed<br>";
    echo "Found " . $stmt->rowCount() . " photos<br><br>";
    
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "<pre>";
        print_r($row);
        echo "</pre>";
    }
    
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "<br>";
    echo "File: " . $e->getFile() . "<br>";
    echo "Line: " . $e->getLine() . "<br>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
