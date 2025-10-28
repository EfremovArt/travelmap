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
    $photoId = $input['photo_id'] ?? null;
    
    // Валидация
    if (!$postId || !$photoId) {
        handleError('Required fields missing: post_id, photo_id', 400);
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
    
    // Проверяем, существует ли связь между постом и фото (в двух местах: таблица и прямое поле)
    $checkStmt1 = $pdo->prepare("
        SELECT id FROM commercial_post_photos 
        WHERE commercial_post_id = ? AND photo_id = ?
    ");
    $checkStmt1->execute([$postId, $photoId]);
    $hasRelationInTable = $checkStmt1->fetch();
    
    $checkStmt2 = $pdo->prepare("
        SELECT id FROM commercial_posts 
        WHERE id = ? AND photo_id = ?
    ");
    $checkStmt2->execute([$postId, $photoId]);
    $hasDirectRelation = $checkStmt2->fetch();
    
    // Проверяем, показывается ли пост на этом фото из-за общей локации
    $checkLocationStmt = $pdo->prepare("
        SELECT cp.location_name, l.title as photo_location_name
        FROM commercial_posts cp
        LEFT JOIN photos p ON p.id = ?
        LEFT JOIN locations l ON p.location_id = l.id
        WHERE cp.id = ? 
            AND cp.location_name IS NOT NULL 
            AND cp.location_name != ''
            AND cp.location_name = l.title
    ");
    $checkLocationStmt->execute([$photoId, $postId]);
    $hasLocationRelation = $checkLocationStmt->fetch();
    
    if (!$hasRelationInTable && !$hasDirectRelation && !$hasLocationRelation) {
        handleError('Post is not attached to this photo', 404);
    }
    
    // Если пост отображается только из-за локации (нет прямой связи),
    // обнуляем location_name чтобы пост больше не показывался на фото этой локации
    if (!$hasRelationInTable && !$hasDirectRelation && $hasLocationRelation) {
        error_log("Detaching post $postId from photo $photoId by removing location (old post with location-based display)");
        // Обнуляем location_name и координаты
        $stmt = $pdo->prepare("
            UPDATE commercial_posts 
            SET location_name = NULL, latitude = NULL, longitude = NULL, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ");
        $stmt->execute([$postId]);
        
        echo json_encode([
            'success' => true,
            'message' => 'Commercial post detached from photo successfully (location removed)',
            'post_id' => $postId,
            'photo_id' => $photoId
        ]);
        exit;
    }
    
    // Начинаем транзакцию
    $pdo->beginTransaction();
    
    try {
        // Удаляем связь из связующей таблицы (если есть)
        if ($hasRelationInTable) {
            $stmt = $pdo->prepare("
                DELETE FROM commercial_post_photos 
                WHERE commercial_post_id = ? AND photo_id = ?
            ");
            $stmt->execute([$postId, $photoId]);
        }
        
        // Удаляем прямую связь (если есть)
        if ($hasDirectRelation) {
            $stmt = $pdo->prepare("
                UPDATE commercial_posts 
                SET photo_id = NULL 
                WHERE id = ? AND photo_id = ?
            ");
            $result = $stmt->execute([$postId, $photoId]);
            
            if (!$result) {
                throw new Exception('Failed to detach post from photo');
            }
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
            'message' => 'Commercial post detached from photo successfully',
            'post_id' => $postId,
            'photo_id' => $photoId
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in detach_post_from_photo.php: " . $e->getMessage());
    handleError("Ошибка при отвязке поста от фото: " . $e->getMessage(), 500);
}
?>

