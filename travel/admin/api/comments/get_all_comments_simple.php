<?php
require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $conn = connectToDatabase();
    
    $page = validateInt(getParam('page', 1, 'int'), 1);
    $perPage = validateInt(getParam('per_page', 50, 'int'), 1, 100);
    $offset = ($page - 1) * $perPage;
    
    // Получаем только комментарии к фото (упрощенная версия)
    $sql = "SELECT 
                c.id,
                c.user_id,
                c.photo_id,
                c.comment,
                c.created_at,
                CONCAT(u.first_name, ' ', u.last_name) as user_name,
                u.email as user_email,
                u.profile_image_url as user_profile_image,
                p.title as photo_title
            FROM comments c
            JOIN users u ON c.user_id = u.id
            LEFT JOIN photos p ON c.photo_id = p.id
            ORDER BY c.created_at DESC
            LIMIT :limit OFFSET :offset";
    
    $stmt = $conn->prepare($sql);
    $stmt->bindValue(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Получаем общее количество
    $countStmt = $conn->query("SELECT COUNT(*) as total FROM comments");
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Форматируем ответ
    $formattedComments = array_map(function($row) {
        return [
            'id' => intval($row['id']),
            'userId' => intval($row['user_id']),
            'userName' => $row['user_name'],
            'userEmail' => $row['user_email'],
            'userProfileImage' => normalizeImageUrl($row['user_profile_image']),
            'photoId' => intval($row['photo_id']),
            'photoTitle' => $row['photo_title'],
            'commentText' => $row['comment'],
            'createdAt' => $row['created_at'],
            'commentType' => 'photo'
        ];
    }, $comments);
    
    echo json_encode([
        'success' => true,
        'comments' => $formattedComments,
        'pagination' => [
            'page' => $page,
            'per_page' => $perPage,
            'total' => intval($total),
            'total_pages' => ceil($total / $perPage)
        ]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении комментариев: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
?>
