<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$currentUserId = requireAuth();

// Обрабатываем только методы GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

// Получаем ID пользователя из параметров запроса
if (!isset($_GET['user_id'])) {
    handleError("Отсутствует обязательный параметр: user_id", 400);
}

$userId = intval($_GET['user_id']);

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Получаем данные пользователя из базы
    $stmt = $db->prepare("
        SELECT id, first_name, last_name, profile_image_url, email
        FROM users
        WHERE id = :user_id
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    $user = $stmt->fetch();
    
    if (!$user) {
        handleError("Пользователь с ID $userId не найден", 404);
    }
    
    // Подготавливаем данные для ответа
    $userData = [
        'id' => $user['id'],
        'firstName' => $user['first_name'],
        'lastName' => $user['last_name'],
        'profileImageUrl' => $user['profile_image_url'],
        'email' => $user['email']
    ];
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'userData' => $userData
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_user_by_id.php: " . $e->getMessage());
    handleError("Ошибка при получении информации о пользователе: " . $e->getMessage(), 500);
} 