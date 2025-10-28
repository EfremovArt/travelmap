<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обрабатываем только GET запросы
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

// Получаем параметры пагинации
$page = isset($_GET['page']) ? intval($_GET['page']) : 1;
$perPage = isset($_GET['per_page']) ? intval($_GET['per_page']) : 20;

// Ограничиваем количество элементов на странице
if ($perPage > 100) {
    $perPage = 100;
}

// Вычисляем смещение
$offset = ($page - 1) * $perPage;

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();

    // Получаем общее количество фотографий от пользователей, на которых подписан текущий
    $stmt = $db->prepare("
        SELECT COUNT(DISTINCT p.id) as total
        FROM photos p
        WHERE p.user_id = :user_id
           OR p.user_id IN (
                SELECT followed_id
                FROM follows
                WHERE follower_id = :user_id
           )
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    $totalPosts = $stmt->fetch()['total'];

    // Получаем фотографии от пользователей, на которых подписан текущий
    $stmt = $db->prepare("
        SELECT p.id, p.user_id, p.location_id, p.file_path, p.title, p.description, p.created_at,
        u.first_name as user_first_name, u.last_name as user_last_name, u.profile_image_url as user_profile_image,
        l.title as location_title, l.address as location_address, l.city as location_city, l.country as location_country,
        (SELECT COUNT(*) FROM likes WHERE photo_id = p.id) as likes_count,
        (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comments_count,
        EXISTS(SELECT 1 FROM likes WHERE user_id = :current_user AND photo_id = p.id) as is_liked,
        EXISTS(SELECT 1 FROM favorites WHERE user_id = :current_user AND photo_id = p.id) as is_favorite
        FROM photos p
        JOIN users u ON p.user_id = u.id
        LEFT JOIN locations l ON p.location_id = l.id
        WHERE p.user_id = :user_id
           OR p.user_id IN (
                SELECT followed_id
                FROM follows
                WHERE follower_id = :user_id
           )
        ORDER BY p.created_at DESC
        LIMIT :limit OFFSET :offset
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':current_user', $userId);
    $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $posts = [];
    
    while ($row = $stmt->fetch()) {
        $posts[] = [
            'id' => $row['id'],
            'userId' => $row['user_id'],
            'locationId' => $row['location_id'],
            'filePath' => $row['file_path'],
            'title' => $row['title'],
            'description' => $row['description'],
            'createdAt' => $row['created_at'],
            'user' => [
                'id' => $row['user_id'],
                'firstName' => $row['user_first_name'],
                'lastName' => $row['user_last_name'],
                'profileImageUrl' => $row['user_profile_image']
            ],
            'location' => $row['location_title'] ? [
                'id' => $row['location_id'],
                'title' => $row['location_title'],
                'address' => $row['location_address'],
                'city' => $row['location_city'],
                'country' => $row['location_country']
            ] : null,
            'likesCount' => $row['likes_count'],
            'commentsCount' => $row['comments_count'],
            'isLiked' => (bool)$row['is_liked'],
            'isFavorite' => (bool)$row['is_favorite']
        ];
    }
    
    // Отправляем успешный ответ с постами и метаданными пагинации
    echo json_encode([
        'success' => true,
        'message' => 'Посты получены успешно',
        'posts' => $posts,
        'pagination' => [
            'total' => $totalPosts,
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => ceil($totalPosts / $perPage)
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при получении постов: " . $e->getMessage(), 500);
} 