<?php
require_once '../config.php';
initApi();

// Включаем вывод ошибок для отладки
ini_set('display_errors', 1);
error_reporting(E_ALL);

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);
$email = $input['email'] ?? '';
$name = $input['name'] ?? '';
$photoUrl = $input['photo_url'] ?? '';
$autoReauth = $input['auto_reauth'] ?? false;

// Если запрос на автоматическую повторную авторизацию 
if ($autoReauth) {
    // Если пользователь уже авторизован
    if (isset($_SESSION['user_id'])) {
        echo json_encode([
            'success' => true,
            'message' => 'Пользователь уже авторизован',
            'isAuthenticated' => true,
            'sessionId' => session_id(),
            'userData' => [
                'id' => $_SESSION['user_id'],
                'email' => $_SESSION['email'] ?? '',
                'firstName' => $_SESSION['first_name'] ?? '',
                'lastName' => $_SESSION['last_name'] ?? '',
            ]
        ]);
        exit;
    }
    
    // Если пользователь не авторизован, используем email из запроса или сессии
    $emailToUse = $email;
    
    if (empty($emailToUse) && isset($_SESSION['last_email'])) {
        $emailToUse = $_SESSION['last_email'];
    }
    
    // Если нет email, возвращаем ошибку
    if (empty($emailToUse)) {
        echo json_encode([
            'success' => false,
            'message' => 'Не удалось восстановить сессию - отсутствует email',
            'isAuthenticated' => false
        ]);
        exit;
    }
    
    // Получаем пользователя по email
    $db = connectToDatabase();
    $stmt = $db->prepare("SELECT * FROM users WHERE email = :email");
    $stmt->bindParam(':email', $emailToUse);
    $stmt->execute();
    $user = $stmt->fetch();
    
    if ($user) {
        // Восстанавливаем сессию
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['email'] = $user['email'];
        $_SESSION['first_name'] = $user['first_name'];
        $_SESSION['last_name'] = $user['last_name'];
        $_SESSION['last_email'] = $user['email']; // Сохраняем для восстановления сессии
        
        echo json_encode([
            'success' => true,
            'message' => 'Сессия восстановлена',
            'isAuthenticated' => true,
            'sessionId' => session_id(),
            'userData' => [
                'id' => $user['id'],
                'email' => $user['email'],
                'firstName' => $user['first_name'],
                'lastName' => $user['last_name'],
                'profileImageUrl' => $user['profile_image_url'],
                'googleId' => $user['google_id']
            ]
        ]);
        exit;
    } else {
        // Если пользователь не найден, возвращаем ошибку
        echo json_encode([
            'success' => false,
            'message' => 'Пользователь не найден',
            'isAuthenticated' => false
        ]);
        exit;
    }
}

// Проверка на наличие токена
$idToken = $input['id_token'] ?? null;
$accessToken = $input['access_token'] ?? null;

// Логирование для отладки
error_log("Received auth data: " . print_r($input, true));
error_log("ID Token: " . ($idToken ? 'present' : 'missing'));
error_log("Access Token: " . ($accessToken ? 'present' : 'missing'));
error_log("Email: " . $email);
error_log("Name: " . $name);

// Если нет ни одного токена, используем переданные данные напрямую
if (!$idToken && !$accessToken && empty($email) && !$autoReauth) {
    handleError("Отсутствуют данные для авторизации", 400);
}

try {
    $googleId = null;
    $payload = null;
    
    // Пытаемся верифицировать токен, если доступна библиотека
    if ($idToken && class_exists('Google_Client')) {
        $client = new Google_Client(['client_id' => GOOGLE_CLIENT_ID]);
        $payload = $client->verifyIdToken($idToken);
        
        if ($payload) {
            $googleId = $payload['sub'];
            $email = $payload['email'];
            $firstName = isset($payload['given_name']) ? $payload['given_name'] : '';
            $lastName = isset($payload['family_name']) ? $payload['family_name'] : '';
            $profileImageUrl = isset($payload['picture']) ? $payload['picture'] : '';
            
            error_log("Token verified with Google_Client. Email: $email");
        } else {
            error_log("Failed to verify token with Google_Client");
        }
    } 
    // Пытаемся использовать access_token, если id_token не сработал или недоступен
    else if ($accessToken) {
        error_log("Using access_token for authentication");
        
        // Если у нас есть email из запроса, используем его
        if (!empty($email)) {
            // Генерируем уникальный ID на основе email
            $googleId = 'access_' . md5($email . time());
            $nameParts = explode(' ', $name, 2);
            $firstName = $nameParts[0] ?? '';
            $lastName = $nameParts[1] ?? '';
            $profileImageUrl = $photoUrl;
            
            error_log("Using email from request with access_token: $email");
        } 
        else {
            error_log("No email in request with access_token");
            handleError("Не удалось получить email пользователя через access_token", 400);
        }
    }
    // Fallback на прямое использование данных из запроса
    else {
        // Fallback режим: используем данные, полученные от клиента напрямую
        error_log("Using fallback mode for token verification");
        
        // Генерируем уникальный ID на основе email
        $googleId = 'manual_' . md5($email . time());
        $nameParts = explode(' ', $name, 2);
        $firstName = $nameParts[0] ?? '';
        $lastName = $nameParts[1] ?? '';
        $profileImageUrl = $photoUrl;
        
        error_log("Fallback data: googleId=$googleId, firstName=$firstName, lastName=$lastName");
    }
    
    // Проверяем, есть ли критически важные данные
    if (empty($email) && !$autoReauth) {
        handleError("Не удалось получить email пользователя", 400);
    }
    
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Проверяем, существует ли пользователь в базе данных
    if (!empty($email)) {
        $stmt = $db->prepare("SELECT * FROM users WHERE email = :email");
        $stmt->bindParam(':email', $email);
        $stmt->execute();
        $user = $stmt->fetch();
        
        if ($user) {
            // Обновляем данные существующего пользователя
            $stmt = $db->prepare("
                UPDATE users 
                SET first_name = :first_name, last_name = :last_name, 
                    profile_image_url = :profile_image_url, updated_at = NOW()
                WHERE id = :id
            ");
            
            if (empty($firstName)) $firstName = $user['first_name'];
            if (empty($lastName)) $lastName = $user['last_name'];
            if (empty($profileImageUrl)) $profileImageUrl = $user['profile_image_url'];
            
            $stmt->bindParam(':first_name', $firstName);
            $stmt->bindParam(':last_name', $lastName);
            $stmt->bindParam(':profile_image_url', $profileImageUrl);
            $stmt->bindParam(':id', $user['id']);
            $stmt->execute();
            
            $userId = $user['id'];
        } else if (!$autoReauth) {
            // Создаем нового пользователя
            $stmt = $db->prepare("
                INSERT INTO users (google_id, email, first_name, last_name, profile_image_url)
                VALUES (:google_id, :email, :first_name, :last_name, :profile_image_url)
            ");
            $stmt->bindParam(':google_id', $googleId);
            $stmt->bindParam(':email', $email);
            $stmt->bindParam(':first_name', $firstName);
            $stmt->bindParam(':last_name', $lastName);
            $stmt->bindParam(':profile_image_url', $profileImageUrl);
            $stmt->execute();
            
            $userId = $db->lastInsertId();
        } else {
            // Если это автоматическая авторизация, но пользователя нет - возвращаем ошибку
            echo json_encode([
                'success' => false,
                'message' => 'Пользователь не найден',
                'isAuthenticated' => false
            ]);
            exit;
        }
        
        // НЕ вызываем session_start() повторно, так как он уже запущен в initApi()
        $_SESSION['user_id'] = $userId;
        $_SESSION['email'] = $email;
        $_SESSION['first_name'] = $firstName;
        $_SESSION['last_name'] = $lastName;
        $_SESSION['last_email'] = $email; // Сохраняем для восстановления сессии
        
        // Подготавливаем данные для ответа
        $userData = [
            'id' => $userId,
            'email' => $email,
            'firstName' => $firstName,
            'lastName' => $lastName,
            'profileImageUrl' => $profileImageUrl,
            'googleId' => $googleId, // Добавляем googleId для проверки в клиенте
        ];
        
        // Логируем сведения о сессии
        error_log("Session created. User ID: $userId, Email: $email");
        error_log("Session ID: " . session_id());
        
        // Подробно логируем ответ
        $responseData = [
            'success' => true,
            'message' => 'Аутентификация успешна',
            'userData' => $userData,
            'isAuthenticated' => true, // Добавляем для совместимости с другими эндпоинтами
            'sessionId' => session_id() // Добавляем ID сессии для клиента
        ];
        
        error_log("Response data: " . json_encode($responseData));
        
        // Установим cookie явно
        setcookie('PHPSESSID', session_id(), 0, '/', '', isset($_SERVER['HTTPS']), false);
        
        // Отправляем ТОЛЬКО JSON ответ без предупреждений PHP
        header("Content-Type: application/json; charset=UTF-8");
        echo json_encode($responseData);
        
        // Завершаем скрипт
        exit();
    } else {
        // Если не указан email
        handleError("Отсутствует email пользователя", 400);
    }
    
} catch (Exception $e) {
    // Логируем детали ошибки для отладки
    error_log("Google Auth Error: " . $e->getMessage());
    handleError("Ошибка при обработке авторизации: " . $e->getMessage(), 500);
} 