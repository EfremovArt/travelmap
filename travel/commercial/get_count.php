<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config.php';

// Подключаемся к базе данных
$pdo = connectToDatabase();

try {
    $albumId = $_GET['album_id'] ?? null;
    
    if (!$albumId) {
        echo json_encode(['success' => false, 'message' => 'Album ID is required']);
        exit;
    }
    
    // Получаем количество коммерческих постов для альбома через таблицу связей
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count
        FROM commercial_posts cp
        INNER JOIN commercial_post_albums cpa ON cp.id = cpa.commercial_post_id
        WHERE cpa.album_id = ? AND cp.is_active = 1
    ");
    
    $stmt->execute([$albumId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $count = (int)$result['count'];
    
    echo json_encode([
        'success' => true,
        'count' => $count
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_count.php: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Server error']);
}
?>
