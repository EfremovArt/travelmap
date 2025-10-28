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
    // Получаем данные из POST запроса
    $photoId = isset($_POST['photo_id']) ? intval($_POST['photo_id']) : null;
    $title = isset($_POST['title']) ? trim($_POST['title']) : null;
    $description = isset($_POST['description']) ? trim($_POST['description']) : null;
    $price = isset($_POST['price']) ? floatval($_POST['price']) : null;
    $currency = isset($_POST['currency']) ? trim($_POST['currency']) : 'USD';
    $contactInfo = isset($_POST['contact_info']) ? trim($_POST['contact_info']) : null;
    
    // Получаем данные локации
    $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : null;
    $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : null;
    $locationName = isset($_POST['location_name']) ? trim($_POST['location_name']) : null;
    
    // Валидация обязательных полей
    if (!$photoId || !$title) {
        handleError('Required fields missing: photo_id, title', 400);
    }
    
    // Проверяем, что фото существует и пользователь имеет права
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
    
    if ($photo['user_id'] != $userId) {
        handleError('Access denied: not the photo owner', 403);
    }
    
    // Если локация не передана в POST, используем локацию из фото
    if (!$latitude && !$longitude && $photo['location_id']) {
        $latitude = $photo['latitude'];
        $longitude = $photo['longitude'];
        $locationName = $locationName ?: $photo['location_name'];
    }
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Создаем коммерческий пост для фото
               $stmt = $pdo->prepare("
                   INSERT INTO commercial_posts (
                       user_id, photo_id, type, title, description, image_url, 
                       price, currency, contact_info, is_active, latitude, longitude, location_name
                   ) VALUES (?, ?, 'standalone', ?, ?, NULL, ?, ?, ?, 1, ?, ?, ?)
               ");
        
        $result = $stmt->execute([
            $userId, $photoId, $title, $description, $price, $currency, $contactInfo, 
            $latitude, $longitude, $locationName
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
        
        // Обрабатываем оригинал первого изображения (если передан)
        $firstImageOriginalUrl = null;
        if (isset($_FILES['first_image_original']) && $_FILES['first_image_original']['error'] === UPLOAD_ERR_OK) {
            $uploadDir = '../uploads/commercial/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0755, true);
            }
            
            $fileName = uniqid() . '_original_' . basename($_FILES['first_image_original']['name']);
            $targetPath = $uploadDir . $fileName;
            
            if (move_uploaded_file($_FILES['first_image_original']['tmp_name'], $targetPath)) {
                $firstImageOriginalUrl = 'uploads/commercial/' . $fileName;
            }
        }
        
        // Сохраняем изображения в таблицу commercial_post_images
        $imagesCount = 0;
        if (isset($_FILES['images']) && is_array($_FILES['images']['name'])) {
            $imageStmt = $pdo->prepare("
                INSERT INTO commercial_post_images (commercial_post_id, image_url, original_image_url, image_order) 
                VALUES (?, ?, ?, ?)
            ");
            
            $uploadDir = '../uploads/commercial/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0755, true);
            }
            
            for ($i = 0; $i < count($_FILES['images']['name']); $i++) {
                if ($_FILES['images']['error'][$i] === UPLOAD_ERR_OK) {
                    $fileName = uniqid() . '_' . basename($_FILES['images']['name'][$i]);
                    $targetPath = $uploadDir . $fileName;
                    
                    if (move_uploaded_file($_FILES['images']['tmp_name'][$i], $targetPath)) {
                        $imageUrl = 'uploads/commercial/' . $fileName;
                        // Для первого изображения используем оригинал, если он есть
                        $originalUrl = ($i === 0 && $firstImageOriginalUrl) ? $firstImageOriginalUrl : $imageUrl;
                        $imageStmt->execute([$postId, $imageUrl, $originalUrl, $i]);
                        $imagesCount++;
                        
                        // Устанавливаем первое изображение как основное для обратной совместимости
                        if ($i === 0) {
                            $updateStmt = $pdo->prepare("
                                UPDATE commercial_posts 
                                SET image_url = ? 
                                WHERE id = ?
                            ");
                            $updateStmt->execute([$imageUrl, $postId]);
                        }
                    }
                }
            }
        }
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post for photo created successfully',
            'post_id' => $postId,
            'images_count' => $imagesCount
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию в случае ошибки
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in create_post_for_photo_with_images.php: " . $e->getMessage());
    handleError("Ошибка при создании поста для фото: " . $e->getMessage(), 500);
}
?>
