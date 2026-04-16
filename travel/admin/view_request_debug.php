<?php
require_once 'config/admin_config.php';
adminRequireAuth();
?>
<!DOCTYPE html>
<html>
<head>
    <title>Отладка запросов от приложения</title>
    <meta charset="UTF-8">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { padding: 20px; }
        pre { background: #f5f5f5; padding: 15px; border-radius: 5px; max-height: 600px; overflow: auto; }
        .alert-info { margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Отладка запросов от приложения</h1>
        
        <div class="alert alert-info">
            <h4>Инструкция:</h4>
            <ol>
                <li>Временно измените в iOS приложении URL для обновления профиля на: <code>/travel/user/debug_request.php</code></li>
                <li>Попросите пользователя обновить дату рождения в приложении</li>
                <li>Обновите эту страницу чтобы увидеть что именно отправляет приложение</li>
                <li>После отладки верните URL обратно на: <code>/travel/user/update_profile.php</code></li>
            </ol>
        </div>
        
        <button class="btn btn-primary" onclick="location.reload()">🔄 Обновить</button>
        <button class="btn btn-danger" onclick="clearLog()">🗑️ Очистить лог</button>
        
        <hr>
        
        <h2>Последние запросы:</h2>
        
        <?php
        $logFile = __DIR__ . '/../user/request_debug.log';
        
        if (file_exists($logFile)) {
            $content = file_get_contents($logFile);
            if (!empty($content)) {
                echo "<pre>" . htmlspecialchars($content) . "</pre>";
            } else {
                echo "<div class='alert alert-warning'>Лог пустой. Ожидание запросов от приложения...</div>";
            }
        } else {
            echo "<div class='alert alert-warning'>Файл лога еще не создан. Ожидание первого запроса...</div>";
        }
        ?>
    </div>
    
    <script>
        function clearLog() {
            if (confirm('Очистить лог?')) {
                fetch('clear_request_debug.php', { method: 'POST' })
                    .then(() => location.reload());
            }
        }
    </script>
</body>
</html>
