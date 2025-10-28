<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Подключаемся к базе данных
$pdo = connectToDatabase();

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $albumId = $input['album_id'] ?? null;
    $title = $input['title'] ?? null;
    $description = $input['description'] ?? null;
    $imageUrl = $input['image_url'] ?? null; // Backward compatibility
    $imageUrls = $input['images'] ?? []; // Multiple images support
    $price = $input['price'] ?? null;
    $currency = $input['currency'] ?? 'USD';
    $contactInfo = $input['contact_info'] ?? null;
    
    // Валидация
    if (!$albumId || !$title) {
        handleError('Required fields missing: album_id, title', 400);
    }
    
    // Проверяем, существует ли альбом (коммерческие посты можно размещать на любых альбомах)
    $stmt = $pdo->prepare("SELECT id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    if (!$stmt->fetch()) {
        handleError('Album not found', 404);
    }
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Создаем коммерческий пост для альбома (image_url теперь опциональный)
        $stmt = $pdo->prepare("
            INSERT INTO commercial_posts (
                user_id, album_id, type, title, description, image_url, 
                price, currency, contact_info, is_active
            ) VALUES (?, ?, 'album', ?, ?, ?, ?, ?, ?, 1)
        ");
        
        // Для обратной совместимости, если есть множественные изображения, первое сохраняем в image_url
        $firstImageUrl = null;
        if (!empty($imageUrls) && is_array($imageUrls)) {
            $firstImageUrl = $imageUrls[0];
        } elseif (!empty($imageUrl)) {
            $firstImageUrl = $imageUrl;
            $imageUrls = [$imageUrl]; // Конвертируем в массив
        }
        
        $result = $stmt->execute([
            $userId, $albumId, $title, $description, $firstImageUrl,
            $price, $currency, $contactInfo
        ]);
        
        if (!$result) {
            throw new Exception('Failed to create commercial post');
        }
        
        $postId = $pdo->lastInsertId();
        
        // Сохраняем все изображения в таблицу commercial_post_images
        if (!empty($imageUrls) && is_array($imageUrls)) {
            $imageStmt = $pdo->prepare("
                INSERT INTO commercial_post_images (commercial_post_id, image_url, image_order) 
                VALUES (?, ?, ?)
            ");
            
            foreach ($imageUrls as $index => $imgUrl) {
                if (!empty($imgUrl)) {
                    $imageStmt->execute([$postId, $imgUrl, $index]);
                }
            }
        }
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post created successfully',
            'post_id' => $postId,
            'images_count' => count($imageUrls)
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in create_post.php: " . $e->getMessage());
    handleError("Ошибка при создании поста: " . $e->getMessage(), 500);
}
