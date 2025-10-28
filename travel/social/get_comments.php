<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

// Получаем ID фотографии из запроса
if (!isset($_GET['photo_id'])) {
    handleError("Отсутствует обязательный параметр: photo_id", 400);
}

$photoId = $_GET['photo_id'];

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
    
    // Проверяем существование фото по ID или UUID
    $realPhotoId = null;
    
    // Сначала проверяем, это числовой ID или UUID
    if (is_numeric($photoId)) {
        // Это числовой ID
        $stmt = $db->prepare("SELECT id FROM photos WHERE id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        } else {
            // Попытка найти синтетическое фото для коммерческого поста по uuid 'commercial_{id}'
            $syntheticUuid = 'commercial_' . $photoId;
            $stmt = $db->prepare("SELECT id FROM photos WHERE uuid = :photo_uuid");
            $stmt->bindParam(':photo_uuid', $syntheticUuid);
            $stmt->execute();
            if ($row = $stmt->fetch()) {
                $realPhotoId = $row['id'];
            }
        }
    } else if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $photoId)) {
        // Это UUID, ищем фотографию по UUID
        $stmt = $db->prepare("SELECT id FROM photos WHERE uuid = :photo_uuid");
        $stmt->bindParam(':photo_uuid', $photoId);
        $stmt->execute();
        
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        }
    } else {
        handleError("Некорректный формат идентификатора фотографии", 400);
    }
    
    // Если фото не найдено — возвращаем корректный пустой ответ
    if (!$realPhotoId) {
        echo json_encode([
            'success' => true,
            'message' => 'Фото не найдено, возвращаем пустой список комментариев',
            'comments' => [],
            'photoOwnerId' => 0,
            'pagination' => [
                'total' => 0,
                'perPage' => $perPage,
                'currentPage' => $page,
                'lastPage' => 1
            ],
            'debug_info' => [
                'photo_id_type' => gettype($photoId),
                'photo_id_value' => $photoId,
                'real_photo_id' => null
            ]
        ]);
        exit;
    }
    
    // Получаем информацию о владельце фото
    $stmt = $db->prepare("
        SELECT user_id as photo_owner_id
        FROM photos
        WHERE id = :photo_id
    ");
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    $photoOwner = $stmt->fetch();
    $photoOwnerId = $photoOwner ? intval($photoOwner['photo_owner_id']) : 0;
    
    // Получаем общее количество комментариев
    $stmt = $db->prepare("
        SELECT COUNT(*) as total
        FROM comments
        WHERE photo_id = :photo_id
    ");
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    $totalComments = $stmt->fetch()['total'];
    
    // Получаем комментарии с пагинацией и информацией о пользователях
    $stmt = $db->prepare("
        SELECT c.id, c.user_id, c.photo_id, c.comment, c.created_at,
               u.first_name as user_first_name, u.last_name as user_last_name, 
               u.profile_image_url as user_profile_image_url
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.photo_id = :photo_id
        ORDER BY c.created_at DESC
        LIMIT :limit OFFSET :offset
    ");
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $comments = [];
    
    while ($row = $stmt->fetch()) {
        $comments[] = [
            'id' => intval($row['id']),
            'userId' => intval($row['user_id']),
            'photoId' => $photoId, // Возвращаем исходный photoId
            'text' => $row['comment'],
            'createdAt' => $row['created_at'],
            'userFirstName' => $row['user_first_name'],
            'userLastName' => $row['user_last_name'],
            'userProfileImageUrl' => $row['user_profile_image_url']
        ];
    }
    
    // Отправляем успешный ответ с комментариями и метаданными пагинации
    echo json_encode([
        'success' => true,
        'message' => 'Комментарии получены успешно',
        'comments' => $comments,
        'photoOwnerId' => $photoOwnerId,
        'pagination' => [
            'total' => $totalComments,
            'perPage' => $perPage,
            'currentPage' => $page,
            'lastPage' => ceil($totalComments / $perPage)
        ],
        'debug_info' => [
            'photo_id_type' => gettype($photoId),
            'photo_id_value' => $photoId,
            'real_photo_id' => $realPhotoId
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при получении комментариев: " . $e->getMessage(), 500);
} 