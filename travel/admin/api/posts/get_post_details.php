<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    // Валидация параметра photo_id
    $photoId = validateInt(getParam('photo_id'), 1);
    
    if ($photoId === false) {
        adminHandleError('Неверный ID поста', 400, 'INVALID_PARAMETERS');
    }
    
    // Получаем информацию о посте
    $sql = "SELECT 
                p.id,
                p.title,
                p.description,
                p.file_path,
                p.created_at,
                p.user_id,
                CONCAT(u.first_name, ' ', u.last_name) as author_name,
                u.email as author_email,
                u.profile_image_url as author_image,
                p.location_id,
                (SELECT COUNT(*) FROM likes WHERE photo_id = p.id) as likes_count,
                (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comments_count,
                (SELECT COUNT(*) FROM favorites WHERE photo_id = p.id) as favorites_count
            FROM photos p
            INNER JOIN users u ON p.user_id = u.id
            WHERE p.id = :photo_id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':photo_id' => $photoId]);
    $post = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$post) {
        throw new Exception('Пост не найден');
    }
    
    // Пытаемся получить название локации
    $locationName = null;
    if ($post['location_id']) {
        try {
            // Пробуем разные варианты названия поля
            $locStmt = $pdo->prepare("SELECT * FROM locations WHERE id = :location_id LIMIT 1");
            $locStmt->execute([':location_id' => $post['location_id']]);
            $location = $locStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($location) {
                // Ищем поле с названием
                $locationName = $location['title'] ?? $location['name'] ?? $location['location_name'] ?? null;
            }
        } catch (Exception $e) {
            // Игнорируем ошибки с локацией
        }
    }
    
    // Получаем список пользователей, которые поставили лайк
    $likesStmt = $pdo->prepare("
        SELECT 
            u.id,
            CONCAT(u.first_name, ' ', u.last_name) as name,
            u.profile_image_url as image,
            l.created_at
        FROM likes l
        INNER JOIN users u ON l.user_id = u.id
        WHERE l.photo_id = :photo_id
        ORDER BY l.created_at DESC
        LIMIT 50
    ");
    $likesStmt->execute([':photo_id' => $photoId]);
    $likes = $likesStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Нормализуем изображения
    foreach ($likes as &$like) {
        $like['image'] = normalizeImageUrl($like['image']);
    }
    unset($like); // Освобождаем ссылку
    
    // Получаем список комментариев
    $commentsStmt = $pdo->prepare("
        SELECT 
            c.id,
            c.comment as text,
            c.created_at,
            u.id as user_id,
            CONCAT(u.first_name, ' ', u.last_name) as user_name,
            u.profile_image_url as user_image
        FROM comments c
        INNER JOIN users u ON c.user_id = u.id
        WHERE c.photo_id = :photo_id
        ORDER BY c.created_at DESC
        LIMIT 50
    ");
    $commentsStmt->execute([':photo_id' => $photoId]);
    $comments = $commentsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Нормализуем изображения
    foreach ($comments as &$comment) {
        $comment['user_image'] = normalizeImageUrl($comment['user_image']);
    }
    unset($comment); // Освобождаем ссылку
    
    // Форматируем ответ
    $response = [
        'success' => true,
        'post' => [
            'id' => intval($post['id']),
            'title' => $post['title'],
            'description' => $post['description'],
            'filePath' => normalizeImageUrl($post['file_path']),
            'createdAt' => $post['created_at'],
            'authorId' => intval($post['user_id']),
            'authorName' => $post['author_name'],
            'authorEmail' => $post['author_email'],
            'authorImage' => normalizeImageUrl($post['author_image']),
            'locationName' => $locationName,
            'likesCount' => intval($post['likes_count']),
            'commentsCount' => intval($post['comments_count']),
            'favoritesCount' => intval($post['favorites_count'])
        ],
        'likes' => $likes,
        'comments' => $comments
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
        'errorCode' => 'DATABASE_ERROR'
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'errorCode' => 'SERVER_ERROR',
        'trace' => $e->getTraceAsString()
    ], JSON_UNESCAPED_UNICODE);
}
