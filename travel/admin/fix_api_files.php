<?php
/**
 * Автоматическое исправление API файлов
 * Добавляет $pdo = connectToDatabase(); в начало каждого API файла
 */

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Исправление API файлов</title>";
echo "<style>body{font-family:monospace;padding:20px;background:#f5f5f5;}";
echo ".success{color:green;}.error{color:red;}.warning{color:orange;}</style></head><body>";

echo "<h1>Исправление API файлов</h1>";

$apiDirs = [
    __DIR__ . '/api/likes',
    __DIR__ . '/api/comments',
    __DIR__ . '/api/users',
    __DIR__ . '/api/follows',
    __DIR__ . '/api/favorites',
    __DIR__ . '/api/posts',
    __DIR__ . '/api/moderation',
    __DIR__ . '/api/dashboard',
];

$fixed = 0;
$skipped = 0;
$errors = 0;

foreach ($apiDirs as $dir) {
    if (!is_dir($dir)) {
        echo "<p class='warning'>⚠️ Директория не найдена: $dir</p>";
        continue;
    }
    
    $files = glob($dir . '/*.php');
    
    foreach ($files as $file) {
        $filename = basename($file);
        echo "<p>Проверка: <code>$filename</code>... ";
        
        $content = file_get_contents($file);
        
        // Проверяем, есть ли уже $pdo = connectToDatabase()
        if (strpos($content, '$pdo = connectToDatabase()') !== false) {
            echo "<span class='warning'>уже исправлен</span></p>";
            $skipped++;
            continue;
        }
        
        // Проверяем, используется ли $pdo в файле
        if (strpos($content, '$pdo->') === false && strpos($content, '$pdo ') === false) {
            echo "<span class='warning'>не использует \$pdo</span></p>";
            $skipped++;
            continue;
        }
        
        // Ищем строку после adminRequireAuth() и header()
        $pattern = '/(adminRequireAuth\(\);.*?header\([^)]+\);.*?)(try\s*\{)/s';
        
        if (preg_match($pattern, $content)) {
            $replacement = '$1' . "\n\ntry {\n    // Подключение к базе данных\n    \$pdo = connectToDatabase();\n    ";
            $newContent = preg_replace($pattern, $replacement, $content, 1);
            
            if ($newContent && $newContent !== $content) {
                if (file_put_contents($file, $newContent)) {
                    echo "<span class='success'>✅ исправлен</span></p>";
                    $fixed++;
                } else {
                    echo "<span class='error'>❌ ошибка записи</span></p>";
                    $errors++;
                }
            } else {
                echo "<span class='error'>❌ не удалось изменить</span></p>";
                $errors++;
            }
        } else {
            echo "<span class='warning'>⚠️ не найден паттерн для вставки</span></p>";
            $skipped++;
        }
    }
}

echo "<hr>";
echo "<h2>Результаты:</h2>";
echo "<p class='success'>✅ Исправлено файлов: $fixed</p>";
echo "<p class='warning'>⚠️ Пропущено файлов: $skipped</p>";
echo "<p class='error'>❌ Ошибок: $errors</p>";

if ($fixed > 0) {
    echo "<hr>";
    echo "<h2>✅ Готово!</h2>";
    echo "<p>Теперь попробуйте открыть админ-панель:</p>";
    echo "<p><a href='index.php'>Перейти в админ-панель</a></p>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после использования!</strong></p>";

echo "</body></html>";
?>
