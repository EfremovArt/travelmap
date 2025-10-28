<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config.php';

// Подключаемся к базе данных
$pdo = connectToDatabase();

try {
    $albumId = $_GET['album_id'] ?? null;
    
    if (!$albumId) {
        echo json_encode(['success' => false, 'message' => 'Album ID is required']);
        exit;
    }
    
    // Получаем коммерческие посты для альбома (через прямую связь И через таблицу связей)
    $stmt = $pdo->prepare("
        SELECT DISTINCT
            cp.*,
            u.first_name,
            u.last_name,
            u.profile_image_url,
            a.title as album_title
        FROM commercial_posts cp
        LEFT JOIN commercial_post_albums cpa ON cp.id = cpa.commercial_post_id
        LEFT JOIN users u ON cp.user_id = u.id
        LEFT JOIN albums a ON COALESCE(cp.album_id, cpa.album_id) = a.id
        WHERE (cp.album_id = ? OR cpa.album_id = ?) AND cp.is_active = 1
        ORDER BY cp.created_at DESC
    ");
    
    $stmt->execute([$albumId, $albumId]);
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Форматируем данные и получаем изображения для каждого поста
    $formattedPosts = [];
    foreach ($posts as $post) {
        // Получаем все изображения для данного поста
        $imageStmt = $pdo->prepare("
            SELECT image_url, original_image_url, image_order
            FROM commercial_post_images 
            WHERE commercial_post_id = ? 
            ORDER BY image_order ASC, id ASC
        ");
        $imageStmt->execute([(int)$post['id']]);
        $imageRows = $imageStmt->fetchAll(PDO::FETCH_ASSOC);
        
        $images = [];
        $originalImages = [];
        foreach ($imageRows as $row) {
            $images[] = $row['image_url'];
            // Если original_image_url не задан, используем image_url (обратная совместимость)
            $originalImages[] = $row['original_image_url'] ?? $row['image_url'];
        }
        
        // Если в новой таблице нет изображений, но есть в старом поле - используем его
        if (empty($images) && !empty($post['image_url'])) {
            $images = [$post['image_url']];
            $originalImages = [$post['image_url']];
        }
        
        $formattedPosts[] = [
            'id' => (int)$post['id'],
            'user_id' => (int)$post['user_id'],
            'album_id' => (int)$post['album_id'],
            'title' => $post['title'],
            'description' => $post['description'],
            'image_url' => $post['image_url'], // Backward compatibility
            'images' => $images, // Multiple images support (cropped for feed)
            'original_images' => $originalImages, // Original images for gallery
            'price' => $post['price'] ? (float)$post['price'] : null,
            'currency' => $post['currency'],
            'contact_info' => $post['contact_info'],
            'latitude' => $post['latitude'] ? (float)$post['latitude'] : null,
            'longitude' => $post['longitude'] ? (float)$post['longitude'] : null,
            'location_name' => $post['location_name'],
            'is_active' => (bool)$post['is_active'],
            'created_at' => $post['created_at'],
            'updated_at' => $post['updated_at'],
            'user_name' => trim(($post['first_name'] ?? '') . ' ' . ($post['last_name'] ?? '')),
            'user_profile_image' => $post['profile_image_url'],
            'album_title' => $post['album_title']
        ];
    }
    
    echo json_encode([
        'success' => true,
        'posts' => $formattedPosts,
        'count' => count($formattedPosts)
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_posts.php: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Server error']);
}
?>
