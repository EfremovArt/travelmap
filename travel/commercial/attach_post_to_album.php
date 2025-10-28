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
    
    // Проверяем, существует ли коммерческий пост и принадлежит ли он текущему пользователю
    $stmt = $pdo->prepare("SELECT id, user_id, is_active FROM commercial_posts WHERE id = ? AND user_id = ? AND is_active = 1");
    $stmt->execute([$postId, $userId]);
    $post = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$post) {
        handleError('Commercial post not found or access denied', 403);
    }
    
    // Проверяем, существует ли альбом
    // Владелец коммерческого поста может размещать его в любых альбомах
    $stmt = $pdo->prepare("SELECT id, owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $album = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$album) {
        handleError('Album not found', 404);
    }
    
    // Проверяем, не привязан ли уже этот пост к этому альбому
    $checkStmt = $pdo->prepare("
        SELECT id FROM commercial_post_albums 
        WHERE commercial_post_id = ? AND album_id = ?
    ");
    $checkStmt->execute([$postId, $albumId]);
    
    if ($checkStmt->fetch()) {
        // Пост уже привязан к этому альбому
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post is already attached to this album',
            'post_id' => $postId,
            'album_id' => $albumId
        ]);
        exit;
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Создаем связь между постом и альбомом
        $insertStmt = $pdo->prepare("
            INSERT INTO commercial_post_albums (commercial_post_id, album_id) 
            VALUES (?, ?)
        ");
        $result = $insertStmt->execute([$postId, $albumId]);
        
        if (!$result) {
            throw new Exception('Failed to attach post to album');
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
            'message' => 'Commercial post attached to album successfully',
            'post_id' => $postId,
            'album_id' => $albumId
        ]);
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in attach_post_to_album.php: " . $e->getMessage());
    handleError("Ошибка при привязке поста к альбому: " . $e->getMessage(), 500);
}
