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
    
    $adminId = $_SESSION['admin_id'];
    
    // Получаем время начала текущего сеанса просмотра из параметров запроса
    // Если параметр передан, используем его вместо last_viewed_at
    $photosSessionStart = isset($_GET['photos_session_start']) ? $_GET['photos_session_start'] : null;
    $commentsSessionStart = isset($_GET['comments_session_start']) ? $_GET['comments_session_start'] : null;
    
    // Получаем последний просмотр фото (используется только если нет активного сеанса)
    $lastPhotoView = null;
    if (!$photosSessionStart) {
        try {
            $stmt = $pdo->prepare("SELECT last_viewed_at FROM admin_views WHERE admin_id = :admin_id AND view_type = 'photos'");
            $stmt->execute([':admin_id' => $adminId]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($result) {
                $lastPhotoView = $result['last_viewed_at'];
            }
        } catch (Exception $e) {
            // Таблица может не существовать
        }
    }
    
    // Получаем последний просмотр комментариев (используется только если нет активного сеанса)
    $lastCommentView = null;
    if (!$commentsSessionStart) {
        try {
            $stmt = $pdo->prepare("SELECT last_viewed_at FROM admin_views WHERE admin_id = :admin_id AND view_type = 'comments'");
            $stmt->execute([':admin_id' => $adminId]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($result) {
                $lastCommentView = $result['last_viewed_at'];
            }
        } catch (Exception $e) {
            // Таблица может не существовать
        }
    }
    
    // Считаем новые фото
    $newPhotosCount = 0;
    try {
        // Если есть активный сеанс просмотра, считаем элементы после начала сеанса
        if ($photosSessionStart) {
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as count 
                FROM photos 
                WHERE created_at > :session_start
            ");
            $stmt->execute([':session_start' => $photosSessionStart]);
            $newPhotosCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } elseif ($lastPhotoView) {
            // Если нет активного сеанса, но есть last_viewed_at
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as count 
                FROM photos 
                WHERE created_at > :last_view
            ");
            $stmt->execute([':last_view' => $lastPhotoView]);
            $newPhotosCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } else {
            // Если никогда не просматривали, показываем последние 24 часа
            $stmt = $pdo->query("
                SELECT COUNT(*) as count 
                FROM photos 
                WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
            ");
            $newPhotosCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        }
    } catch (Exception $e) {
        error_log("Error counting new photos: " . $e->getMessage());
        $newPhotosCount = 0;
    }
    
    // Считаем новые комментарии - к фото и альбомам
    $newCommentsCount = 0;
    try {
        // Если есть активный сеанс просмотра, считаем элементы после начала сеанса
        if ($commentsSessionStart) {
            // Считаем комментарии к фото
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as count 
                FROM comments 
                WHERE created_at > :session_start
            ");
            $stmt->execute([':session_start' => $commentsSessionStart]);
            $photoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            
            // Считаем комментарии к альбомам
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as count 
                FROM album_comments 
                WHERE created_at > :session_start
            ");
            $stmt->execute([':session_start' => $commentsSessionStart]);
            $albumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            
            $newCommentsCount = $photoComments + $albumComments;
        } elseif ($lastCommentView) {
            // Если нет активного сеанса, но есть last_viewed_at
            // Считаем комментарии к фото
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as count 
                FROM comments 
                WHERE created_at > :last_view
            ");
            $stmt->execute([':last_view' => $lastCommentView]);
            $photoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            
            // Считаем комментарии к альбомам
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as count 
                FROM album_comments 
                WHERE created_at > :last_view
            ");
            $stmt->execute([':last_view' => $lastCommentView]);
            $albumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            
            $newCommentsCount = $photoComments + $albumComments;
        } else {
            // Если никогда не просматривали, показываем последние 24 часа
            $stmt = $pdo->query("
                SELECT COUNT(*) as count 
                FROM comments 
                WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
            ");
            $photoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            
            $stmt = $pdo->query("
                SELECT COUNT(*) as count 
                FROM album_comments 
                WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
            ");
            $albumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            
            $newCommentsCount = $photoComments + $albumComments;
        }
    } catch (Exception $e) {
        error_log("Error counting new comments: " . $e->getMessage());
        $newCommentsCount = 0;
    }
    
    echo json_encode([
        'success' => true,
        'counts' => [
            'newPhotos' => intval($newPhotosCount),
            'newComments' => intval($newCommentsCount),
            'lastPhotoView' => $lastPhotoView,
            'lastCommentView' => $lastCommentView
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении счетчиков: ' . $e->getMessage()
    ]);
}
