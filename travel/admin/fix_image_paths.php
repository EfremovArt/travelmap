<?php
/**
 * Добавление функции нормализации путей к изображениям в admin_config.php
 */

$configFile = __DIR__ . '/config/admin_config.php';

if (!file_exists($configFile)) {
    die("Файл admin_config.php не найден!");
}

$content = file_get_contents($configFile);

// Проверяем, есть ли уже функция
if (strpos($content, 'function normalizeImageUrl') !== false) {
    echo "Функция normalizeImageUrl уже существует!";
    exit;
}

// Добавляем функцию в конец файла (перед закрывающим ?>)
$newFunction = "
// ============================================
// Image URL Helper Functions
// ============================================

/**
 * Нормализация URL изображения
 * Убирает дублирование /travel/ и обрабатывает внешние URL
 */
function normalizeImageUrl(\$url) {
    if (empty(\$url)) {
        return null;
    }
    
    // Если это внешний URL (Google, etc), возвращаем как есть
    if (strpos(\$url, 'http://') === 0 || strpos(\$url, 'https://') === 0) {
        return \$url;
    }
    
    // Убираем дублирование /travel/
    \$url = preg_replace('#/travel/+#', '/travel/', \$url);
    
    // Убираем начальный /travel/ если он есть
    \$url = preg_replace('#^/travel/#', '', \$url);
    
    // Добавляем /travel/ в начало
    return '/travel/' . \$url;
}
";

// Находим последнюю строку перед закрывающим тегом или в конце файла
if (strpos($content, '?>') !== false) {
    $content = str_replace('?>', $newFunction . "\n?>", $content);
} else {
    $content .= "\n" . $newFunction;
}

if (file_put_contents($configFile, $content)) {
    echo "✅ Функция normalizeImageUrl добавлена в admin_config.php<br>";
    echo "<a href='fix_api_image_paths.php'>Перейти к следующему шагу</a>";
} else {
    echo "❌ Ошибка записи в файл!";
}
?>
