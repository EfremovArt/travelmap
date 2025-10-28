<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Проверяем наличие необходимых параметров
if (!isset($_GET['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

// Можно проверять лайки как для текущего пользователя, так и для указанного user_id
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
    
    // Если фото не найдено, возвращаем корректный ответ без 404
    if (!$realPhotoId) {
        echo json_encode([
            'success' => true,
            'isLiked' => false,
            'likesCount' => 0,
            'debug_info' => [
                'photo_id_type' => gettype($photoId),
                'photo_id_value' => $photoId,
                'real_photo_id' => null,
                'note' => 'Фото не найдено, возвращаем нулевые значения'
            ]
        ]);
        exit;
    }
    
    // Проверяем наличие лайка
    $stmt = $db->prepare("
        SELECT id FROM likes 
        WHERE user_id = :user_id AND photo_id = :photo_id
    ");
    $stmt->bindParam(':user_id', $checkUserId);
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    
    $isLiked = $stmt->fetch() ? true : false;
    
    // Получаем общее количество лайков для этой фотографии
    $stmt = $db->prepare("
        SELECT COUNT(*) as likes_count 
        FROM likes 
        WHERE photo_id = :photo_id
    ");
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    $likesCount = $stmt->fetch()['likes_count'];
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'isLiked' => $isLiked,
        'likesCount' => $likesCount,
        'debug_info' => [
            'photo_id_type' => gettype($photoId),
            'photo_id_value' => $photoId,
            'real_photo_id' => $realPhotoId
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при проверке лайка: " . $e->getMessage(), 500);
} 