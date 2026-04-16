<?php
require_once '../config.php';

$userId = 20;

echo "<h2>Testing favorites SQL query for user_id = $userId</h2>";

try {
    $pdo = connectToDatabase();
    
    $userFavoritesSql = "
        SELECT p.id, p.title, p.description, p.file_path, p.created_at, l.name as location_name,
               u.first_name as author_first_name, u.last_name as author_last_name,
               u.profile_image_url as author_profile_image,
               f.created_at as favorited_at
        FROM favorites f
        JOIN photos p ON f.photo_id = p.id
        JOIN users u ON p.user_id = u.id
        LEFT JOIN locations l ON p.location_id = l.id
        WHERE f.user_id = :user_id
        ORDER BY f.created_at DESC
        LIMIT 50
    ";
    
    echo "<h3>SQL Query:</h3>";
    echo "<pre>" . htmlspecialchars($userFavoritesSql) . "</pre>";
    
    $userFavoritesStmt = $pdo->prepare($userFavoritesSql);
    $userFavoritesStmt->execute([':user_id' => $userId]);
    $userFavorites = $userFavoritesStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Results:</h3>";
    echo "<p>Found: " . count($userFavorites) . " records</p>";
    echo "<pre>";
    print_r($userFavorites);
    echo "</pre>";
    
    // Test with normalizeImageUrl
    echo "<h3>Formatted results (as API would return):</h3>";
    require_once 'config/admin_config.php';
    
    $formatted = array_map(function($p) {
        return [
            'id' => intval($p['id']),
            'title' => $p['title'],
            'description' => $p['description'],
            'filePath' => normalizeImageUrl($p['file_path']),
            'locationName' => $p['location_name'],
            'authorName' => $p['author_first_name'] . ' ' . $p['author_last_name'],
            'authorImage' => normalizeImageUrl($p['author_profile_image']),
            'createdAt' => $p['created_at'],
            'favoritedAt' => $p['favorited_at']
        ];
    }, $userFavorites);
    
    echo "<pre>";
    echo json_encode($formatted, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
