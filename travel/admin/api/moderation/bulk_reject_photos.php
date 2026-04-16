<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

// Verify CSRF token
verifyCsrfToken();

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['photoIds']) || !is_array($input['photoIds'])) {
        throw new Exception('Photo IDs array is required');
    }
    
    $photoIds = array_map('intval', $input['photoIds']);
    
    if (empty($photoIds)) {
        throw new Exception('No photos selected');
    }
    
    $adminId = $_SESSION['admin_id'];
    $pdo = connectToDatabase();
    
    // Build placeholders for IN clause
    $placeholders = implode(',', array_fill(0, count($photoIds), '?'));
    
    // Update photos status to rejected
    $sql = "UPDATE photo 
            SET moderation_status = 'rejected',
                moderated_at = NOW(),
                moderated_by = ?
            WHERE id IN ($placeholders)";
    
    $stmt = $pdo->prepare($sql);
    $params = array_merge([$adminId], $photoIds);
    $stmt->execute($params);
    
    $affectedRows = $stmt->rowCount();
    
    echo json_encode([
        'success' => true,
        'message' => "Отклонено фотографий: $affectedRows"
    ]);
    
} catch (Exception $e) {
    error_log("Bulk reject photos error: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
