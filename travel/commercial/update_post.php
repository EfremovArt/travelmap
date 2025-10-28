<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Обработка запроса только методами POST и PUT
if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'PUT') {
    handleError("Метод не поддерживается", 405);
}

// Подключаемся к базе данных
$pdo = connectToDatabase();

try {
    // Определяем источник данных в зависимости от типа запроса
    $isMultipart = isset($_SERVER['CONTENT_TYPE']) && strpos($_SERVER['CONTENT_TYPE'], 'multipart/form-data') !== false;
    
    if ($isMultipart) {
        // Для multipart/form-data читаем из $_POST
        $input = $_POST;
    } else {
        // Для JSON читаем из тела запроса
        $input = json_decode(file_get_contents('php://input'), true);
    }
    
    $postId = $input['id'] ?? null;
    $title = $input['title'] ?? null;
    $description = $input['description'] ?? null;
    $imageUrl = $input['image_url'] ?? null; // Backward compatibility
    $imageUrls = $input['images'] ?? null; // Multiple images support
    $price = $input['price'] ?? null;
    $currency = $input['currency'] ?? null;
    $contactInfo = $input['contact_info'] ?? null;
    $isActive = $input['is_active'] ?? null;
    
    // Обрабатываем существующие изображения из JSON строки
    $existingImageUrls = [];
    if (isset($input['existing_image_urls'])) {
        $decoded = json_decode($input['existing_image_urls'], true);
        if (is_array($decoded)) {
            $existingImageUrls = $decoded;
        }
    }
    
    // Валидация
    if (!$postId) {
        handleError('Post ID is required', 400);
    }
    
    // Проверяем, существует ли пост и принадлежит ли он пользователю
    $stmt = $pdo->prepare("SELECT id FROM commercial_posts WHERE id = ? AND user_id = ?");
    $stmt->execute([$postId, $userId]);
    if (!$stmt->fetch()) {
        handleError('Post not found or access denied', 403);
    }
    
    // Обрабатываем загрузку новых изображений
    $uploadedImageUrls = [];
    if ($isMultipart && isset($_FILES['new_images']) && is_array($_FILES['new_images']['name'])) {
        $uploadDir = __DIR__ . '/../uploads/commercial/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0777, true);
        }
        
        $fileCount = count($_FILES['new_images']['name']);
        for ($i = 0; $i < $fileCount; $i++) {
            if ($_FILES['new_images']['error'][$i] === UPLOAD_ERR_OK) {
                $tmpName = $_FILES['new_images']['tmp_name'][$i];
                $originalName = $_FILES['new_images']['name'][$i];
                $extension = pathinfo($originalName, PATHINFO_EXTENSION);
                $fileName = 'commercial_' . uniqid() . '_' . time() . '.' . $extension;
                $filePath = $uploadDir . $fileName;
                
                if (move_uploaded_file($tmpName, $filePath)) {
                    $uploadedImageUrls[] = 'uploads/commercial/' . $fileName;
                }
            }
        }
    }
    
    // Объединяем существующие и новые изображения
    $finalImageUrls = array_merge($existingImageUrls, $uploadedImageUrls);
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Строим запрос для обновления основной таблицы
        $updateFields = [];
        $params = [];
        
        if ($title !== null) {
            $updateFields[] = "title = ?";
            $params[] = $title;
        }
        
        if ($description !== null) {
            $updateFields[] = "description = ?";
            $params[] = $description;
        }
        
        // Обрабатываем изображения
        $updateImagesTable = false;
        if (!empty($finalImageUrls)) {
            // Обновляем таблицу изображений
            $updateImagesTable = true;
            $imageUrls = $finalImageUrls;
            
            // Для обратной совместимости, первое изображение сохраняем в image_url
            $updateFields[] = "image_url = ?";
            $params[] = $finalImageUrls[0];
        } elseif ($imageUrls !== null && is_array($imageUrls)) {
            // Если передан массив изображений, обновляем таблицу изображений
            $updateImagesTable = true;
            
            // Для обратной совместимости, первое изображение сохраняем в image_url
            if (!empty($imageUrls)) {
                $updateFields[] = "image_url = ?";
                $params[] = $imageUrls[0];
            } else {
                $updateFields[] = "image_url = ?";
                $params[] = null;
            }
        } elseif ($imageUrl !== null) {
            // Если передано одно изображение через старое поле
            $updateFields[] = "image_url = ?";
            $params[] = $imageUrl;
            $imageUrls = $imageUrl ? [$imageUrl] : [];
            $updateImagesTable = true;
        }
        
        if ($price !== null) {
            $updateFields[] = "price = ?";
            $params[] = $price;
        }
        
        if ($currency !== null) {
            $updateFields[] = "currency = ?";
            $params[] = $currency;
        }
        
        // Убираем обработку contact_info, так как это поле больше не используется
        
        if ($isActive !== null) {
            $updateFields[] = "is_active = ?";
            $params[] = $isActive ? 1 : 0;
        }
        
        // Обновляем основную запись, если есть поля для обновления
        if (!empty($updateFields)) {
            $updateFields[] = "updated_at = CURRENT_TIMESTAMP";
            $params[] = $postId;
            
            $sql = "UPDATE commercial_posts SET " . implode(", ", $updateFields) . " WHERE id = ?";
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
        }
        
        // Обновляем таблицу изображений, если необходимо
        if ($updateImagesTable) {
            // Удаляем существующие изображения
            $deleteImagesStmt = $pdo->prepare("DELETE FROM commercial_post_images WHERE commercial_post_id = ?");
            $deleteImagesStmt->execute([$postId]);
            
            // Добавляем новые изображения
            if (!empty($imageUrls)) {
                $insertImageStmt = $pdo->prepare("
                    INSERT INTO commercial_post_images (commercial_post_id, image_url, image_order) 
                    VALUES (?, ?, ?)
                ");
                
                foreach ($imageUrls as $index => $imgUrl) {
                    if (!empty($imgUrl)) {
                        $insertImageStmt->execute([$postId, $imgUrl, $index]);
                    }
                }
            }
        }
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post updated successfully',
            'images_updated' => $updateImagesTable,
            'images_count' => $updateImagesTable ? count($imageUrls ?? []) : 0
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in update_post.php: " . $e->getMessage());
    handleError("Ошибка при обновлении поста: " . $e->getMessage(), 500);
}
