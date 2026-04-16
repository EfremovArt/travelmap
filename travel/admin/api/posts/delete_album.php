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
    
    $albumId = isset($_POST['album_id']) ? intval($_POST['album_id']) : 0;
    
    if (!$albumId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID альбома'
        ]);
        exit;
    }
    
    // Start transaction
    $pdo->beginTransaction();
    
    try {
        // Delete related data
        $pdo->prepare("DELETE FROM album_likes WHERE album_id = :album_id")->execute([':album_id' => $albumId]);
        $pdo->prepare("DELETE FROM album_comments WHERE album_id = :album_id")->execute([':album_id' => $albumId]);
        $pdo->prepare("DELETE FROM album_favorites WHERE album_id = :album_id")->execute([':album_id' => $albumId]);
        $pdo->prepare("DELETE FROM album_photos WHERE album_id = :album_id")->execute([':album_id' => $albumId]);
        
        // Delete the album
        $stmt = $pdo->prepare("DELETE FROM albums WHERE id = :album_id");
        $stmt->execute([':album_id' => $albumId]);
        
        $pdo->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Альбом успешно удален'
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении альбома: ' . $e->getMessage()
    ]);
}
