<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

echo "<h2>Тест системы отслеживания просмотров</h2>";

$pdo = connectToDatabase();
$adminId = $_SESSION['admin_id'];

// Проверяем существование таблицы
echo "<h3>1. Проверка таблицы admin_views:</h3>";
try {
    $stmt = $pdo->query("SHOW TABLES LIKE 'admin_views'");
    $exists = $stmt->fetch();
    if ($exists) {
        echo "<p style='color: green;'>✓ Таблица admin_views существует</p>";
        
        // Показываем структуру
        echo "<h4>Структура таблицы:</h4>";
        $stmt = $pdo->query("DESCRIBE admin_views");
        $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th></tr>";
        foreach ($columns as $col) {
            echo "<tr><td>{$col['Field']}</td><td>{$col['Type']}</td><td>{$col['Null']}</td><td>{$col['Key']}</td></tr>";
        }
        echo "</table>";
        
        // Показываем данные
        echo "<h4>Данные для текущего админа (ID: $adminId):</h4>";
        $stmt = $pdo->prepare("SELECT * FROM admin_views WHERE admin_id = :admin_id");
        $stmt->execute([':admin_id' => $adminId]);
        $views = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if ($views) {
            echo "<table border='1' cellpadding='5'>";
            echo "<tr><th>ID</th><th>Admin ID</th><th>View Type</th><th>Last Viewed At</th></tr>";
            foreach ($views as $view) {
                echo "<tr><td>{$view['id']}</td><td>{$view['admin_id']}</td><td>{$view['view_type']}</td><td>{$view['last_viewed_at']}</td></tr>";
            }
            echo "</table>";
        } else {
            echo "<p style='color: orange;'>⚠ Нет записей просмотров для текущего админа</p>";
        }
    } else {
        echo "<p style='color: red;'>✗ Таблица admin_views НЕ существует!</p>";
        echo "<p><a href='apply_views_tracking.php'>Создать таблицу</a></p>";
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>✗ Ошибка: " . $e->getMessage() . "</p>";
}

// Проверяем количество фото на модерации
echo "<h3>2. Фото на модерации:</h3>";
try {
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM photos WHERE moderation_status IS NULL OR moderation_status = 'pending'");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "<p>Всего фото на модерации: <strong>$count</strong></p>";
    
    // Последние 5 фото
    $stmt = $pdo->query("SELECT id, title, created_at, moderation_status FROM photos WHERE moderation_status IS NULL OR moderation_status = 'pending' ORDER BY created_at DESC LIMIT 5");
    $photos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if ($photos) {
        echo "<h4>Последние 5 фото:</h4>";
        echo "<table border='1' cellpadding='5'>";
        echo "<tr><th>ID</th><th>Title</th><th>Created At</th><th>Status</th></tr>";
        foreach ($photos as $photo) {
            echo "<tr><td>{$photo['id']}</td><td>{$photo['title']}</td><td>{$photo['created_at']}</td><td>{$photo['moderation_status']}</td></tr>";
        }
        echo "</table>";
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// Тестируем API
echo "<h3>3. Тест API get_new_counts.php:</h3>";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'http://' . $_SERVER['HTTP_HOST'] . '/travel/admin/api/moderation/get_new_counts.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
$response = curl_exec($ch);
curl_close($ch);

echo "<h4>Ответ API:</h4>";
echo "<pre>" . htmlspecialchars($response) . "</pre>";

$data = json_decode($response, true);
if ($data && $data['success']) {
    echo "<h4>Расшифровка:</h4>";
    echo "<ul>";
    echo "<li>Новые фото: " . $data['counts']['newPhotos'] . "</li>";
    echo "<li>Новые комментарии: " . $data['counts']['newComments'] . "</li>";
    echo "<li>Последний просмотр фото: " . ($data['counts']['lastPhotoView'] ?: 'никогда') . "</li>";
    echo "<li>Последний просмотр комментариев: " . ($data['counts']['lastCommentView'] ?: 'никогда') . "</li>";
    echo "</ul>";
}

echo "<hr>";
echo "<p><a href='views/moderation.php'>Перейти к модерации</a></p>";
