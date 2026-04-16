<?php
// Отладка API лайков
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h2>Отладка API лайков</h2>";

// Устанавливаем параметры как в реальном запросе
$_GET['page'] = 1;
$_GET['per_page'] = 50;
$_GET['search'] = '';
$_GET['sort_by'] = 'created_at';
$_GET['sort_order'] = 'desc';
$_GET['user_id'] = '';
$_GET['photo_id'] = '';

echo "<h3>Параметры запроса:</h3>";
echo "<pre>";
print_r($_GET);
echo "</pre>";

echo "<h3>Результат API:</h3>";

// Временно изменяем error_reporting в API файле
$apiFile = file_get_contents('api/likes/get_all_likes.php');
$apiFile = str_replace('error_reporting(0);', 'error_reporting(E_ALL);', $apiFile);
$apiFile = str_replace("ini_set('display_errors', 0);", "ini_set('display_errors', 1);", $apiFile);
file_put_contents('api/likes/get_all_likes_debug.php', $apiFile);

ob_start();
try {
    include 'api/likes/get_all_likes_debug.php';
    $output = ob_get_clean();
    
    echo "<pre>";
    echo htmlspecialchars($output);
    echo "</pre>";
    
    echo "<h3>Декодированный JSON:</h3>";
    $json = json_decode($output, true);
    echo "<pre>";
    print_r($json);
    echo "</pre>";
    
} catch (Exception $e) {
    ob_end_clean();
    echo "<div style='color: red;'>";
    echo "<h3>Ошибка:</h3>";
    echo "<p>" . $e->getMessage() . "</p>";
    echo "<p>Файл: " . $e->getFile() . "</p>";
    echo "<p>Строка: " . $e->getLine() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
    echo "</div>";
}
