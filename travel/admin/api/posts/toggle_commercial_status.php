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
    
    $commercialId = isset($_POST['commercial_id']) ? intval($_POST['commercial_id']) : 0;
    $isActive = isset($_POST['is_active']) ? intval($_POST['is_active']) : 0;
    
    if (!$commercialId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID платного поста'
        ]);
        exit;
    }
    
    // Update status
    $stmt = $pdo->prepare("UPDATE commercial_posts SET is_active = :is_active WHERE id = :commercial_id");
    $stmt->execute([
        ':is_active' => $isActive,
        ':commercial_id' => $commercialId
    ]);
    
    if ($stmt->rowCount() > 0) {
        echo json_encode([
            'success' => true,
            'message' => $isActive ? 'Платный пост активирован' : 'Платный пост деактивирован',
            'is_active' => $isActive
        ]);
    } else {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Платный пост не найден'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при изменении статуса: ' . $e->getMessage()
    ]);
}
