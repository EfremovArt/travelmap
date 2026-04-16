<?php
require_once '../config.php';

$pdo = connectToDatabase();

echo "=== Проверка коммерческого поста ID 24 ===\n\n";

// Получаем данные поста
$stmt = $pdo->prepare("SELECT * FROM commercial_posts WHERE id = 24");
$stmt->execute();
$post = $stmt->fetch(PDO::FETCH_ASSOC);

if ($post) {
    echo "Коммерческий пост найден:\n";
    foreach ($post as $key => $value) {
        echo "  $key: " . ($value ?? 'NULL') . "\n";
    }
    
    // Если есть image_url, показываем его
    if ($post['image_url']) {
        echo "\nImage URL: " . $post['image_url'] . "\n";
    }
    
    // Проверяем, есть ли связанные записи в photo_commercial_posts
    echo "\n=== Проверка photo_commercial_posts ===\n";
    try {
        $stmt = $pdo->prepare("
            SELECT pcp.*, p.title as photo_title, p.file_path 
            FROM photo_commercial_posts pcp
            LEFT JOIN photos p ON pcp.photo_id = p.id
            WHERE pcp.commercial_post_id = 24
        ");
        $stmt->execute();
        $relations = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (count($relations) > 0) {
            echo "Найдено связей: " . count($relations) . "\n";
            foreach ($relations as $rel) {
                echo "  - Photo ID: " . $rel['photo_id'] . ", Title: " . ($rel['photo_title'] ?? 'NULL') . "\n";
                echo "    File path: " . ($rel['file_path'] ?? 'NULL') . "\n";
            }
        } else {
            echo "Связей не найдено\n";
        }
    } catch (Exception $e) {
        echo "Ошибка: " . $e->getMessage() . "\n";
    }
    
    // Если тип album, но album_id NULL, ищем альбомы этого пользователя
    if ($post['type'] === 'album' && !$post['album_id']) {
        echo "\n=== Альбомы пользователя " . $post['user_id'] . " ===\n";
        $stmt = $pdo->prepare("
            SELECT a.id, a.title, 
                   (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) as photos_count
            FROM albums a
            WHERE a.owner_id = ?
            ORDER BY a.created_at DESC
            LIMIT 10
        ");
        $stmt->execute([$post['user_id']]);
        $albums = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (count($albums) > 0) {
            echo "Найдено альбомов: " . count($albums) . "\n";
            foreach ($albums as $album) {
                echo "  - ID: " . $album['id'] . ", Title: " . $album['title'] . ", Photos: " . $album['photos_count'] . "\n";
            }
        } else {
            echo "Альбомов не найдено\n";
        }
    }
    
} else {
    echo "Пост не найден!\n";
}

// Проверяем все коммерческие посты
echo "\n=== Все коммерческие посты ===\n";
$stmt = $pdo->query("
    SELECT id, title, type, album_id, photo_id, image_url 
    FROM commercial_posts 
    ORDER BY id DESC 
    LIMIT 10
");
$posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

foreach ($posts as $p) {
    echo "ID: " . $p['id'] . " | Type: " . $p['type'] . " | Album: " . ($p['album_id'] ?? 'NULL') . " | Photo: " . ($p['photo_id'] ?? 'NULL') . " | Image: " . ($p['image_url'] ? 'YES' : 'NO') . "\n";
}
