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
    
    if (!$commercialId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID платного поста'
        ]);
        exit;
    }
    
    // Start transaction
    $pdo->beginTransaction();
    
    try {
        // Delete related data if exists
        try {
            $pdo->prepare("DELETE FROM commercial_favorites WHERE commercial_post_id = :commercial_id")->execute([':commercial_id' => $commercialId]);
        } catch (Exception $e) {}
        
        try {
            $pdo->prepare("DELETE FROM photo_commercial_posts WHERE commercial_post_id = :commercial_id")->execute([':commercial_id' => $commercialId]);
        } catch (Exception $e) {}
        
        // Delete the commercial post
        $stmt = $pdo->prepare("DELETE FROM commercial_posts WHERE id = :commercial_id");
        $stmt->execute([':commercial_id' => $commercialId]);
        
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Платный пост успешно удален'
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении платного поста: ' . $e->getMessage()
    ]);
}
