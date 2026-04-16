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
    
    $postId = isset($_POST['post_id']) ? intval($_POST['post_id']) : 0;
    
    if (!$postId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID поста'
        ]);
        exit;
    }
    
    // Start transaction
    $pdo->beginTransaction();
    
    try {
        // Delete related data
        $pdo->prepare("DELETE FROM likes WHERE photo_id = :post_id")->execute([':post_id' => $postId]);
        $pdo->prepare("DELETE FROM comments WHERE photo_id = :post_id")->execute([':post_id' => $postId]);
        $pdo->prepare("DELETE FROM favorites WHERE photo_id = :post_id")->execute([':post_id' => $postId]);
        $pdo->prepare("DELETE FROM album_photos WHERE photo_id = :post_id")->execute([':post_id' => $postId]);
        
        // Delete the post
        $stmt = $pdo->prepare("DELETE FROM photos WHERE id = :post_id");
        $stmt->execute([':post_id' => $postId]);
        
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Пост успешно удален'
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении поста: ' . $e->getMessage()
    ]);
}
