<?php
/**
 * Исправление названий колонок в API файлах
 * profile_image -> profile_image_url
 */

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Исправление колонок</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".success{color:green;}.error{color:red;}</style></head><body>";

echo "<h1>Исправление названий колонок</h1>";

$replacements = [
    'u.profile_image' => 'u.profile_image_url',
    'profile_image' => 'profile_image_url',
];

$directories = [
    __DIR__ . '/api',
    __DIR__ . '/views',
];

$fixed = 0;
$errors = 0;

function processDirectory($dir, $replacements, &$fixed, &$errors) {
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($dir, RecursiveDirectoryIterator::SKIP_DOTS),
        RecursiveIteratorIterator::SELF_FIRST
    );
    
    foreach ($iterator as $file) {
        if ($file->isFile() && $file->getExtension() === 'php') {
            $filepath = $file->getPathname();
            $content = file_get_contents($filepath);
            $originalContent = $content;
            
            foreach ($replacements as $search => $replace) {
                $content = str_replace($search, $replace, $content);
            }
            
            if ($content !== $originalContent) {
                if (file_put_contents($filepath, $content)) {
                    echo "<p class='success'>✅ " . basename($filepath) . "</p>";
                    $fixed++;
                } else {
                    echo "<p class='error'>❌ " . basename($filepath) . " - ошибка записи</p>";
                    $errors++;
                }
            }
        }
    }
}

foreach ($directories as $dir) {
    if (is_dir($dir)) {
        processDirectory($dir, $replacements, $fixed, $errors);
    }
}

echo "<hr>";
echo "<h2>Результаты:</h2>";
echo "<p class='success'>✅ Исправлено файлов: $fixed</p>";
echo "<p class='error'>❌ Ошибок: $errors</p>";

if ($fixed > 0) {
    echo "<hr>";
    echo "<h2>✅ Готово!</h2>";
    echo "<p>Теперь попробуйте открыть:</p>";
    echo "<p><a href='api/likes/get_all_likes.php'>API Likes</a></p>";
    echo "<p><a href='index.php'>Админ-панель</a></p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после использования!</strong></p>";

echo "</body></html>";
?>
