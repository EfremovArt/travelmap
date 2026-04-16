<?php
// Прямой тест API деталей пользователя
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

header('Content-Type: text/html; charset=UTF-8');

// Проверяем авторизацию
session_start();
if (!isset($_SESSION['admin_logged_in'])) {
    echo "<p style='color: red;'>Вы не авторизованы. <a href='login.php'>Войти</a></p>";
    exit;
}

echo "<h2>Тест API деталей пользователя (ID: 27)</h2>";

try {
    $pdo = connectToDatabase();
    $userId = 27;
    
    // Get user basic info
    echo "<h3>1. Основная информация</h3>";
    $userSql = "SELECT id, first_name, last_name, email, profile_image_url, created_at FROM users WHERE id = :user_id";
    $userStmt = $pdo->prepare($userSql);
    $userStmt->execute([':user_id' => $userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        echo "<p style='color: red;'>Пользователь не найден!</p>";
        exit;
    }
    
    echo "<pre>";
    print_r($user);
    echo "</pre>";
    
    // Get statistics
    echo "<h3>2. Статистика</h3>";
    
    $stats = [];
    
    $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM follows WHERE followed_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $stats['followers_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    
    $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM follows WHERE follower_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $stats['following_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    
    $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM photos WHERE user_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $stats['posts_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    
    $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM likes WHERE user_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $stats['likes_given'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    
    $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM comments WHERE user_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $stats['comments_given'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    
    echo "<pre>";
    print_r($stats);
    echo "</pre>";
    
    // Test API call
    echo "<h3>3. Тест API вызова</h3>";
    echo "<p>URL: <a href='api/users/get_user_details.php?user_id=27' target='_blank'>api/users/get_user_details.php?user_id=27</a></p>";
    
    echo "<p style='color: green;'>✓ Все запросы выполнены успешно!</p>";
    echo "<p>Теперь попробуйте открыть: <a href='views/user_details.php?id=27' target='_blank'>views/user_details.php?id=27</a></p>";
    
} catch (Exception $e) {
    echo "<div style='color: red;'>";
    echo "<h3>Ошибка:</h3>";
    echo "<p>" . $e->getMessage() . "</p>";
    echo "<p>Файл: " . $e->getFile() . "</p>";
    echo "<p>Строка: " . $e->getLine() . "</p>";
    echo "</div>";
}
