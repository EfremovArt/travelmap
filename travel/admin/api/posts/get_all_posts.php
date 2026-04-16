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
    $userSearch = isset($_GET['user_search']) ? trim($_GET['user_search']) : '';
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'asc' ? 'ASC' : 'DESC';
    
    $allowedSortFields = ['created_at', 'title', 'user_name', 'location_name', 'likes_count', 'comments_count'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    // Filter by specific user if user_id is provided
    if ($userId > 0) {
        $whereConditions[] = "p.user_id = :user_id";
        $params[':user_id'] = $userId;
    }
    
    if ($userSearch) {
        $searchValue = '%' . $userSearch . '%';
        $whereConditions[] = '(p.title LIKE :search1 OR p.description LIKE :search2 OR u.first_name LIKE :search3 OR u.last_name LIKE :search4 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search5)';
        $params[':search1'] = $searchValue;
        $params[':search2'] = $searchValue;
        $params[':search3'] = $searchValue;
        $params[':search4'] = $searchValue;
        $params[':search5'] = $searchValue;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total 
                 FROM photos p
                 LEFT JOIN users u ON p.user_id = u.id
                 LEFT JOIN locations l ON p.location_id = l.id
                 {$whereClause}";
    
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get posts
    $sql = "SELECT 
                p.id,
                p.user_id,
                CONCAT(u.first_name, ' ', u.last_name) as user_name,
                u.email as user_email,
                u.profile_image_url as user_profile_image,
                p.location_id,
                l.title as location_name,
                l.latitude,
                l.longitude,
                p.title,
                p.description,
                p.file_path as preview,
                p.created_at,
                (SELECT COUNT(*) FROM likes WHERE photo_id = p.id) as likes_count,
                (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comments_count
            FROM photos p
            LEFT JOIN users u ON p.user_id = u.id
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
    
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Normalize image URLs
    foreach ($posts as &$post) {
        $post['user_profile_image'] = $post['user_profile_image'] ? normalizeImageUrl($post['user_profile_image']) : null;
        $post['preview'] = $post['preview'] ? normalizeImageUrl($post['preview']) : null;
    }
    
    echo json_encode([
        'success' => true,
        'posts' => $posts,
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
        'message' => 'Ошибка при получении постов: ' . $e->getMessage()
    ]);
}
