<?php
require_once __DIR__ . '/config/admin_config.php';
require_once __DIR__ . '/../config.php';

adminRequireAuth();

header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html>
<head>
    <title>Apply Moderation Migration</title>
    <style>
        body { font-family: monospace; padding: 20px; background: #f5f5f5; }
        .success { color: green; }
        .error { color: red; }
        .info { color: blue; }
        pre { background: white; padding: 10px; border: 1px solid #ddd; }
    </style>
</head>
<body>
    <h1>Applying Moderation Migration</h1>
    
<?php
try {
    $pdo = connectToDatabase();
    
    echo "<p class='info'>Reading migration file...</p>";
    $sql = file_get_contents(__DIR__ . '/migrations/add_moderation_status.sql');
    
    // Split by semicolon and execute each statement
    $statements = array_filter(
        array_map('trim', explode(';', $sql)),
        function($stmt) {
            return !empty($stmt) && !preg_match('/^\s*--/', $stmt);
        }
    );
    
    echo "<p class='info'>Found " . count($statements) . " SQL statements</p>";
    
    foreach ($statements as $index => $statement) {
        if (empty(trim($statement))) continue;
        
        echo "<p class='info'>Executing statement " . ($index + 1) . "...</p>";
        echo "<pre>" . htmlspecialchars($statement) . "</pre>";
        
        try {
            $pdo->exec($statement);
            echo "<p class='success'>✓ Success</p>";
        } catch (PDOException $e) {
            // Check if error is about column already existing
            if (strpos($e->getMessage(), 'Duplicate column name') !== false) {
                echo "<p class='info'>⚠ Column already exists, skipping...</p>";
            } else {
                echo "<p class='error'>✗ Error: " . htmlspecialchars($e->getMessage()) . "</p>";
            }
        }
    }
    
    echo "<h2 class='success'>Migration completed!</h2>";
    echo "<p><a href='views/moderation.php'>Go to Moderation Panel</a></p>";
    
} catch (Exception $e) {
    echo "<p class='error'>Fatal error: " . htmlspecialchars($e->getMessage()) . "</p>";
}
?>

</body>
</html>
