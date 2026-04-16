<?php
/**
 * Проверка структуры файлов админ-панели
 */

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Проверка структуры</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".exists{color:green;}.missing{color:red;}</style></head><body>";

echo "<h1>Проверка структуры файлов</h1>";

$requiredFiles = [
    'config/admin_config.php',
    'config/cache_config.php',
    'api/dashboard/get_stats.php',
    'api/likes/get_all_likes.php',
    'api/comments/get_all_comments.php',
    'api/users/get_all_users.php',
    'api/follows/get_all_follows.php',
    'api/favorites/get_all_favorites.php',
    'api/posts/get_all_posts.php',
    'api/moderation/get_all_photos.php',
    'assets/js/users.js',
    'assets/js/likes.js',
    'assets/js/comments.js',
    'views/users.php',
    'views/likes.php',
    'login.php',
    'index.php',
];

$baseDir = __DIR__;

echo "<h2>Базовая директория: <code>$baseDir</code></h2>";

echo "<h2>Проверка файлов:</h2>";
echo "<ul>";

$missing = [];
foreach ($requiredFiles as $file) {
    $fullPath = $baseDir . '/' . $file;
    $exists = file_exists($fullPath);
    
    $class = $exists ? 'exists' : 'missing';
    $icon = $exists ? '✅' : '❌';
    
    echo "<li class='$class'>$icon <code>$file</code>";
    
    if (!$exists) {
        $missing[] = $file;
        echo " <strong>(НЕ НАЙДЕН)</strong>";
    }
    
    echo "</li>";
}

echo "</ul>";

if (!empty($missing)) {
    echo "<h2 style='color:red;'>❌ Отсутствующие файлы:</h2>";
    echo "<ul>";
    foreach ($missing as $file) {
        echo "<li><code>$file</code></li>";
    }
    echo "</ul>";
    
    echo "<h3>Что делать:</h3>";
    echo "<ol>";
    echo "<li>Убедитесь, что все файлы загружены на сервер</li>";
    echo "<li>Проверьте структуру папок</li>";
    echo "<li>Загрузите недостающие файлы через FTP/SFTP</li>";
    echo "</ol>";
} else {
    echo "<h2 style='color:green;'>✅ Все файлы на месте!</h2>";
}

// Проверка содержимого config/admin_config.php
echo "<hr>";
echo "<h2>Проверка config/admin_config.php:</h2>";

$configPath = $baseDir . '/config/admin_config.php';
if (file_exists($configPath)) {
    echo "<p class='exists'>✅ Файл существует</p>";
    echo "<p>Размер: " . filesize($configPath) . " байт</p>";
    echo "<p>Последнее изменение: " . date('Y-m-d H:i:s', filemtime($configPath)) . "</p>";
    
    // Показываем первые 10 строк
    $lines = file($configPath);
    echo "<h3>Первые 10 строк:</h3>";
    echo "<pre>";
    for ($i = 0; $i < min(10, count($lines)); $i++) {
        echo htmlspecialchars($lines[$i]);
    }
    echo "</pre>";
} else {
    echo "<p class='missing'>❌ Файл НЕ найден!</p>";
    echo "<p>Ожидаемый путь: <code>$configPath</code></p>";
}

// Список всех файлов в директории config
echo "<hr>";
echo "<h2>Содержимое папки config/:</h2>";
$configDir = $baseDir . '/config';
if (is_dir($configDir)) {
    $files = scandir($configDir);
    echo "<ul>";
    foreach ($files as $file) {
        if ($file != '.' && $file != '..') {
            echo "<li><code>$file</code></li>";
        }
    }
    echo "</ul>";
} else {
    echo "<p class='missing'>❌ Папка config/ не найдена!</p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после проверки!</strong></p>";

echo "</body></html>";
?>
