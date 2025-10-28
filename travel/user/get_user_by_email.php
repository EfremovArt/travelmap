<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Проверяем наличие параметра email
if (!isset($_GET['email'])) {
    handleError("Отсутствует обязательный параметр: email", 400);
}

$email = $_GET['email'];

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Получаем данные пользователя по email
    $stmt = $db->prepare("
        SELECT id, email, first_name, last_name, birth_date, bio, profile_image_url, created_at
        FROM users
        WHERE email = :email
    ");
    $stmt->bindParam(':email', $email);
    $stmt->execute();
    
    $userData = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$userData) {
        // Пользователь не найден
        echo json_encode([
            'success' => false,
            'message' => 'Пользователь не найден'
        ]);
        exit;
    }
    
    // Преобразуем данные к нужному формату
    $formattedUserData = [
        'id' => $userData['id'],
        'email' => $userData['email'],
        'firstName' => $userData['first_name'],
        'lastName' => $userData['last_name'],
        'birthDate' => $userData['birth_date'],
        'bio' => $userData['bio'],
        'profileImageUrl' => $userData['profile_image_url'],
        'createdAt' => $userData['created_at'],
    ];
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'userData' => $formattedUserData
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при получении данных пользователя: " . $e->getMessage(), 500);
} 