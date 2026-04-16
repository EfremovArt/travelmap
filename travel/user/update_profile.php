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

// Логируем входящие данные
error_log("Update profile request: " . json_encode($input));

// Проверяем наличие необходимых данных
$firstName = isset($input['firstName']) ? trim($input['firstName']) : null;
$lastName = isset($input['lastName']) ? trim($input['lastName']) : null;
// Проверяем разные варианты названия поля даты рождения
$birthday = isset($input['birthday']) ? trim($input['birthday']) : 
            (isset($input['dateOfBirth']) ? trim($input['dateOfBirth']) : 
            (isset($input['date_of_birth']) ? trim($input['date_of_birth']) : null));

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
        error_log("Processing birthday: $birthday");
        
        // Пробуем разные форматы даты
        $formats = [
            'Y-m-d',           // 2024-01-15
            'Y-m-d H:i:s',     // 2024-01-15 00:00:00
            'Y-m-d\TH:i:s',    // 2024-01-15T00:00:00 (ISO 8601)
            'Y-m-d\TH:i:s.u',  // 2024-01-15T00:00:00.000 (ISO 8601 с миллисекундами)
            'Y-m-d\TH:i:s\Z',  // 2024-01-15T00:00:00Z (ISO 8601 UTC)
            'm/d/Y',           // 01/15/2024
            'd.m.Y',           // 15.01.2024
            'd-m-Y'            // 15-01-2024
        ];
        
        foreach ($formats as $format) {
            $birthdayDate = DateTime::createFromFormat($format, $birthday);
            if ($birthdayDate && $birthdayDate->format($format) === $birthday) {
                $birthdayFormatted = $birthdayDate->format('Y-m-d');
                error_log("Birthday parsed successfully with format '$format': $birthdayFormatted");
                break;
            }
        }
        
        // Если не удалось распарсить точно, пробуем strtotime
        if (!$birthdayFormatted) {
            $timestamp = strtotime($birthday);
            if ($timestamp !== false) {
                $birthdayFormatted = date('Y-m-d', $timestamp);
                error_log("Birthday parsed with strtotime: $birthdayFormatted");
            } else {
                error_log("Failed to parse birthday with all methods: $birthday");
            }
        }
    }
    
    // Обновляем данные пользователя
    // Сохраняем дату рождения в обе колонки для совместимости
    $stmt = $db->prepare("
        UPDATE users 
        SET first_name = :first_name, 
            last_name = :last_name,
            birthday = :birthday,
            date_of_birth = :date_of_birth,
            updated_at = NOW()
        WHERE id = :user_id
    ");
    $stmt->bindParam(':first_name', $firstName);
    $stmt->bindParam(':last_name', $lastName);
    $stmt->bindParam(':birthday', $birthdayFormatted);
    $stmt->bindParam(':date_of_birth', $birthdayFormatted);
    $stmt->bindParam(':user_id', $userId);
    $result = $stmt->execute();
    
    error_log("Update result: " . ($result ? 'success' : 'failed') . ", rows affected: " . $stmt->rowCount());
    
    // Проверяем что сохранилось
    $checkStmt = $db->prepare("SELECT birthday, date_of_birth FROM users WHERE id = :user_id");
    $checkStmt->execute([':user_id' => $userId]);
    $savedData = $checkStmt->fetch(PDO::FETCH_ASSOC);
    error_log("Saved data - birthday: " . ($savedData['birthday'] ?? 'NULL') . ", date_of_birth: " . ($savedData['date_of_birth'] ?? 'NULL'));
    
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