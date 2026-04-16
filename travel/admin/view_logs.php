<?php
require_once 'config/admin_config.php';
adminRequireAuth();
?>
<!DOCTYPE html>
<html>
<head>
    <title>Просмотр логов</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: monospace; margin: 20px; background: #1e1e1e; color: #d4d4d4; }
        h1 { color: #4ec9b0; }
        .log-entry { margin: 10px 0; padding: 10px; background: #252526; border-left: 3px solid #007acc; }
        .log-entry.error { border-left-color: #f48771; }
        .log-entry.warning { border-left-color: #dcdcaa; }
        .log-entry.info { border-left-color: #4ec9b0; }
        .timestamp { color: #608b4e; }
        .filter { margin: 20px 0; }
        .filter input { padding: 5px; width: 300px; }
        button { padding: 10px 20px; background: #007acc; color: white; border: none; cursor: pointer; }
        button:hover { background: #005a9e; }
        pre { white-space: pre-wrap; word-wrap: break-word; }
    </style>
</head>
<body>
    <h1>📋 Логи приложения</h1>
    
    <div class="filter">
        <input type="text" id="searchInput" placeholder="Поиск по логам (например: 'birthday', 'update_profile')">
        <button onclick="filterLogs()">Фильтр</button>
        <button onclick="location.reload()">Обновить</button>
        <button onclick="clearSearch()">Очистить</button>
    </div>
    
    <div id="logs">
        <?php
        // Пути к возможным файлам логов
        $logPaths = [
            '/Applications/MAMP/logs/php_error.log',
            '/var/log/apache2/error.log',
            '/var/log/php_errors.log',
            ini_get('error_log'),
            __DIR__ . '/../error_log',
            __DIR__ . '/../../error_log'
        ];
        
        $foundLog = false;
        
        foreach ($logPaths as $logPath) {
            if ($logPath && file_exists($logPath) && is_readable($logPath)) {
                echo "<h2>Файл: $logPath</h2>";
                
                // Читаем последние 200 строк
                $lines = [];
                $file = new SplFileObject($logPath);
                $file->seek(PHP_INT_MAX);
                $totalLines = $file->key();
                
                $startLine = max(0, $totalLines - 200);
                $file->seek($startLine);
                
                while (!$file->eof()) {
                    $line = $file->current();
                    if (!empty(trim($line))) {
                        $lines[] = $line;
                    }
                    $file->next();
                }
                
                // Выводим логи в обратном порядке (новые сверху)
                $lines = array_reverse($lines);
                
                foreach ($lines as $line) {
                    $class = 'log-entry';
                    if (stripos($line, 'error') !== false || stripos($line, 'fatal') !== false) {
                        $class .= ' error';
                    } elseif (stripos($line, 'warning') !== false) {
                        $class .= ' warning';
                    } elseif (stripos($line, 'birthday') !== false || stripos($line, 'update') !== false) {
                        $class .= ' info';
                    }
                    
                    echo "<div class='$class'>" . htmlspecialchars($line) . "</div>";
                }
                
                $foundLog = true;
                break; // Показываем только первый найденный лог
            }
        }
        
        if (!$foundLog) {
            echo "<div class='log-entry error'>";
            echo "<p>❌ Файлы логов не найдены в следующих местах:</p>";
            echo "<ul>";
            foreach ($logPaths as $path) {
                if ($path) {
                    echo "<li>" . htmlspecialchars($path) . "</li>";
                }
            }
            echo "</ul>";
            echo "<p>Текущая директория: " . __DIR__ . "</p>";
            echo "<p>error_log из php.ini: " . ini_get('error_log') . "</p>";
            echo "</div>";
        }
        ?>
    </div>
    
    <script>
        function filterLogs() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const logs = document.querySelectorAll('.log-entry');
            
            logs.forEach(log => {
                if (log.textContent.toLowerCase().includes(searchTerm)) {
                    log.style.display = 'block';
                } else {
                    log.style.display = 'none';
                }
            });
        }
        
        function clearSearch() {
            document.getElementById('searchInput').value = '';
            const logs = document.querySelectorAll('.log-entry');
            logs.forEach(log => {
                log.style.display = 'block';
            });
        }
        
        // Автоматический поиск при вводе
        document.getElementById('searchInput').addEventListener('input', filterLogs);
    </script>
</body>
</html>
