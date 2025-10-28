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
    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : null;
    
    if (!$userId) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        exit;
    }
    
    // Получаем все standalone коммерческие посты (можно привязывать многократно)
    $stmt = $pdo->prepare("
        SELECT 
            cp.*,
            u.first_name,
            u.last_name,
            u.profile_image_url
        FROM commercial_posts cp
        LEFT JOIN users u ON cp.user_id = u.id
        WHERE cp.user_id = ? AND cp.type = 'standalone' AND cp.is_active = 1
        ORDER BY cp.created_at DESC
    ");
    
    $stmt->execute([$userId]);
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Обрабатываем посты и добавляем изображения
    $processedPosts = [];
    foreach ($posts as $post) {
        // Получаем изображения для каждого поста
        $imageStmt = $pdo->prepare("
            SELECT image_url, original_image_url, image_order 
            FROM commercial_post_images 
            WHERE commercial_post_id = ? 
            ORDER BY image_order ASC
        ");
        $imageStmt->execute([$post['id']]);
        $images = $imageStmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Добавляем изображения к посту (cropped и original)
        $post['images'] = array_map(function($img) {
            return $img['image_url'];
        }, $images);
        
        $post['original_images'] = array_map(function($img) {
            // Если original_image_url не задан, используем image_url
            return $img['original_image_url'] ?? $img['image_url'];
        }, $images);
        
        // Если есть изображения, используем первое как основное
        if (!empty($post['images'])) {
            $post['image_url'] = $post['images'][0];
        }
        
        // Форматируем данные пользователя
        $post['user_name'] = trim(($post['first_name'] ?? '') . ' ' . ($post['last_name'] ?? ''));
        $post['user_profile_image'] = $post['profile_image_url'];
        
        $processedPosts[] = $post;
    }
    
    echo json_encode([
        'success' => true,
        'posts' => $processedPosts,
        'count' => count($processedPosts)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false, 
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}
?>
