<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Fixing Profile Image URLs in Database</h2>";

try {
    $pdo = connectToDatabase();
    
    // Find URLs that start with /http
    $stmt = $pdo->query("SELECT id, profile_image_url FROM users WHERE profile_image_url LIKE '/http%'");
    $badUrls = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Found " . count($badUrls) . " URLs to fix:</h3>";
    
    if (count($badUrls) > 0) {
        echo "<pre>";
        print_r($badUrls);
        echo "</pre>";
        
        // Fix them
        $updateStmt = $pdo->prepare("UPDATE users SET profile_image_url = ? WHERE id = ?");
        
        foreach ($badUrls as $user) {
            $fixedUrl = ltrim($user['profile_image_url'], '/');
            $updateStmt->execute([$fixedUrl, $user['id']]);
            echo "Fixed user {$user['id']}: '{$user['profile_image_url']}' => '$fixedUrl'<br>";
        }
        
        echo "<h3>✓ All URLs fixed!</h3>";
    } else {
        echo "<p>No bad URLs found in database.</p>";
    }
    
} catch (Exception $e) {
    echo "<h3 style='color: red;'>✗ Error: " . $e->getMessage() . "</h3>";
}
