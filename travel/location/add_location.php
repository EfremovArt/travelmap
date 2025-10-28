<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['title']) || !isset($input['latitude']) || !isset($input['longitude'])) {
    handleError("Отсутствуют обязательные поля: title, latitude, longitude", 400);
}

$title = trim($input['title']);
$description = isset($input['description']) ? trim($input['description']) : null;
$latitude = floatval($input['latitude']);
$longitude = floatval($input['longitude']);
$address = isset($input['address']) ? trim($input['address']) : null;
$city = isset($input['city']) ? trim($input['city']) : null;
$country = isset($input['country']) ? trim($input['country']) : null;

// Валидация данных
if (empty($title)) {
    handleError("Название локации обязательно для заполнения", 400);
}

if ($latitude < -90 || $latitude > 90) {
    handleError("Широта должна быть в диапазоне от -90 до 90", 400);
}

if ($longitude < -180 || $longitude > 180) {
    handleError("Долгота должна быть в диапазоне от -180 до 180", 400);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Добавляем новую локацию
    $stmt = $db->prepare("
        INSERT INTO locations (user_id, title, description, latitude, longitude, address, city, country)
        VALUES (:user_id, :title, :description, :latitude, :longitude, :address, :city, :country)
    ");
    $stmt->bindParam(':user_id', $userId);
    $stmt->bindParam(':title', $title);
    $stmt->bindParam(':description', $description);
    $stmt->bindParam(':latitude', $latitude);
    $stmt->bindParam(':longitude', $longitude);
    $stmt->bindParam(':address', $address);
    $stmt->bindParam(':city', $city);
    $stmt->bindParam(':country', $country);
    $stmt->execute();
    
    $locationId = $db->lastInsertId();
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Локация добавлена успешно',
        'location' => [
            'id' => $locationId,
            'userId' => $userId,
            'title' => $title,
            'description' => $description,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'address' => $address,
            'city' => $city,
            'country' => $country,
            'createdAt' => date('Y-m-d H:i:s')
        ],
        'debug_info' => [
            'db_working' => $db ? true : false,
            'userId' => $userId,
            'params_received' => [
                'title' => $title ? 'yes' : 'no',
                'latitude' => $latitude ? 'yes' : 'no',
                'longitude' => $longitude ? 'yes' : 'no'
            ]
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при добавлении локации: " . $e->getMessage(), 500);
} 