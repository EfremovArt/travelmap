<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Обработка запроса только методом DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Подключаемся к базе данных
$pdo = connectToDatabase();

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $postId = $input['id'] ?? null;
    
    // Валидация
    if (!$postId) {
        handleError('Post ID is required', 400);
    }
    
    // Проверяем, существует ли пост и принадлежит ли он пользователю
    $stmt = $pdo->prepare("SELECT id FROM commercial_posts WHERE id = ? AND user_id = ?");
    $stmt->execute([$postId, $userId]);
    if (!$stmt->fetch()) {
        handleError('Post not found or access denied', 403);
    }
    
    // Начинаем транзакцию для атомарности операции
    $pdo->beginTransaction();
    
    try {
        // Получаем количество связанных изображений для статистики
        $imageCountStmt = $pdo->prepare("SELECT COUNT(*) FROM commercial_post_images WHERE commercial_post_id = ?");
        $imageCountStmt->execute([$postId]);
        $imageCount = $imageCountStmt->fetchColumn();
        
        // Удаляем связанные изображения (хотя CASCADE должен это делать автоматически)
        $deleteImagesStmt = $pdo->prepare("DELETE FROM commercial_post_images WHERE commercial_post_id = ?");
        $deleteImagesStmt->execute([$postId]);
        
        // Удаляем сам пост
        $stmt = $pdo->prepare("DELETE FROM commercial_posts WHERE id = ? AND user_id = ?");
        $result = $stmt->execute([$postId, $userId]);
        
        if ($result && $stmt->rowCount() > 0) {
            // Подтверждаем транзакцию
            $pdo->commit();
            
            echo json_encode([
                'success' => true,
                'message' => 'Commercial post deleted successfully',
                'deleted_images' => $imageCount
            ]);
        } else {
            $pdo->rollback();
            handleError('Failed to delete commercial post', 500);
        }
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in delete_post.php: " . $e->getMessage());
    handleError("Ошибка при удалении поста: " . $e->getMessage(), 500);
}
