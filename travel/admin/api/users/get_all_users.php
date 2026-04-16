<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    // Валидация и получение параметров
    $page = validateInt(getParam('page', 1, 'int'), 1);
    $perPage = validateInt(getParam('per_page', 50, 'int'), 1, 10000);
    $search = validateString(getParam('search', '', 'string'), 0, 255);
    $sortBy = getParam('sort_by', 'created_at', 'string');
    $sortOrder = strtoupper(getParam('sort_order', 'DESC', 'string'));
    
    // Валидация параметров
    if ($page === false || $perPage === false) {
        adminHandleError('Неверные параметры пагинации', 400, 'INVALID_PARAMETERS');
    }
    
    if ($search === false) {
        $search = '';
    }
    
    // Валидация поля сортировки
    $allowedSortFields = ['id', 'first_name', 'last_name', 'email', 'created_at', 'followers_count', 'following_count', 'posts_count'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    // Валидация порядка сортировки
    if (!in_array($sortOrder, ['ASC', 'DESC'])) {
        $sortOrder = 'DESC';
    }
    
    $offset = ($page - 1) * $perPage;
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    // Trim search and check if not empty
    $search = trim($search);
    if (!empty($search) && strlen($search) > 0) {
        $searchValue = "%{$search}%";
        $whereConditions[] = "(
            u.first_name LIKE :search1 
            OR u.last_name LIKE :search2 
            OR u.email LIKE :search3 
            OR u.apple_id LIKE :search4
            OR CONCAT(u.first_name, ' ', u.last_name) LIKE :search5
        )";
        $params[':search1'] = $searchValue;
        $params[':search2'] = $searchValue;
        $params[':search3'] = $searchValue;
        $params[':search4'] = $searchValue;
        $params[':search5'] = $searchValue;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total FROM users u {$whereClause}";
    $countStmt = $pdo->prepare($countSql);
    
    // Bind parameters for count query
    if (!empty($params)) {
        foreach ($params as $key => $value) {
            $countStmt->bindValue($key, $value);
        }
    }
    
    $countStmt->execute();
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get users with statistics
    $sql = "
        SELECT 
            u.id,
            u.first_name,
            u.last_name,
            u.email,
            u.apple_id,
            u.profile_image_url,
            u.created_at,
            (SELECT COUNT(*) FROM follows WHERE followed_id = u.id) as followers_count,
            (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) as following_count,
            (SELECT COUNT(*) FROM photos WHERE user_id = u.id) as posts_count,
            (SELECT COUNT(*) FROM likes WHERE user_id = u.id) as likes_count,
            (SELECT COUNT(*) FROM comments WHERE user_id = u.id) + 
            (SELECT COUNT(*) FROM album_comments WHERE user_id = u.id) as comments_count
        FROM users u
        {$whereClause}
        ORDER BY {$sortBy} {$sortOrder}
        LIMIT :limit OFFSET :offset
    ";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind search parameters for main query
    if (!empty($params)) {
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, $value);
        }
    }
    
    // Bind pagination parameters
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Format users data
    $formattedUsers = array_map(function($user) {
        // Normalize profile image URL
        $profileImage = $user['profile_image_url'] ? normalizeImageUrl($user['profile_image_url']) : null;
        
        return [
            'id' => intval($user['id']),
            'firstName' => $user['first_name'],
            'lastName' => $user['last_name'],
            'email' => $user['email'],
            'appleId' => $user['apple_id'],
            'profileImage' => $profileImage,
            'createdAt' => $user['created_at'],
            'followersCount' => intval($user['followers_count']),
            'followingCount' => intval($user['following_count']),
            'postsCount' => intval($user['posts_count']),
            'likesCount' => intval($user['likes_count']),
            'commentsCount' => intval($user['comments_count'])
        ];
    }, $users);
    
    echo json_encode([
        'success' => true,
        'users' => $formattedUsers,
        'pagination' => [
            'total' => intval($total),
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => ceil($total / $perPage)
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении пользователей'
    ], JSON_UNESCAPED_UNICODE);
}
