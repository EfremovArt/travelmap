<?php
require_once '../config.php';

// Инициализация API и подключение к базе данных
initApi();
$pdo = connectToDatabase();

// Проверяем метод запроса
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['message' => 'Method not allowed']);
    exit;
}

// Проверяем авторизацию
try {
    $userId = requireAuth();
    error_log("User authenticated for cover deletion: $userId");
} catch (Exception $e) {
    error_log("Authentication failed for cover deletion: " . $e->getMessage());
    http_response_code(401);
    echo json_encode(['message' => 'Authentication required']);
    exit;
}

// Получаем данные из тела запроса
$input = json_decode(file_get_contents('php://input'), true);

if (!isset($input['cover_id']) || empty($input['cover_id'])) {
    http_response_code(400);
    echo json_encode(['message' => 'Cover ID is required']);
    exit;
}

$coverId = intval($input['cover_id']);
error_log("Attempting to delete cover with photo ID: $coverId");

try {
    // Находим обложку в таблице photos (теперь обложки сохраняются там)
    // Проверяем, что это действительно обложка альбома (location_id = NULL и title содержит "Album Cover")
    $stmt = $pdo->prepare("
        SELECT file_path FROM photos 
        WHERE id = ? AND user_id = ? AND location_id IS NULL AND title LIKE '%Album Cover%'
    ");
    $stmt->execute([$coverId, $userId]);
    $cover = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$cover) {
        error_log("Cover not found or access denied for ID: $coverId, user: $userId");
        http_response_code(404);
        echo json_encode(['message' => 'Cover not found or access denied']);
        exit;
    }
    
    error_log("Found cover file: " . $cover['file_path']);
    
    // Удаляем файл с диска
    $filePath = __DIR__ . '/..' . $cover['file_path'];
    if (file_exists($filePath)) {
        unlink($filePath);
        error_log("Deleted cover file: $filePath");
    } else {
        error_log("Cover file not found on disk: $filePath");
    }
    
    // Удаляем запись из базы данных photos
    $stmt = $pdo->prepare("DELETE FROM photos WHERE id = ? AND user_id = ? AND location_id IS NULL AND title LIKE '%Album Cover%'");
    $stmt->execute([$coverId, $userId]);
    
    if ($stmt->rowCount() > 0) {
        error_log("Cover deleted successfully from database");
        echo json_encode([
            'success' => true,
            'message' => 'Album cover deleted successfully'
        ]);
    } else {
        error_log("No cover was deleted from database");
        http_response_code(404);
        echo json_encode(['message' => 'Cover not found']);
    }
    
} catch (Exception $e) {
    error_log("Album cover deletion error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo json_encode(['message' => 'Error deleting album cover: ' . $e->getMessage()]);
}
?>
