<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['photo_id']) || !isset($input['comment'])) {
    handleError("Отсутствуют обязательные поля: photo_id, comment", 400);
}

$photoId = $input['photo_id'];
$comment = trim($input['comment']);

// Проверяем, что комментарий не пустой
if (empty($comment)) {
    handleError("Комментарий не может быть пустым", 400);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Проверяем существование фото по ID или UUID
    $realPhotoId = null;
    
    // Сначала проверяем, это числовой ID или UUID
    if (is_numeric($photoId)) {
        // Это числовой ID
        $stmt = $db->prepare("SELECT id FROM photos WHERE id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        } else {
            // Попытка найти синтетическое фото для коммерческого поста по uuid 'commercial_{id}'
            $syntheticUuid = 'commercial_' . $photoId;
            $stmt = $db->prepare("SELECT id FROM photos WHERE uuid = :photo_uuid");
            $stmt->bindParam(':photo_uuid', $syntheticUuid);
            $stmt->execute();
            if ($row = $stmt->fetch()) {
                $realPhotoId = $row['id'];
            } else {
                // Создаем синтетическую запись фото для коммерческого поста
                $stmt = $db->prepare("
                INSERT INTO photos (user_id, file_path, uuid) 
                VALUES (:user_id, 'temp_photo.jpg', :uuid)
            ");
                $stmt->bindParam(':user_id', $userId);
                $stmt->bindParam(':uuid', $syntheticUuid);
                $stmt->execute();
                $realPhotoId = $db->lastInsertId();
            }
        }
    } else if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $photoId)) {
        // Это UUID, ищем фотографию по UUID
        $stmt = $db->prepare("SELECT id FROM photos WHERE uuid = :photo_uuid");
        $stmt->bindParam(':photo_uuid', $photoId);
        $stmt->execute();
        
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        } else {
            // Если фото не найдено, создаем временную запись
            $stmt = $db->prepare("
                INSERT INTO photos (user_id, file_path, uuid) 
                VALUES (:user_id, 'temp_photo.jpg', :uuid)
            ");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':uuid', $photoId);
            $stmt->execute();
            
            // Получаем ID созданной фотографии
            $realPhotoId = $db->lastInsertId();
            
            error_log("Created temporary photo with ID: " . $realPhotoId . " for UUID: " . $photoId);
        }
    } else {
        handleError("Некорректный формат идентификатора фотографии", 400);
    }
    
    if (!$realPhotoId) {
        handleError("Фото не найдено", 404);
    }
    
    // Добавляем комментарий
    $stmt = $db->prepare("
        INSERT INTO comments (user_id, photo_id, comment)
        VALUES (:user_id, :photo_id, :comment)
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->bindParam(':comment', $comment);
    $stmt->execute();
    
    $commentId = $db->lastInsertId();
    
    // Получаем информацию о пользователе для ответа
    $stmt = $db->prepare("
        SELECT u.first_name, u.last_name, u.profile_image_url
        FROM users u
        WHERE u.id = :user_id
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    $user = $stmt->fetch();
    
    // Получаем полную информацию о новом комментарии
    $stmt = $db->prepare("
        SELECT c.id, c.user_id, c.photo_id, c.comment, c.created_at,
               u.first_name, u.last_name, u.profile_image_url
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.id = :comment_id
    ");
    $stmt->bindParam(':comment_id', $commentId);
    $stmt->execute();
    $commentData = $stmt->fetch();
    
    // Используем исходный photoId в ответе, чтобы клиент мог его использовать
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Комментарий добавлен успешно',
        'comment' => [
            'id' => intval($commentId),
            'userId' => intval($userId),
            'photoId' => $photoId, // Возвращаем исходный photoId
            'text' => $comment,
            'createdAt' => $commentData['created_at'],
            'userFirstName' => $user['first_name'],
            'userLastName' => $user['last_name'],
            'userProfileImageUrl' => $user['profile_image_url']
        ],
        'debug_info' => [
            'photo_id_type' => gettype($photoId),
            'photo_id_value' => $photoId,
            'real_photo_id' => $realPhotoId
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при добавлении комментария: " . $e->getMessage(), 500);
} 