<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обрабатываем только метод POST (совместимость с клиентом) и DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    handleError('Метод не поддерживается', 405);
}

// Получаем данные из запроса
$input = [];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Поддерживаем формы (application/x-www-form-urlencoded) и JSON
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        $input = $decoded;
    } else {
        $input = $_POST;
    }
} else {
    // Для DELETE читаем тело как JSON
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        $input = $decoded;
    }
}

if (!isset($input['photo_id'])) {
    handleError('Отсутствует обязательное поле: photo_id', 400);
}

$photoId = $input['photo_id'];

try {
    $db = connectToDatabase();

    // Определяем реальный ID фотографии в базе данных
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

    // Если фотография не найдена — считаем, что лайка нет, возвращаем корректный ответ
    if (!$realPhotoId) {
        echo json_encode([
            'success' => true,
            'message' => 'Лайк не существует (фото не найдено)',
            'likesCount' => 0,
            'debug_info' => [
                'photo_id_type' => gettype($photoId),
                'photo_id_value' => $photoId,
                'real_photo_id' => null,
            ],
        ]);
        exit;
    }

    // Удаляем лайк
    $stmt = $db->prepare('DELETE FROM likes WHERE user_id = :user_id AND photo_id = :photo_id');
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':photo_id', $realPhotoId);
    $stmt->execute();

    $rowCount = $stmt->rowCount();

    // Получаем новое количество лайков
    $cntStmt = $db->prepare('SELECT COUNT(*) as likes_count FROM likes WHERE photo_id = :photo_id');
    $cntStmt->bindParam(':photo_id', $realPhotoId);
    $cntStmt->execute();
    $likesCount = (int)($cntStmt->fetch()['likes_count'] ?? 0);

    echo json_encode([
        'success' => true,
        'message' => $rowCount > 0 ? 'Лайк удален успешно' : 'Лайк не существует',
        'likesCount' => $likesCount,
        'debug_info' => [
            'photo_id_type' => gettype($photoId),
            'photo_id_value' => $photoId,
            'real_photo_id' => $realPhotoId,
            'rows_affected' => $rowCount,
        ],
    ]);
} catch (Exception $e) {
    handleError('Ошибка при удалении лайка: ' . $e->getMessage(), 500);
}
