<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    if (!$pdo) {
        throw new Exception('Не удалось подключиться к базе данных');
    }
    
    $albumPhotoId = isset($_POST['album_photo_id']) ? intval($_POST['album_photo_id']) : 0;
    
    if (!$albumPhotoId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID фото в альбоме'
        ]);
        exit;
    }
    
    // Delete the photo from album (not the photo itself, just the relation)
    $stmt = $pdo->prepare("DELETE FROM album_photos WHERE id = :album_photo_id");
    $stmt->execute([':album_photo_id' => $albumPhotoId]);
    
    if ($stmt->rowCount() > 0) {
        echo json_encode([
            'success' => true,
            'message' => 'Фото успешно удалено из альбома'
        ]);
    } else {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Фото не найдено'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении фото: ' . $e->getMessage()
    ]);
}
