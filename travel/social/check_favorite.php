<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Проверяем наличие необходимых параметров
if (!isset($_GET['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

// Можно проверять избранное как для текущего пользователя, так и для указанного user_id
$photoId = $_GET['photo_id'];
$checkUserId = isset($_GET['user_id']) ? $_GET['user_id'] : $userId;

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Определяем реальный ID фотографии в базе данных
    $realPhotoId = null;
    
    // Сначала проверяем, это числовой ID или UUID
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
        handleError("Фотография не найдена", 404);
    }
    
    // Проверяем наличие в избранном
    $stmt = $db->prepare("
        SELECT id FROM favorites 
        WHERE user_id = :user_id AND photo_id = :photo_id
    ");
    $stmt->bindParam(':user_id', $checkUserId);
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    
    $isFavorite = $stmt->fetch() ? true : false;
    
    // Получаем общее количество добавлений в избранное для этой фотографии
    $stmt = $db->prepare("
        SELECT COUNT(*) as favorites_count 
        FROM favorites 
        WHERE photo_id = :photo_id
    ");
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    $favoritesCount = $stmt->fetch()['favorites_count'];
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'isFavorite' => $isFavorite,
        'favoritesCount' => $favoritesCount,
        'debug_info' => [
            'photo_id_type' => gettype($photoId),
            'photo_id_value' => $photoId,
            'real_photo_id' => $realPhotoId
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при проверке избранного: " . $e->getMessage(), 500);
} 