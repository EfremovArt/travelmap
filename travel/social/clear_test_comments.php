<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    handleError("Метод не поддерживается, используйте DELETE", 405);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Удаляем только тестовые комментарии (по ключевому слову в тексте)
    $stmt = $db->prepare("
        DELETE FROM comments 
        WHERE comment LIKE '%тест%' OR comment LIKE '%test%'
    ");
    $stmt->execute();
    
    $affectedRows = $stmt->rowCount();
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Тестовые комментарии удалены успешно',
        'deletedCount' => $affectedRows,
        'debug_info' => [
            'db_working' => $db ? true : false,
            'userId' => $userId
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при удалении тестовых комментариев: " . $e->getMessage(), 500);
} 