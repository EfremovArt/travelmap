<?php
/**
 * Исправление путей к изображениям во всех API файлах
 */

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Исправление путей изображений</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".success{color:green;}.error{color:red;}</style></head><body>";

echo "<h1>Исправление путей к изображениям в API</h1>";

$apiFiles = [
    __DIR__ . '/api/posts/get_all_posts.php',
    __DIR__ . '/api/posts/get_all_albums.php',
    __DIR__ . '/api/posts/get_all_commercial_posts.php',
    __DIR__ . '/api/users/get_all_users.php',
    __DIR__ . '/api/users/get_user_details.php',
    __DIR__ . '/api/likes/get_all_likes.php',
    __DIR__ . '/api/comments/get_all_comments.php',
    __DIR__ . '/api/follows/get_all_follows.php',
    __DIR__ . '/api/favorites/get_all_favorites.php',
    __DIR__ . '/api/moderation/get_all_photos.php',
];

$fixed = 0;
$errors = 0;

foreach ($apiFiles as $file) {
    if (!file_exists($file)) {
        echo "<p class='error'>❌ Файл не найден: " . basename($file) . "</p>";
        continue;
    }
    
    $content = file_get_contents($file);
    $originalContent = $content;
    $changed = false;
    
    // Паттерны для замены
    $patterns = [
        // Для profile_image_url
        "/('profileImageUrl'\s*=>\s*)([^,\n]+)/",
        "/('userProfileImage'\s*=>\s*)([^,\n]+)/",
        "/('ownerProfileImage'\s*=>\s*)([^,\n]+)/",
        "/('followerProfileImage'\s*=>\s*)([^,\n]+)/",
        "/('followedProfileImage'\s*=>\s*)([^,\n]+)/",
        // Для preview/filePath
        "/('preview'\s*=>\s*)([^,\n]+)/",
        "/('filePath'\s*=>\s*)([^,\n]+)/",
        "/('coverPhoto'\s*=>\s*)([^,\n]+)/",
    ];
    
    foreach ($patterns as $pattern) {
        $content = preg_replace_callback($pattern, function($matches) {
            $key = $matches[1];
            $value = trim($matches[2]);
            
            // Если значение уже обернуто в normalizeImageUrl, пропускаем
            if (strpos($value, 'normalizeImageUrl') !== false) {
                return $matches[0];
            }
            
            // Оборачиваем в normalizeImageUrl
            return $key . 'normalizeImageUrl(' . $value . ')';
        }, $content);
    }
    
    if ($content !== $originalContent) {
        if (file_put_contents($file, $content)) {
            echo "<p class='success'>✅ " . basename($file) . "</p>";
            $fixed++;
        } else {
            echo "<p class='error'>❌ " . basename($file) . " - ошибка записи</p>";
            $errors++;
        }
    } else {
        echo "<p>⚪ " . basename($file) . " - не требует изменений</p>";
    }
}

echo "<hr>";
echo "<h2>Результаты:</h2>";
echo "<p class='success'>✅ Исправлено: $fixed</p>";
echo "<p class='error'>❌ Ошибок: $errors</p>";

if ($fixed > 0 || $errors == 0) {
    echo "<hr>";
    echo "<h2>✅ Готово!</h2>";
    echo "<p>Пути к изображениям исправлены!</p>";
    echo "<p><a href='views/posts.php'>Проверить публикации</a></p>";
    echo "<p><a href='index.php'>Перейти в админ-панель</a></p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите все временные файлы после проверки!</strong></p>";
echo "<pre>rm fix_*.php check_*.php debug_*.php create_*.php final_fix.php</pre>";

echo "</body></html>";
?>
