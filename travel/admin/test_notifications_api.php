<?php
session_start();
require_once 'config/admin_config.php';

// Check if user is authenticated
if (!isset($_SESSION['admin_id'])) {
    header('Location: /travel/admin/login.php');
    exit;
}
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Notifications API</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-5">
        <h1>Тест API уведомлений</h1>
        
        <div class="card mt-4">
            <div class="card-header">
                <h5>Результат API</h5>
            </div>
            <div class="card-body">
                <button class="btn btn-primary" onclick="testAPI()">Загрузить уведомления</button>
                <button class="btn btn-secondary ms-2" onclick="clearViews()">Очистить просмотры</button>
                <pre id="result" class="mt-3 p-3 bg-light" style="max-height: 400px; overflow: auto;"></pre>
            </div>
        </div>
        
        <div class="card mt-4">
            <div class="card-header">
                <h5>Статистика БД</h5>
            </div>
            <div class="card-body">
                <button class="btn btn-info" onclick="checkDB()">Проверить БД</button>
                <pre id="dbResult" class="mt-3 p-3 bg-light"></pre>
            </div>
        </div>
    </div>

    <script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
    <script>
        function testAPI() {
            $('#result').text('Загрузка...');
            
            fetch('api/moderation/get_new_counts.php')
                .then(response => response.json())
                .then(data => {
                    $('#result').text(JSON.stringify(data, null, 2));
                })
                .catch(error => {
                    $('#result').text('Ошибка: ' + error);
                });
        }
        
        function clearViews() {
            if (!confirm('Очистить все просмотры?')) return;
            
            fetch('api/moderation/mark_as_viewed.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    view_type: 'reset'
                })
            })
            .then(response => response.json())
            .then(data => {
                alert('Просмотры очищены');
                testAPI();
            })
            .catch(error => {
                alert('Ошибка: ' + error);
            });
        }
        
        function checkDB() {
            $('#dbResult').text('Загрузка...');
            
            $.ajax({
                url: 'check_notifications_db.php',
                method: 'GET',
                success: function(data) {
                    $('#dbResult').text(data);
                },
                error: function(xhr, status, error) {
                    $('#dbResult').text('Ошибка: ' + error);
                }
            });
        }
        
        // Автоматически загрузить при открытии
        $(document).ready(function() {
            testAPI();
        });
    </script>
</body>
</html>
