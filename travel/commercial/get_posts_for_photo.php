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
    $photoId = $_GET['photo_id'] ?? null;
    
    if (!$photoId) {
        echo json_encode(['success' => false, 'message' => 'Photo ID is required']);
        exit;
    }
    
    // Сначала получаем локацию фото
    $locationStmt = $pdo->prepare("
        SELECT location_id 
        FROM photos 
        WHERE id = ?
    ");
    $locationStmt->execute([$photoId]);
    $photoData = $locationStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photoData) {
        echo json_encode(['success' => false, 'message' => 'Photo not found']);
        exit;
    }
    
    $locationId = $photoData['location_id'];
    
    // Если у фото нет локации, получаем только посты привязанные к этому фото
    if (!$locationId) {
        $stmt = $pdo->prepare("
            SELECT 
                cp.*,
                u.first_name,
                u.last_name,
                u.profile_image_url,
                p.title as photo_title,
                p.file_path as photo_url,
                NULL as location_name
            FROM commercial_posts cp
            INNER JOIN commercial_post_photos cpp ON cp.id = cpp.commercial_post_id
            LEFT JOIN users u ON cp.user_id = u.id
            LEFT JOIN photos p ON cpp.photo_id = p.id
            WHERE cpp.photo_id = ? AND cp.is_active = 1
            ORDER BY cp.created_at DESC
        ");
        $stmt->execute([$photoId]);
    } else {
        // Получаем название локации
        $locationInfoStmt = $pdo->prepare("
            SELECT title, latitude, longitude
            FROM locations
            WHERE id = ?
        ");
        $locationInfoStmt->execute([$locationId]);
        $locationInfo = $locationInfoStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$locationInfo) {
            echo json_encode(['success' => false, 'message' => 'Location not found']);
            exit;
        }
        
        // Получаем коммерческие посты для этой локации
        // Ищем двумя способами:
        // 1. По location_name коммерческого поста (для постов с локацией)
        // 2. По связям через commercial_post_photos и photos с той же локацией (для старых постов)
        $stmt = $pdo->prepare("
            SELECT DISTINCT
                cp.*,
                u.first_name,
                u.last_name,
                u.profile_image_url
            FROM commercial_posts cp
            LEFT JOIN users u ON cp.user_id = u.id
            LEFT JOIN commercial_post_photos cpp ON cp.id = cpp.commercial_post_id
            LEFT JOIN photos p ON cpp.photo_id = p.id
            WHERE (
                (cp.location_name = ? AND cp.location_name IS NOT NULL AND cp.location_name != '')
                OR (p.location_id = ?)
            ) AND cp.is_active = 1
            ORDER BY cp.created_at DESC
        ");
        $stmt->execute([$locationInfo['title'], $locationId]);
    }
    
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
            'photo_id' => $post['photo_id'] ? (int)$post['photo_id'] : null,
            'type' => $post['type'],
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
            'photo_title' => null, // Not available when searching by location
            'photo_url' => null // Not available when searching by location
        ];
    }
    
    echo json_encode([
        'success' => true,
        'posts' => $formattedPosts,
        'count' => count($formattedPosts)
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_posts_for_photo.php: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Server error']);
}
?>
