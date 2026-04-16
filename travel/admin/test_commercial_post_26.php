<?php
require_once '../config.php';

$commercialPostId = 26;

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Commercial Post #$commercialPostId Details:</h2>";
    
    // Get commercial post
    $sql = "SELECT * FROM commercial_posts WHERE id = :id";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':id' => $commercialPostId]);
    $cp = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<h3>Commercial Post Data:</h3>";
    echo "<pre>";
    print_r($cp);
    echo "</pre>";
    
    // If it has photo_id, get photo location
    if ($cp['photo_id']) {
        echo "<h3>Related Photo:</h3>";
        $photoSql = "SELECT p.*, l.title as location_name 
                     FROM photos p 
                     LEFT JOIN locations l ON p.location_id = l.id 
                     WHERE p.id = :photo_id";
        $photoStmt = $pdo->prepare($photoSql);
        $photoStmt->execute([':photo_id' => $cp['photo_id']]);
        $photo = $photoStmt->fetch(PDO::FETCH_ASSOC);
        echo "<pre>";
        print_r($photo);
        echo "</pre>";
    }
    
    // If it has album_id, get album location
    if ($cp['album_id']) {
        echo "<h3>Related Album:</h3>";
        $albumSql = "SELECT * FROM albums WHERE id = :album_id";
        $albumStmt = $pdo->prepare($albumSql);
        $albumStmt->execute([':album_id' => $cp['album_id']]);
        $album = $albumStmt->fetch(PDO::FETCH_ASSOC);
        echo "<pre>";
        print_r($album);
        echo "</pre>";
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}
