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
    // Проверяем, существует ли уже альбом с id = 0
    $checkStmt = $pdo->prepare("SELECT COUNT(*) as album_exists FROM albums WHERE id = 0");
    $checkStmt->execute();
    $result = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result['album_exists'] > 0) {
        echo json_encode([
            'success' => true,
            'message' => 'System album already exists',
            'album_id' => 0
        ]);
        exit;
    }
    
    // Получаем первого пользователя для назначения владельцем системного альбома
    $userStmt = $pdo->prepare("SELECT id FROM users ORDER BY id ASC LIMIT 1");
    $userStmt->execute();
    $firstUser = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$firstUser) {
        echo json_encode([
            'success' => false,
            'message' => 'No users found in the system. Please create a user first.'
        ]);
        exit;
    }
    
    $ownerId = $firstUser['id'];
    
    // Создаем системный альбом
    $insertStmt = $pdo->prepare("
        INSERT INTO albums (
            id, 
            title, 
            description, 
            owner_id, 
            is_public, 
            created_at, 
            updated_at
        ) VALUES (
            0,
            'System Album for Standalone Commercial Posts',
            'This is a system album used for commercial posts that are not associated with any specific user album',
            ?,
            0,
            NOW(),
            NOW()
        )
    ");
    
    $success = $insertStmt->execute([$ownerId]);
    
    if ($success) {
        echo json_encode([
            'success' => true,
            'message' => 'System album created successfully',
            'album_id' => 0,
            'owner_id' => $ownerId
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to create system album'
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}
?>
