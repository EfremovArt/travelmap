<?php
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors in JSON response
ini_set('log_errors', 1);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    $pdo->exec("SET NAMES utf8mb4");
    
    // Get query parameters
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : null;
    $userSearch = isset($_GET['user_search']) ? trim($_GET['user_search']) : null;
    $dateFrom = isset($_GET['date_from']) ? $_GET['date_from'] : null;
    $dateTo = isset($_GET['date_to']) ? $_GET['date_to'] : null;
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) && strtolower($_GET['sort_order']) === 'asc' ? 'ASC' : 'DESC';
    
    // Validate sort field
    $allowedSortFields = ['created_at', 'title', 'user_id'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    $offset = ($page - 1) * $perPage;
    
    // Build WHERE clause
    $whereConditions = [];
    $params = [];
    
    // Note: moderation_status column doesn't exist, so we show all photos
    
    if ($userId) {
        $whereConditions[] = 'p.user_id = :user_id';
        $params[':user_id'] = $userId;
    }
    
    // Search by user name, photo title, or description
    if ($userSearch) {
        $searchValue = '%' . $userSearch . '%';
        $whereConditions[] = '(u.first_name LIKE :search1 OR u.last_name LIKE :search2 OR CONCAT(u.first_name, " ", u.last_name) LIKE :search3 OR p.title LIKE :search4 OR p.description LIKE :search5)';
        $params[':search1'] = $searchValue;
        $params[':search2'] = $searchValue;
        $params[':search3'] = $searchValue;
        $params[':search4'] = $searchValue;
        $params[':search5'] = $searchValue;
    }
    
    if ($dateFrom) {
        $whereConditions[] = 'DATE(p.created_at) >= :date_from';
        $params[':date_from'] = $dateFrom;
    }
    
    if ($dateTo) {
        $whereConditions[] = 'DATE(p.created_at) <= :date_to';
        $params[':date_to'] = $dateTo;
    }
    
    $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
    
    // Get total count
    $countSql = "SELECT COUNT(*) as total 
                 FROM photos p
                 LEFT JOIN users u ON p.user_id = u.id
                 $whereClause";
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Get photos with user and location info
    $sql = "SELECT 
                p.id,
                p.user_id,
                p.location_id,
                p.title,
                p.description,
                p.file_path,
                p.created_at,
                u.first_name,
                u.last_name,
                u.email,
                l.title as location_name
            FROM photos p
            LEFT JOIN users u ON p.user_id = u.id
            LEFT JOIN locations l ON p.location_id = l.id
            $whereClause
            ORDER BY p.$sortBy $sortOrder
            LIMIT :limit OFFSET :offset";
    
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $photos = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $albums = [];
        $commercialPosts = [];
        $commentsCount = 0;
        $contentType = 'post';
        
        try {
            // Get albums this photo is in
            $albumSql = "SELECT a.title 
                         FROM album_photos ap
                         JOIN albums a ON ap.album_id = a.id
                         WHERE ap.photo_id = :photo_id";
            $albumStmt = $pdo->prepare($albumSql);
            $albumStmt->execute([':photo_id' => $row['id']]);
            $albums = $albumStmt->fetchAll(PDO::FETCH_COLUMN);
        } catch (Exception $e) {
            error_log("Error getting albums: " . $e->getMessage());
        }
        
        try {
            // Get commercial posts this photo is in
            // Check both direct photo_id link and through albums
            $commercialSql = "SELECT DISTINCT cp.title 
                              FROM commercial_posts cp
                              LEFT JOIN album_photos ap ON cp.album_id = ap.album_id
                              WHERE cp.photo_id = :photo_id 
                                 OR ap.photo_id = :photo_id";
            $commercialStmt = $pdo->prepare($commercialSql);
            $commercialStmt->execute([':photo_id' => $row['id']]);
            $commercialPosts = $commercialStmt->fetchAll(PDO::FETCH_COLUMN);
        } catch (Exception $e) {
            error_log("Error getting commercial posts: " . $e->getMessage());
        }
        
        try {
            // Get comments count
            $commentsSql = "SELECT COUNT(*) as count FROM comments WHERE photo_id = :photo_id";
            $commentsStmt = $pdo->prepare($commentsSql);
            $commentsStmt->execute([':photo_id' => $row['id']]);
            $commentsCount = $commentsStmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (Exception $e) {
            error_log("Error getting comments count: " . $e->getMessage());
        }
        
        // Determine content type
        if (!empty($commercialPosts)) {
            $contentType = 'commercial';
        } elseif (!empty($albums)) {
            $contentType = 'album';
        }
        
        // Normalize image path
        $filePath = normalizeImageUrl($row['file_path']);
        
        $photos[] = [
            'id' => intval($row['id']),
            'userId' => intval($row['user_id']),
            'userName' => trim($row['first_name'] . ' ' . $row['last_name']),
            'userEmail' => $row['email'],
            'locationId' => $row['location_id'] ? intval($row['location_id']) : null,
            'locationName' => $row['location_name'],
            'title' => $row['title'],
            'description' => $row['description'],
            'filePath' => $filePath,
            'moderationStatus' => 'approved', // Default since column doesn't exist
            'moderatedAt' => null,
            'createdAt' => $row['created_at'],
            'contentType' => $contentType,
            'inAlbums' => $albums,
            'inCommercialPosts' => $commercialPosts,
            'commentsCount' => intval($commentsCount)
        ];
    }
    
    // Add commercial posts only on first page to avoid duplicates
    if ($page === 1) {
        try {
            $commercialSql = "SELECT 
                                cp.id,
                                cp.user_id,
                                cp.title,
                                cp.description,
                                cp.image_url as file_path,
                                cp.created_at,
                                u.first_name,
                                u.last_name,
                                u.email,
                                cp.location_name
                            FROM commercial_posts cp
                            LEFT JOIN users u ON cp.user_id = u.id
                            WHERE cp.is_active = 1
                            ORDER BY cp.created_at DESC
                            LIMIT 20";
            
            $commercialStmt = $pdo->prepare($commercialSql);
            $commercialStmt->execute();
            
            while ($row = $commercialStmt->fetch(PDO::FETCH_ASSOC)) {
                $filePath = $row['file_path'];
                
                // Use placeholder if no image
                if (empty($filePath) || $filePath === 'NULL') {
                    $filePath = '/travel/admin/assets/images/default-avatar.svg';
                } else {
                    $filePath = normalizeImageUrl($filePath);
                }
                
                $photos[] = [
                    'id' => 'commercial_' . $row['id'], // Prefix to distinguish from regular photos
                    'userId' => intval($row['user_id']),
                    'userName' => trim($row['first_name'] . ' ' . $row['last_name']),
                    'userEmail' => $row['email'],
                    'locationId' => null,
                    'locationName' => $row['location_name'],
                    'title' => $row['title'] ?: 'Без названия',
                    'description' => $row['description'],
                    'filePath' => $filePath,
                    'moderationStatus' => 'approved',
                    'moderatedAt' => null,
                    'createdAt' => $row['created_at'],
                    'contentType' => 'commercial',
                    'inAlbums' => [],
                    'inCommercialPosts' => [$row['title']],
                    'commentsCount' => 0
                ];
            }
            
            // Sort all items by date
            usort($photos, function($a, $b) {
                return strtotime($b['createdAt']) - strtotime($a['createdAt']);
            });
        } catch (Exception $e) {
            error_log("Error getting commercial posts: " . $e->getMessage());
        }
    }
    
    echo json_encode([
        'success' => true,
        'photos' => $photos,
        'pagination' => [
            'total' => intval($total) + count($photos),
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => ceil($total / $perPage)
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Moderation API Error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении фотографий: ' . $e->getMessage(),
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
}
