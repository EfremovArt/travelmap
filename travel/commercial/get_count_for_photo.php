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
    $photoId = $_GET['photo_id'] ?? null;
    
    if (!$photoId) {
        echo json_encode(['success' => false, 'message' => 'Photo ID is required']);
        exit;
    }
    
    // Сначала получаем локацию фото
    $locationStmt = $pdo->prepare("
        SELECT location_id 
        FROM photos 
        WHERE id = ?
    ");
    $locationStmt->execute([$photoId]);
    $photoData = $locationStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photoData) {
        echo json_encode(['success' => false, 'message' => 'Photo not found']);
        exit;
    }
    
    $locationId = $photoData['location_id'];
    
    // Если у фото нет локации, считаем только посты привязанные к этому фото
    if (!$locationId) {
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as count
            FROM commercial_posts cp
            INNER JOIN commercial_post_photos cpp ON cp.id = cpp.commercial_post_id
            WHERE cpp.photo_id = ? AND cp.is_active = 1
        ");
        $stmt->execute([$photoId]);
    } else {
        // Получаем название локации
        $locationInfoStmt = $pdo->prepare("
            SELECT title
            FROM locations
            WHERE id = ?
        ");
        $locationInfoStmt->execute([$locationId]);
        $locationInfo = $locationInfoStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$locationInfo) {
            echo json_encode(['success' => false, 'message' => 'Location not found']);
            exit;
        }
        
        // Считаем коммерческие посты для этой локации
        // Ищем двумя способами, как и в get_posts_for_photo.php
        $stmt = $pdo->prepare("
            SELECT COUNT(DISTINCT cp.id) as count
            FROM commercial_posts cp
            LEFT JOIN commercial_post_photos cpp ON cp.id = cpp.commercial_post_id
            LEFT JOIN photos p ON cpp.photo_id = p.id
            WHERE (
                (cp.location_name = ? AND cp.location_name IS NOT NULL AND cp.location_name != '')
                OR (p.location_id = ?)
            ) AND cp.is_active = 1
        ");
        $stmt->execute([$locationInfo['title'], $locationId]);
    }
    
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    $count = (int)$result['count'];
    
    echo json_encode([
        'success' => true,
        'count' => $count
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_count_for_photo.php: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Server error']);
}
?>
