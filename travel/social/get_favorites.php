<?php
require_once '../config.php';
initApi();

// Функция для логирования в файл
function debugLog($message) {
    $logFile = '/www/wwwroot/bearded-fox.ru/travel/debug.log';
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] GET_FAVORITES: $message" . PHP_EOL;
    file_put_contents($logFile, $logMessage, FILE_APPEND | LOCK_EX);
}

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();
debugLog("Получен запрос от пользователя ID: $userId");

// Обрабатываем только методы GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

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
    
    // Получаем общее количество избранных фотографий
    $stmt = $db->prepare("
        SELECT COUNT(*) as total 
        FROM favorites 
        WHERE user_id = :user_id
    ");
    $stmt->bindParam(':user_id', $targetUserId);
    $stmt->execute();
    $total = $stmt->fetch()['total'];
    
    // Получаем избранные фотографии с данными
    $stmt = $db->prepare("
        SELECT p.id, p.user_id, p.location_id, p.file_path, p.title, p.description, p.created_at,
               u.first_name, u.last_name, u.profile_image_url,
               f.created_at as favorited_at,
               (SELECT COUNT(*) FROM likes WHERE photo_id = p.id) as likes_count,
               (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comments_count,
               EXISTS(SELECT 1 FROM likes WHERE user_id = :current_user AND photo_id = p.id) as is_liked
        FROM favorites f
        JOIN photos p ON f.photo_id = p.id
        JOIN users u ON p.user_id = u.id
        WHERE f.user_id = :user_id
        ORDER BY f.created_at DESC
        LIMIT :limit OFFSET :offset
    ");
    $stmt->bindParam(':current_user', $userId);
    $stmt->bindParam(':user_id', $targetUserId);
    $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $photos = [];
    while ($row = $stmt->fetch()) {
        $photos[] = [
            'id' => $row['id'],
            'userId' => $row['user_id'],
            'locationId' => $row['location_id'],
            'filePath' => $row['file_path'],
            'title' => $row['title'],
            'description' => $row['description'],
            'createdAt' => $row['created_at'],
            'favoritedAt' => $row['favorited_at'],
            'user' => [
                'firstName' => $row['first_name'],
                'lastName' => $row['last_name'],
                'profileImageUrl' => $row['profile_image_url']
            ],
            'stats' => [
                'likesCount' => $row['likes_count'],
                'commentsCount' => $row['comments_count'],
                'isLiked' => (bool)$row['is_liked'],
                'isFavorited' => true // Всегда true для этого запроса
            ]
        ];
    }
    
    // ===== Избранные коммерческие посты =====
    debugLog("Запрашиваем коммерческие избранные для пользователя ID = " . $targetUserId);
    
    // Общее количество коммерческих избранных
    $stmt = $db->prepare("
        SELECT COUNT(*) as total
        FROM commercial_post_favorites cf
        WHERE cf.user_id = :user_id
    ");
    $stmt->bindParam(':user_id', $targetUserId);
    $stmt->execute();
    $commercialTotal = (int)$stmt->fetch()['total'];
    
    debugLog("Найдено коммерческих избранных: " . $commercialTotal);

    // Список коммерческих избранных (с данными пользователя и альбома)
    $stmt = $db->prepare("
        SELECT 
            cp.*,
            cf.created_at as favorited_at,
            u.first_name,
            u.last_name,
            u.profile_image_url,
            a.title as album_title
        FROM commercial_post_favorites cf
        JOIN commercial_posts cp ON cp.id = cf.commercial_post_id
        LEFT JOIN users u ON cp.user_id = u.id
        LEFT JOIN albums a ON cp.album_id = a.id
        WHERE cf.user_id = :user_id
        ORDER BY cf.created_at DESC
        LIMIT :limit OFFSET :offset
    ");
    $stmt->bindParam(':user_id', $targetUserId);
    $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $commercialPosts = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        // Получаем все изображения для коммерческого поста
        $imgStmt = $db->prepare("SELECT image_url FROM commercial_post_images WHERE commercial_post_id = ? ORDER BY image_order ASC, id ASC");
        $imgStmt->execute([(int)$row['id']]);
        $images = $imgStmt->fetchAll(PDO::FETCH_COLUMN);

        if (empty($images) && !empty($row['image_url'])) {
            $images = [$row['image_url']];
        }

        $commercialPosts[] = [
            'id' => (int)$row['id'],
            'user_id' => (int)$row['user_id'],
            'album_id' => (int)$row['album_id'],
            'title' => $row['title'],
            'description' => $row['description'],
            'image_url' => $row['image_url'], // For backward compatibility
            'images' => $images,
            'price' => isset($row['price']) ? (float)$row['price'] : null,
            'currency' => $row['currency'],
            'contact_info' => $row['contact_info'],
            'is_active' => (bool)$row['is_active'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],
            'favorited_at' => $row['favorited_at'],
            'user_name' => trim(($row['first_name'] ?? '') . ' ' . ($row['last_name'] ?? '')),
            'user_profile_image' => $row['profile_image_url'],
            'album_title' => $row['album_title'],
        ];
    }
    
    // Вычисляем общее количество страниц
    $totalPages = ceil($total / $perPage);
    $commercialTotalPages = ceil($commercialTotal / $perPage);
    
    debugLog("Отправляем ответ с " . count($commercialPosts) . " коммерческими постами");
    debugLog("Коммерческие посты: " . print_r($commercialPosts, true));
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'data' => [
            'photos' => $photos,
            'pagination' => [
                'total' => $total,
                'per_page' => $perPage,
                'current_page' => $page,
                'total_pages' => $totalPages
            ],
            // Новое: коммерческие посты в избранном
            'commercial_posts' => $commercialPosts,
            'commercial_pagination' => [
                'total' => $commercialTotal,
                'per_page' => $perPage,
                'current_page' => $page,
                'total_pages' => $commercialTotalPages
            ]
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при получении избранных фотографий: " . $e->getMessage(), 500);
} 