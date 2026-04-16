<?php
/**
 * Скрипт для создания таблицы photo_commercial_posts
 */

require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Создание таблицы photo_commercial_posts</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .info { color: #17a2b8; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container mt-5">
        <h1>Создание таблицы photo_commercial_posts</h1>
        <p class="text-muted">Эта таблица хранит связи между фотографиями и коммерческими постами</p>
        
        <hr>
        
        <?php
        try {
            $pdo = connectToDatabase();
            
            if (!$pdo) {
                throw new Exception('Не удалось подключиться к базе данных');
            }
            
            echo "<div class='alert alert-info'>✓ Подключение к базе данных установлено</div>";
            
            // Проверяем, существует ли таблица
            $checkTableSql = "SHOW TABLES LIKE 'photo_commercial_posts'";
            $result = $pdo->query($checkTableSql);
            
            if ($result->rowCount() > 0) {
                echo "<div class='alert alert-warning'>⚠️ Таблица photo_commercial_posts уже существует</div>";
                
                // Показываем структуру таблицы
                $describeResult = $pdo->query("DESCRIBE photo_commercial_posts");
                echo "<h3>Текущая структура таблицы:</h3>";
                echo "<pre>";
                while ($row = $describeResult->fetch(PDO::FETCH_ASSOC)) {
                    print_r($row);
                }
                echo "</pre>";
            } else {
                // Читаем SQL из файла миграции
                $sqlFile = __DIR__ . '/migrations/create_photo_commercial_posts_table.sql';
                
                if (!file_exists($sqlFile)) {
                    throw new Exception("Файл миграции не найден: $sqlFile");
                }
                
                $sql = file_get_contents($sqlFile);
                
                echo "<h3>Выполняемый SQL:</h3>";
                echo "<pre>" . htmlspecialchars($sql) . "</pre>";
                
                // Разбиваем на отдельные запросы
                $statements = array_filter(
                    array_map('trim', explode(';', $sql)),
                    function($stmt) {
                        return !empty($stmt) && strpos($stmt, '--') !== 0;
                    }
                );
                
                echo "<h3>Выполнение миграции:</h3>";
                
                foreach ($statements as $statement) {
                    if (empty(trim($statement))) continue;
                    
                    try {
                        $pdo->exec($statement);
                        echo "<div class='alert alert-success'>✓ Запрос выполнен успешно</div>";
                    } catch (PDOException $e) {
                        echo "<div class='alert alert-danger'>✗ Ошибка: " . htmlspecialchars($e->getMessage()) . "</div>";
                        echo "<pre>" . htmlspecialchars($statement) . "</pre>";
                    }
                }
                
                // Проверяем, что таблица создана
                $result = $pdo->query($checkTableSql);
                
                if ($result->rowCount() > 0) {
                    echo "<div class='alert alert-success'><h4>✓ Таблица photo_commercial_posts успешно создана!</h4></div>";
                    
                    // Показываем структуру таблицы
                    $describeResult = $pdo->query("DESCRIBE photo_commercial_posts");
                    echo "<h3>Структура таблицы:</h3>";
                    echo "<table class='table table-bordered'>";
                    echo "<thead><tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr></thead>";
                    echo "<tbody>";
                    while ($row = $describeResult->fetch(PDO::FETCH_ASSOC)) {
                        echo "<tr>";
                        echo "<td>" . htmlspecialchars($row['Field']) . "</td>";
                        echo "<td>" . htmlspecialchars($row['Type']) . "</td>";
                        echo "<td>" . htmlspecialchars($row['Null']) . "</td>";
                        echo "<td>" . htmlspecialchars($row['Key']) . "</td>";
                        echo "<td>" . htmlspecialchars($row['Default'] ?? 'NULL') . "</td>";
                        echo "<td>" . htmlspecialchars($row['Extra']) . "</td>";
                        echo "</tr>";
                    }
                    echo "</tbody></table>";
                } else {
                    echo "<div class='alert alert-danger'>✗ Таблица не была создана</div>";
                }
            }
            
        } catch (Exception $e) {
            echo "<div class='alert alert-danger'>";
            echo "<h4>✗ Ошибка:</h4>";
            echo "<p>" . htmlspecialchars($e->getMessage()) . "</p>";
            echo "</div>";
        }
        ?>
        
        <hr>
        <div class="mt-4">
            <a href="views/posts.php" class="btn btn-primary">← Вернуться к постам</a>
            <a href="index.php" class="btn btn-secondary">← На главную</a>
        </div>
    </div>
</body>
</html>
