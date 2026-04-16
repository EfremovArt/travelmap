<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';

// Проверка авторизации
adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $conn = connectToDatabase();
    
    if (!$conn) {
        throw new Exception('Не удалось подключиться к базе данных');
    }
    
    // Валидация и получение параметров запроса
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $perPage = isset($_GET['per_page']) ? max(1, min(100, intval($_GET['per_page']))) : 50;
    $userId = isset($_GET['user_id']) && $_GET['user_id'] !== '' ? intval($_GET['user_id']) : null;
    $photoId = isset($_GET['photo_id']) && $_GET['photo_id'] !== '' ? intval($_GET['photo_id']) : null;
    $albumId = isset($_GET['album_id']) && $_GET['album_id'] !== '' ? intval($_GET['album_id']) : null;
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $sortBy = isset($_GET['sort_by']) ? $_GET['sort_by'] : 'created_at';
    $sortOrder = isset($_GET['sort_order']) ? strtoupper($_GET['sort_order']) : 'DESC';
    
    $offset = ($page - 1) * $perPage;
    
    // Валидация поля сортировки
    $allowedSortFields = ['created_at', 'user_id', 'photo_id', 'album_id'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'created_at';
    }
    
    // Валидация порядка сортировки
    if (!in_array($sortOrder, ['ASC', 'DESC'])) {
        $sortOrder = 'DESC';
    }
    
    $comments = [];
    $totalCount = 0;
    
    // Получаем комментарии к фотографиям
    $photoCommentsQuery = "
        SELECT 
            c.id,
            c.user_id,
            c.photo_id,
            NULL as album_id,
            c.comment as comment_text,
            c.created_at,
            u.first_name,
            u.last_name,
            u.email,
            u.profile_image_url,
            p.title as photo_title,
            NULL as album_title,
            'photo' as comment_type
        FROM comments c
        JOIN users u ON c.user_id = u.id
        LEFT JOIN photos p ON c.photo_id = p.id
        WHERE 1=1
    ";
    
    // Получаем комментарии к альбомам
    $albumCommentsQuery = "
        SELECT 
            ac.id,
            ac.user_id,
            NULL as photo_id,
            ac.album_id,
            ac.comment as comment_text,
            ac.created_at,
            u.first_name,
            u.last_name,
            u.email,
            u.profile_image_url,
            NULL as photo_title,
            a.title as album_title,
            'album' as comment_type
        FROM album_comments ac
        JOIN users u ON ac.user_id = u.id
        LEFT JOIN albums a ON ac.album_id = a.id
        WHERE 1=1
    ";
    
    $params = [];
    $countParams = [];
    
    // Добавляем фильтры для комментариев к фото
    $photoFilterConditions = "";
    $albumFilterConditions = "";
    
    if ($userId !== null) {
        $photoFilterConditions .= " AND c.user_id = :user_id";
        $albumFilterConditions .= " AND ac.user_id = :user_id";
        $params['user_id'] = $userId;
        $countParams['user_id'] = $userId;
    }
    
    if ($photoId !== null) {
        $photoFilterConditions .= " AND c.photo_id = :photo_id";
        $params['photo_id'] = $photoId;
        $countParams['photo_id'] = $photoId;
    }
    
    if ($albumId !== null) {
        $albumFilterConditions .= " AND ac.album_id = :album_id";
        $params['album_id'] = $albumId;
        $countParams['album_id'] = $albumId;
    }
    
    if ($search !== '') {
        $params['search'] = '%' . $search . '%';
        $countParams['search'] = '%' . $search . '%';
    }
    
    // Объединяем запросы
    $unionQuery = "";
    
    // Если фильтр только по альбому, берем только комментарии альбомов
    if ($albumId !== null && $photoId === null) {
        $unionQuery = $albumCommentsQuery . $albumFilterConditions;
        if ($search !== '') {
            $unionQuery .= " AND (ac.comment LIKE :search OR u.first_name LIKE :search OR u.last_name LIKE :search)";
        }
    }
    // Если фильтр только по фото, берем только комментарии фото
    elseif ($photoId !== null && $albumId === null) {
        $unionQuery = $photoCommentsQuery . $photoFilterConditions;
        if ($search !== '') {
            $unionQuery .= " AND (c.comment LIKE :search OR u.first_name LIKE :search OR u.last_name LIKE :search)";
        }
    }
    // Иначе берем оба типа комментариев
    else {
        $photoQuery = $photoCommentsQuery . $photoFilterConditions;
        $albumQuery = $albumCommentsQuery . $albumFilterConditions;
        
        if ($search !== '') {
            $photoQuery .= " AND (c.comment LIKE :search OR u.first_name LIKE :search OR u.last_name LIKE :search)";
            $albumQuery .= " AND (ac.comment LIKE :search OR u.first_name LIKE :search OR u.last_name LIKE :search)";
        }
        
        $unionQuery = "(" . $photoQuery . ") UNION ALL (" . $albumQuery . ")";
    }
    
    // Подсчет общего количества
    $countQuery = "SELECT COUNT(*) as total FROM (" . $unionQuery . ") as all_comments";
    $countStmt = $conn->prepare($countQuery);
    foreach ($countParams as $key => $value) {
        $countStmt->bindValue(':' . $key, $value);
    }
    $countStmt->execute();
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Получаем комментарии с пагинацией
    $finalQuery = "SELECT * FROM (" . $unionQuery . ") as all_comments ORDER BY " . $sortBy . " " . $sortOrder . " LIMIT :limit OFFSET :offset";
    $stmt = $conn->prepare($finalQuery);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue(':' . $key, $value);
    }
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $comments[] = [
            'id' => intval($row['id']),
            'userId' => intval($row['user_id']),
            'userName' => trim(($row['first_name'] ?? '') . ' ' . ($row['last_name'] ?? '')),
            'userEmail' => $row['email'],
            'userProfileImage' => normalizeImageUrl($row['profile_image_url']),
            'photoId' => $row['photo_id'] ? intval($row['photo_id']) : null,
            'albumId' => $row['album_id'] ? intval($row['album_id']) : null,
            'photoTitle' => $row['photo_title'],
            'albumTitle' => $row['album_title'],
            'commentText' => $row['comment_text'],
            'commentType' => $row['comment_type'],
            'createdAt' => $row['created_at']
        ];
    }
    
    echo json_encode([
        'success' => true,
        'comments' => $comments,
        'pagination' => [
            'total' => intval($totalCount),
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => ceil($totalCount / $perPage)
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении комментариев: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
