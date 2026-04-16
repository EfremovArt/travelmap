<?php
require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

// Проверка CSRF токена
requireCsrfToken();

header('Content-Type: application/json; charset=UTF-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Метод не разрешен'
    ]);
    exit;
}

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['photoIds']) || !is_array($input['photoIds']) || empty($input['photoIds'])) {
        adminHandleError('Неверный список ID фотографий', 400, 'INVALID_PARAMETERS');
    }
    
    // Валидация каждого ID
    $photoIds = [];
    foreach ($input['photoIds'] as $id) {
        $validId = validateInt($id, 1);
        if ($validId !== false) {
            $photoIds[] = $validId;
        }
    }
    
    if (empty($photoIds)) {
        adminHandleError('Не указаны корректные ID фотографий', 400, 'INVALID_PARAMETERS');
    }
    $pdo = getDBConnection();
    
    // Get photo file paths before deletion
    $placeholders = implode(',', array_fill(0, count($photoIds), '?'));
    $stmt = $pdo->prepare("SELECT id, file_path FROM photos WHERE id IN ($placeholders)");
    $stmt->execute($photoIds);
    $photos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($photos)) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Фотографии не найдены'
        ]);
        exit;
    }
    
    $pdo->beginTransaction();
    
    try {
        $deletedCount = 0;
        
        foreach ($photos as $photo) {
            $photoId = $photo['id'];
            
            // Delete from album_photos
            $stmt = $pdo->prepare("DELETE FROM album_photos WHERE photo_id = :photo_id");
            $stmt->execute([':photo_id' => $photoId]);
            
            // Delete from favorites
            $stmt = $pdo->prepare("DELETE FROM favorites WHERE photo_id = :photo_id");
            $stmt->execute([':photo_id' => $photoId]);
            
            // Delete from likes
            $stmt = $pdo->prepare("DELETE FROM likes WHERE photo_id = :photo_id");
            $stmt->execute([':photo_id' => $photoId]);
            
            // Delete from comments
            $stmt = $pdo->prepare("DELETE FROM comments WHERE photo_id = :photo_id");
            $stmt->execute([':photo_id' => $photoId]);
            
            // Update commercial posts that reference this photo
            $stmt = $pdo->prepare("UPDATE commercial_posts SET photo_id = NULL WHERE photo_id = :photo_id");
            $stmt->execute([':photo_id' => $photoId]);
            
            // Delete the photo record
            $stmt = $pdo->prepare("DELETE FROM photos WHERE id = :id");
            $stmt->execute([':id' => $photoId]);
            
            $deletedCount++;
            
            // Delete physical file
            $filePath = $photo['file_path'];
            if ($filePath) {
                // Suppress warnings for file operations due to open_basedir restrictions
                if (@file_exists($filePath)) {
                    if (!@unlink($filePath)) {
                        error_log("Failed to delete file: $filePath");
                    }
                }
            }
        }
        
        $pdo->commit();
        
        // Логируем массовое удаление фотографий
        logAdminAction('bulk_delete_photos', [
            'photo_ids' => $photoIds,
            'deleted_count' => $deletedCount
        ], 'photo', null);
        
        echo json_encode([
            'success' => true,
            'message' => "Удалено фотографий: $deletedCount",
            'deletedCount' => $deletedCount
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при массовом удалении фотографий: ' . $e->getMessage()
    ]);
}
