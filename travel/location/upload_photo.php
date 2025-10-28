<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Проверяем, был ли отправлен файл
if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    $error = isset($_FILES['photo']) ? $_FILES['photo']['error'] : 'Файл не был отправлен';
    handleError("Ошибка при загрузке файла: " . $error, 400);
}

// Получаем данные из запроса
$locationId = isset($_POST['location_id']) ? intval($_POST['location_id']) : null;
$title = isset($_POST['title']) ? trim($_POST['title']) : null;
$description = isset($_POST['description']) ? trim($_POST['description']) : null;

$uploadedFile = $_FILES['photo'];

// Проверяем тип файла
$allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
if (!in_array($uploadedFile['type'], $allowedTypes)) {
    handleError("Недопустимый тип файла. Разрешены только JPEG, PNG и GIF", 400);
}

// Проверяем размер файла (максимум 10MB)
$maxFileSize = 10 * 1024 * 1024; // 10MB в байтах
if ($uploadedFile['size'] > $maxFileSize) {
    handleError("Размер файла превышает допустимый максимум в 10MB", 400);
}

try {
    // Создаем директорию для загрузки, если она не существует
    if (!file_exists(LOCATION_IMAGES_DIR)) {
        mkdir(LOCATION_IMAGES_DIR, 0755, true);
    }
    
    // Генерируем уникальное имя файла для cropped версии
    $fileName = $userId . '_' . ($locationId ? $locationId . '_' : '') . generateUniqueFileName($uploadedFile['name']);
    $filePath = LOCATION_IMAGES_DIR . $fileName;
    
    // Перемещаем cropped файл в директорию для загрузки
    if (!move_uploaded_file($uploadedFile['tmp_name'], $filePath)) {
        handleError("Не удалось сохранить файл", 500);
    }
    
    // Обрабатываем оригинал первого изображения (если передан)
    error_log("🔍 SERVER: Checking for photo_original");
    error_log("🔍 SERVER: _FILES keys: " . json_encode(array_keys($_FILES)));
    
    $originalFileName = null;
    $originalRelativeUrl = null;
    if (isset($_FILES['photo_original'])) {
        error_log("🔍 SERVER: photo_original isset: YES");
        error_log("🔍 SERVER: photo_original error code: " . $_FILES['photo_original']['error']);
        
        if ($_FILES['photo_original']['error'] === UPLOAD_ERR_OK) {
            error_log("✅ SERVER: photo_original received successfully!");
            $originalFile = $_FILES['photo_original'];
            $originalFileName = $userId . '_' . ($locationId ? $locationId . '_' : '') . 'original_' . generateUniqueFileName($originalFile['name']);
            $originalFilePath = LOCATION_IMAGES_DIR . $originalFileName;
            
            if (move_uploaded_file($originalFile['tmp_name'], $originalFilePath)) {
                $originalRelativeUrl = '/travel/uploads/location_images/' . $originalFileName;
                error_log("✅ SERVER: Original image saved: $originalRelativeUrl");
            } else {
                error_log("❌ SERVER: Failed to move original file");
            }
        } else {
            error_log("❌ SERVER: photo_original has error code: " . $_FILES['photo_original']['error']);
        }
    } else {
        error_log("❌ SERVER: photo_original NOT in _FILES");
    }
    
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Формируем относительный URL для изображения (cropped)
    $relativeUrl = '/travel/uploads/location_images/' . $fileName;
    
    // Проверяем существование локации, если она указана
    if ($locationId) {
        $stmt = $db->prepare("
            SELECT id FROM locations 
            WHERE id = :location_id AND user_id = :user_id
        ");
        $stmt->bindParam(':location_id', $locationId);
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();
        
        if (!$stmt->fetch()) {
            handleError("Указанная локация не найдена или не принадлежит текущему пользователю", 404);
        }
    }
    
    // Определяем позицию для новой фотографии (следующая после последней)
    $positionStmt = $db->prepare("
        SELECT COALESCE(MAX(position), -1) + 1 as next_position 
        FROM photos 
        WHERE location_id = :location_id
    ");
    $positionStmt->bindParam(':location_id', $locationId);
    $positionStmt->execute();
    $nextPosition = $positionStmt->fetch()['next_position'];
    
    // Сохраняем информацию о фотографии в базе данных
    // Если есть оригинал, используем его, иначе используем cropped
    $originalPath = $originalRelativeUrl ?? $relativeUrl;
    
    $stmt = $db->prepare("
        INSERT INTO photos (user_id, location_id, file_path, original_file_path, title, description, position)
        VALUES (:user_id, :location_id, :file_path, :original_file_path, :title, :description, :position)
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':location_id', $locationId);
    $stmt->bindParam(':file_path', $relativeUrl);
    $stmt->bindParam(':original_file_path', $originalPath);
    $stmt->bindParam(':title', $title);
    $stmt->bindParam(':description', $description);
    $stmt->bindParam(':position', $nextPosition);
    $stmt->execute();
    
    $photoId = $db->lastInsertId();
    
    // Проверяем, действительно ли запись добавлена
    $stmt = $db->prepare("SELECT id FROM photos WHERE id = :photo_id");
    $stmt->bindParam(':photo_id', $photoId);
    $stmt->execute();
    
    if (!$stmt->fetch()) {
        handleError("Ошибка при сохранении фото в базе данных", 500);
    }
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Фотография загружена успешно',
        'photo' => [
            'id' => $photoId,
            'userId' => $userId,
            'locationId' => $locationId,
            'filePath' => $relativeUrl,
            'title' => $title,
            'description' => $description
        ],
        'debug_info' => [
            'file_permission' => is_writable(LOCATION_IMAGES_DIR),
            'file_size' => $uploadedFile['size'],
            'file_mime' => $uploadedFile['type'],
            'upload_dir' => LOCATION_IMAGES_DIR,
            'server_path' => $filePath,
            'sql_success' => true,
            'photo_id' => $photoId
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при загрузке фотографии: " . $e->getMessage(), 500);
} 