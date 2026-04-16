<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $offset = ($page - 1) * $perPage;
    
    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : null;
    $activityType = isset($_GET['type']) ? $_GET['type'] : 'all'; // all, like, comment, favorite
    
    $activities = [];
    
    // Получаем лайки
    if ($activityType === 'all' || $activityType === 'like') {
        $likesSql = "SELECT 
                        'like' as activity_type,
                        l.id as activity_id,
                        l.created_at,
                        l.user_id as actor_id,
                        CONCAT(u.first_name, ' ', u.last_name) as actor_name,
                        u.profile_image_url as actor_image,
                        l.photo_id as target_id,
                        'photo' as target_type,
                        p.title as target_title,
                        p.file_path as target_image,
                        p.user_id as target_owner_id,
                        CONCAT(owner.first_name, ' ', owner.last_name) as target_owner_name
                     FROM likes l
                     INNER JOIN users u ON l.user_id = u.id
                     INNER JOIN photos p ON l.photo_id = p.id
                     INNER JOIN users owner ON p.user_id = owner.id";
        
        if ($userId) {
            $likesSql .= " WHERE p.user_id = :user_id";
        }
        
        $likesStmt = $pdo->prepare($likesSql);
        if ($userId) {
            $likesStmt->execute([':user_id' => $userId]);
        } else {
            $likesStmt->execute();
        }
        $activities = array_merge($activities, $likesStmt->fetchAll(PDO::FETCH_ASSOC));
    }
    
    // Получаем комментарии
    if ($activityType === 'all' || $activityType === 'comment') {
        $commentsSql = "SELECT 
                           'comment' as activity_type,
                           c.id as activity_id,
                           c.created_at,
                           c.user_id as actor_id,
                           CONCAT(u.first_name, ' ', u.last_name) as actor_name,
                           u.profile_image_url as actor_image,
                           c.photo_id as target_id,
                           'photo' as target_type,
                           p.title as target_title,
                           p.file_path as target_image,
                           c.comment as comment_text,
                           p.user_id as target_owner_id,
                           CONCAT(owner.first_name, ' ', owner.last_name) as target_owner_name
                        FROM comments c
                        INNER JOIN users u ON c.user_id = u.id
                        INNER JOIN photos p ON c.photo_id = p.id
                        INNER JOIN users owner ON p.user_id = owner.id";
        
        if ($userId) {
            $commentsSql .= " WHERE p.user_id = :user_id";
        }
        
        $commentsStmt = $pdo->prepare($commentsSql);
        if ($userId) {
            $commentsStmt->execute([':user_id' => $userId]);
        } else {
            $commentsStmt->execute();
        }
        $activities = array_merge($activities, $commentsStmt->fetchAll(PDO::FETCH_ASSOC));
    }
    
    // Получаем избранное
    if ($activityType === 'all' || $activityType === 'favorite') {
        $favoritesSql = "SELECT 
                            'favorite' as activity_type,
                            f.id as activity_id,
                            f.created_at,
                            f.user_id as actor_id,
                            CONCAT(u.first_name, ' ', u.last_name) as actor_name,
                            u.profile_image_url as actor_image,
                            f.photo_id as target_id,
                            'photo' as target_type,
                            p.title as target_title,
                            p.file_path as target_image,
                            p.user_id as target_owner_id,
                            CONCAT(owner.first_name, ' ', owner.last_name) as target_owner_name
                         FROM favorites f
                         INNER JOIN users u ON f.user_id = u.id
                         INNER JOIN photos p ON f.photo_id = p.id
                         INNER JOIN users owner ON p.user_id = owner.id";
        
        if ($userId) {
            $favoritesSql .= " WHERE p.user_id = :user_id";
        }
        
        $favoritesStmt = $pdo->prepare($favoritesSql);
        if ($userId) {
            $favoritesStmt->execute([':user_id' => $userId]);
        } else {
            $favoritesStmt->execute();
        }
        $activities = array_merge($activities, $favoritesStmt->fetchAll(PDO::FETCH_ASSOC));
    }
    
    // Сортируем по дате (новые сверху)
    usort($activities, function($a, $b) {
        return strtotime($b['created_at']) - strtotime($a['created_at']);
    });
    
    // Применяем пагинацию
    $total = count($activities);
    $activities = array_slice($activities, $offset, $perPage);
    
    // Нормализуем изображения и фильтруем temp_photo
    foreach ($activities as &$activity) {
        $activity['actor_image'] = normalizeImageUrl($activity['actor_image']);
        $activity['target_image'] = normalizeImageUrl($activity['target_image']);
        
        // Фильтруем temp_photo.jpg
        if (strpos($activity['actor_image'], 'temp_photo') !== false) {
            $activity['actor_image'] = null;
        }
        if (strpos($activity['target_image'], 'temp_photo') !== false) {
            $activity['target_image'] = null;
        }
    }
    unset($activity);
    
    $lastPage = ceil($total / $perPage);
    
    echo json_encode([
        'success' => true,
        'activities' => $activities,
        'pagination' => [
            'total' => $total,
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => $lastPage
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении ленты активности: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
