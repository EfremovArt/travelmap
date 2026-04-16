<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once '../config.php';

$photoId = 213;

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Testing Post Details API for Photo ID: $photoId</h2>";
    
    // Test main post query
    echo "<h3>1. Main Post Query:</h3>";
    $sql = "SELECT 
                p.id,
                p.title,
                p.description,
                p.file_path,
                p.created_at,
                p.user_id,
                CONCAT(u.first_name, ' ', u.last_name) as author_name,
                u.email as author_email,
                u.profile_image_url as author_image,
                p.location_id,
                (SELECT COUNT(*) FROM likes WHERE photo_id = p.id) as likes_count,
                (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comments_count,
                (SELECT COUNT(*) FROM favorites WHERE photo_id = p.id) as favorites_count
            FROM photos p
            INNER JOIN users u ON p.user_id = u.id
            WHERE p.id = :photo_id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':photo_id' => $photoId]);
    $post = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$post) {
        echo "<p style='color: red;'>Post not found!</p>";
        exit;
    }
    
    echo "<pre>";
    print_r($post);
    echo "</pre>";
    
    // Test likes query
    echo "<h3>2. Likes Query:</h3>";
    $likesStmt = $pdo->prepare("
        SELECT 
            u.id,
            CONCAT(u.first_name, ' ', u.last_name) as name,
            u.profile_image_url as image,
            l.created_at
        FROM likes l
        INNER JOIN users u ON l.user_id = u.id
        WHERE l.photo_id = :photo_id
        ORDER BY l.created_at DESC
        LIMIT 50
    ");
    $likesStmt->execute([':photo_id' => $photoId]);
    $likes = $likesStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p>Found " . count($likes) . " likes</p>";
    echo "<pre>";
    print_r($likes);
    echo "</pre>";
    
    // Test comments query
    echo "<h3>3. Comments Query:</h3>";
    $commentsStmt = $pdo->prepare("
        SELECT 
            c.id,
            c.comment as text,
            c.created_at,
            u.id as user_id,
            CONCAT(u.first_name, ' ', u.last_name) as user_name,
            u.profile_image_url as user_image
        FROM comments c
        INNER JOIN users u ON c.user_id = u.id
        WHERE c.photo_id = :photo_id
        ORDER BY c.created_at DESC
        LIMIT 50
    ");
    $commentsStmt->execute([':photo_id' => $photoId]);
    $comments = $commentsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p>Found " . count($comments) . " comments</p>";
    echo "<pre>";
    print_r($comments);
    echo "</pre>";
    
    // Test location query
    echo "<h3>4. Location Query:</h3>";
    if ($post['location_id']) {
        $locStmt = $pdo->prepare("SELECT * FROM locations WHERE id = :location_id LIMIT 1");
        $locStmt->execute([':location_id' => $post['location_id']]);
        $location = $locStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($location) {
            echo "<pre>";
            print_r($location);
            echo "</pre>";
            
            $locationName = $location['title'] ?? $location['name'] ?? $location['location_name'] ?? null;
            echo "<p><strong>Location Name:</strong> " . ($locationName ?: 'NULL') . "</p>";
        } else {
            echo "<p>Location not found</p>";
        }
    } else {
        echo "<p>No location_id</p>";
    }
    
    echo "<h3>5. Full API Response:</h3>";
    echo "<p>Calling API...</p>";
    
    $apiUrl = "https://bearded-fox.ru/travel/admin/api/posts/get_post_details.php?photo_id=$photoId";
    echo "<p>URL: <a href='$apiUrl' target='_blank'>$apiUrl</a></p>";
    
    // Try to call API
    $ch = curl_init($apiUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "<p><strong>HTTP Code:</strong> $httpCode</p>";
    echo "<p><strong>Response:</strong></p>";
    echo "<pre>";
    echo htmlspecialchars($response);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'><strong>Error:</strong> " . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
