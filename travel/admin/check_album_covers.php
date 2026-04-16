<?php
require_once '../config.php';
$pdo = connectToDatabase();

// Проверяем структуру таблицы albums
echo "=== Структура таблицы albums ===\n";
$stmt = $pdo->query("DESCRIBE albums");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo $row['Field'] . " - " . $row['Type'] . "\n";
}

// Проверяем, есть ли таблица album_covers
echo "\n=== Проверка таблицы album_covers ===\n";
try {
    $stmt = $pdo->query("SHOW TABLES LIKE 'album_covers'");
    $exists = $stmt->fetch();
    if ($exists) {
        echo "Таблица album_covers существует\n";
        $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM album_covers");
        $count = $stmt->fetch(PDO::FETCH_ASSOC);
        echo "Записей в album_covers: " . $count['cnt'] . "\n";
    } else {
        echo "Таблица album_covers НЕ существует\n";
    }
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
}

// Проверяем связь альбомов с фото
echo "\n=== Проверка связи альбомов с фото ===\n";
$stmt = $pdo->query("
    SELECT a.id, a.title, a.cover_photo_id, 
           (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) as photos_count
    FROM albums a 
    LIMIT 5
");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "Album ID: {$row['id']}, Title: {$row['title']}, Cover ID: {$row['cover_photo_id']}, Photos: {$row['photos_count']}\n";
}

// Проверяем таблицу photos
echo "\n=== Проверка таблицы photos ===\n";
$stmt = $pdo->query("DESCRIBE photos");
echo "Структура таблицы photos:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo $row['Field'] . " - " . $row['Type'] . "\n";
}
