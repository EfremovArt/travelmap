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
    
    $albumId = isset($_GET['album_id']) ? intval($_GET['album_id']) : 0;
    
    if (!$albumId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID альбома'
        ]);
        exit;
    }
    
    // Get album info
    $albumSql = "SELECT 
                    a.id,
                    a.title,
                    a.description,
                    a.owner_id,
                    CONCAT(u.first_name, ' ', u.last_name) as owner_name,
                    a.is_public,
                    a.created_at
                 FROM albums a
                 LEFT JOIN users u ON a.owner_id = u.id
                 WHERE a.id = :album_id";
    
    $albumStmt = $pdo->prepare($albumSql);
    $albumStmt->execute([':album_id' => $albumId]);
    $album = $albumStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$album) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Альбом не найден'
        ]);
        exit;
    }
    
    // Get album photos
    $photosSql = "SELECT 
                    ap.id as album_photo_id,
                    ap.album_id,
                    ap.photo_id,
                    p.file_path,
                    p.title,
                    p.description,
                    ap.position,
                    ap.created_at as added_at,
                    p.created_at as photo_created_at,
                    p.location_id,
                    l.title as location_name,
                    l.latitude,
                    l.longitude
                  FROM album_photos ap
                  INNER JOIN photos p ON ap.photo_id = p.id
                  LEFT JOIN locations l ON p.location_id = l.id
                  WHERE ap.album_id = :album_id
                  ORDER BY ap.position ASC, ap.created_at ASC";
    
    $photosStmt = $pdo->prepare($photosSql);
    $photosStmt->execute([':album_id' => $albumId]);
    $photos = $photosStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Normalize image URLs
    foreach ($photos as &$photo) {
        $photo['file_path'] = $photo['file_path'] ? normalizeImageUrl($photo['file_path']) : null;
    }
    unset($photo);
    
    // Получаем все ID фотографий альбома
    $photoIds = array_column($photos, 'photo_id');
    
    $likes = [];
    $comments = [];
    
    if (!empty($photoIds)) {
        // Получаем лайки для всех фотографий альбома
        $placeholders = str_repeat('?,', count($photoIds) - 1) . '?';
        $likesStmt = $pdo->prepare("
            SELECT 
                l.photo_id,
                u.id,
                CONCAT(u.first_name, ' ', u.last_name) as name,
                u.profile_image_url as image,
                l.created_at
            FROM likes l
            INNER JOIN users u ON l.user_id = u.id
            WHERE l.photo_id IN ($placeholders)
            ORDER BY l.created_at DESC
        ");
        $likesStmt->execute($photoIds);
        $likesData = $likesStmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Группируем лайки по photo_id
        foreach ($likesData as $like) {
            $like['image'] = normalizeImageUrl($like['image']);
            $likes[$like['photo_id']][] = $like;
        }
        
        // Получаем комментарии для всех фотографий альбома
        $commentsStmt = $pdo->prepare("
            SELECT 
                c.photo_id,
                c.id,
                c.comment as text,
                c.created_at,
                u.id as user_id,
                CONCAT(u.first_name, ' ', u.last_name) as user_name,
                u.profile_image_url as user_image
            FROM comments c
            INNER JOIN users u ON c.user_id = u.id
            WHERE c.photo_id IN ($placeholders)
            ORDER BY c.created_at DESC
        ");
        $commentsStmt->execute($photoIds);
        $commentsData = $commentsStmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Группируем комментарии по photo_id
        foreach ($commentsData as $comment) {
            $comment['user_image'] = normalizeImageUrl($comment['user_image']);
            $comments[$comment['photo_id']][] = $comment;
        }
    }
    
    echo json_encode([
        'success' => true,
        'album' => $album,
        'photos' => $photos,
        'likes' => $likes,
        'comments' => $comments
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении фотографий альбома: ' . $e->getMessage()
    ]);
}
