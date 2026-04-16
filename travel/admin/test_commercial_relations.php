<?php
require_once '../config.php';

$commercialPostId = 54;

$pdo = connectToDatabase();

echo "=== Проверка коммерческого поста ID: $commercialPostId ===\n\n";

// Проверяем сам пост
$stmt = $pdo->prepare("SELECT * FROM commercial_posts WHERE id = ?");
$stmt->execute([$commercialPostId]);
$post = $stmt->fetch(PDO::FETCH_ASSOC);

if ($post) {
    echo "Пост найден:\n";
    echo "Type: " . $post['type'] . "\n";
    echo "Album ID: " . ($post['album_id'] ?? 'NULL') . "\n";
    echo "Photo ID: " . ($post['photo_id'] ?? 'NULL') . "\n\n";
    
    // Если тип album, проверяем альбом
    if ($post['type'] === 'album' && $post['album_id']) {
        echo "=== Проверка альбома ===\n";
        $stmt = $pdo->prepare("SELECT * FROM albums WHERE id = ?");
        $stmt->execute([$post['album_id']]);
        $album = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($album) {
            echo "Альбом найден: " . $album['title'] . "\n";
            
            // Проверяем фото в альбоме
            $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM album_photos WHERE album_id = ?");
            $stmt->execute([$post['album_id']]);
            $count = $stmt->fetch(PDO::FETCH_ASSOC);
            echo "Фото в альбоме: " . $count['cnt'] . "\n\n";
            
            // Пробуем получить первое фото
            $stmt = $pdo->prepare("
                SELECT p.file_path 
                FROM album_photos ap 
                INNER JOIN photos p ON ap.photo_id = p.id 
                WHERE ap.album_id = ? 
                ORDER BY ap.position ASC, ap.created_at ASC 
                LIMIT 1
            ");
            $stmt->execute([$post['album_id']]);
            $firstPhoto = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($firstPhoto) {
                echo "Первое фото: " . $firstPhoto['file_path'] . "\n";
            } else {
                echo "Первое фото не найдено\n";
            }
        } else {
            echo "Альбом НЕ найден!\n";
        }
    }
    
    // Если тип photo, проверяем фото
    if ($post['type'] === 'photo' && $post['photo_id']) {
        echo "=== Проверка фото ===\n";
        $stmt = $pdo->prepare("SELECT * FROM photos WHERE id = ?");
        $stmt->execute([$post['photo_id']]);
        $photo = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($photo) {
            echo "Фото найдено: " . $photo['title'] . "\n";
            echo "File path: " . $photo['file_path'] . "\n";
        } else {
            echo "Фото НЕ найдено!\n";
        }
    }
    
} else {
    echo "Пост НЕ найден!\n";
}

// Проверяем таблицу photo_commercial_posts
echo "\n=== Проверка таблицы photo_commercial_posts ===\n";
try {
    $stmt = $pdo->query("SHOW TABLES LIKE 'photo_commercial_posts'");
    if ($stmt->fetch()) {
        echo "Таблица существует\n";
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM photo_commercial_posts WHERE commercial_post_id = ?");
        $stmt->execute([$commercialPostId]);
        $count = $stmt->fetch(PDO::FETCH_ASSOC);
        echo "Записей для поста $commercialPostId: " . $count['cnt'] . "\n";
    } else {
        echo "Таблица НЕ существует\n";
    }
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
}
