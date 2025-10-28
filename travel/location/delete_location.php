<?php
// Подключение к базе данных и проверка аутентификации
require_once '../config.php';

// Инициализация API (включает настройку сессии и заголовков)
initApi();

// Инициализация подключения к базе данных
$pdo = connectToDatabase();

// Заголовки для CORS и JSON
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: DELETE, OPTIONS, POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization, Cookie");
header("Access-Control-Allow-Credentials: true");
header("Content-Type: application/json; charset=UTF-8");

// Обработка OPTIONS запроса (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Проверка метода запроса
if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

// Проверка аутентификации
$user = checkAuth();
error_log("Delete location - Auth check result: " . ($user ? "Authorized (User ID: " . $user['id'] . ")" : "Not authorized"));
error_log("Delete location - Request method: " . $_SERVER['REQUEST_METHOD']);
error_log("Delete location - POST data: " . print_r($_POST, true));
error_log("Delete location - Raw input: " . file_get_contents('php://input'));
error_log("Delete location - Cookies: " . print_r($_COOKIE, true));
error_log("Delete location - Session ID: " . session_id());
error_log("Delete location - Session data: " . print_r($_SESSION, true));

if (!$user) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit();
}

// Получение ID локации из запроса (поддержка как GET, так и POST)
$locationId = null;
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $locationId = isset($_GET['id']) ? $_GET['id'] : null;
} else {
    // Для POST запросов проверяем как $_POST, так и данные из php://input
    $locationId = isset($_POST['id']) ? $_POST['id'] : null;
    if (!$locationId) {
        // Если нет в $_POST, пробуем получить из php://input как JSON
        $input = file_get_contents('php://input');
        $jsonData = json_decode($input, true);
        if ($jsonData && isset($jsonData['id'])) {
            $locationId = $jsonData['id'];
        }
    }
}

error_log("Delete location - Location ID: " . ($locationId ?? 'not found'));
error_log("Delete location - JSON data: " . print_r(json_decode(file_get_contents('php://input'), true), true));

if (!$locationId) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Location ID is required']);
    exit();
}

try {
    // Проверка владельца локации
    $stmt = $pdo->prepare("SELECT user_id FROM locations WHERE id = ?");
    $stmt->execute([$locationId]);
    $location = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$location) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Location not found']);
        exit();
    }
    
    // Проверка, является ли текущий пользователь владельцем локации
    if ($location['user_id'] != $user['id']) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'You do not have permission to delete this location']);
        exit();
    }
    
    // Начало транзакции
    $pdo->beginTransaction();
    
    // Сначала получаем список файлов изображений для удаления
    $stmt = $pdo->prepare("SELECT file_path FROM photos WHERE location_id = ?");
    $stmt->execute([$locationId]);
    $photos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Удаление записей фотографий из базы данных
    $stmt = $pdo->prepare("DELETE FROM photos WHERE location_id = ?");
    $stmt->execute([$locationId]);
    
    // Удаление локации
    $stmt = $pdo->prepare("DELETE FROM locations WHERE id = ?");
    $stmt->execute([$locationId]);
    
    // Фиксация транзакции
    $pdo->commit();
    
    // Удаление файлов изображений с сервера
    foreach ($photos as $photo) {
        $filePath = $_SERVER['DOCUMENT_ROOT'] . $photo['file_path'];
        if (file_exists($filePath)) {
            unlink($filePath);
        }
    }
    
    // Отправка успешного ответа
    echo json_encode(['success' => true, 'message' => 'Location deleted successfully']);
    
} catch (PDOException $e) {
    // Откат транзакции в случае ошибки
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    exit();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
    exit();
}
?> 