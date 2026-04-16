<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    $userId = isset($_POST['user_id']) ? intval($_POST['user_id']) : 0;
    $photoId = isset($_POST['photo_id']) ? intval($_POST['photo_id']) : 0;
    
    if (!$userId || !$photoId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указаны user_id или photo_id'
        ]);
        exit;
    }
    
    // Delete favorite
    $sql = "DELETE FROM favorites WHERE user_id = :user_id AND photo_id = :photo_id";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':user_id' => $userId,
        ':photo_id' => $photoId
    ]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Избранное успешно удалено'
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении избранного'
    ]);
}
