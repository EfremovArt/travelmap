<?php
require_once '../config.php';
initApi();

// Требуется авторизация для доступа
$userId = requireAuth();

// Проверяем наличие обязательного параметра
if (!isset($_GET['photo_id'])) {
    handleError('Отсутствует обязательный параметр: photo_id', 400);
}

$photoId = $_GET['photo_id'];

try {
    $db = connectToDatabase();

    // Определяем реальный ID фотографии (числовой ID или UUID)
    $realPhotoId = null;

    if (is_numeric($photoId)) {
        $stmt = $db->prepare('SELECT id FROM photos WHERE id = :photo_id');
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        }
    } elseif (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $photoId)) {
        $stmt = $db->prepare('SELECT id FROM photos WHERE uuid = :uuid');
        $stmt->bindParam(':uuid', $photoId);
        $stmt->execute();
        if ($row = $stmt->fetch()) {
            $realPhotoId = $row['id'];
        }
    }

    // Если фото не найдено — возвращаем пустой список и 0
    if (!$realPhotoId) {
        echo json_encode([
            'success' => true,
            'likes' => [],
            'likesCount' => 0,
            'debug_info' => [
                'photo_id_type' => gettype($photoId),
                'photo_id_value' => $photoId,
                'real_photo_id' => null,
            ],
        ]);
        exit;
    }

    // Получаем список лайков с данными пользователей
    $stmt = $db->prepare('
        SELECT l.id as like_id, l.user_id, l.photo_id, l.created_at,
               u.first_name, u.last_name, u.profile_image_url,
               CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name
        FROM likes l
        JOIN users u ON u.id = l.user_id
        WHERE l.photo_id = :photo_id
        ORDER BY l.created_at DESC
    ');
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Считаем количество лайков
    $countStmt = $db->prepare('SELECT COUNT(*) as cnt FROM likes WHERE photo_id = :photo_id');
    $countStmt->bindParam(':photo_id', $realPhotoId);
    $countStmt->execute();
    $likesCount = (int)($countStmt->fetch()['cnt'] ?? 0);

    echo json_encode([
        'success' => true,
        'likes' => $rows,
        'likesCount' => $likesCount,
        'debug_info' => [
            'photo_id_type' => gettype($photoId),
            'photo_id_value' => $photoId,
            'real_photo_id' => $realPhotoId,
        ],
    ]);
} catch (Exception $e) {
    handleError('Ошибка при получении списка лайков: ' . $e->getMessage(), 500);
}
