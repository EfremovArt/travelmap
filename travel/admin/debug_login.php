<?php
/**
 * Скрипт для диагностики проблем с авторизацией
 * Удалите после использования!
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Диагностика авторизации</title>";
echo "<style>body{font-family:Arial,sans-serif;max-width:900px;margin:50px auto;padding:20px;background:#f5f5f5;}";
echo ".box{background:white;padding:20px;margin:10px 0;border-radius:5px;box-shadow:0 2px 5px rgba(0,0,0,0.1);}";
echo ".success{color:green;}.error{color:red;}.warning{color:orange;}";
echo "pre{background:#f8f8f8;padding:10px;border-radius:3px;overflow-x:auto;}</style></head><body>";

echo "<h1>🔍 Диагностика авторизации</h1>";

// 1. Проверка подключения к БД
echo "<div class='box'>";
echo "<h2>1. Подключение к базе данных</h2>";
try {
    require_once '../config.php';
    $conn = connectToDatabase();
    echo "<p class='success'>✅ Подключение успешно</p>";
    
    // Показываем имя базы данных
    $dbName = $conn->query("SELECT DATABASE()")->fetchColumn();
    echo "<p>База данных: <strong>$dbName</strong></p>";
} catch (Exception $e) {
    echo "<p class='error'>❌ Ошибка подключения: " . $e->getMessage() . "</p>";
    echo "</div></body></html>";
    exit;
}
echo "</div>";

// 2. Проверка таблицы admin_users
echo "<div class='box'>";
echo "<h2>2. Таблица admin_users</h2>";
try {
    $stmt = $conn->query("SHOW TABLES LIKE 'admin_users'");
    if ($stmt->rowCount() > 0) {
        echo "<p class='success'>✅ Таблица admin_users существует</p>";
        
        // Проверяем количество администраторов
        $count = $conn->query("SELECT COUNT(*) FROM admin_users")->fetchColumn();
        echo "<p>Количество администраторов: <strong>$count</strong></p>";
        
        if ($count > 0) {
            // Показываем список администраторов (без паролей!)
            $admins = $conn->query("SELECT id, username, email, created_at, last_login FROM admin_users")->fetchAll(PDO::FETCH_ASSOC);
            echo "<table border='1' cellpadding='5' style='border-collapse:collapse;width:100%;'>";
            echo "<tr><th>ID</th><th>Username</th><th>Email</th><th>Создан</th><th>Последний вход</th></tr>";
            foreach ($admins as $admin) {
                echo "<tr>";
                echo "<td>" . $admin['id'] . "</td>";
                echo "<td><strong>" . htmlspecialchars($admin['username']) . "</strong></td>";
                echo "<td>" . htmlspecialchars($admin['email']) . "</td>";
                echo "<td>" . $admin['created_at'] . "</td>";
                echo "<td>" . ($admin['last_login'] ?? 'Никогда') . "</td>";
                echo "</tr>";
            }
            echo "</table>";
        } else {
            echo "<p class='warning'>⚠️ Нет администраторов в базе данных!</p>";
            echo "<p>Создайте администратора через SQL:</p>";
            echo "<pre>INSERT INTO admin_users (username, password_hash, email, created_at) 
VALUES ('admin', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@example.com', NOW());</pre>";
            echo "<p>Пароль: <strong>password</strong></p>";
        }
    } else {
        echo "<p class='error'>❌ Таблица admin_users не найдена!</p>";
        echo "<p>Создайте таблицу через setup_admin_table.sql</p>";
    }
} catch (Exception $e) {
    echo "<p class='error'>❌ Ошибка: " . $e->getMessage() . "</p>";
}
echo "</div>";

// 3. Проверка таблиц безопасности
echo "<div class='box'>";
echo "<h2>3. Таблицы безопасности</h2>";

$securityTables = ['admin_logs', 'login_attempts'];
foreach ($securityTables as $table) {
    try {
        $stmt = $conn->query("SHOW TABLES LIKE '$table'");
        if ($stmt->rowCount() > 0) {
            $count = $conn->query("SELECT COUNT(*) FROM $table")->fetchColumn();
            echo "<p class='success'>✅ Таблица $table существует ($count записей)</p>";
        } else {
            echo "<p class='warning'>⚠️ Таблица $table не найдена</p>";
            echo "<p>Запустите: <a href='create_security_tables.php'>create_security_tables.php</a></p>";
        }
    } catch (Exception $e) {
        echo "<p class='error'>❌ Ошибка проверки $table: " . $e->getMessage() . "</p>";
    }
}
echo "</div>";

// 4. Проверка расширений PHP
echo "<div class='box'>";
echo "<h2>4. Расширения PHP</h2>";
$extensions = ['pdo', 'pdo_mysql', 'json', 'session', 'mbstring'];
foreach ($extensions as $ext) {
    $loaded = extension_loaded($ext);
    if ($loaded) {
        echo "<p class='success'>✅ $ext установлено</p>";
    } else {
        if ($ext === 'mbstring') {
            echo "<p class='warning'>⚠️ $ext не установлено (не критично)</p>";
        } else {
            echo "<p class='error'>❌ $ext не установлено</p>";
        }
    }
}
echo "</div>";

// 5. Проверка прав доступа
echo "<div class='box'>";
echo "<h2>5. Права доступа</h2>";
$cacheDir = __DIR__ . '/cache';
if (file_exists($cacheDir)) {
    $writable = is_writable($cacheDir);
    echo "<p class='" . ($writable ? 'success' : 'error') . "'>";
    echo ($writable ? '✅' : '❌') . " Директория cache " . ($writable ? 'доступна' : 'НЕ доступна') . " для записи</p>";
} else {
    echo "<p class='error'>❌ Директория cache не существует</p>";
}
echo "</div>";

// 6. Тест авторизации
echo "<div class='box'>";
echo "<h2>6. Тест авторизации</h2>";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_once 'config/admin_config.php';
    
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    echo "<h3>Попытка входа:</h3>";
    echo "<p>Username: <strong>" . htmlspecialchars($username) . "</strong></p>";
    
    try {
        // Проверяем существование пользователя
        $stmt = $conn->prepare("SELECT id, username, password_hash, email FROM admin_users WHERE username = ?");
        $stmt->execute([$username]);
        $admin = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$admin) {
            echo "<p class='error'>❌ Пользователь не найден</p>";
        } else {
            echo "<p class='success'>✅ Пользователь найден (ID: {$admin['id']})</p>";
            
            // Проверяем пароль
            if (password_verify($password, $admin['password_hash'])) {
                echo "<p class='success'>✅ Пароль верный!</p>";
                echo "<p class='success'>🎉 Авторизация должна работать!</p>";
                echo "<p><a href='login.php'>Попробуйте войти через login.php</a></p>";
            } else {
                echo "<p class='error'>❌ Неверный пароль</p>";
                echo "<p>Hash в БД: <code>" . substr($admin['password_hash'], 0, 30) . "...</code></p>";
            }
        }
    } catch (Exception $e) {
        echo "<p class='error'>❌ Ошибка: " . $e->getMessage() . "</p>";
        echo "<pre>" . $e->getTraceAsString() . "</pre>";
    }
} else {
    echo "<form method='POST'>";
    echo "<p><label>Username: <input type='text' name='username' value='admin' required></label></p>";
    echo "<p><label>Password: <input type='password' name='password' required></label></p>";
    echo "<p><button type='submit'>Проверить авторизацию</button></p>";
    echo "</form>";
}
echo "</div>";

// 7. Информация о сессии
echo "<div class='box'>";
echo "<h2>7. Информация о сессии</h2>";
if (session_status() == PHP_SESSION_NONE) {
    session_start();
}
echo "<p>Session ID: <code>" . session_id() . "</code></p>";
echo "<p>Session status: <strong>" . (session_status() == PHP_SESSION_ACTIVE ? 'Активна' : 'Неактивна') . "</strong></p>";
if (!empty($_SESSION)) {
    echo "<p>Данные сессии:</p><pre>" . print_r($_SESSION, true) . "</pre>";
} else {
    echo "<p>Сессия пуста</p>";
}
echo "</div>";

echo "<hr>";
echo "<p><strong>⚠️ ВАЖНО: Удалите этот файл после диагностики!</strong></p>";
echo "<p><code>rm " . __FILE__ . "</code></p>";

echo "</body></html>";
?>
