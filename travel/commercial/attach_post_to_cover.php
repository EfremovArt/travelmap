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
    
    // Проверяем, существует ли коммерческий пост и принадлежит ли он текущему пользователю
    $stmt = $pdo->prepare("
        SELECT id, user_id, is_active 
        FROM commercial_posts 
        WHERE id = ? AND user_id = ? AND is_active = 1
    ");
    $stmt->execute([$postId, $userId]);
    $post = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$post) {
        handleError('Commercial post not found or access denied', 403);
    }
    
    // Проверяем, существует ли обложка (это должна быть запись в photos с location_id = NULL)
    $stmt = $pdo->prepare("
        SELECT id, user_id 
        FROM photos 
        WHERE id = ? AND location_id IS NULL
    ");
    $stmt->execute([$coverId]);
    $cover = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$cover) {
        handleError('Cover not found', 404);
    }
    
    // Проверяем, не привязан ли уже этот пост к этой обложке
    $checkStmt = $pdo->prepare("
        SELECT id FROM commercial_post_photos 
        WHERE commercial_post_id = ? AND photo_id = ?
    ");
    $checkStmt->execute([$postId, $coverId]);
    
    if ($checkStmt->fetch()) {
        // Пост уже привязан к этой обложке
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post is already attached to this cover',
            'post_id' => $postId,
            'cover_id' => $coverId
        ]);
        exit;
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Создаем связь между постом и обложкой через таблицу commercial_post_photos
        $insertStmt = $pdo->prepare("
            INSERT INTO commercial_post_photos (commercial_post_id, photo_id) 
            VALUES (?, ?)
        ");
        $result = $insertStmt->execute([$postId, $coverId]);
        
        if (!$result) {
            throw new Exception('Failed to attach post to cover');
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
            'message' => 'Commercial post attached to cover successfully',
            'post_id' => $postId,
            'cover_id' => $coverId
        ]);
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in attach_post_to_cover.php: " . $e->getMessage());
    handleError("Ошибка при привязке поста к обложке: " . $e->getMessage(), 500);
}
?>

