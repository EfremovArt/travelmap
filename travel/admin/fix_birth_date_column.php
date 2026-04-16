<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();

echo "<h2>Исправление колонки date_of_birth</h2>";

// 1. Проверяем существование колонки
echo "<h3>1. Проверка колонки date_of_birth</h3>";
try {
    $stmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'date_of_birth'");
    $column = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($column) {
        echo "<p style='color: green;'>✓ Колонка date_of_birth существует</p>";
        echo "<pre>";
        print_r($column);
        echo "</pre>";
    } else {
        echo "<p style='color: orange;'>⚠ Колонка date_of_birth не существует</p>";
        echo "<p>Создаем колонку...</p>";
        
        try {
            $pdo->exec("ALTER TABLE users ADD COLUMN date_of_birth DATE NULL AFTER email");
            echo "<p style='color: green;'>✓ Колонка date_of_birth успешно создана</p>";
            
            // Проверяем снова
            $stmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'date_of_birth'");
            $column = $stmt->fetch(PDO::FETCH_ASSOC);
            echo "<pre>";
            print_r($column);
            echo "</pre>";
        } catch (Exception $e) {
            echo "<p style='color: red;'>✗ Ошибка создания: " . $e->getMessage() . "</p>";
        }
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 2. Проверяем все колонки таблицы users
echo "<h3>2. Все колонки таблицы users</h3>";
try {
    $stmt = $pdo->query("SHOW COLUMNS FROM users");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>";
    foreach ($columns as $col) {
        $highlight = $col['Field'] === 'date_of_birth' ? 'background-color: #90EE90;' : '';
        echo "<tr style='$highlight'>";
        echo "<td><strong>{$col['Field']}</strong></td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "<td>" . ($col['Default'] ?? 'NULL') . "</td>";
        echo "<td>{$col['Extra']}</td>";
        echo "</tr>";
    }
    echo "</table>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 3. Тестовое обновление даты рождения
echo "<h3>3. Тестовое обновление даты рождения</h3>";
echo "<form method='post'>";
echo "<p>Выберите пользователя:</p>";
echo "<select name='user_id' required>";

try {
    $stmt = $pdo->query("SELECT id, first_name, last_name, email FROM users ORDER BY id DESC LIMIT 20");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($users as $user) {
        echo "<option value='{$user['id']}'>{$user['id']} - {$user['first_name']} {$user['last_name']} ({$user['email']})</option>";
    }
} catch (Exception $e) {
    echo "<option>Ошибка загрузки пользователей</option>";
}

echo "</select>";
echo "<p>Дата рождения: <input type='date' name='birth_date' required></p>";
echo "<button type='submit' name='update_birth_date'>Обновить дату рождения</button>";
echo "</form>";

if (isset($_POST['update_birth_date'])) {
    $userId = intval($_POST['user_id']);
    $birthDate = $_POST['birth_date'];
    
    try {
        $stmt = $pdo->prepare("UPDATE users SET date_of_birth = :birth_date WHERE id = :user_id");
        $stmt->execute([
            ':birth_date' => $birthDate,
            ':user_id' => $userId
        ]);
        
        echo "<p style='color: green;'>✓ Дата рождения успешно обновлена для пользователя ID: $userId</p>";
        
        // Проверяем результат
        $stmt = $pdo->prepare("SELECT id, first_name, last_name, date_of_birth FROM users WHERE id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        echo "<p><strong>Результат:</strong></p>";
        echo "<pre>";
        print_r($user);
        echo "</pre>";
        
        echo "<p><a href='views/user_details.php?id=$userId' target='_blank'>Открыть профиль пользователя в админке</a></p>";
    } catch (Exception $e) {
        echo "<p style='color: red;'>✗ Ошибка обновления: " . $e->getMessage() . "</p>";
    }
}

// 4. Проверка API приложения для обновления профиля
echo "<h3>4. Проверка API приложения</h3>";
echo "<p>Проверьте, что API приложения для обновления профиля сохраняет дату рождения:</p>";
echo "<ul>";
echo "<li>Файл API: <code>/travel/user/update_profile.php</code></li>";
echo "<li>Должен принимать параметр <code>birthday</code>, <code>date_of_birth</code> или <code>dateOfBirth</code></li>";
echo "<li>Должен сохранять значение в колонку <code>date_of_birth</code> таблицы <code>users</code></li>";
echo "</ul>";

// Ищем файлы API для обновления профиля
echo "<p><strong>Поиск файлов API для обновления профиля:</strong></p>";
// Проверка файла API для обновления профиля
$apiFile = '../user/update_profile.php';
if (file_exists($apiFile)) {
    echo "<p style='color: green;'>✓ Файл API найден: <code>/travel/user/update_profile.php</code></p>";
    
    // Проверяем содержимое файла
    $content = file_get_contents($apiFile);
    $checks = [
        'Поле birthday' => strpos($content, 'birthday') !== false,
        'Поле dateOfBirth' => strpos($content, 'dateOfBirth') !== false,
        'Колонка date_of_birth' => strpos($content, 'date_of_birth') !== false,
        'Логирование включено' => strpos($content, 'error_log') !== false
    ];
    
    echo "<p><strong>Проверка содержимого API:</strong></p>";
    echo "<ul>";
    foreach ($checks as $check => $result) {
        $icon = $result ? '✓' : '✗';
        $color = $result ? 'green' : 'red';
        echo "<li style='color: $color;'>$icon $check</li>";
    }
    echo "</ul>";
    
    echo "<div style='margin: 20px 0;'>";
    echo "<a href='view_logs.php' class='btn btn-primary' target='_blank' style='margin-right: 10px;'>📋 Просмотреть логи PHP</a>";
    echo "<a href='view_request_debug.php' class='btn btn-info' target='_blank'>🔍 Отладка запросов от приложения</a>";
    echo "</div>";
    
    echo "<div class='alert alert-info'>";
    echo "<h4>Инструкция для отладки:</h4>";
    echo "<ol>";
    echo "<li>Попросите пользователя обновить дату рождения в приложении</li>";
    echo "<li>Откройте <a href='view_logs.php' target='_blank'>логи PHP</a> и найдите записи с 'birthday' или 'Update profile'</li>";
    echo "<li>Если логов нет, значит запрос не доходит до API - проверьте URL в приложении</li>";
    echo "</ol>";
    echo "</div>";
} else {
    echo "<p style='color: red;'>✗ Файл API не найден: <code>/travel/user/update_profile.php</code></p>";
}

echo "<hr>";
echo "<p><a href='test_birth_date_api.php'>← Вернуться к тесту даты рождения</a></p>";
echo "<p><a href='views/users.php'>← Вернуться к списку пользователей</a></p>";
?>
