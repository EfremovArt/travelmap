<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Получаем данные из запроса
$input = null;

// Проверяем метод запроса и получаем данные соответствующим образом
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $input = json_decode(file_get_contents('php://input'), true);
} else if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Также принимаем POST запросы с параметром _method=DELETE
    if (isset($_POST['_method']) && $_POST['_method'] === 'DELETE') {
        $input = $_POST;
    }
    else {
        $input = json_decode(file_get_contents('php://input'), true);
    }
} else {
    // Для GET запросов или других методов
    $input = $_REQUEST;
}

// Записываем отладочную информацию
error_log("Метод запроса: " . $_SERVER['REQUEST_METHOD']);
error_log("Входящие данные: " . print_r($input, true));

// Проверяем наличие необходимых данных
if (!isset($input['comment_id'])) {
    handleError("Отсутствует обязательное поле: comment_id", 400);
}

$commentId = $input['comment_id'];

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Отладочная информация
    error_log("Запрос на удаление комментария с ID: " . $commentId . " пользователем: " . $userId);
    
    // Проверяем существование комментария и права на его удаление
    $stmt = $db->prepare("
        SELECT c.id, c.user_id, c.photo_id, p.user_id as photo_owner_id
        FROM comments c
        JOIN photos p ON c.photo_id = p.id
        WHERE c.id = :comment_id
    ");
    
    $stmt->bindParam(':comment_id', $commentId);
    $stmt->execute();
    
    $comment = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$comment) {
        error_log("Комментарий не найден: " . $commentId);
        handleError("Комментарий не найден", 404);
    }
    
    error_log("Данные комментария: " . print_r($comment, true));
    
    // Проверяем право на удаление комментария
    // Комментарий может удалить либо автор комментария, либо владелец поста
    if ($comment['user_id'] != $userId && $comment['photo_owner_id'] != $userId) {
        error_log("Отказ в доступе: user_id=" . $userId . ", comment_user_id=" . $comment['user_id'] . ", photo_owner_id=" . $comment['photo_owner_id']);
        handleError("У вас нет прав на удаление этого комментария", 403);
    }
    
    // Удаляем комментарий
    $stmt = $db->prepare("DELETE FROM comments WHERE id = :comment_id");
    $stmt->bindParam(':comment_id', $commentId);
    $result = $stmt->execute();
    
    error_log("Результат удаления: " . ($result ? "успешно" : "неудачно") . ", затронуто строк: " . $stmt->rowCount());
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Комментарий успешно удален',
        'deletedCommentId' => intval($commentId),
        'rowsAffected' => $stmt->rowCount()
    ]);
    
} catch (Exception $e) {
    error_log("Ошибка при удалении комментария: " . $e->getMessage());
    handleError("Ошибка при удалении комментария: " . $e->getMessage(), 500);
} 