<?php
/**
 * Финальное исправление всех API файлов
 */

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Финальное исправление</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".success{color:green;}.error{color:red;}</style></head><body>";

echo "<h1>Финальное исправление API файлов</h1>";

$files = [
    __DIR__ . '/api/moderation/bulk_delete_photos.php',
    __DIR__ . '/api/moderation/delete_photo.php',
    __DIR__ . '/api/moderation/get_all_photos.php',
    __DIR__ . '/api/comments/delete_comment.php',
];

$fixed = 0;
$errors = 0;

foreach ($files as $file) {
    if (!file_exists($file)) {
        echo "<p class='error'>❌ Файл не найден: " . basename($file) . "</p>";
        continue;
    }
    
    $content = file_get_contents($file);
    $originalContent = $content;
    
    // Заменяем getDbConnection() и getDBConnection() на connectToDatabase()
    $content = str_replace('getDbConnection()', 'connectToDatabase()', $content);
    $content = str_replace('getDBConnection()', 'connectToDatabase()', $content);
    
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
    echo "<p><a href='index.php'>Перейти в админ-панель</a></p>";
    echo "<p><a href='views/posts.php'>Проверить публикации</a></p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после использования!</strong></p>";

echo "</body></html>";
?>
