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
    $albumId = isset($_POST['album_id']) ? intval($_POST['album_id']) : null;
    $title = isset($_POST['title']) ? trim($_POST['title']) : null;
    $description = isset($_POST['description']) ? trim($_POST['description']) : null;
    $price = isset($_POST['price']) ? floatval($_POST['price']) : null;
    $currency = isset($_POST['currency']) ? trim($_POST['currency']) : 'USD';
    
    // Получаем данные локации
    $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : null;
    $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : null;
    $locationName = isset($_POST['location_name']) ? trim($_POST['location_name']) : null;
    
    // Валидация обязательных полей
    if (!$albumId || !$title) {
        handleError('Required fields missing: album_id, title', 400);
    }
    
    // Проверяем, существует ли альбом (коммерческие посты можно размещать на любых альбомах)
    $stmt = $pdo->prepare("SELECT id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    if (!$stmt->fetch()) {
        handleError('Album not found', 404);
    }
    
    // Обрабатываем загруженные изображения
    $imageUrls = [];
    $originalImageUrls = [];
    $firstImageUrl = null;
    $firstImageOriginalUrl = null;
    
    // Обрабатываем оригинал первого изображения (если передан)
    if (isset($_FILES['first_image_original']) && $_FILES['first_image_original']['error'] === UPLOAD_ERR_OK) {
        $uploadsDir = COMMERCIAL_IMAGES_DIR;
        if (!file_exists($uploadsDir)) {
            mkdir($uploadsDir, 0755, true);
        }
        
        $fileExtension = strtolower(pathinfo($_FILES['first_image_original']['name'], PATHINFO_EXTENSION));
        $fileName = 'commercial_original_' . $userId . '_' . time() . '_0.' . $fileExtension;
        $filePath = $uploadsDir . $fileName;
        
        if (move_uploaded_file($_FILES['first_image_original']['tmp_name'], $filePath)) {
            $firstImageOriginalUrl = '/travel/uploads/commercial_images/' . $fileName;
        }
    }
    
    if (isset($_FILES['images']) && is_array($_FILES['images']['tmp_name'])) {
        // Множественная загрузка изображений
        $imageCount = count($_FILES['images']['tmp_name']);
        
        // Используем константу из config.php для папки коммерческих изображений
        $uploadsDir = COMMERCIAL_IMAGES_DIR;
        if (!file_exists($uploadsDir)) {
            mkdir($uploadsDir, 0755, true);
        }
        
        for ($i = 0; $i < $imageCount; $i++) {
            if ($_FILES['images']['error'][$i] === UPLOAD_ERR_OK) {
                $uploadedFile = [
                    'tmp_name' => $_FILES['images']['tmp_name'][$i],
                    'name' => $_FILES['images']['name'][$i],
                    'type' => $_FILES['images']['type'][$i],
                    'size' => $_FILES['images']['size'][$i]
                ];
                
                // Проверяем тип файла
                $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
                if (!in_array($uploadedFile['type'], $allowedTypes)) {
                    continue; // Пропускаем файлы неподдерживаемых типов
                }
                
                // Проверяем размер файла (максимум 10MB)
                $maxFileSize = 10 * 1024 * 1024; // 10MB в байтах
                if ($uploadedFile['size'] > $maxFileSize) {
                    continue; // Пропускаем слишком большие файлы
                }
                
                // Генерируем уникальное имя файла
                $fileExtension = strtolower(pathinfo($uploadedFile['name'], PATHINFO_EXTENSION));
                $fileName = 'commercial_' . $userId . '_' . time() . '_' . $i . '.' . $fileExtension;
                $filePath = $uploadsDir . $fileName;
                
                // Перемещаем файл в директорию для загрузки
                if (move_uploaded_file($uploadedFile['tmp_name'], $filePath)) {
                    // Формируем относительный URL для изображения
                    $relativeUrl = '/travel/uploads/commercial_images/' . $fileName;
                    $imageUrls[] = $relativeUrl;
                    
                    // Первое изображение используем как основное для обратной совместимости
                    if ($firstImageUrl === null) {
                        $firstImageUrl = $relativeUrl;
                    }
                }
            }
        }
    }
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Создаем коммерческий пост
        $stmt = $pdo->prepare("
            INSERT INTO commercial_posts (
                user_id, album_id, title, description, image_url, 
                price, currency, latitude, longitude, location_name, 
                is_active, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
        ");
        
        $result = $stmt->execute([
            $userId, $albumId, $title, $description, $firstImageUrl,
            $price, $currency, $latitude, $longitude, $locationName
        ]);
        
        if (!$result) {
            throw new Exception('Failed to create commercial post');
        }
        
        $postId = $pdo->lastInsertId();
        
        // Сохраняем все изображения в таблицу commercial_post_images
        if (!empty($imageUrls)) {
            $imageStmt = $pdo->prepare("
                INSERT INTO commercial_post_images (commercial_post_id, image_url, original_image_url, image_order) 
                VALUES (?, ?, ?, ?)
            ");
            
            foreach ($imageUrls as $index => $imgUrl) {
                // Для первого изображения используем оригинал, если он есть
                $originalUrl = ($index === 0 && $firstImageOriginalUrl) ? $firstImageOriginalUrl : $imgUrl;
                $imageStmt->execute([$postId, $imgUrl, $originalUrl, $index]);
            }
        }
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post created successfully',
            'post_id' => $postId,
            'images_count' => count($imageUrls),
            'main_image' => $firstImageUrl
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in create_post_with_images.php: " . $e->getMessage());
    handleError("Ошибка при создании поста: " . $e->getMessage(), 500);
}
