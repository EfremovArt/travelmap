<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

try {
    $pdo = connectToDatabase();
    echo "✓ Database connected<br><br>";
    
    // Check commercial_posts table structure
    echo "<h3>Commercial Posts Table Structure:</h3>";
    $stmt = $pdo->query("DESCRIBE commercial_posts");
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th></tr>";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "<tr><td>{$row['Field']}</td><td>{$row['Type']}</td></tr>";
    }
    echo "</table><br>";
    
    // Count commercial posts
    $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM commercial_posts");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    echo "Total commercial posts: <strong>$count</strong><br><br>";
    
    if ($count > 0) {
        // Show sample commercial posts
        $stmt = $pdo->query("
            SELECT id, title, type, photo_id, album_id, user_id
            FROM commercial_posts
            LIMIT 5
        ");
        
        echo "<h3>Sample Commercial Posts:</h3>";
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Title</th><th>Type</th><th>Photo ID</th><th>Album ID</th><th>User ID</th></tr>";
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "<tr>";
            echo "<td>{$row['id']}</td>";
            echo "<td>" . htmlspecialchars($row['title'] ?? 'N/A') . "</td>";
            echo "<td>{$row['type']}</td>";
            echo "<td>" . ($row['photo_id'] ?? 'NULL') . "</td>";
            echo "<td>" . ($row['album_id'] ?? 'NULL') . "</td>";
            echo "<td>{$row['user_id']}</td>";
            echo "</tr>";
        }
        echo "</table><br>";
        
        // Check if commercial posts link directly to photos
        $stmt = $pdo->query("
            SELECT COUNT(*) as cnt 
            FROM commercial_posts 
            WHERE photo_id IS NOT NULL
        ");
        $photoCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        echo "<p>Commercial posts with direct photo_id: <strong>$photoCount</strong></p>";
        
        // Check commercial posts with albums
        $stmt = $pdo->query("
            SELECT COUNT(*) as cnt 
            FROM commercial_posts 
            WHERE album_id IS NOT NULL
        ");
        $albumCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        echo "<p>Commercial posts with album_id: <strong>$albumCount</strong></p><br>";
        
        // Check photos in commercial albums
        if ($albumCount > 0) {
            $stmt = $pdo->query("
                SELECT cp.id as commercial_id, cp.title, cp.album_id, 
                       COUNT(ap.photo_id) as photos_count
                FROM commercial_posts cp
                LEFT JOIN album_photos ap ON cp.album_id = ap.album_id
                WHERE cp.album_id IS NOT NULL
                GROUP BY cp.id
            ");
            
            echo "<h3>Photos in Commercial Albums:</h3>";
            echo "<table border='1' cellpadding='5'>";
            echo "<tr><th>Commercial ID</th><th>Title</th><th>Album ID</th><th>Photos Count</th></tr>";
            while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
                echo "<tr>";
                echo "<td>{$row['commercial_id']}</td>";
                echo "<td>" . htmlspecialchars($row['title']) . "</td>";
                echo "<td>{$row['album_id']}</td>";
                echo "<td>{$row['photos_count']}</td>";
                echo "</tr>";
            }
            echo "</table>";
        }
    }
    
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "<br>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
