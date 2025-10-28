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
    $title = isset($_POST['title']) ? trim($_POST['title']) : null;
    $description = isset($_POST['description']) ? trim($_POST['description']) : null;
    $price = isset($_POST['price']) ? floatval($_POST['price']) : null;
    $currency = isset($_POST['currency']) ? trim($_POST['currency']) : 'USD';
    
    // Получаем данные локации
    $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : null;
    $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : null;
    $locationName = isset($_POST['location_name']) ? trim($_POST['location_name']) : null;
    
    // Валидация обязательных полей
    if (!$title) {
        handleError('Required field missing: title', 400);
    }
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Создаем standalone коммерческий пост (без привязки к альбому или фото)
        $stmt = $pdo->prepare("
            INSERT INTO commercial_posts (
                user_id, album_id, photo_id, type, title, description, image_url, 
                price, currency, contact_info, is_active, latitude, longitude, location_name
            ) VALUES (?, NULL, NULL, 'standalone', ?, ?, NULL, ?, ?, NULL, 1, ?, ?, ?)
        ");
        
        $result = $stmt->execute([
            $userId, $title, $description, $price, $currency, $latitude, $longitude, $locationName
        ]);
        
        if (!$result) {
            throw new Exception('Failed to create commercial post');
        }
        
        $postId = $pdo->lastInsertId();
        
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
                    }
                }
            }
        }
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true, 
            'message' => 'Commercial post created successfully',
            'post_id' => $postId,
            'images_count' => $imagesCount
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию в случае ошибки
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in create_post_standalone.php: " . $e->getMessage());
    handleError("Ошибка при создании поста: " . $e->getMessage(), 500);
}
