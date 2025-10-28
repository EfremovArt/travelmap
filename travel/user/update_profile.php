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
$firstName = isset($input['firstName']) ? trim($input['firstName']) : null;
$lastName = isset($input['lastName']) ? trim($input['lastName']) : null;
$birthday = isset($input['birthday']) ? trim($input['birthday']) : null;

// Валидация данных
if (empty($firstName)) {
    handleError("Имя обязательно для заполнения", 400);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Преобразуем дату рождения в формат SQL, если она предоставлена
    $birthdayFormatted = null;
    if (!empty($birthday)) {
        // Проверяем, в каком формате пришла дата
        if (strpos($birthday, '-') !== false) {
            // Уже в формате yyyy-MM-dd
            $birthdayDate = DateTime::createFromFormat('Y-m-d', $birthday);
            if ($birthdayDate) {
                $birthdayFormatted = $birthday;
                error_log("Birthday already in correct format: $birthdayFormatted");
            }
        } else {
            // В формате MM/dd/yyyy
            $birthdayDate = DateTime::createFromFormat('m/d/Y', $birthday);
            if ($birthdayDate) {
                $birthdayFormatted = $birthdayDate->format('Y-m-d');
                error_log("Birthday converted from MM/dd/yyyy to: $birthdayFormatted");
            }
        }
        
        if (!$birthdayFormatted) {
            error_log("Failed to parse birthday: $birthday");
        }
    }
    
    // Обновляем данные пользователя
    $stmt = $db->prepare("
        UPDATE users 
        SET first_name = :first_name, 
            last_name = :last_name,
            birthday = :birthday,
            updated_at = NOW()
        WHERE id = :user_id
    ");
    $stmt->bindParam(':first_name', $firstName);
    $stmt->bindParam(':last_name', $lastName);
    $stmt->bindParam(':birthday', $birthdayFormatted);
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    
    // Обновляем данные в сессии
    $_SESSION['first_name'] = $firstName;
    $_SESSION['last_name'] = $lastName;
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Профиль обновлен успешно',
        'userData' => [
            'id' => $userId,
            'firstName' => $firstName,
            'lastName' => $lastName,
            'birthday' => $birthdayFormatted
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при обновлении профиля: " . $e->getMessage(), 500);
} 