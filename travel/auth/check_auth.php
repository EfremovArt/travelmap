<?php
require_once '../config.php';
initApi();

// Логируем для отладки
error_log("Request method: " . $_SERVER['REQUEST_METHOD']);
error_log("Session ID: " . session_id());
error_log("User in session: " . (isset($_SESSION['user_id']) ? $_SESSION['user_id'] : 'not set'));
error_log("Cookie headers: " . (isset($_SERVER['HTTP_COOKIE']) ? $_SERVER['HTTP_COOKIE'] : 'not set'));

// Обработка запроса только методом GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

// Запускаем сессию и проверяем авторизацию
session_start();

// Проверяем, авторизован ли пользователь
if (!isset($_SESSION['user_id'])) {
    error_log("User not authorized in session");
    echo json_encode([
        'success' => false,
        'isAuthenticated' => false,
        'message' => 'Пользователь не авторизован'
    ]);
    exit;
}

try {
    // Получаем ID пользователя из сессии
    $userId = $_SESSION['user_id'];
    error_log("Found user ID in session: $userId");
    
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Получаем данные пользователя из базы
    $stmt = $db->prepare("
        SELECT id, google_id, email, first_name, last_name, profile_image_url, birthday
        FROM users
        WHERE id = :user_id
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    $user = $stmt->fetch();
    
    if (!$user) {
        // Если пользователь удален из базы данных, очищаем сессию
        error_log("User ID $userId not found in database");
        session_unset();
        session_destroy();
        
        echo json_encode([
            'success' => false,
            'isAuthenticated' => false,
            'message' => 'Пользователь не найден'
        ]);
        exit;
    }
    
    error_log("User found in database: " . $user['email']);
    
    // Подготавливаем данные для ответа
    $userData = [
        'id' => $user['id'],
        'email' => $user['email'],
        'firstName' => $user['first_name'],
        'lastName' => $user['last_name'],
        'profileImageUrl' => $user['profile_image_url'],
        'birthday' => $user['birthday'],
        'googleId' => $user['google_id']
    ];
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'isAuthenticated' => true,
        'userData' => $userData,
        'sessionId' => session_id()
    ]);
    
} catch (Exception $e) {
    error_log("Error in check_auth.php: " . $e->getMessage());
    handleError("Ошибка при проверке аутентификации: " . $e->getMessage(), 500);
} 