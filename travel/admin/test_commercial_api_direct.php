<?php
session_start();

// Устанавливаем сессию администратора для теста
$_SESSION['admin_id'] = 1;
$_SESSION['admin_username'] = 'test';

// Устанавливаем ID коммерческого поста
$_GET['commercial_post_id'] = 54;

// Включаем отображение ошибок
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "=== Тестирование API get_commercial_post_relations.php ===\n\n";

// Подключаем API файл
ob_start();
include 'api/posts/get_commercial_post_relations.php';
$output = ob_get_clean();

echo "=== Вывод API ===\n";
echo $output . "\n\n";

echo "=== Декодированный JSON ===\n";
$json = json_decode($output, true);
if ($json) {
    echo "Success: " . ($json['success'] ? 'true' : 'false') . "\n";
    
    if (isset($json['commercialPost'])) {
        echo "\nКоммерческий пост:\n";
        print_r($json['commercialPost']);
    }
    
    if (isset($json['relatedAlbums'])) {
        echo "\nСвязанные альбомы (" . count($json['relatedAlbums']) . "):\n";
        foreach ($json['relatedAlbums'] as $album) {
            echo "  - " . $album['title'] . " (cover: " . ($album['cover_photo'] ?? 'NULL') . ")\n";
        }
    }
    
    if (isset($json['relatedPhotos'])) {
        echo "\nСвязанные фото (" . count($json['relatedPhotos']) . "):\n";
        foreach ($json['relatedPhotos'] as $photo) {
            echo "  - " . ($photo['title'] ?? 'Без названия') . " (preview: " . ($photo['preview'] ?? 'NULL') . ")\n";
        }
    }
    
    if (isset($json['displayedInPhotos'])) {
        echo "\nОтображается в постах (" . count($json['displayedInPhotos']) . "):\n";
        foreach ($json['displayedInPhotos'] as $photo) {
            echo "  - " . ($photo['title'] ?? 'Без названия') . " (preview: " . ($photo['preview'] ?? 'NULL') . ")\n";
        }
    }
    
    if (isset($json['message'])) {
        echo "\nСообщение: " . $json['message'] . "\n";
    }
    
    if (isset($json['file'])) {
        echo "Файл ошибки: " . $json['file'] . "\n";
        echo "Строка: " . $json['line'] . "\n";
    }
} else {
    echo "Ошибка декодирования JSON: " . json_last_error_msg() . "\n";
}
