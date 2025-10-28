<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обрабатываем только методы GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

// Получаем тип списка (followers - подписчики, following - подписки)
if (!isset($_GET['type']) || ($_GET['type'] !== 'followers' && $_GET['type'] !== 'following')) {
    handleError("Необходимо указать корректный тип (followers или following)", 400);
}

$type = $_GET['type'];

// ID пользователя, для которого запрашивается список (по умолчанию - текущий пользователь)
$targetUserId = isset($_GET['user_id']) ? intval($_GET['user_id']) : $userId;

// Получение параметров для пагинации
$page = isset($_GET['page']) ? intval($_GET['page']) : 1;
$perPage = isset($_GET['per_page']) ? intval($_GET['per_page']) : 20;

// Ограничение максимального количества элементов на странице
if ($perPage > 100) {
    $perPage = 100;
}

// Вычисление смещения для SQL запроса
$offset = ($page - 1) * $perPage;

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();

    // Проверяем существование пользователя
    $stmt = $db->prepare("SELECT id FROM users WHERE id = :user_id");
    $stmt->bindParam(':user_id', $targetUserId);
    $stmt->execute();
    
    if (!$stmt->fetch()) {
        handleError("Пользователь не найден", 404);
    }
    
    if ($type === 'followers') {
        // Получаем общее количество подписчиков
        $stmt = $db->prepare("
            SELECT COUNT(*) as total 
            FROM follows 
            WHERE followed_id = :user_id
        ");
        $stmt->bindParam(':user_id', $targetUserId);
        $stmt->execute();
        $total = $stmt->fetch()['total'];
        
        // Получаем список подписчиков с данными пользователей
        $stmt = $db->prepare("
            SELECT u.id, u.first_name, u.last_name, u.profile_image_url, 
                   f.created_at as followed_at,
                   EXISTS(SELECT 1 FROM follows WHERE follower_id = :current_user AND followed_id = u.id) as is_followed
            FROM follows f
            JOIN users u ON f.follower_id = u.id
            WHERE f.followed_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT :limit OFFSET :offset
        ");
        $stmt->bindParam(':current_user', $userId);
        $stmt->bindParam(':user_id', $targetUserId);
        $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
    } else { // type === 'following'
        // Получаем общее количество подписок
        $stmt = $db->prepare("
            SELECT COUNT(*) as total 
            FROM follows 
            WHERE follower_id = :user_id
        ");
        $stmt->bindParam(':user_id', $targetUserId);
        $stmt->execute();
        $total = $stmt->fetch()['total'];
        
        // Получаем список подписок с данными пользователей
        $stmt = $db->prepare("
            SELECT u.id, u.first_name, u.last_name, u.profile_image_url, 
                   f.created_at as followed_at,
                   EXISTS(SELECT 1 FROM follows WHERE follower_id = :current_user AND followed_id = u.id) as is_followed
            FROM follows f
            JOIN users u ON f.followed_id = u.id
            WHERE f.follower_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT :limit OFFSET :offset
        ");
        $stmt->bindParam(':current_user', $userId);
        $stmt->bindParam(':user_id', $targetUserId);
        $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
        $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
    }
    
    $users = [];
    while ($row = $stmt->fetch()) {
        $users[] = [
            'id' => $row['id'],
            'firstName' => $row['first_name'],
            'lastName' => $row['last_name'],
            'profileImageUrl' => $row['profile_image_url'],
            'followedAt' => $row['followed_at'],
            'isFollowed' => (bool)$row['is_followed']
        ];
    }
    
    // Вычисляем общее количество страниц
    $totalPages = ceil($total / $perPage);
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'data' => [
            'users' => $users,
            'type' => $type,
            'pagination' => [
                'total' => $total,
                'per_page' => $perPage,
                'current_page' => $page,
                'total_pages' => $totalPages
            ]
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при получении списка: " . $e->getMessage(), 500);
} 