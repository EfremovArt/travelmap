<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Fixing Commercial Posts Links</h2>";

try {
    $pdo = connectToDatabase();
    echo "✓ Database connected<br><br>";
    
    // Get all commercial posts
    $stmt = $pdo->query("SELECT * FROM commercial_posts");
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Processing " . count($posts) . " commercial posts...</h3>";
    
    foreach ($posts as $post) {
        echo "<div style='border: 1px solid #ccc; padding: 10px; margin: 10px 0;'>";
        echo "<strong>ID {$post['id']}: {$post['title']}</strong><br>";
        echo "Type: {$post['type']}<br>";
        echo "Current album_id: " . ($post['album_id'] ?? 'NULL') . "<br>";
        echo "Current photo_id: " . ($post['photo_id'] ?? 'NULL') . "<br>";
        
        $updated = false;
        
        // If type is 'album', try to find matching album by title
        if ($post['type'] === 'album' && empty($post['album_id'])) {
            $albumStmt = $pdo->prepare("
                SELECT id FROM albums 
                WHERE title LIKE :title 
                   OR title LIKE :title2
                LIMIT 1
            ");
            $titlePattern = '%' . $post['title'] . '%';
            $albumStmt->execute([
                ':title' => $titlePattern,
                ':title2' => $post['title']
            ]);
            $album = $albumStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($album) {
                $updateStmt = $pdo->prepare("
                    UPDATE commercial_posts 
                    SET album_id = :album_id 
                    WHERE id = :id
                ");
                $updateStmt->execute([
                    ':album_id' => $album['id'],
                    ':id' => $post['id']
                ]);
                echo "<span style='color: green;'>✓ Updated album_id to {$album['id']}</span><br>";
                $updated = true;
            } else {
                echo "<span style='color: orange;'>⚠ No matching album found</span><br>";
            }
        }
        
        // If type is 'photo', try to find matching photo by title
        if ($post['type'] === 'photo' && empty($post['photo_id'])) {
            $photoStmt = $pdo->prepare("
                SELECT id FROM photos 
                WHERE title LIKE :title 
                   OR title LIKE :title2
                LIMIT 1
            ");
            $titlePattern = '%' . $post['title'] . '%';
            $photoStmt->execute([
                ':title' => $titlePattern,
                ':title2' => $post['title']
            ]);
            $photo = $photoStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($photo) {
                $updateStmt = $pdo->prepare("
                    UPDATE commercial_posts 
                    SET photo_id = :photo_id 
                    WHERE id = :id
                ");
                $updateStmt->execute([
                    ':photo_id' => $photo['id'],
                    ':id' => $post['id']
                ]);
                echo "<span style='color: green;'>✓ Updated photo_id to {$photo['id']}</span><br>";
                $updated = true;
            } else {
                echo "<span style='color: orange;'>⚠ No matching photo found</span><br>";
            }
        }
        
        if (!$updated) {
            echo "<span style='color: gray;'>- No changes needed</span><br>";
        }
        
        echo "</div>";
    }
    
    echo "<br><h3>✓ Done!</h3>";
    echo "<p><a href='test_commercial_photos.php'>Check results</a></p>";
    
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "<br>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
