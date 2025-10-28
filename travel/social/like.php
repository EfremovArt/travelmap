<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обрабатываем только методы POST и DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

$photoId = $input['photo_id'];

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

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Добавление лайка
        
        // Проверяем, существует ли уже лайк
        $stmt = $db->prepare("
            SELECT id FROM likes 
            WHERE user_id = :user_id AND photo_id = :photo_id
        ");
        $stmt->bindParam(':user_id', $userId);
        $stmt->bindParam(':photo_id', $realPhotoId);
        $stmt->execute();
        
        if ($stmt->fetch()) {
            // Лайк уже существует, ничего не делаем
            echo json_encode([
                'success' => true,
                'message' => 'Лайк уже существует'
            ]);
            exit;
        }
        
        // Добавляем новый лайк
        $stmt = $db->prepare("
            INSERT INTO likes (user_id, photo_id)
            VALUES (:user_id, :photo_id)
        ");
        $stmt->bindParam(':user_id', $userId);
        $stmt->bindParam(':photo_id', $realPhotoId);
        $stmt->execute();
        
        $likeId = $db->lastInsertId();
        
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
            'message' => 'Лайк добавлен успешно',
            'like' => [
                'id' => $likeId,
                'userId' => $userId,
                'photoId' => $photoId // Возвращаем исходный photoId
            ],
            'likesCount' => $likesCount,
            'debug_info' => [
                'photo_id_type' => gettype($photoId),
                'photo_id_value' => $photoId,
                'real_photo_id' => $realPhotoId
            ]
        ]);
        
    } else if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        // Удаление лайка
        
        // Удаляем лайк
        $stmt = $db->prepare("
            DELETE FROM likes 
            WHERE user_id = :user_id AND photo_id = :photo_id
        ");
        $stmt->bindParam(':user_id', $userId);
        $stmt->bindParam(':photo_id', $realPhotoId);
        $stmt->execute();
        
        $rowCount = $stmt->rowCount();
        
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
            'message' => $rowCount > 0 ? 'Лайк удален успешно' : 'Лайк не существует',
            'likesCount' => $likesCount,
            'debug_info' => [
                'photo_id_type' => gettype($photoId),
                'photo_id_value' => $photoId,
                'real_photo_id' => $realPhotoId,
                'rows_affected' => $rowCount
            ]
        ]);
    }
    
} catch (Exception $e) {
    handleError("Ошибка при обработке лайка: " . $e->getMessage(), 500);
} 