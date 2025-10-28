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
if (!isset($_FILES['profile_image']) || $_FILES['profile_image']['error'] !== UPLOAD_ERR_OK) {
    $error = isset($_FILES['profile_image']) ? $_FILES['profile_image']['error'] : 'Файл не был отправлен';
    handleError("Ошибка при загрузке файла: " . $error, 400);
}

$uploadedFile = $_FILES['profile_image'];

// Логируем информацию о загруженном файле
error_log("Uploaded file info: " . print_r($uploadedFile, true));
error_log("File type: " . $uploadedFile['type']);

// Проверяем тип файла
$allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
if (!in_array($uploadedFile['type'], $allowedTypes)) {
    error_log("Invalid file type: " . $uploadedFile['type'] . ". Allowed types: " . implode(', ', $allowedTypes));
    handleError("Недопустимый тип файла. Разрешены только JPEG, PNG и GIF", 400);
}

// Проверяем размер файла (максимум 5MB)
$maxFileSize = 5 * 1024 * 1024; // 5MB в байтах
if ($uploadedFile['size'] > $maxFileSize) {
    handleError("Размер файла превышает допустимый максимум в 5MB", 400);
}

try {
    // Создаем директорию для загрузки, если она не существует
    if (!file_exists(PROFILE_IMAGES_DIR)) {
        mkdir(PROFILE_IMAGES_DIR, 0755, true);
        error_log("Created directory: " . PROFILE_IMAGES_DIR);
    }
    
    // Генерируем уникальное имя файла
    $fileName = $userId . '_' . generateUniqueFileName($uploadedFile['name']);
    $filePath = PROFILE_IMAGES_DIR . $fileName;
    
    error_log("Attempting to save file to: " . $filePath);
    
    // Перемещаем файл в директорию для загрузки
    if (!move_uploaded_file($uploadedFile['tmp_name'], $filePath)) {
        error_log("Failed to move uploaded file from: " . $uploadedFile['tmp_name'] . " to " . $filePath);
        handleError("Не удалось сохранить файл", 500);
    }
    
    error_log("File successfully saved to: " . $filePath);
    
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Формируем относительный URL для изображения
    $relativeUrl = '/travel/uploads/profile_images/' . $fileName;
    
    // Проверяем, существует ли файл по указанному пути
    $absoluteUrl = 'https://bearded-fox.ru' . $relativeUrl;
    
    // Добавляем логирование путей для отладки
    error_log("Physical file path: $filePath");
    error_log("Relative URL path: $relativeUrl");
    error_log("Absolute URL: $absoluteUrl");
    
    // Обновляем запись в базе данных
    $stmt = $db->prepare("
        UPDATE users 
        SET profile_image_url = :profile_image_url,
            updated_at = NOW() 
        WHERE id = :user_id
    ");
    $stmt->bindParam(':profile_image_url', $relativeUrl);
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Изображение профиля обновлено успешно',
        'profileImageUrl' => $relativeUrl,
        'absoluteUrl' => $absoluteUrl,
        'fileName' => $fileName,
        'filePath' => str_replace($_SERVER['DOCUMENT_ROOT'], '', $filePath)
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при загрузке изображения профиля: " . $e->getMessage(), 500);
} 