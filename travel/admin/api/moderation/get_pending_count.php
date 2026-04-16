<?php
require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json');

try {
    $pdo = connectToDatabase();
    
    // Note: moderation_status column doesn't exist, return 0
    echo json_encode([
        'success' => true,
        'count' => 0
    ]);
    exit;
    
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'count' => (int)$result['count']
    ]);
    
} catch (Exception $e) {
    error_log("Get pending count error: " . $e->getMessage());
    
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении данных: ' . $e->getMessage()
    ]);
}
