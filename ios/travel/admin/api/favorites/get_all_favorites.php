<?php
require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $type = isset($_GET['type']) ? trim($_GET['type']) : 'all';
    $userId = isset($_GET['user_id']) && $_GET['user_id'] !== '' ? intval($_GET['user_id']) : null;
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'asc' ? 'ASC' : 'DESC';
    
    $validTypes = ['all', 'photo', 'album', 'commercial'];
    if (!in_array($type, $validTypes)) {
        $type = 'all';
    }
    
    $allowedSortFields = ['created_at', 'user_name', 'content_title'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    $offset = ($page - 1) * $perPage;
    
    $favorites = [];
    $total = 0;
    
    if ($type === 'all' || $type === 'photo') {
        $whereConditions = [];
        $params = [];
        
        if ($userId !== null) {
            $whereConditions[] = "f.user_id = :user_id";
            $params[':user_id'] = $userId;
        }
        
        if ($search !== '') {
            $whereConditions[] = "(CONCAT(u.first_name, ' ', u.last_name) LIKE :search OR p.title LIKE :search)";
            $params[':search'] = "%{$search}%";
        }
        
        $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
        
        if ($type === 'photo') {
            $countSql = "SELECT COUNT(*) as total 
                         FROM favorites f
                         INNER JOIN users u ON f.user_id = u.id
                         INNER JOIN photos p ON f.photo_id = p.id
                         {$whereClause}";
            
            $countStmt = $pdo->prepare($countSql);
            $countStmt->execute($params);
            $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
            
            $sql = "SELECT 
                        f.id,
                        f.user_id as userId,
                        CONCAT(u.first_name, ' ', u.last_name) as userName,
                        u.profile_image_url as userImage,
                        'photo' as contentType,
                        p.id as contentId,
                        p.title as contentTitle,
                        p.file_path as contentPreview,
                        loc.name as locationName,
                        f.created_at as createdAt
                    FROM favorites f
                    INNER JOIN users u ON f.user_id = u.id
                    INNER JOIN photos p ON f.photo_id = p.id
                    LEFT JOIN locations loc ON p.location_id = loc.id
                    {$whereClause}
                    ORDER BY ";
            
            if ($sortBy === 'user_name') {
                $sql .= "userName {$sortOrder}";
            } elseif ($sortBy === 'content_title') {
                $sql .= "contentTitle {$sortOrder}";
            } else {
                $sql .= "f.created_at {$sortOrder}";
            }
            
            $sql .= " LIMIT :limit OFFSET :offset";
            
            $stmt = $pdo->prepare($sql);
            foreach ($params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            
            $stmt->execute();
            $favorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } else {
            $sql = "SELECT 
                        f.id,
                        f.user_id as userId,
                        CONCAT(u.first_name, ' ', u.last_name) as userName,
                        u.profile_image_url as userImage,
                        'photo' as contentType,
                        p.id as contentId,
                        p.title as contentTitle,
                        p.file_path as contentPreview,
                        loc.name as locationName,
                        f.created_at as createdAt
                    FROM favorites f
                    INNER JOIN users u ON f.user_id = u.id
                    INNER JOIN photos p ON f.photo_id = p.id
                    LEFT JOIN locations loc ON p.location_id = loc.id
                    {$whereClause}";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $photoFavorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $favorites = array_merge($favorites, $photoFavorites);
        }
    }
    
    if ($type === 'all' || $type === 'album') {
        $whereConditions = [];
        $params = [];
        
        if ($userId !== null) {
            $whereConditions[] = "af.user_id = :user_id";
            $params[':user_id'] = $userId;
        }
        
        if ($search !== '') {
            $whereConditions[] = "(CONCAT(u.first_name, ' ', u.last_name) LIKE :search OR a.title LIKE :search)";
            $params[':search'] = "%{$search}%";
        }
        
        $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
        
        if ($type === 'album') {
            $countSql = "SELECT COUNT(*) as total 
                         FROM album_favorites af
                         INNER JOIN users u ON af.user_id = u.id
                         INNER JOIN albums a ON af.album_id = a.id
                         {$whereClause}";
            
            $countStmt = $pdo->prepare($countSql);
            $countStmt->execute($params);
            $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
            
            $sql = "SELECT 
                        af.id,
                        af.user_id as userId,
                        CONCAT(u.first_name, ' ', u.last_name) as userName,
                        u.profile_image_url as userImage,
                        'album' as contentType,
                        a.id as contentId,
                        a.title as contentTitle,
                        p.file_path as contentPreview,
                        NULL as locationName,
                        af.created_at as createdAt
                    FROM album_favorites af
                    INNER JOIN users u ON af.user_id = u.id
                    INNER JOIN albums a ON af.album_id = a.id
                    LEFT JOIN photos p ON a.cover_photo_id = p.id
                    {$whereClause}
                    ORDER BY ";
            
            if ($sortBy === 'user_name') {
                $sql .= "userName {$sortOrder}";
            } elseif ($sortBy === 'content_title') {
                $sql .= "contentTitle {$sortOrder}";
            } else {
                $sql .= "af.created_at {$sortOrder}";
            }
            
            $sql .= " LIMIT :limit OFFSET :offset";
            
            $stmt = $pdo->prepare($sql);
            foreach ($params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            
            $stmt->execute();
            $favorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } else {
            $sql = "SELECT 
                        af.id,
                        af.user_id as userId,
                        CONCAT(u.first_name, ' ', u.last_name) as userName,
                        u.profile_image_url as userImage,
                        'album' as contentType,
                        a.id as contentId,
                        a.title as contentTitle,
                        p.file_path as contentPreview,
                        NULL as locationName,
                        af.created_at as createdAt
                    FROM album_favorites af
                    INNER JOIN users u ON af.user_id = u.id
                    INNER JOIN albums a ON af.album_id = a.id
                    LEFT JOIN photos p ON a.cover_photo_id = p.id
                    {$whereClause}";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $albumFavorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $favorites = array_merge($favorites, $albumFavorites);
        }
    }
    
    if ($type === 'all' || $type === 'commercial') {
        $whereConditions = [];
        $params = [];
        
        if ($userId !== null) {
            $whereConditions[] = "cf.user_id = :user_id";
            $params[':user_id'] = $userId;
        }
        
        if ($search !== '') {
            $whereConditions[] = "(CONCAT(u.first_name, ' ', u.last_name) LIKE :search OR cp.title LIKE :search)";
            $params[':search'] = "%{$search}%";
        }
        
        $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
        
        if ($type === 'commercial') {
            $countSql = "SELECT COUNT(*) as total 
                         FROM commercial_favorites cf
                         INNER JOIN users u ON cf.user_id = u.id
                         INNER JOIN commercial_posts cp ON cf.commercial_post_id = cp.id
                         {$whereClause}";
            
            $countStmt = $pdo->prepare($countSql);
            $countStmt->execute($params);
            $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
            
            $sql = "SELECT 
                        cf.id,
                        cf.user_id as userId,
                        CONCAT(u.first_name, ' ', u.last_name) as userName,
                        u.profile_image_url as userImage,
                        'commercial' as contentType,
                        cp.id as contentId,
                        cp.title as contentTitle,
                        cpi.image_url as contentPreview,
                        cp.location_name as locationName,
                        cf.created_at as createdAt
                    FROM commercial_favorites cf
                    INNER JOIN users u ON cf.user_id = u.id
                    INNER JOIN commercial_posts cp ON cf.commercial_post_id = cp.id
                    LEFT JOIN commercial_post_images cpi ON cp.id = cpi.commercial_post_id AND cpi.image_order = 0
                    {$whereClause}
                    ORDER BY ";
            
            if ($sortBy === 'user_name') {
                $sql .= "userName {$sortOrder}";
            } elseif ($sortBy === 'content_title') {
                $sql .= "contentTitle {$sortOrder}";
            } else {
                $sql .= "cf.created_at {$sortOrder}";
            }
            
            $sql .= " LIMIT :limit OFFSET :offset";
            
            $stmt = $pdo->prepare($sql);
            foreach ($params as $key => $value) {
                $stmt->bindValue($key, $value);
            }
            $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            
            $stmt->execute();
            $favorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } else {
            $sql = "SELECT 
                        cf.id,
                        cf.user_id as userId,
                        CONCAT(u.first_name, ' ', u.last_name) as userName,
                        u.profile_image_url as userImage,
                        'commercial' as contentType,
                        cp.id as contentId,
                        cp.title as contentTitle,
                        cpi.image_url as contentPreview,
                        cp.location_name as locationName,
                        cf.created_at as createdAt
                    FROM commercial_favorites cf
                    INNER JOIN users u ON cf.user_id = u.id
                    INNER JOIN commercial_posts cp ON cf.commercial_post_id = cp.id
                    LEFT JOIN commercial_post_images cpi ON cp.id = cpi.commercial_post_id AND cpi.image_order = 0
                    {$whereClause}";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $commercialFavorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $favorites = array_merge($favorites, $commercialFavorites);
        }
    }
    
    if ($type === 'all') {
        $total = count($favorites);
        
        usort($favorites, function($a, $b) use ($sortBy, $sortOrder) {
            $aVal = $sortBy === 'user_name' ? $a['userName'] : 
                    ($sortBy === 'content_title' ? $a['contentTitle'] : $a['createdAt']);
            $bVal = $sortBy === 'user_name' ? $b['userName'] : 
                    ($sortBy === 'content_title' ? $b['contentTitle'] : $b['createdAt']);
            
            $comparison = $aVal <=> $bVal;
            return $sortOrder === 'DESC' ? -$comparison : $comparison;
        });
        
        $favorites = array_slice($favorites, $offset, $perPage);
    }
    
    $lastPage = ceil($total / $perPage);
    
    echo json_encode([
        'success' => true,
        'favorites' => $favorites,
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
