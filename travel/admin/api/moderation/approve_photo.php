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
    
    if (!isset($input['photoId'])) {
        throw new Exception('Photo ID is required');
    }
    
    $photoId = intval($input['photoId']);
    $adminId = $_SESSION['admin_id'];
    
    $pdo = connectToDatabase();
    
    // Check if photo exists
    $checkSql = "SELECT id, title FROM photos WHERE id = :photo_id";
    $checkStmt = $pdo->prepare($checkSql);
    $checkStmt->execute([':photo_id' => $photoId]);
    $photo = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photo) {
        throw new Exception('Photo not found');
    }
    
    // Update photo status to approved
    $sql = "UPDATE photos 
            SET moderation_status = 'approved',
                moderated_at = NOW(),
                moderated_by = :admin_id
            WHERE id = :photo_id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':photo_id' => $photoId,
        ':admin_id' => $adminId
    ]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Фотография одобрена'
    ]);
    
} catch (Exception $e) {
    error_log("Approve photo error: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
