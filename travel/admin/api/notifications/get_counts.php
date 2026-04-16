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
    
    // Получаем количество фото на модерации (статус pending или NULL)
    $pendingPhotos = 0;
    try {
        $pendingPhotosStmt = $pdo->query("
            SELECT COUNT(*) as count 
            FROM photos 
            WHERE moderation_status IS NULL OR moderation_status = 'pending'
        ");
        $pendingPhotos = $pendingPhotosStmt->fetch(PDO::FETCH_ASSOC)['count'];
    } catch (Exception $e) {
        // Колонка moderation_status может не существовать
        $pendingPhotos = 0;
    }
    
    // Получаем количество новых постов за последние 24 часа
    $newPosts = 0;
    try {
        $newPostsStmt = $pdo->query("
            SELECT COUNT(*) as count 
            FROM photos 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ");
        $newPosts = $newPostsStmt->fetch(PDO::FETCH_ASSOC)['count'];
    } catch (Exception $e) {
        $newPosts = 0;
    }
    
    // Получаем количество новых альбомов за последние 24 часа
    $newAlbums = 0;
    try {
        $newAlbumsStmt = $pdo->query("
            SELECT COUNT(*) as count 
            FROM albums 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ");
        $newAlbums = $newAlbumsStmt->fetch(PDO::FETCH_ASSOC)['count'];
    } catch (Exception $e) {
        $newAlbums = 0;
    }
    
    // Получаем количество новых платных постов за последние 24 часа
    $newCommercial = 0;
    try {
        $newCommercialStmt = $pdo->query("
            SELECT COUNT(*) as count 
            FROM commercial_posts 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ");
        $newCommercial = $newCommercialStmt->fetch(PDO::FETCH_ASSOC)['count'];
    } catch (Exception $e) {
        $newCommercial = 0;
    }
    
    // Получаем количество новых пользователей за последние 24 часа
    $newUsers = 0;
    try {
        $newUsersStmt = $pdo->query("
            SELECT COUNT(*) as count 
            FROM users 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ");
        $newUsers = $newUsersStmt->fetch(PDO::FETCH_ASSOC)['count'];
    } catch (Exception $e) {
        $newUsers = 0;
    }
    
    // Получаем количество новых комментариев за последние 24 часа
    $newComments = 0;
    try {
        $newCommentsStmt = $pdo->query("
            SELECT COUNT(*) as count 
            FROM comments 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ");
        $newComments = $newCommentsStmt->fetch(PDO::FETCH_ASSOC)['count'];
    } catch (Exception $e) {
        $newComments = 0;
    }
    
    // Общее количество новых элементов
    $totalNew = $pendingPhotos + $newPosts + $newAlbums + $newCommercial + $newUsers + $newComments;
    
    echo json_encode([
        'success' => true,
        'counts' => [
            'pendingPhotos' => intval($pendingPhotos),
            'newPosts' => intval($newPosts),
            'newAlbums' => intval($newAlbums),
            'newCommercial' => intval($newCommercial),
            'newUsers' => intval($newUsers),
            'newComments' => intval($newComments),
            'total' => intval($totalNew)
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении уведомлений: ' . $e->getMessage()
    ]);
}
