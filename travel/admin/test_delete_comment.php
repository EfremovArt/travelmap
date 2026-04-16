<?php
require_once 'config/admin_config.php';

echo "<h1>Тест удаления комментария</h1>";

// Получаем комментарий для теста
$conn = connectToDatabase();

$stmt = $conn->query("
    SELECT c.id, c.comment, c.photo_id, u.first_name, u.last_name
    FROM comments c
    JOIN users u ON c.user_id = u.id
    LIMIT 1
");

$comment = $stmt->fetch(PDO::FETCH_ASSOC);

if ($comment) {
    echo "<h2>Тестовый комментарий:</h2>";
    echo "<pre>";
    print_r($comment);
    echo "</pre>";
    
    echo "<h2>Тест API удаления</h2>";
    echo "<p>Отправляем запрос с правильными параметрами:</p>";
    
    $testData = [
        'commentId' => (int)$comment['id'],
        'commentType' => 'photo',
        'csrf_token' => generateCsrfToken()
    ];
    
    echo "<pre>";
    echo "POST /travel/admin/api/comments/delete_comment.php\n";
    echo "Content-Type: application/json\n";
    echo "X-CSRF-Token: " . generateCsrfToken() . "\n\n";
    echo json_encode($testData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    echo "</pre>";
    
    echo "<h3>Ожидаемые параметры API:</h3>";
    echo "<ul>";
    echo "<li><strong>commentId</strong> (int) - ID комментария</li>";
    echo "<li><strong>commentType</strong> (string) - 'photo' или 'album'</li>";
    echo "<li><strong>csrf_token</strong> (string) - CSRF токен</li>";
    echo "</ul>";
    
    echo "<h3>Неправильные параметры (которые были раньше):</h3>";
    echo "<ul>";
    echo "<li><del>comment_id</del> → commentId</li>";
    echo "<li><del>comment_type</del> → commentType</li>";
    echo "</ul>";
    
} else {
    echo "<p>Комментарии не найдены в базе данных</p>";
}

// Проверяем структуру API
echo "<h2>Проверка API delete_comment.php</h2>";
$apiFile = __DIR__ . '/api/comments/delete_comment.php';
if (file_exists($apiFile)) {
    $content = file_get_contents($apiFile);
    
    echo "<h3>Проверка параметров в коде:</h3>";
    
    if (strpos($content, "input['commentId']") !== false) {
        echo "✅ API ожидает <code>commentId</code><br>";
    } else {
        echo "❌ API НЕ ожидает <code>commentId</code><br>";
    }
    
    if (strpos($content, "input['commentType']") !== false) {
        echo "✅ API ожидает <code>commentType</code><br>";
    } else {
        echo "❌ API НЕ ожидает <code>commentType</code><br>";
    }
    
    if (strpos($content, "input['comment_id']") !== false) {
        echo "⚠️ API также проверяет <code>comment_id</code> (старый формат)<br>";
    }
    
    if (strpos($content, "input['comment_type']") !== false) {
        echo "⚠️ API также проверяет <code>comment_type</code> (старый формат)<br>";
    }
} else {
    echo "<p>❌ Файл API не найден: $apiFile</p>";
}

echo "<h2>JavaScript код (moderation.js)</h2>";
$jsFile = __DIR__ . '/assets/js/moderation.js';
if (file_exists($jsFile)) {
    $content = file_get_contents($jsFile);
    
    echo "<h3>Проверка отправляемых параметров:</h3>";
    
    if (strpos($content, "commentId:") !== false) {
        echo "✅ JavaScript отправляет <code>commentId</code><br>";
    } else {
        echo "❌ JavaScript НЕ отправляет <code>commentId</code><br>";
    }
    
    if (strpos($content, "commentType:") !== false) {
        echo "✅ JavaScript отправляет <code>commentType</code><br>";
    } else {
        echo "❌ JavaScript НЕ отправляет <code>commentType</code><br>";
    }
    
    if (strpos($content, "comment_id:") !== false) {
        echo "⚠️ JavaScript также отправляет <code>comment_id</code> (старый формат)<br>";
    }
    
    if (strpos($content, "comment_type:") !== false) {
        echo "⚠️ JavaScript также отправляет <code>comment_type</code> (старый формат)<br>";
    }
}
?>

<style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    pre { background: #f5f5f5; padding: 10px; border-radius: 5px; }
    code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
    h2 { color: #2c3e50; margin-top: 30px; }
    h3 { color: #34495e; }
</style>
