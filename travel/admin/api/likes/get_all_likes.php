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
    
    // Валидация и получение параметров запроса
    $page = validateInt(getParam('page', 1, 'int'), 1);
    $perPage = validateInt(getParam('per_page', 50, 'int'), 1, 100);
    
    // Обработка опциональных параметров
    $userIdParam = getParam('user_id', '', 'string');
    $userId = ($userIdParam !== '' && $userIdParam !== null) ? validateInt($userIdParam, 1) : null;
    
    $photoIdParam = getParam('photo_id', '', 'string');
    $photoId = ($photoIdParam !== '' && $photoIdParam !== null) ? validateInt($photoIdParam, 1) : null;
    
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
    $allowedSortFields = ['created_at', 'user_name', 'photo_title'];
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
    
    if ($userId !== null) {
        $whereConditions[] = "l.user_id = :user_id";
        $params[':user_id'] = $userId;
    }
    
    if ($photoId !== null) {
        $whereConditions[] = "l.photo_id = :photo_id";
        $params[':photo_id'] = $photoId;
    }
    
    if ($search !== '') {
        $whereConditions[] = "(CONCAT(u.first_name, ' ', u.last_name) LIKE :search OR u.email LIKE :search)";
        $params[':search'] = "%{$search}%";
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total 
                 FROM likes l
                 INNER JOIN users u ON l.user_id = u.id
                 INNER JOIN photos p ON l.photo_id = p.id
                 {$whereClause}";
    
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get likes data
    $sql = "SELECT 
                l.id,
                l.user_id as userId,
                CONCAT(u.first_name, ' ', u.last_name) as userName,
                u.email as userEmail,
                u.profile_image_url as userProfileImage,
                l.photo_id as photoId,
                p.title as photoTitle,
                p.file_path as photoPreview,
                p.location_id,
                loc.title as locationName,
                loc.latitude,
                loc.longitude,
                l.created_at as createdAt
            FROM likes l
            INNER JOIN users u ON l.user_id = u.id
            INNER JOIN photos p ON l.photo_id = p.id
            LEFT JOIN locations loc ON p.location_id = loc.id
            {$whereClause}
            ORDER BY ";
    
    // Add sorting
    if ($sortBy === 'user_name') {
        $sql .= "userName {$sortOrder}";
    } elseif ($sortBy === 'photo_title') {
        $sql .= "photoTitle {$sortOrder}";
    } else {
        $sql .= "l.created_at {$sortOrder}";
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
    $likes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Normalize image URLs
    foreach ($likes as &$like) {
        $like['userProfileImage'] = $like['userProfileImage'] ? normalizeImageUrl($like['userProfileImage']) : null;
        $like['photoPreview'] = $like['photoPreview'] ? normalizeImageUrl($like['photoPreview']) : null;
        
        // locationName, latitude, longitude are already included in SQL query
        // Remove location_id from response
        unset($like['location_id']);
    }
    
    // Calculate pagination
    $lastPage = ceil($total / $perPage);
    
    echo json_encode([
        'success' => true,
        'likes' => $likes,
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
