<?php
require_once '../../config/admin_config.php';

// Проверка авторизации
adminRequireAuth();

// Проверка CSRF токена
requireCsrfToken();

header('Content-Type: application/json; charset=UTF-8');

try {
    // Получаем данные из запроса
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['commentId']) || !isset($input['commentType'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID комментария или тип',
            'errorCode' => 'INVALID_PARAMETERS'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Валидация параметров
    $commentId = validateInt($input['commentId'], 1);
    if ($commentId === false) {
        adminHandleError('Неверный ID комментария', 400, 'INVALID_PARAMETERS');
    }
    
    $commentType = validateString($input['commentType']);
    
    if ($commentId <= 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Неверный ID комментария',
            'errorCode' => 'INVALID_PARAMETERS'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    if (!in_array($commentType, ['photo', 'album'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Неверный тип комментария',
            'errorCode' => 'INVALID_PARAMETERS'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    $conn = getDbConnection();
    
    // Проверяем существование комментария
    if ($commentType === 'photo') {
        $checkStmt = $conn->prepare("SELECT id FROM comments WHERE id = :comment_id");
    } else {
        $checkStmt = $conn->prepare("SELECT id FROM album_comments WHERE id = :comment_id");
    }
    
    $checkStmt->bindParam(':comment_id', $commentId, PDO::PARAM_INT);
    $checkStmt->execute();
    
    if (!$checkStmt->fetch()) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Комментарий не найден',
            'errorCode' => 'NOT_FOUND'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    
    // Удаляем комментарий
    if ($commentType === 'photo') {
        $deleteStmt = $conn->prepare("DELETE FROM comments WHERE id = :comment_id");
    } else {
        $deleteStmt = $conn->prepare("DELETE FROM album_comments WHERE id = :comment_id");
    }
    
    $deleteStmt->bindParam(':comment_id', $commentId, PDO::PARAM_INT);
    $result = $deleteStmt->execute();
    
    if ($result) {
        // Логируем удаление комментария
        logAdminAction('delete_comment', [
            'comment_id' => $commentId,
            'comment_type' => $commentType
        ], 'comment', $commentId);
        
        echo json_encode([
            'success' => true,
            'message' => 'Комментарий успешно удален'
        ], JSON_UNESCAPED_UNICODE);
    } else {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Ошибка при удалении комментария',
            'errorCode' => 'DATABASE_ERROR'
        ], JSON_UNESCAPED_UNICODE);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении комментария: ' . $e->getMessage(),
        'errorCode' => 'DATABASE_ERROR'
    ], JSON_UNESCAPED_UNICODE);
}
