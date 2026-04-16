<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    // Подключение к базе данных
    $pdo = connectToDatabase();
    
    if (!$pdo) {
        throw new Exception('Не удалось подключиться к базе данных');
    }
    
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $offset = ($page - 1) * $perPage;
    
    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
    $userSearch = isset($_GET['user_search']) ? trim($_GET['user_search']) : '';
    $type = isset($_GET['type']) ? trim($_GET['type']) : '';
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'asc' ? 'ASC' : 'DESC';
    
    $allowedSortFields = ['created_at', 'title', 'user_name', 'type', 'is_active'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    // Filter by specific user if user_id is provided
    if ($userId > 0) {
        $whereConditions[] = "cp.user_id = :user_id";
        $params[':user_id'] = $userId;
    }
    
    if ($type && in_array($type, ['album', 'photo', 'standalone'])) {
        $whereConditions[] = "cp.type = :type";
        $params[':type'] = $type;
    }
    
    if ($userSearch) {
        $searchValue = '%' . $userSearch . '%';
        $whereConditions[] = '(cp.title LIKE :search1 OR cp.description LIKE :search2 OR u.first_name LIKE :search3 OR u.last_name LIKE :search4 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search5)';
        $params[':search1'] = $searchValue;
        $params[':search2'] = $searchValue;
        $params[':search3'] = $searchValue;
        $params[':search4'] = $searchValue;
        $params[':search5'] = $searchValue;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total 
                 FROM commercial_posts cp
                 LEFT JOIN users u ON cp.user_id = u.id
                 {$whereClause}";
    
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get commercial posts
    $sql = "SELECT 
                cp.id,
                cp.user_id,
                CONCAT(u.first_name, ' ', u.last_name) as user_name,
                u.email as user_email,
                u.profile_image_url as user_profile_image,
                cp.type,
                cp.album_id,
                cp.photo_id,
                cp.title,
                cp.description,
                COALESCE(
                    cp.image_url,
                    CASE 
                        WHEN cp.type = 'photo' THEN p.file_path
                        WHEN cp.type = 'album' THEN (
                            SELECT ph.file_path 
                            FROM album_photos ap 
                            INNER JOIN photos ph ON ap.photo_id = ph.id 
                            WHERE ap.album_id = cp.album_id 
                            ORDER BY ap.position ASC, ap.created_at ASC 
                            LIMIT 1
                        )
                        ELSE NULL
                    END
                ) as preview,
                cp.latitude,
                cp.longitude,
                cp.is_active,
                cp.created_at,
                CASE 
                    WHEN cp.type = 'album' THEN a.title
                    WHEN cp.type = 'photo' THEN p.title
                    ELSE NULL
                END as related_title,
                COALESCE(
                    cp.location_name,
                    CASE 
                        WHEN cp.type = 'photo' AND p.location_id IS NOT NULL THEN l.title
                        ELSE NULL
                    END
                ) as location_name
            FROM commercial_posts cp
            LEFT JOIN users u ON cp.user_id = u.id
            LEFT JOIN albums a ON cp.album_id = a.id
            LEFT JOIN photos p ON cp.photo_id = p.id
            LEFT JOIN locations l ON p.location_id = l.id
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
    
    $commercialPosts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Normalize image URLs
    foreach ($commercialPosts as &$post) {
        $post['user_profile_image'] = $post['user_profile_image'] ? normalizeImageUrl($post['user_profile_image']) : null;
        $post['preview'] = $post['preview'] ? normalizeImageUrl($post['preview']) : null;
    }
    
    echo json_encode([
        'success' => true,
        'commercialPosts' => $commercialPosts,
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
        'message' => 'Ошибка при получении коммерческих постов: ' . $e->getMessage()
    ]);
}
