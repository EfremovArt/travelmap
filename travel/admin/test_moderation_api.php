<?php
// Test script to debug moderation API
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Testing Moderation API</h2>";

try {
    $pdo = connectToDatabase();
    echo "✓ Database connection successful<br>";
    
    // Test photos table
    echo "<h3>Testing photos table:</h3>";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM photos");
    $count = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Photos count: " . $count['count'] . "<br>";
    
    // Test query from get_all_photos.php
    echo "<h3>Testing main query:</h3>";
    $sql = "SELECT 
                p.id,
                p.user_id,
                p.location_id,
                p.title,
                p.description,
                p.file_path,
                p.created_at,
                u.first_name,
                u.last_name,
                u.email,
                l.title as location_name
            FROM photos p
            LEFT JOIN users u ON p.user_id = u.id
            LEFT JOIN locations l ON p.location_id = l.id
            ORDER BY p.created_at DESC
            LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $photos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($photos) . " photos<br>";
    echo "<pre>";
    print_r($photos);
    echo "</pre>";
    
    // Test album_photos query
    if (!empty($photos)) {
        $photoId = $photos[0]['id'];
        echo "<h3>Testing album_photos for photo ID $photoId:</h3>";
        
        $albumSql = "SELECT a.title 
                     FROM album_photos ap
                     JOIN albums a ON ap.album_id = a.id
                     WHERE ap.photo_id = :photo_id";
        $albumStmt = $pdo->prepare($albumSql);
        $albumStmt->execute([':photo_id' => $photoId]);
        $albums = $albumStmt->fetchAll(PDO::FETCH_COLUMN);
        
        echo "Albums: ";
        print_r($albums);
        echo "<br>";
        
        // Test commercial_posts query
        echo "<h3>Testing commercial_posts for photo ID $photoId:</h3>";
        $commercialSql = "SELECT cp.title 
                          FROM commercial_posts cp
                          WHERE cp.photo_id = :photo_id";
        $commercialStmt = $pdo->prepare($commercialSql);
        $commercialStmt->execute([':photo_id' => $photoId]);
        $commercialPosts = $commercialStmt->fetchAll(PDO::FETCH_COLUMN);
        
        echo "Commercial posts: ";
        print_r($commercialPosts);
        echo "<br>";
    }
    
    echo "<h3>✓ All tests passed!</h3>";
    
} catch (Exception $e) {
    echo "<h3 style='color: red;'>✗ Error: " . $e->getMessage() . "</h3>";
    echo "<pre>";
    echo $e->getTraceAsString();
    echo "</pre>";
}
