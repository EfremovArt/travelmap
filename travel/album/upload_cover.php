<?php
require_once '../config.php';

// Инициализация API и подключение к базе данных
initApi();
$pdo = connectToDatabase();

// Проверяем метод запроса
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['message' => 'Method not allowed']);
    exit;
}

// Проверяем авторизацию
try {
    $userId = requireAuth();
    error_log("User authenticated successfully: $userId");
} catch (Exception $e) {
    error_log("Authentication failed: " . $e->getMessage());
    http_response_code(401);
    echo json_encode(['message' => 'Authentication required']);
    exit;
}

// Проверяем, что файл был загружен
error_log("Checking uploaded files: " . json_encode($_FILES));
if (!isset($_FILES['cover_image']) || $_FILES['cover_image']['error'] !== UPLOAD_ERR_OK) {
    $errorMsg = 'No valid file uploaded';
    if (isset($_FILES['cover_image']['error'])) {
        $errorMsg .= '. Upload error code: ' . $_FILES['cover_image']['error'];
    }
    error_log("File upload failed: $errorMsg");
    http_response_code(400);
    echo json_encode(['message' => $errorMsg]);
    exit;
}

$uploadedFile = $_FILES['cover_image'];

// Проверяем размер файла (максимум 10MB)
$maxSize = 10 * 1024 * 1024; // 10MB в байтах
if ($uploadedFile['size'] > $maxSize) {
    http_response_code(400);
    echo json_encode(['message' => 'File size exceeds maximum limit (10MB)']);
    exit;
}

// Проверяем тип файла по расширению
$allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
$fileExtension = strtolower(pathinfo($uploadedFile['name'], PATHINFO_EXTENSION));
if (!in_array($fileExtension, $allowedExtensions)) {
    error_log("Invalid file extension: $fileExtension");
    http_response_code(400);
    echo json_encode(['message' => 'Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed']);
    exit;
}
error_log("File extension validated: $fileExtension");

try {
    error_log("Starting album cover upload for user: $userId");
    
    // Используем стандартную директорию для изображений локаций (совместимость с существующей архитектурой)
    $imageDir = __DIR__ . '/../uploads/location_images/';
    if (!file_exists($imageDir)) {
        mkdir($imageDir, 0755, true);
        error_log("Created image directory: $imageDir");
    }
    
    // Генерируем уникальное имя файла с префиксом для обложек альбомов
    $fileName = $userId . '_album_cover_' . generateUniqueFileName($uploadedFile['name']);
    $filePath = $imageDir . $fileName;
    error_log("Generated file path: $filePath");
    
    // Перемещаем файл
    if (!move_uploaded_file($uploadedFile['tmp_name'], $filePath)) {
        error_log("Failed to move uploaded file");
        http_response_code(500);
        echo json_encode(['message' => 'Failed to save file']);
        exit;
    }
    error_log("File moved successfully");
    
    // Формируем относительный URL для изображения (совместимый с существующей системой)
    $relativeUrl = '/travel/uploads/location_images/' . $fileName;
    error_log("Relative URL: $relativeUrl");
    
    // Проверяем подключение к базе данных
    if (!$pdo) {
        error_log("PDO connection is null");
        http_response_code(500);
        echo json_encode(['message' => 'Database connection failed']);
        exit;
    }
    
    // Сохраняем как специальную запись в таблице photos (совместимость с существующей архитектурой)
    // location_id = NULL означает, что это обложка альбома, а не пост с локацией
    $stmt = $pdo->prepare("
        INSERT INTO photos (user_id, location_id, file_path, title, description, created_at)
        VALUES (?, NULL, ?, 'Album Cover', 'Uploaded as album cover', NOW())
    ");
    $stmt->execute([$userId, $relativeUrl]);
    error_log("Database insert completed");
    
    $photoId = $pdo->lastInsertId();
    error_log("Generated photo ID: $photoId");
    
    // Возвращаем успешный ответ с ID, который можно использовать как cover_photo_id в albums
    echo json_encode([
        'success' => true,
        'id' => $photoId, // Это будет использоваться как cover_photo_id
        'file_path' => $relativeUrl,
        'message' => 'Album cover uploaded successfully'
    ]);
    
} catch (Exception $e) {
    // Удаляем файл, если он был загружен, но произошла ошибка
    if (isset($filePath) && file_exists($filePath)) {
        unlink($filePath);
        error_log("Removed file due to error: $filePath");
    }
    
    error_log("Album cover upload error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error uploading album cover: ' . $e->getMessage(),
        'error' => $e->getMessage()
    ]);
}
?>
