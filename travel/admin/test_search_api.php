<?php
// Тест API поиска пользователей
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

echo "<h2>Тест API поиска пользователей</h2>";

// Тест 1: Поиск по email
$search = 'efremov058@gmail.com';
echo "<h3>Поиск: {$search}</h3>";

$url = "http://bearded-fox.ru/travel/admin/api/users/get_all_users.php?page=1&per_page=25&search=" . urlencode($search) . "&sort_by=id&sort_order=desc";

echo "<p>URL: {$url}</p>";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "<p>HTTP Code: {$httpCode}</p>";
echo "<pre>";
echo htmlspecialchars($response);
echo "</pre>";

// Тест 2: Прямой запрос к БД
echo "<hr><h3>Прямой запрос к БД</h3>";

try {
    $pdo = connectToDatabase();
    
    $sql = "SELECT * FROM users WHERE email LIKE :search LIMIT 5";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':search' => "%{$search}%"]);
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p>Найдено пользователей: " . count($users) . "</p>";
    echo "<pre>";
    print_r($users);
    echo "</pre>";
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage();
}
