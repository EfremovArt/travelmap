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
    $albumId = $input['album_id'] ?? null;
    
    // Валидация
    if (!$postId || !$albumId) {
        handleError('Required fields missing: post_id, album_id', 400);
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
    
    // Проверяем, существует ли альбом
    $stmt = $pdo->prepare("SELECT id, owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $album = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$album) {
        handleError('Album not found', 404);
    }
    
    // Проверяем, существует ли связь между постом и альбомом
    $checkStmt = $pdo->prepare("
        SELECT id FROM commercial_post_albums 
        WHERE commercial_post_id = ? AND album_id = ?
    ");
    $checkStmt->execute([$postId, $albumId]);
    $hasRelation = $checkStmt->fetch();
    
    if (!$hasRelation) {
        handleError('Post is not attached to this album', 404);
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Удаляем связь между постом и альбомом
        $stmt = $pdo->prepare("
            DELETE FROM commercial_post_albums 
            WHERE commercial_post_id = ? AND album_id = ?
        ");
        $result = $stmt->execute([$postId, $albumId]);
        
        if (!$result) {
            throw new Exception('Failed to detach post from album');
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
            'message' => 'Commercial post detached from album successfully',
            'post_id' => $postId,
            'album_id' => $albumId
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in detach_post_from_album.php: " . $e->getMessage());
    handleError("Ошибка при отвязке поста от альбома: " . $e->getMessage(), 500);
}
?>

