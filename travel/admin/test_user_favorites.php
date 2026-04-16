<?php
require_once 'config/admin_config.php';
require_once '../config.php';

// Test user ID (замените на ID пользователя у которого есть избранное)
$userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 1;

echo "<h2>Testing User Favorites for User ID: $userId</h2>";

try {
    $pdo = connectToDatabase();
    
    // Check favorites table
    echo "<h3>1. Checking favorites table:</h3>";
    $checkSql = "SELECT * FROM favorites WHERE user_id = :user_id LIMIT 10";
    $checkStmt = $pdo->prepare($checkSql);
    $checkStmt->execute([':user_id' => $userId]);
    $favorites = $checkStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p>Found " . count($favorites) . " favorites</p>";
    echo "<pre>" . print_r($favorites, true) . "</pre>";
    
    // Test the actual query from API
    echo "<h3>2. Testing API query:</h3>";
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
    
    $userFavoritesStmt = $pdo->prepare($userFavoritesSql);
    $userFavoritesStmt->execute([':user_id' => $userId]);
    $userFavorites = $userFavoritesStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p>Found " . count($userFavorites) . " user favorites with details</p>";
    echo "<pre>" . print_r($userFavorites, true) . "</pre>";
    
    // Test API call
    echo "<h3>3. Testing API endpoint:</h3>";
    $apiUrl = "http://bearded-fox.ru/travel/admin/api/users/get_user_details.php?user_id=$userId";
    echo "<p>API URL: <a href='$apiUrl' target='_blank'>$apiUrl</a></p>";
    
    $ch = curl_init($apiUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
    $response = curl_exec($ch);
    curl_close($ch);
    
    $data = json_decode($response, true);
    
    if ($data && isset($data['userFavorites'])) {
        echo "<p>API returned " . count($data['userFavorites']) . " favorites</p>";
        echo "<pre>" . json_encode($data['userFavorites'], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "</pre>";
    } else {
        echo "<p style='color: red;'>API did not return userFavorites field!</p>";
        echo "<pre>" . print_r($data, true) . "</pre>";
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
?>
