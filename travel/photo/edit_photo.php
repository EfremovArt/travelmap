<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

$photoId = intval($input['photo_id']);
$title = isset($input['title']) ? trim($input['title']) : null;
$description = isset($input['description']) ? trim($input['description']) : null;

// Валидация - хотя бы одно поле должно быть передано для обновления
if ($title === null && $description === null) {
    handleError("Необходимо указать хотя бы одно поле для обновления: title или description", 400);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Проверяем, существует ли фотография и принадлежит ли она текущему пользователю
    $stmt = $db->prepare("
        SELECT id, user_id, title, description FROM photos 
        WHERE id = :photo_id AND user_id = :user_id
    ");
    $stmt->bindParam(':photo_id', $photoId);
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    
    $photo = $stmt->fetch();
    
    if (!$photo) {
        handleError("Указанная фотография не найдена или не принадлежит текущему пользователю", 404);
    }
    
    // Подготавливаем данные для обновления
    $updateFields = [];
    $params = [];
    
    if ($title !== null) {
        $updateFields[] = "title = :title";
        $params[':title'] = $title;
    }
    
    if ($description !== null) {
        $updateFields[] = "description = :description";
        $params[':description'] = $description;
    }
    
    // Добавляем обновление времени изменения
    $updateFields[] = "updated_at = NOW()";
    
    // Формируем и выполняем запрос на обновление
    $sql = "UPDATE photos SET " . implode(", ", $updateFields) . " WHERE id = :photo_id AND user_id = :user_id";
    $params[':photo_id'] = $photoId;
    $params[':user_id'] = $userId;
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    
    // Проверяем, была ли обновлена запись
    if ($stmt->rowCount() === 0) {
        handleError("Не удалось обновить фотографию", 500);
    }
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Фотография обновлена успешно',
        'photo' => [
            'id' => $photoId,
            'title' => $title ?? $photo['title'],
            'description' => $description ?? $photo['description'],
            'updated_at' => date('Y-m-d H:i:s')
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Error in edit_photo.php: " . $e->getMessage());
    handleError("Ошибка при обновлении фотографии: " . $e->getMessage(), 500);
}
