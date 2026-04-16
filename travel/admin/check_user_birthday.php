<?php
require_once 'config/admin_config.php';
require_once '../config.php';
adminRequireAuth();

$pdo = connectToDatabase();

// Получаем ID пользователя
$userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

if ($userId === 0) {
    echo "<h2>Выберите пользователя</h2>";
    $stmt = $pdo->query("SELECT id, first_name, last_name, email FROM users ORDER BY id DESC LIMIT 20");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<ul>";
    foreach ($users as $user) {
        $name = trim($user['first_name'] . ' ' . $user['last_name']);
        if (empty($name)) $name = 'Без имени';
        echo "<li><a href='?user_id={$user['id']}'>ID {$user['id']}: $name ({$user['email']})</a></li>";
    }
    echo "</ul>";
    exit;
}

// Проверяем данные пользователя
echo "<h2>Проверка даты рождения пользователя ID: $userId</h2>";

$stmt = $pdo->prepare("SELECT id, first_name, last_name, email, birthday, date_of_birth, created_at FROM users WHERE id = :user_id");
$stmt->execute([':user_id' => $userId]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    echo "<p style='color: red;'>Пользователь не найден</p>";
    exit;
}

echo "<h3>Данные из базы:</h3>";
echo "<table border='1' cellpadding='10'>";
echo "<tr><th>Поле</th><th>Значение</th><th>Тип</th></tr>";
foreach ($user as $key => $value) {
    $type = gettype($value);
    $displayValue = $value === null ? '<span style="color: red;">NULL</span>' : htmlspecialchars($value);
    echo "<tr><td><strong>$key</strong></td><td>$displayValue</td><td>$type</td></tr>";
}
echo "</table>";

echo "<h3>Выводы:</h3>";

if ($user['date_of_birth'] === null && $user['birthday'] === null) {
    echo "<div style='background: #ffebee; padding: 20px; border-left: 4px solid #f44336;'>";
    echo "<h4 style='color: #c62828;'>❌ Дата рождения НЕ СОХРАНЕНА</h4>";
    echo "<p>В базе данных нет даты рождения для этого пользователя.</p>";
    echo "<p><strong>Возможные причины:</strong></p>";
    echo "<ul>";
    echo "<li>Пользователь не указывал дату рождения в приложении</li>";
    echo "<li>Запрос от приложения не доходит до API</li>";
    echo "<li>API не сохраняет дату (проверьте логи)</li>";
    echo "</ul>";
    echo "<p><a href='view_logs.php' target='_blank' class='btn btn-primary'>📋 Проверить логи</a></p>";
    echo "</div>";
} else {
    $dateValue = $user['date_of_birth'] ?? $user['birthday'];
    echo "<div style='background: #e8f5e9; padding: 20px; border-left: 4px solid #4caf50;'>";
    echo "<h4 style='color: #2e7d32;'>✓ Дата рождения СОХРАНЕНА</h4>";
    echo "<p>Дата в базе: <strong style='font-size: 18px;'>$dateValue</strong></p>";
    echo "<p>Если дата не показывается в профиле пользователя, проблема в отображении.</p>";
    echo "</div>";
}

echo "<hr>";
echo "<p><a href='views/user_details.php?id=$userId'>Открыть профиль пользователя</a></p>";
echo "<p><a href='?'>Выбрать другого пользователя</a></p>";
