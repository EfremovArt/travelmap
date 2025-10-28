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
    
    $postId = $input['post_id'] ?? null;
    $photoId = $input['photo_id'] ?? null;
    
    // Валидация
    if (!$postId || !$photoId) {
        handleError('Required fields missing: post_id, photo_id', 400);
    }
    
    // Проверяем, что коммерческий пост существует и принадлежит пользователю
    $stmt = $pdo->prepare("
        SELECT id, user_id, type, is_active 
        FROM commercial_posts 
        WHERE id = ? AND user_id = ? AND is_active = 1
    ");
    $stmt->execute([$postId, $userId]);
    $post = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$post) {
        handleError('Commercial post not found or access denied', 404);
    }
    
    // Проверяем, что фото существует и получаем его локацию
    // Владелец коммерческого поста может размещать его на любых фото
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
    
    // Получаем все фото в той же локации
    $photosInLocationStmt = $pdo->prepare("
        SELECT DISTINCT p.id 
        FROM photos p
        WHERE p.location_id = ?
    ");
    $photosInLocationStmt->execute([$photo['location_id']]);
    $photosInLocation = $photosInLocationStmt->fetchAll(PDO::FETCH_COLUMN);
    
    if (empty($photosInLocation)) {
        handleError('No photos found in this location', 404);
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        $attachedCount = 0;
        $alreadyAttachedCount = 0;
        
        // Привязываем пост ко всем фото в локации
        foreach ($photosInLocation as $currentPhotoId) {
            // Проверяем, не привязан ли уже этот пост к текущему фото
            $checkStmt = $pdo->prepare("
                SELECT id FROM commercial_post_photos 
                WHERE commercial_post_id = ? AND photo_id = ?
            ");
            $checkStmt->execute([$postId, $currentPhotoId]);
            
            if ($checkStmt->fetch()) {
                $alreadyAttachedCount++;
                continue; // Пропускаем если уже привязан
            }
            
            // Создаем связь между постом и фото
            $stmt = $pdo->prepare("
                INSERT INTO commercial_post_photos (commercial_post_id, photo_id) 
                VALUES (?, ?)
            ");
            
            $result = $stmt->execute([$postId, $currentPhotoId]);
            
            if ($result) {
                $attachedCount++;
            }
        }
        
        // Обновляем локацию поста, если у него ее нет, а у фото есть
        if ($photo['location_id']) {
            $updateStmt = $pdo->prepare("
                UPDATE commercial_posts 
                SET latitude = COALESCE(latitude, ?), 
                    longitude = COALESCE(longitude, ?),
                    location_name = COALESCE(location_name, ?),
                    updated_at = CURRENT_TIMESTAMP 
                WHERE id = ?
            ");
            $updateStmt->execute([
                $photo['latitude'], 
                $photo['longitude'], 
                $photo['location_name'],
                $postId
            ]);
        } else {
            // Обновляем только время изменения поста
            $updateStmt = $pdo->prepare("
                UPDATE commercial_posts 
                SET updated_at = CURRENT_TIMESTAMP 
                WHERE id = ?
            ");
            $updateStmt->execute([$postId]);
        }
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => "Commercial post attached to $attachedCount photo(s) in the location successfully",
            'post_id' => $postId,
            'photo_id' => $photoId,
            'attached_count' => $attachedCount,
            'already_attached_count' => $alreadyAttachedCount,
            'total_photos_in_location' => count($photosInLocation)
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in attach_post_to_photo.php: " . $e->getMessage());
    handleError("Ошибка при привязке поста к фото: " . $e->getMessage(), 500);
}
?>
