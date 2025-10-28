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
    
    $photoId = $input['photo_id'] ?? null;
    $title = $input['title'] ?? null;
    $description = $input['description'] ?? null;
    $imageUrl = $input['image_url'] ?? null; // Backward compatibility
    $imageUrls = $input['images'] ?? []; // Multiple images support
    $price = $input['price'] ?? null;
    $currency = $input['currency'] ?? 'USD';
    $contactInfo = $input['contact_info'] ?? null;
    
    // Валидация
    if (!$photoId || !$title) {
        handleError('Required fields missing: photo_id, title', 400);
    }
    
    // Проверяем, существует ли фото и имеет ли пользователь права на его изменение
    // Также получаем локацию фото
    $stmt = $pdo->prepare("
        SELECT p.id, p.user_id, p.location_id, l.latitude, l.longitude, l.title as location_name
        FROM photos p
        LEFT JOIN locations l ON p.location_id = l.id
        WHERE p.id = ?
    ");
    $stmt->execute([$photoId]);
    $photo = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photo) {
        handleError('Photo not found', 404);
    }
    
    // Проверяем права: либо владелец фото, либо админ (для будущего расширения)
    if ($photo['user_id'] != $userId) {
        handleError('Access denied: not the photo owner', 403);
    }
    
    // Получаем локацию из фото
    $latitude = $photo['latitude'];
    $longitude = $photo['longitude'];
    $locationName = $photo['location_name'];
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Создаем коммерческий пост для фото
               $stmt = $pdo->prepare("
                   INSERT INTO commercial_posts (
                       user_id, photo_id, type, title, description, image_url, 
                       price, currency, contact_info, is_active, latitude, longitude, location_name
                   ) VALUES (?, ?, 'standalone', ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
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
            $userId, $photoId, $title, $description, $firstImageUrl,
            $price, $currency, $contactInfo, $latitude, $longitude, $locationName
        ]);
        
        if (!$result) {
            throw new Exception('Failed to create commercial post for photo');
        }
        
        $postId = $pdo->lastInsertId();
        
        // Создаем связь в таблице commercial_post_photos
        $linkStmt = $pdo->prepare("
            INSERT INTO commercial_post_photos (commercial_post_id, photo_id)
            VALUES (?, ?)
        ");
        $linkStmt->execute([$postId, $photoId]);
        
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
            'message' => 'Commercial post for photo created successfully',
            'post_id' => $postId,
            'images_count' => count($imageUrls)
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in create_post_for_photo.php: " . $e->getMessage());
    handleError("Ошибка при создании поста для фото: " . $e->getMessage(), 500);
}
?>
