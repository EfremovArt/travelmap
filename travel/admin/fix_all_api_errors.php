<?php
/**
 * Скрипт для добавления error_reporting(0) во все API файлы
 */

$apiFiles = [
    'api/comments/delete_comment.php',
    'api/comments/get_all_comments_simple.php',
    'api/comments/get_all_comments.php',
    'api/dashboard/get_stats.php',
    'api/favorites/get_all_favorites.php',
    'api/follows/get_all_follows.php',
    'api/likes/get_all_likes.php',
    'api/moderation/bulk_delete_photos.php',
    'api/moderation/delete_photo.php',
    'api/moderation/get_all_photos.php',
    'api/posts/get_album_photos.php',
    'api/users/get_all_users.php',
    'api/users/get_user_details.php',
];

$errorSuppression = "error_reporting(0);\nini_set('display_errors', 0);\n\n";

foreach ($apiFiles as $file) {
    $filePath = __DIR__ . '/' . $file;
    
    if (!file_exists($filePath)) {
        echo "❌ Файл не найден: $file\n";
        continue;
    }
    
    $content = file_get_contents($filePath);
    
    // Проверяем, есть ли уже error_reporting(0)
    if (strpos($content, 'error_reporting(0)') !== false) {
        echo "⏭️  Пропущен (уже исправлен): $file\n";
        continue;
    }
    
    // Добавляем error_reporting(0) после <?php
    $content = preg_replace(
        '/^<\?php\s*\n/',
        "<?php\n" . $errorSuppression,
        $content
    );
    
    // Сохраняем файл
    if (file_put_contents($filePath, $content)) {
        echo "✅ Исправлен: $file\n";
    } else {
        echo "❌ Ошибка записи: $file\n";
    }
}

echo "\n✅ Готово!\n";
