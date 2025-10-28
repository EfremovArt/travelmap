<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Проверяем наличие необходимых параметров
if (!isset($_GET['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

$photoId = intval($_GET['photo_id']);

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Получаем информацию о фотографии
    $stmt = $db->prepare("
        SELECT p.*, u.first_name, u.last_name, u.profile_image_url,
               l.title as location_title, l.description as location_description,
               l.latitude, l.longitude,
               (SELECT COUNT(*) FROM likes WHERE photo_id = p.id) as likes_count,
               (SELECT COUNT(*) FROM favorites WHERE photo_id = p.id) as favorites_count,
               (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comments_count
        FROM photos p
        LEFT JOIN users u ON p.user_id = u.id
        LEFT JOIN locations l ON p.location_id = l.id
        WHERE p.id = :photo_id
    ");
    $stmt->bindParam(':photo_id', $photoId);
    $stmt->execute();
    
    $photo = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$photo) {
        handleError("Фотография не найдена", 404);
    }
    
    // Проверяем, поставил ли текущий пользователь лайк
    $stmt = $db->prepare("
        SELECT COUNT(*) as is_liked
        FROM likes 
        WHERE user_id = :user_id AND photo_id = :photo_id
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':photo_id', $photoId);
    $stmt->execute();
    $isLiked = $stmt->fetch(PDO::FETCH_ASSOC)['is_liked'] > 0;
    
    // Проверяем, добавил ли текущий пользователь фото в избранное
    $stmt = $db->prepare("
        SELECT COUNT(*) as is_favorite
        FROM favorites 
        WHERE user_id = :user_id AND photo_id = :photo_id
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':photo_id', $photoId);
    $stmt->execute();
    $isFavorite = $stmt->fetch(PDO::FETCH_ASSOC)['is_favorite'] > 0;
    
    // Форматируем результат
    $result = [
        'id' => $photo['id'],
        'user_id' => $photo['user_id'],
        'location_id' => $photo['location_id'],
        'title' => $photo['title'],
        'description' => $photo['description'],
        'image_url' => $photo['image_url'],
        'created_at' => $photo['created_at'],
        'author' => [
            'first_name' => $photo['first_name'],
            'last_name' => $photo['last_name'],
            'profile_image_url' => $photo['profile_image_url'],
        ],
        'location' => [
            'title' => $photo['location_title'],
            'description' => $photo['location_description'],
            'latitude' => $photo['latitude'],
            'longitude' => $photo['longitude'],
        ],
        'stats' => [
            'likes_count' => $photo['likes_count'],
            'favorites_count' => $photo['favorites_count'],
            'comments_count' => $photo['comments_count'],
            'is_liked' => $isLiked,
            'is_favorite' => $isFavorite,
        ],
    ];
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'photo' => $result
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при получении информации о фотографии: " . $e->getMessage(), 500);
} 