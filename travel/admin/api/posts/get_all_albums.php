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
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $offset = ($page - 1) * $perPage;
    
    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
    $albumId = isset($_GET['album_id']) ? intval($_GET['album_id']) : 0;
    $userSearch = isset($_GET['user_search']) ? trim($_GET['user_search']) : '';
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'asc' ? 'ASC' : 'DESC';
    
    $allowedSortFields = ['created_at', 'title', 'owner_name', 'photos_count', 'likes_count', 'comments_count', 'favorites_count'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    // Filter by specific album if album_id is provided
    if ($albumId > 0) {
        $whereConditions[] = "a.id = :album_id";
        $params[':album_id'] = $albumId;
    }
    
    // Filter by specific user if user_id is provided
    if ($userId > 0) {
        $whereConditions[] = "a.owner_id = :user_id";
        $params[':user_id'] = $userId;
    }
    
    if ($userSearch) {
        $searchValue = '%' . $userSearch . '%';
        $whereConditions[] = '(a.title LIKE :search1 OR a.description LIKE :search2 OR u.first_name LIKE :search3 OR u.last_name LIKE :search4 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search5)';
        $params[':search1'] = $searchValue;
        $params[':search2'] = $searchValue;
        $params[':search3'] = $searchValue;
        $params[':search4'] = $searchValue;
        $params[':search5'] = $searchValue;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total 
                 FROM albums a
                 LEFT JOIN users u ON a.owner_id = u.id
                 {$whereClause}";
    
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get albums
    $sql = "SELECT 
                a.id,
                a.owner_id,
                CONCAT(u.first_name, ' ', u.last_name) as owner_name,
                u.email as owner_email,
                u.profile_image_url as owner_profile_image,
                a.title,
                a.description,
                a.cover_photo_id,
                (SELECT p.file_path 
                 FROM album_photos ap 
                 INNER JOIN photos p ON ap.photo_id = p.id 
                 WHERE ap.album_id = a.id 
                 ORDER BY ap.position ASC, ap.created_at ASC 
                 LIMIT 1) as cover_photo,
                a.is_public,
                a.created_at,
                (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) as photos_count,
                (SELECT COUNT(*) FROM album_likes WHERE album_id = a.id) as likes_count,
                (SELECT COUNT(*) FROM album_comments WHERE album_id = a.id) as comments_count,
                (SELECT COUNT(*) FROM album_favorites WHERE album_id = a.id) as favorites_count
            FROM albums a
            LEFT JOIN users u ON a.owner_id = u.id
            {$whereClause}
            ORDER BY {$sortBy} {$sortOrder}
            LIMIT :limit OFFSET :offset";
    
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $albums = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Normalize image URLs
    foreach ($albums as &$album) {
        $album['owner_profile_image'] = $album['owner_profile_image'] ? normalizeImageUrl($album['owner_profile_image']) : null;
        $album['cover_photo'] = $album['cover_photo'] ? normalizeImageUrl($album['cover_photo']) : null;
    }
    
    echo json_encode([
        'success' => true,
        'albums' => $albums,
        'pagination' => [
            'total' => intval($total),
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => ceil($total / $perPage)
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении альбомов: ' . $e->getMessage()
    ]);
}
