<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Подключаемся к базе данных
$pdo = connectToDatabase();

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $postId = $input['post_id'] ?? null;
    $coverId = $input['cover_id'] ?? null; // ID обложки (photo_id)
    
    // Валидация
    if (!$postId || !$coverId) {
        handleError('Required fields missing: post_id, cover_id', 400);
    }
    
    // Проверяем, что коммерческий пост существует и принадлежит пользователю
    $stmt = $pdo->prepare("
        SELECT id, user_id 
        FROM commercial_posts 
        WHERE id = ? AND user_id = ?
    ");
    $stmt->execute([$postId, $userId]);
    $post = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$post) {
        handleError('Commercial post not found or access denied', 403);
    }
    
    // Проверяем, существует ли обложка
    $stmt = $pdo->prepare("
        SELECT id 
        FROM photos 
        WHERE id = ? AND location_id IS NULL
    ");
    $stmt->execute([$coverId]);
    $cover = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$cover) {
        handleError('Cover not found', 404);
    }
    
    // Проверяем, существует ли связь между постом и обложкой
    $checkStmt = $pdo->prepare("
        SELECT id FROM commercial_post_photos 
        WHERE commercial_post_id = ? AND photo_id = ?
    ");
    $checkStmt->execute([$postId, $coverId]);
    $hasRelation = $checkStmt->fetch();
    
    if (!$hasRelation) {
        handleError('Post is not attached to this cover', 404);
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Удаляем связь между постом и обложкой
        $stmt = $pdo->prepare("
            DELETE FROM commercial_post_photos 
            WHERE commercial_post_id = ? AND photo_id = ?
        ");
        $result = $stmt->execute([$postId, $coverId]);
        
        if (!$result) {
            throw new Exception('Failed to detach post from cover');
        }
        
        // Обновляем время изменения поста
        $updateStmt = $pdo->prepare("
            UPDATE commercial_posts 
            SET updated_at = CURRENT_TIMESTAMP 
            WHERE id = ?
        ");
        $updateStmt->execute([$postId]);
        
        // Подтверждаем транзакцию
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post detached from cover successfully',
            'post_id' => $postId,
            'cover_id' => $coverId
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in detach_post_from_cover.php: " . $e->getMessage());
    handleError("Ошибка при отвязке поста от обложки: " . $e->getMessage(), 500);
}
?>

