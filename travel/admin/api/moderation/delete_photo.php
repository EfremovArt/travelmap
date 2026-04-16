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
    
    // Валидация параметров
    $photoId = validateInt($input['photoId'] ?? null, 1);
    if ($photoId === false) {
        adminHandleError('Неверный ID фотографии', 400, 'INVALID_PARAMETERS');
    }
    $pdo = connectToDatabase();
    
    // Get photo file path before deletion
    $stmt = $pdo->prepare("SELECT file_path FROM photos WHERE id = :id");
    $stmt->execute([':id' => $photoId]);
    $photo = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photo) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Фотография не найдена'
        ]);
        exit;
    }
    
    $pdo->beginTransaction();
    
    try {
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
        
        $pdo->commit();
        
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
        
        // Логируем удаление фотографии
        logAdminAction('delete_photo', [
            'photo_id' => $photoId,
            'file_path' => $filePath
        ], 'photo', $photoId);
        
        echo json_encode([
            'success' => true,
            'message' => 'Фотография успешно удалена'
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении фотографии: ' . $e->getMessage()
    ]);
}
