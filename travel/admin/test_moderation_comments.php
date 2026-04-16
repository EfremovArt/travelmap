<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

echo "<h2>Тест API комментариев для модерации</h2>";

$pdo = connectToDatabase();

// Проверяем структуру таблицы comments
echo "<h3>Структура таблицы comments:</h3>";
try {
    $stmt = $pdo->query("DESCRIBE comments");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th></tr>";
    foreach ($columns as $col) {
        echo "<tr>";
        echo "<td>{$col['Field']}</td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "</tr>";
    }
    echo "</table>";
} catch (Exception $e) {
    echo "<p class='error'>Ошибка: " . $e->getMessage() . "</p>";
}

// Проверяем количество комментариев
echo "<h3>Количество комментариев:</h3>";
try {
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM comments");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "<p>Всего комментариев: <strong>$count</strong></p>";
} catch (Exception $e) {
    echo "<p class='error'>Ошибка: " . $e->getMessage() . "</p>";
}

// Тестируем API
echo "<h3>Тест API:</h3>";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'http://' . $_SERVER['HTTP_HOST'] . '/travel/admin/api/moderation/get_all_comments.php?page=1&per_page=5');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "<p>HTTP Code: <strong>$httpCode</strong></p>";
echo "<h4>Ответ API:</h4>";
echo "<pre>" . htmlspecialchars($response) . "</pre>";

$data = json_decode($response, true);
if ($data && $data['success']) {
    echo "<h4>Расшифровка:</h4>";
    echo "<p>Найдено комментариев: " . count($data['comments']) . "</p>";
    echo "<p>Всего: " . $data['pagination']['total'] . "</p>";
    
    if (!empty($data['comments'])) {
        echo "<h4>Первый комментарий:</h4>";
        echo "<pre>" . print_r($data['comments'][0], true) . "</pre>";
    }
}

echo "<hr>";
echo "<a href='views/moderation.php'>Перейти к модерации</a>";
