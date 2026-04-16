<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();

echo "<h2>Тест даты рождения</h2>";

// Получаем ID пользователя из параметра
$userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

if ($userId > 0) {
    echo "<h3>Проверка пользователя ID: $userId</h3>";
    
    // 1. Проверяем данные в базе
    echo "<h4>1. Данные в базе данных</h4>";
    try {
        $stmt = $pdo->prepare("SELECT id, first_name, last_name, email, date_of_birth, created_at FROM users WHERE id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user) {
            echo "<table border='1' cellpadding='5'>";
            foreach ($user as $key => $value) {
                echo "<tr><td><strong>$key</strong></td><td>" . htmlspecialchars($value ?? 'NULL') . "</td></tr>";
            }
            echo "</table>";
            
            echo "<p><strong>date_of_birth тип:</strong> " . gettype($user['date_of_birth']) . "</p>";
            echo "<p><strong>date_of_birth значение:</strong> " . var_export($user['date_of_birth'], true) . "</p>";
        } else {
            echo "<p style='color: red;'>Пользователь не найден</p>";
        }
    } catch (Exception $e) {
        echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
    }
    
    // 2. Проверяем что возвращает API
    echo "<h4>2. Ответ API get_user_details.php</h4>";
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "http://bearded-fox.ru/travel/admin/api/users/get_user_details.php?user_id=$userId");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "<p><strong>HTTP Code:</strong> $httpCode</p>";
    echo "<p><strong>Raw Response:</strong></p>";
    echo "<pre>" . htmlspecialchars($response) . "</pre>";
    
    $data = json_decode($response, true);
    if ($data && isset($data['user'])) {
        echo "<p><strong>Parsed User Data:</strong></p>";
        echo "<table border='1' cellpadding='5'>";
        foreach ($data['user'] as $key => $value) {
            echo "<tr><td><strong>$key</strong></td><td>" . htmlspecialchars(var_export($value, true)) . "</td></tr>";
        }
        echo "</table>";
        
        if (isset($data['user']['dateOfBirth'])) {
            echo "<p style='color: green;'><strong>✓ dateOfBirth присутствует в ответе</strong></p>";
            echo "<p><strong>Значение:</strong> " . var_export($data['user']['dateOfBirth'], true) . "</p>";
            echo "<p><strong>Тип:</strong> " . gettype($data['user']['dateOfBirth']) . "</p>";
        } else {
            echo "<p style='color: red;'><strong>✗ dateOfBirth отсутствует в ответе</strong></p>";
        }
    }
    
    // 3. Проверяем структуру таблицы users
    echo "<h4>3. Структура таблицы users</h4>";
    try {
        $stmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'date_of_birth'");
        $column = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($column) {
            echo "<p style='color: green;'>✓ Колонка date_of_birth существует</p>";
            echo "<pre>";
            print_r($column);
            echo "</pre>";
        } else {
            echo "<p style='color: red;'>✗ Колонка date_of_birth не существует</p>";
            echo "<p>Создаем колонку...</p>";
            
            try {
                $pdo->exec("ALTER TABLE users ADD COLUMN date_of_birth DATE NULL AFTER email");
                echo "<p style='color: green;'>✓ Колонка date_of_birth создана</p>";
            } catch (Exception $e) {
                echo "<p style='color: red;'>Ошибка создания: " . $e->getMessage() . "</p>";
            }
        }
    } catch (Exception $e) {
        echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
    }
    
} else {
    // Показываем список пользователей для выбора
    echo "<h3>Выберите пользователя для проверки</h3>";
    
    try {
        $stmt = $pdo->query("
            SELECT id, first_name, last_name, email, date_of_birth, created_at
            FROM users
            ORDER BY id DESC
            LIMIT 20
        ");
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Имя</th><th>Email</th><th>Дата рождения</th><th>Действие</th></tr>";
        
        foreach ($users as $user) {
            $birthDate = $user['date_of_birth'] ?? 'NULL';
            $style = $birthDate && $birthDate !== 'NULL' ? 'color: green;' : 'color: red;';
            
            echo "<tr>";
            echo "<td>{$user['id']}</td>";
            echo "<td>{$user['first_name']} {$user['last_name']}</td>";
            echo "<td>{$user['email']}</td>";
            echo "<td style='$style'>" . htmlspecialchars($birthDate) . "</td>";
            echo "<td><a href='?user_id={$user['id']}'>Проверить</a></td>";
            echo "</tr>";
        }
        
        echo "</table>";
    } catch (Exception $e) {
        echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
    }
}

echo "<hr>";
echo "<p><a href='views/users.php'>← Вернуться к списку пользователей</a></p>";
?>
