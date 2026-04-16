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
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 20;
    $offset = ($page - 1) * $perPage;
    
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $dateFrom = isset($_GET['date_from']) ? $_GET['date_from'] : '';
    $dateTo = isset($_GET['date_to']) ? $_GET['date_to'] : '';
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    if ($search) {
        $searchValue = '%' . $search . '%';
        $whereConditions[] = '(c.comment LIKE :search1 OR u.first_name LIKE :search2 OR u.last_name LIKE :search3 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search4)';
        $params[':search1'] = $searchValue;
        $params[':search2'] = $searchValue;
        $params[':search3'] = $searchValue;
        $params[':search4'] = $searchValue;
    }
    
    if ($dateFrom) {
        $whereConditions[] = 'c.created_at >= :date_from';
        $params[':date_from'] = $dateFrom . ' 00:00:00';
    }
    
    if ($dateTo) {
        $whereConditions[] = 'c.created_at <= :date_to';
        $params[':date_to'] = $dateTo . ' 23:59:59';
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count - both photo and album comments
    $total = 0;
    try {
        // Build WHERE clause for photo comments count
        $photoCountWhereConditions = [];
        $photoCountParams = [];
        
        if ($search) {
            $searchValue = '%' . $search . '%';
            $photoCountWhereConditions[] = '(c.comment LIKE :search1 OR u.first_name LIKE :search2 OR u.last_name LIKE :search3 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search4)';
            $photoCountParams[':search1'] = $searchValue;
            $photoCountParams[':search2'] = $searchValue;
            $photoCountParams[':search3'] = $searchValue;
            $photoCountParams[':search4'] = $searchValue;
        }
        
        if ($dateFrom) {
            $photoCountWhereConditions[] = 'c.created_at >= :date_from';
            $photoCountParams[':date_from'] = $dateFrom . ' 00:00:00';
        }
        
        if ($dateTo) {
            $photoCountWhereConditions[] = 'c.created_at <= :date_to';
            $photoCountParams[':date_to'] = $dateTo . ' 23:59:59';
        }
        
        $photoCountWhereClause = !empty($photoCountWhereConditions) ? 'WHERE ' . implode(' AND ', $photoCountWhereConditions) : '';
        
        // Build WHERE clause for album comments count
        $albumCountWhereConditions = [];
        $albumCountParams = [];
        
        if ($search) {
            $searchValue = '%' . $search . '%';
            $albumCountWhereConditions[] = '(ac.comment LIKE :search1 OR u.first_name LIKE :search2 OR u.last_name LIKE :search3 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search4)';
            $albumCountParams[':search1'] = $searchValue;
            $albumCountParams[':search2'] = $searchValue;
            $albumCountParams[':search3'] = $searchValue;
            $albumCountParams[':search4'] = $searchValue;
        }
        
        if ($dateFrom) {
            $albumCountWhereConditions[] = 'ac.created_at >= :date_from';
            $albumCountParams[':date_from'] = $dateFrom . ' 00:00:00';
        }
        
        if ($dateTo) {
            $albumCountWhereConditions[] = 'ac.created_at <= :date_to';
            $albumCountParams[':date_to'] = $dateTo . ' 23:59:59';
        }
        
        $albumCountWhereClause = !empty($albumCountWhereConditions) ? 'WHERE ' . implode(' AND ', $albumCountWhereConditions) : '';
        
        $countSql = "SELECT COUNT(*) as total FROM (
                        (SELECT c.id FROM comments c
                         LEFT JOIN users u ON c.user_id = u.id
                         {$photoCountWhereClause})
                        UNION ALL
                        (SELECT ac.id FROM album_comments ac
                         LEFT JOIN users u ON ac.user_id = u.id
                         {$albumCountWhereClause})
                     ) as all_comments";
        
        $countStmt = $pdo->prepare($countSql);
        
        // Bind photo count params
        foreach ($photoCountParams as $key => $value) {
            $countStmt->bindValue($key, $value);
        }
        
        // Bind album count params
        foreach ($albumCountParams as $key => $value) {
            $countStmt->bindValue($key, $value);
        }
        
        $countStmt->execute();
        $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    } catch (PDOException $e) {
        error_log("Error counting comments: " . $e->getMessage());
        $total = 0;
    }
    
    // Get comments - both photo and album comments with UNION
    $comments = [];
    try {
        // Build WHERE clause for photo comments
        $photoWhereConditions = [];
        $photoParams = [];
        
        if ($search) {
            $searchValue = '%' . $search . '%';
            $photoWhereConditions[] = '(c.comment LIKE :search1 OR u.first_name LIKE :search2 OR u.last_name LIKE :search3 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search4)';
            $photoParams[':search1'] = $searchValue;
            $photoParams[':search2'] = $searchValue;
            $photoParams[':search3'] = $searchValue;
            $photoParams[':search4'] = $searchValue;
        }
        
        if ($dateFrom) {
            $photoWhereConditions[] = 'c.created_at >= :date_from';
            $photoParams[':date_from'] = $dateFrom . ' 00:00:00';
        }
        
        if ($dateTo) {
            $photoWhereConditions[] = 'c.created_at <= :date_to';
            $photoParams[':date_to'] = $dateTo . ' 23:59:59';
        }
        
        $photoWhereClause = !empty($photoWhereConditions) ? 'WHERE ' . implode(' AND ', $photoWhereConditions) : '';
        
        // Build WHERE clause for album comments
        $albumWhereConditions = [];
        $albumParams = [];
        
        if ($search) {
            $searchValue = '%' . $search . '%';
            $albumWhereConditions[] = '(ac.comment LIKE :search1 OR u.first_name LIKE :search2 OR u.last_name LIKE :search3 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search4)';
            $albumParams[':search1'] = $searchValue;
            $albumParams[':search2'] = $searchValue;
            $albumParams[':search3'] = $searchValue;
            $albumParams[':search4'] = $searchValue;
        }
        
        if ($dateFrom) {
            $albumWhereConditions[] = 'ac.created_at >= :date_from';
            $albumParams[':date_from'] = $dateFrom . ' 00:00:00';
        }
        
        if ($dateTo) {
            $albumWhereConditions[] = 'ac.created_at <= :date_to';
            $albumParams[':date_to'] = $dateTo . ' 23:59:59';
        }
        
        $albumWhereClause = !empty($albumWhereConditions) ? 'WHERE ' . implode(' AND ', $albumWhereConditions) : '';
        
        // Photo comments query
        $photoSql = "SELECT 
                    c.id,
                    c.photo_id,
                    NULL as album_id,
                    c.user_id,
                    c.comment as text,
                    c.created_at,
                    CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) as user_name,
                    u.profile_image_url as user_image,
                    p.title as photo_title,
                    p.file_path as photo_preview,
                    'photo' as comment_type
                FROM comments c
                LEFT JOIN users u ON c.user_id = u.id
                LEFT JOIN photos p ON c.photo_id = p.id
                {$photoWhereClause}";
        
        // Album comments query
        $albumSql = "SELECT 
                    ac.id,
                    NULL as photo_id,
                    ac.album_id,
                    ac.user_id,
                    ac.comment as text,
                    ac.created_at,
                    CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) as user_name,
                    u.profile_image_url as user_image,
                    a.title as photo_title,
                    NULL as photo_preview,
                    'album' as comment_type
                FROM album_comments ac
                LEFT JOIN users u ON ac.user_id = u.id
                LEFT JOIN albums a ON ac.album_id = a.id
                {$albumWhereClause}";
        
        // Union query
        $sql = "SELECT * FROM (
                    ({$photoSql})
                    UNION ALL
                    ({$albumSql})
                ) as all_comments
                ORDER BY created_at DESC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $pdo->prepare($sql);
        
        // Bind photo params
        foreach ($photoParams as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        
        // Bind album params (they have the same keys, so we can reuse)
        foreach ($albumParams as $key => $value) {
            $stmt->bindValue($key, $value);
        }
        
        $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Normalize image URLs
        foreach ($comments as &$comment) {
            $comment['user_image'] = $comment['user_image'] ? normalizeImageUrl($comment['user_image']) : null;
            $comment['photo_preview'] = $comment['photo_preview'] ? normalizeImageUrl($comment['photo_preview']) : null;
            $comment['user_name'] = trim($comment['user_name']) ?: 'Неизвестный пользователь';
        }
    } catch (PDOException $e) {
        // If there's an error with the query, return empty array
        error_log("Error fetching comments: " . $e->getMessage());
        $comments = [];
    }
    
    echo json_encode([
        'success' => true,
        'comments' => $comments,
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
        'message' => 'Ошибка при получении комментариев: ' . $e->getMessage()
    ]);
}
