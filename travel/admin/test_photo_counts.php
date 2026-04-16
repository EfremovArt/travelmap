<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();
$adminId = $_SESSION['admin_id'];

echo "<h2>Тест счетчиков фотографий</h2>";

// 1. Проверяем таблицу admin_views
echo "<h3>1. Проверка таблицы admin_views</h3>";
try {
    $stmt = $pdo->prepare("SELECT * FROM admin_views WHERE admin_id = :admin_id");
    $stmt->execute([':admin_id' => $adminId]);
    $views = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($views);
    echo "</pre>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 2. Проверяем количество фото с pending статусом
echo "<h3>2. Фото с pending статусом</h3>";
try {
    $stmt = $pdo->query("
        SELECT COUNT(*) as count 
        FROM photos 
        WHERE moderation_status IS NULL OR moderation_status = 'pending'
    ");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p>Всего фото с pending статусом: <strong>" . $result['count'] . "</strong></p>";
    
    // Показываем несколько примеров
    $stmt = $pdo->query("
        SELECT id, title, created_at, moderation_status 
        FROM photos 
        WHERE moderation_status IS NULL OR moderation_status = 'pending'
        LIMIT 5
    ");
    $photos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($photos);
    echo "</pre>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 3. Проверяем последний просмотр фото
echo "<h3>3. Последний просмотр фото</h3>";
try {
    $stmt = $pdo->prepare("
        SELECT last_viewed_at 
        FROM admin_views 
        WHERE admin_id = :admin_id AND view_type = 'photos'
    ");
    $stmt->execute([':admin_id' => $adminId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        $lastView = $result['last_viewed_at'];
        echo "<p>Последний просмотр: <strong>$lastView</strong></p>";
        
        // Считаем новые фото после последнего просмотра
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as count 
            FROM photos 
            WHERE (moderation_status IS NULL OR moderation_status = 'pending')
            AND created_at > :last_view
        ");
        $stmt->execute([':last_view' => $lastView]);
        $newCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "<p>Новых фото после последнего просмотра: <strong>$newCount</strong></p>";
    } else {
        echo "<p>Просмотров еще не было</p>";
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 4. Тестируем API get_new_counts.php
echo "<h3>4. Тест API get_new_counts.php</h3>";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'http://bearded-fox.ru/travel/admin/api/moderation/get_new_counts.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
$response = curl_exec($ch);
curl_close($ch);

echo "<pre>";
echo htmlspecialchars($response);
echo "</pre>";

$data = json_decode($response, true);
if ($data) {
    echo "<p>Декодированный ответ:</p>";
    echo "<pre>";
    print_r($data);
    echo "</pre>";
}

// 5. Проверяем структуру таблицы photos
echo "<h3>5. Структура таблицы photos (колонка moderation_status)</h3>";
try {
    $stmt = $pdo->query("SHOW COLUMNS FROM photos LIKE 'moderation_status'");
    $column = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($column);
    echo "</pre>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}

// 6. Проверяем распределение статусов
echo "<h3>6. Распределение статусов модерации</h3>";
try {
    $stmt = $pdo->query("
        SELECT 
            moderation_status,
            COUNT(*) as count
        FROM photos
        GROUP BY moderation_status
    ");
    $statuses = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<pre>";
    print_r($statuses);
    echo "</pre>";
} catch (Exception $e) {
    echo "<p style='color: red;'>Ошибка: " . $e->getMessage() . "</p>";
}
?>
