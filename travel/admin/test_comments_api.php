<?php
require_once 'config/admin_config.php';

// Тестируем API комментариев
echo "<h1>Тест API комментариев</h1>";

// Получаем ID фото с комментариями
$conn = connectToDatabase();

// Найдем фото с комментариями
$stmt = $conn->query("
    SELECT p.id, p.title, COUNT(c.id) as comment_count
    FROM photos p
    LEFT JOIN comments c ON p.id = c.photo_id
    GROUP BY p.id
    HAVING comment_count > 0
    LIMIT 5
");

$photosWithComments = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "<h2>Фото с комментариями:</h2>";
echo "<pre>";
print_r($photosWithComments);
echo "</pre>";

if (!empty($photosWithComments)) {
    $testPhotoId = $photosWithComments[0]['id'];
    
    echo "<h2>Тест API для фото ID: $testPhotoId</h2>";
    
    // Получаем комментарии через API
    $apiUrl = "http://" . $_SERVER['HTTP_HOST'] . "/travel/admin/api/comments/get_all_comments.php?photo_id=$testPhotoId";
    
    echo "<p>API URL: <a href='$apiUrl' target='_blank'>$apiUrl</a></p>";
    
    // Получаем данные напрямую из БД
    $stmt = $conn->prepare("
        SELECT 
            c.id,
            c.user_id,
            c.photo_id,
            c.comment,
            c.created_at,
            u.first_name,
            u.last_name,
            u.email
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.photo_id = ?
        LIMIT 5
    ");
    $stmt->execute([$testPhotoId]);
    $dbComments = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Данные из БД (таблица comments):</h3>";
    echo "<pre>";
    print_r($dbComments);
    echo "</pre>";
    
    echo "<h3>Структура таблицы comments:</h3>";
    $stmt = $conn->query("DESCRIBE comments");
    $structure = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    foreach ($structure as $col) {
        echo "<tr>";
        echo "<td>{$col['Field']}</td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "<td>{$col['Default']}</td>";
        echo "</tr>";
    }
    echo "</table>";
}

// Проверяем альбомы с комментариями
$stmt = $conn->query("
    SELECT a.id, a.title, COUNT(ac.id) as comment_count
    FROM albums a
    LEFT JOIN album_comments ac ON a.id = ac.album_id
    GROUP BY a.id
    HAVING comment_count > 0
    LIMIT 5
");

$albumsWithComments = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "<h2>Альбомы с комментариями:</h2>";
echo "<pre>";
print_r($albumsWithComments);
echo "</pre>";

if (!empty($albumsWithComments)) {
    echo "<h3>Структура таблицы album_comments:</h3>";
    $stmt = $conn->query("DESCRIBE album_comments");
    $structure = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    foreach ($structure as $col) {
        echo "<tr>";
        echo "<td>{$col['Field']}</td>";
        echo "<td>{$col['Type']}</td>";
        echo "<td>{$col['Null']}</td>";
        echo "<td>{$col['Key']}</td>";
        echo "<td>{$col['Default']}</td>";
        echo "</tr>";
    }
    echo "</table>";
}
?>
