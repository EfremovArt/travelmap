<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    // Get query parameters
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $userId = isset($_GET['user_id']) && $_GET['user_id'] !== '' ? intval($_GET['user_id']) : null;
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'asc' ? 'ASC' : 'DESC';
    
    // Validate sort_by to prevent SQL injection
    $allowedSortFields = ['created_at', 'follower_name', 'followed_name'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    $offset = ($page - 1) * $perPage;
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    if ($userId !== null) {
        $whereConditions[] = "(f.follower_id = :user_id OR f.followed_id = :user_id2)";
        $params[':user_id'] = $userId;
        $params[':user_id2'] = $userId;
    }
    
    if ($search !== '') {
        $whereConditions[] = "(CONCAT(follower.first_name, ' ', follower.last_name) LIKE :search OR 
                              CONCAT(followed.first_name, ' ', followed.last_name) LIKE :search2 OR
                              follower.email LIKE :search3 OR followed.email LIKE :search4)";
        $searchParam = "%{$search}%";
        $params[':search'] = $searchParam;
        $params[':search2'] = $searchParam;
        $params[':search3'] = $searchParam;
        $params[':search4'] = $searchParam;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total 
                 FROM follows f
                 INNER JOIN users follower ON f.follower_id = follower.id
                 INNER JOIN users followed ON f.followed_id = followed.id
                 {$whereClause}";
    
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get follows data
    $sql = "SELECT 
                f.id,
                f.follower_id as followerId,
                CONCAT(follower.first_name, ' ', follower.last_name) as followerName,
                follower.email as followerEmail,
                follower.profile_image_url as followerImage,
                f.followed_id as followedId,
                CONCAT(followed.first_name, ' ', followed.last_name) as followedName,
                followed.email as followedEmail,
                followed.profile_image_url as followedImage,
                f.created_at as createdAt
            FROM follows f
            INNER JOIN users follower ON f.follower_id = follower.id
            INNER JOIN users followed ON f.followed_id = followed.id
            {$whereClause}
            ORDER BY ";
    
    // Add sorting
    if ($sortBy === 'follower_name') {
        $sql .= "followerName {$sortOrder}";
    } elseif ($sortBy === 'followed_name') {
        $sql .= "followedName {$sortOrder}";
    } else {
        $sql .= "f.created_at {$sortOrder}";
    }
    
    $sql .= " LIMIT :limit OFFSET :offset";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind parameters
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    
    $stmt->execute();
    $follows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Normalize image URLs
    foreach ($follows as &$follow) {
        $follow['followerImage'] = $follow['followerImage'] ? normalizeImageUrl($follow['followerImage']) : null;
        $follow['followedImage'] = $follow['followedImage'] ? normalizeImageUrl($follow['followedImage']) : null;
    }
    
    // Calculate pagination
    $lastPage = ceil($total / $perPage);
    
    echo json_encode([
        'success' => true,
        'follows' => $follows,
        'pagination' => [
            'total' => intval($total),
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => $lastPage
        ]
    ], JSON_UNESCAPED_UNICODE);
    
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
        'errorCode' => 'SERVER_ERROR'
    ], JSON_UNESCAPED_UNICODE);
}
