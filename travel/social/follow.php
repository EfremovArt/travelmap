<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обрабатываем только методы POST и DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['follow_id'])) {
    handleError("Отсутствует обязательное поле: follow_id", 400);
}

$followId = intval($input['follow_id']);

// Проверяем, что пользователь не пытается подписаться на самого себя
if ($followId === $userId) {
    handleError("Невозможно подписаться на самого себя", 400);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();

    // Проверяем существование пользователя, на которого подписываются
    $stmt = $db->prepare("SELECT id FROM users WHERE id = :follow_id");
    $stmt->bindParam(':follow_id', $followId);
    $stmt->execute();
    
    if (!$stmt->fetch()) {
        handleError("Пользователь не найден", 404);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Подписка на пользователя
        
        // Проверяем, существует ли уже подписка
        $stmt = $db->prepare("
            SELECT id FROM follows 
            WHERE follower_id = :follower_id AND followed_id = :followed_id
        ");
        $stmt->bindParam(':follower_id', $userId);
        $stmt->bindParam(':followed_id', $followId);
        $stmt->execute();
        
        if ($stmt->fetch()) {
            // Подписка уже существует, ничего не делаем
            echo json_encode([
                'success' => true,
                'message' => 'Подписка уже существует'
            ]);
            exit;
        }
        
        // Добавляем новую подписку
        $stmt = $db->prepare("
            INSERT INTO follows (follower_id, followed_id)
            VALUES (:follower_id, :followed_id)
        ");
        $stmt->bindParam(':follower_id', $userId);
        $stmt->bindParam(':followed_id', $followId);
        $stmt->execute();
        
        $followRecordId = $db->lastInsertId();
        
        // Получаем информацию о пользователе, на которого подписались
        $stmt = $db->prepare("
            SELECT first_name, last_name, profile_image_url
            FROM users
            WHERE id = :follow_id
        ");
        $stmt->bindParam(':follow_id', $followId);
        $stmt->execute();
        $followedUser = $stmt->fetch();
        
        // Получаем количество подписчиков и подписок
        $stmt = $db->prepare("
            SELECT COUNT(*) as followers_count 
            FROM follows 
            WHERE followed_id = :follow_id
        ");
        $stmt->bindParam(':follow_id', $followId);
        $stmt->execute();
        $followersCount = $stmt->fetch()['followers_count'];
        
        $stmt = $db->prepare("
            SELECT COUNT(*) as following_count 
            FROM follows 
            WHERE follower_id = :user_id
        ");
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();
        $followingCount = $stmt->fetch()['following_count'];
        
        // Отправляем успешный ответ
        echo json_encode([
            'success' => true,
            'message' => 'Подписка оформлена успешно',
            'follow' => [
                'id' => $followRecordId,
                'followerId' => $userId,
                'followedId' => $followId,
                'followedUser' => [
                    'firstName' => $followedUser['first_name'],
                    'lastName' => $followedUser['last_name'],
                    'profileImageUrl' => $followedUser['profile_image_url']
                ]
            ],
            'counters' => [
                'followersCount' => $followersCount,
                'followingCount' => $followingCount
            ]
        ]);
        
    } else if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        // Отписка от пользователя
        
        // Удаляем подписку
        $stmt = $db->prepare("
            DELETE FROM follows 
            WHERE follower_id = :follower_id AND followed_id = :followed_id
        ");
        $stmt->bindParam(':follower_id', $userId);
        $stmt->bindParam(':followed_id', $followId);
        $stmt->execute();
        
        $rowCount = $stmt->rowCount();
        
        if ($rowCount === 0) {
            echo json_encode([
                'success' => true,
                'message' => 'Подписка не существует'
            ]);
            exit;
        }
        
        // Получаем обновленное количество подписчиков и подписок
        $stmt = $db->prepare("
            SELECT COUNT(*) as followers_count 
            FROM follows 
            WHERE followed_id = :follow_id
        ");
        $stmt->bindParam(':follow_id', $followId);
        $stmt->execute();
        $followersCount = $stmt->fetch()['followers_count'];
        
        $stmt = $db->prepare("
            SELECT COUNT(*) as following_count 
            FROM follows 
            WHERE follower_id = :user_id
        ");
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();
        $followingCount = $stmt->fetch()['following_count'];
        
        // Отправляем успешный ответ
        echo json_encode([
            'success' => true,
            'message' => 'Отписка выполнена успешно',
            'counters' => [
                'followersCount' => $followersCount,
                'followingCount' => $followingCount
            ]
        ]);
    }
    
} catch (Exception $e) {
    handleError("Ошибка при работе с подпиской: " . $e->getMessage(), 500);
}