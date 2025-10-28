<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Получаем ID фотографии из параметров запроса
if (!isset($_GET['photo_id'])) {
    handleError("Отсутствует обязательный параметр: photo_id", 400);
}

$photoId = $_GET['photo_id'];

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Отладочная информация
    error_log("=== GET_PHOTO DEBUG ===");
    error_log("Запрос информации о фото с ID: " . $photoId . " пользователем: " . $userId);
    
    // Реальный ID фотографии (может быть числом или UUID)
    $realPhotoId = null;
    
    // Проверяем, это числовой ID или UUID
    if (is_numeric($photoId)) {
        // Это числовой ID
        $stmt = $db->prepare("SELECT id FROM photos WHERE id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        }
    } else if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $photoId)) {
        // Это UUID, ищем фотографию по UUID
        $stmt = $db->prepare("SELECT id FROM photos WHERE uuid = :photo_uuid");
        $stmt->bindParam(':photo_uuid', $photoId);
        $stmt->execute();
        
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        }
    }
    
    if (!$realPhotoId) {
        error_log("Фото не найдено по ID/UUID: " . $photoId);
        handleError("Фото не найдено", 404);
    }
    
    error_log("Найден realPhotoId: " . $realPhotoId);
    
    // Получаем информацию о фотографии
    $stmt = $db->prepare("
        SELECT p.id, p.user_id, p.location_id, p.file_path, p.original_file_path, p.title, p.description, p.created_at,
               u.first_name, u.last_name, u.profile_image_url
        FROM photos p
        JOIN users u ON p.user_id = u.id
        WHERE p.id = :photo_id
    ");
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    
    $photo = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photo) {
        error_log("Фото не найдено с ID: " . $realPhotoId);
        handleError("Фото не найдено", 404);
    }
    
    // Fallback для оригинального изображения (обратная совместимость)
    if (empty($photo['original_file_path'])) {
        $photo['original_file_path'] = $photo['file_path'];
    }
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'photo' => [
            'id' => $photoId, // Возвращаем исходный ID
            'userId' => intval($photo['user_id']),
            'locationId' => intval($photo['location_id']),
            'filePath' => $photo['file_path'],
            'originalFilePath' => $photo['original_file_path'],
            'title' => $photo['title'],
            'description' => $photo['description'],
            'createdAt' => $photo['created_at'],
            'userFirstName' => $photo['first_name'],
            'userLastName' => $photo['last_name'],
            'userProfileImageUrl' => $photo['profile_image_url']
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Ошибка при получении информации о фото: " . $e->getMessage());
    handleError("Ошибка при получении информации о фото: " . $e->getMessage(), 500);
} 