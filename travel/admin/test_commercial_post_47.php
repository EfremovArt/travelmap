<?php
require_once '../config.php';

$commercialPostId = 47;

try {
    $pdo = connectToDatabase();
    
    echo "<h2>Commercial Post #$commercialPostId Analysis:</h2>";
    
    // Get commercial post
    $sql = "SELECT * FROM commercial_posts WHERE id = :id";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':id' => $commercialPostId]);
    $cp = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<h3>1. Commercial Post Data:</h3>";
    echo "<pre>";
    print_r($cp);
    echo "</pre>";
    
    echo "<p><strong>Type:</strong> {$cp['type']}</p>";
    echo "<p><strong>Photo ID:</strong> {$cp['photo_id']}</p>";
    echo "<p><strong>Album ID:</strong> {$cp['album_id']}</p>";
    echo "<p><strong>Coordinates:</strong> {$cp['latitude']}, {$cp['longitude']}</p>";
    
    // If it has photo_id, get photo location
    if ($cp['photo_id']) {
        echo "<h3>2. Related Photo Data:</h3>";
        $photoSql = "SELECT p.id, p.title, p.location_id, l.id as loc_id, l.title as location_name 
                     FROM photos p 
                     LEFT JOIN locations l ON p.location_id = l.id 
                     WHERE p.id = :photo_id";
        $photoStmt = $pdo->prepare($photoSql);
        $photoStmt->execute([':photo_id' => $cp['photo_id']]);
        $photo = $photoStmt->fetch(PDO::FETCH_ASSOC);
        echo "<pre>";
        print_r($photo);
        echo "</pre>";
        
        if ($photo && $photo['location_name']) {
            echo "<p style='color: green;'><strong>✅ Location found:</strong> {$photo['location_name']}</p>";
        } else {
            echo "<p style='color: orange;'><strong>⚠️ No location linked to this photo</strong></p>";
        }
    }
    
    // If it has album_id, get album
    if ($cp['album_id']) {
        echo "<h3>3. Related Album Data:</h3>";
        $albumSql = "SELECT * FROM albums WHERE id = :album_id";
        $albumStmt = $pdo->prepare($albumSql);
        $albumStmt->execute([':album_id' => $cp['album_id']]);
        $album = $albumStmt->fetch(PDO::FETCH_ASSOC);
        echo "<pre>";
        print_r($album);
        echo "</pre>";
    }
    
    // Try to find nearest location by coordinates
    if ($cp['latitude'] && $cp['longitude']) {
        echo "<h3>4. Searching for nearest location by coordinates:</h3>";
        $nearSql = "SELECT id, title, latitude, longitude,
                    (6371 * acos(cos(radians(:lat)) * cos(radians(latitude)) * 
                    cos(radians(longitude) - radians(:lng)) + 
                    sin(radians(:lat)) * sin(radians(latitude)))) AS distance
                    FROM locations
                    HAVING distance < 50
                    ORDER BY distance
                    LIMIT 5";
        $nearStmt = $pdo->prepare($nearSql);
        $nearStmt->execute([
            ':lat' => $cp['latitude'],
            ':lng' => $cp['longitude']
        ]);
        $nearLocations = $nearStmt->fetchAll(PDO::FETCH_ASSOC);
        
        if ($nearLocations) {
            echo "<p><strong>Found " . count($nearLocations) . " locations within 50km:</strong></p>";
            echo "<pre>";
            print_r($nearLocations);
            echo "</pre>";
        } else {
            echo "<p style='color: red;'><strong>❌ No locations found within 50km</strong></p>";
        }
    }
    
    // Test API call
    echo "<h3>5. API Response:</h3>";
    $apiUrl = "https://bearded-fox.ru/travel/admin/api/posts/get_commercial_post_relations.php?commercial_post_id=$commercialPostId";
    echo "<p>URL: <a href='$apiUrl' target='_blank'>$apiUrl</a></p>";
    
    $ch = curl_init($apiUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
    $response = curl_exec($ch);
    curl_close($ch);
    
    $data = json_decode($response, true);
    if ($data && isset($data['commercialPost'])) {
        echo "<p><strong>location_name from API:</strong> " . ($data['commercialPost']['location_name'] ?: 'NULL') . "</p>";
    }
    echo "<pre>";
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
