<?php
// Тест API деталей пользователя
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h2>Тест API деталей пользователя</h2>";

// Прямой вызов API
$_GET['user_id'] = 27;

ob_start();
try {
    include 'api/users/get_user_details.php';
    $output = ob_get_clean();
    
    echo "<h3>Результат API:</h3>";
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
