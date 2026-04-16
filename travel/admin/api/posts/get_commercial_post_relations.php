<?php
// Устанавливаем обработчик ошибок для перехвата всех ошибок
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
});

error_reporting(E_ALL);
ini_set('display_errors', 0);

// Очищаем буфер вывода, чтобы избежать случайного вывода HTML
ob_start();

try {
    require_once '../../config/admin_config.php';
    require_once '../../../config.php';
    
    adminRequireAuth();
    
    // Очищаем любой вывод, который мог произойти
    ob_clean();
    
    header('Content-Type: application/json; charset=UTF-8');
    $pdo = connectToDatabase();
    
    if (!$pdo) {
        throw new Exception('Не удалось подключиться к базе данных');
    }
    
    $commercialPostId = isset($_GET['commercial_post_id']) ? intval($_GET['commercial_post_id']) : 0;
    
    if (!$commercialPostId) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Не указан ID коммерческого поста'
        ]);
        exit;
    }
    
    // Get commercial post info
    $cpSql = "SELECT 
                cp.id,
                cp.title,
                cp.description,
                cp.type,
                cp.album_id,
                cp.photo_id,
                cp.user_id,
                cp.image_url,
                CONCAT(u.first_name, ' ', u.last_name) as user_name,
                cp.latitude,
                cp.longitude,
                cp.location_name,
                cp.is_active,
                cp.created_at
              FROM commercial_posts cp
              LEFT JOIN users u ON cp.user_id = u.id
              WHERE cp.id = :commercial_post_id";
    
    $cpStmt = $pdo->prepare($cpSql);
    $cpStmt->execute([':commercial_post_id' => $commercialPostId]);
    $commercialPost = $cpStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$commercialPost) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Коммерческий пост не найден'
        ]);
        exit;
    }
    
    // Normalize image_url if exists
    if ($commercialPost['image_url']) {
        $commercialPost['image_url'] = normalizeImageUrl($commercialPost['image_url']);
    }
    
    // If location_name is not set in commercial_posts, try to get it from related photo
    if (empty($commercialPost['location_name']) && $commercialPost['type'] == 'photo' && $commercialPost['photo_id']) {
        $locSql = "SELECT l.title FROM photos p 
                   LEFT JOIN locations l ON p.location_id = l.id 
                   WHERE p.id = :photo_id AND l.id IS NOT NULL";
        $locStmt = $pdo->prepare($locSql);
        $locStmt->execute([':photo_id' => $commercialPost['photo_id']]);
        $locResult = $locStmt->fetch(PDO::FETCH_ASSOC);
        if ($locResult) {
            $commercialPost['location_name'] = $locResult['title'];
        }
    }
    
    $relatedAlbums = [];
    $relatedPhotos = [];
    
    // Get related albums if type is 'album'
    if ($commercialPost['type'] === 'album' && $commercialPost['album_id']) {
        $albumSql = "SELECT 
                        a.id,
                        a.title,
                        a.description,
                        (SELECT p.file_path 
                         FROM album_photos ap 
                         INNER JOIN photos p ON ap.photo_id = p.id 
                         WHERE ap.album_id = a.id 
                         ORDER BY ap.position ASC, ap.created_at ASC 
                         LIMIT 1) as cover_photo,
                        (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) as photos_count
                     FROM albums a
                     WHERE a.id = :album_id";
        
        $albumStmt = $pdo->prepare($albumSql);
        $albumStmt->execute([':album_id' => $commercialPost['album_id']]);
        $album = $albumStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($album) {
            $album['cover_photo'] = $album['cover_photo'] ? normalizeImageUrl($album['cover_photo']) : null;
            $relatedAlbums[] = $album;
            
            // Get photos in the album
            $albumPhotosSql = "SELECT 
                                ap.id,
                                ap.photo_id,
                                p.title,
                                p.file_path as preview,
                                p.location_id,
                                l.title as location_name
                               FROM album_photos ap
                               INNER JOIN photos p ON ap.photo_id = p.id
                               LEFT JOIN locations l ON p.location_id = l.id
                               WHERE ap.album_id = :album_id
                               ORDER BY ap.position ASC, ap.created_at ASC";
            
            $albumPhotosStmt = $pdo->prepare($albumPhotosSql);
            $albumPhotosStmt->execute([':album_id' => $commercialPost['album_id']]);
            $relatedPhotos = $albumPhotosStmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Normalize image URLs
            foreach ($relatedPhotos as &$photo) {
                $photo['preview'] = $photo['preview'] ? normalizeImageUrl($photo['preview']) : null;
            }
        }
    }
    
    // Get related photo if type is 'photo'
    if ($commercialPost['type'] === 'photo' && $commercialPost['photo_id']) {
        $photoSql = "SELECT 
                        p.id,
                        p.title,
                        p.description,
                        p.file_path as preview,
                        p.location_id,
                        l.title as location_name,
                        l.latitude,
                        l.longitude
                     FROM photos p
                     LEFT JOIN locations l ON p.location_id = l.id
                     WHERE p.id = :photo_id";
        
        $photoStmt = $pdo->prepare($photoSql);
        $photoStmt->execute([':photo_id' => $commercialPost['photo_id']]);
        $photo = $photoStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($photo) {
            $photo['preview'] = $photo['preview'] ? normalizeImageUrl($photo['preview']) : null;
            $relatedPhotos[] = $photo;
        }
    }
    
    // Get all photos where this commercial post is displayed
    $displayedInPhotos = [];
    
    // Проверяем, существует ли таблица (для обратной совместимости)
    try {
        $displayedInSql = "SELECT 
                            p.id,
                            p.title,
                            p.file_path as preview,
                            p.location_id,
                            l.title as location_name
                           FROM photo_commercial_posts pcp
                           INNER JOIN photos p ON pcp.photo_id = p.id
                           LEFT JOIN locations l ON p.location_id = l.id
                           WHERE pcp.commercial_post_id = :commercial_post_id
                           AND pcp.is_active = 1
                           ORDER BY pcp.position ASC, pcp.created_at DESC";
        
        $displayedInStmt = $pdo->prepare($displayedInSql);
        $displayedInStmt->execute([':commercial_post_id' => $commercialPostId]);
        $displayedInPhotos = $displayedInStmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Normalize image URLs
        foreach ($displayedInPhotos as &$photo) {
            $photo['preview'] = $photo['preview'] ? normalizeImageUrl($photo['preview']) : null;
        }
    } catch (PDOException $e) {
        // Таблица может не существовать - это нормально для старых установок
        $displayedInPhotos = [];
    }
    
    // Очищаем буфер и отправляем JSON
    ob_clean();
    echo json_encode([
        'success' => true,
        'commercialPost' => $commercialPost,
        'relatedAlbums' => $relatedAlbums,
        'relatedPhotos' => $relatedPhotos,
        'displayedInPhotos' => $displayedInPhotos
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    
} catch (Exception $e) {
    ob_clean();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении связей коммерческого поста: ' . $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    ob_end_flush();
    exit;
}

// Завершаем буферизацию
ob_end_flush();

// Восстанавливаем обработчик ошибок
restore_error_handler();
