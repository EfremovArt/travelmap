# Требования к серверу и решение проблем

## Минимальные требования

### PHP
- **Версия:** 7.4 или выше
- **Обязательные расширения:**
  - PDO
  - PDO_MySQL
  - JSON (обычно включено по умолчанию)
  - Session (обычно включено по умолчанию)

### Рекомендуемые расширения PHP
- **mbstring** - для корректной работы с многобайтными строками (UTF-8)
  - ⚠️ Если не установлено, админ-панель всё равно будет работать
  - Используется fallback на стандартные функции

### MySQL/MariaDB
- **MySQL:** 5.5 или выше (рекомендуется 5.7+)
- **MariaDB:** 10.3 или выше

### Web Server
- **Apache:** 2.4+ с mod_rewrite
- **Nginx:** 1.18+

### Права доступа
- Директория `travel/admin/cache/` должна быть доступна для записи (755)

## Проверка установленных расширений PHP

Создайте файл `phpinfo.php` в корне сайта:

```php
<?php
phpinfo();
?>
```

Откройте в браузере: `http://ваш-домен/phpinfo.php`

Найдите секции:
- **PDO** - должна быть включена
- **pdo_mysql** - должна быть включена
- **mbstring** - желательно, но не обязательно

⚠️ **Удалите файл после проверки!**

## Установка недостающих расширений

### Ubuntu/Debian

```bash
# Обновите список пакетов
sudo apt update

# Установите расширения PHP (замените 8.1 на вашу версию PHP)
sudo apt install php8.1-mbstring php8.1-mysql php8.1-pdo

# Перезапустите веб-сервер
sudo systemctl restart apache2
# или для nginx
sudo systemctl restart php8.1-fpm
```

### CentOS/RHEL

```bash
# Установите расширения PHP
sudo yum install php-mbstring php-mysqlnd php-pdo

# Перезапустите веб-сервер
sudo systemctl restart httpd
# или для nginx
sudo systemctl restart php-fpm
```

### Через панель управления хостингом

#### cPanel
1. Войдите в cPanel
2. Найдите "Select PHP Version" или "MultiPHP Manager"
3. Выберите вашу версию PHP
4. Отметьте галочками:
   - mbstring
   - mysqlnd
   - pdo
   - pdo_mysql
5. Сохраните изменения

#### Plesk
1. Войдите в Plesk
2. Перейдите в "Инструменты и настройки"
3. Выберите "Настройки PHP"
4. Включите расширения:
   - mbstring
   - mysqli
   - pdo
   - pdo_mysql
5. Примените изменения

#### ISPmanager
1. Войдите в ISPmanager
2. Перейдите в "WWW" → "PHP"
3. Выберите версию PHP
4. Включите модули:
   - mbstring
   - mysqli
   - pdo_mysql
5. Сохраните

## Решение распространенных проблем

### Ошибка: "Call to undefined function mb_strlen()"

**Причина:** Расширение mbstring не установлено

**Решение 1 (ИСПРАВЛЕНО):** Код админ-панели уже исправлен и работает без mbstring

**Решение 2:** Установите mbstring (см. инструкции выше)

### Ошибка: "could not find driver"

**Причина:** Расширение PDO_MySQL не установлено

**Решение:**
```bash
# Ubuntu/Debian
sudo apt install php8.1-mysql

# CentOS/RHEL
sudo yum install php-mysqlnd

# Перезапустите веб-сервер
sudo systemctl restart apache2
```

### Ошибка: "Permission denied" для cache

**Причина:** Недостаточно прав для записи в директорию cache

**Решение:**
```bash
chmod 755 travel/admin/cache
chown www-data:www-data travel/admin/cache  # Ubuntu/Debian
# или
chown apache:apache travel/admin/cache      # CentOS/RHEL
```

### Ошибка: "Access denied for user"

**Причина:** Неверные данные подключения к базе данных

**Решение:** Проверьте файл `travel/config.php`:
```php
$host = 'localhost';      // Обычно localhost
$dbname = 'ваша_база';    // Имя базы данных
$username = 'ваш_юзер';   // Пользователь БД
$password = 'ваш_пароль'; // Пароль БД
```

### Ошибка: "Table doesn't exist"

**Причина:** Миграции не выполнены

**Решение:** Выполните миграции согласно [QUICK_START.md](QUICK_START.md)

## Проверка конфигурации PHP

Создайте файл `check_requirements.php`:

```php
<?php
echo "<h1>Проверка требований для админ-панели</h1>";

// Проверка версии PHP
echo "<h2>PHP Version</h2>";
echo "Текущая версия: " . PHP_VERSION . "<br>";
echo "Требуется: 7.4+<br>";
echo (version_compare(PHP_VERSION, '7.4.0') >= 0) ? "✅ OK" : "❌ FAIL";

echo "<hr>";

// Проверка расширений
echo "<h2>Расширения PHP</h2>";

$required = ['pdo', 'pdo_mysql', 'json', 'session'];
$recommended = ['mbstring'];

echo "<h3>Обязательные:</h3>";
foreach ($required as $ext) {
    $loaded = extension_loaded($ext);
    echo "$ext: " . ($loaded ? "✅ Установлено" : "❌ НЕ установлено") . "<br>";
}

echo "<h3>Рекомендуемые:</h3>";
foreach ($recommended as $ext) {
    $loaded = extension_loaded($ext);
    echo "$ext: " . ($loaded ? "✅ Установлено" : "⚠️ Не установлено (не критично)") . "<br>";
}

echo "<hr>";

// Проверка прав доступа
echo "<h2>Права доступа</h2>";
$cacheDir = __DIR__ . '/cache';
if (file_exists($cacheDir)) {
    $writable = is_writable($cacheDir);
    echo "Директория cache: " . ($writable ? "✅ Доступна для записи" : "❌ НЕ доступна для записи") . "<br>";
} else {
    echo "Директория cache: ❌ Не существует<br>";
}

echo "<hr>";

// Проверка подключения к БД
echo "<h2>Подключение к базе данных</h2>";
try {
    require_once '../config.php';
    $conn = connectToDatabase();
    echo "✅ Подключение успешно<br>";
    
    // Проверка таблиц
    $tables = ['admin_users', 'admin_logs', 'login_attempts', 'users', 'photos', 'likes', 'comments'];
    echo "<h3>Таблицы:</h3>";
    foreach ($tables as $table) {
        $stmt = $conn->prepare("SHOW TABLES LIKE ?");
        $stmt->execute([$table]);
        $exists = $stmt->fetch() !== false;
        echo "$table: " . ($exists ? "✅ Существует" : "⚠️ Не найдена") . "<br>";
    }
} catch (Exception $e) {
    echo "❌ Ошибка подключения: " . $e->getMessage() . "<br>";
}

echo "<hr>";
echo "<p><strong>⚠️ Удалите этот файл после проверки!</strong></p>";
?>
```

Откройте: `http://ваш-домен/travel/admin/check_requirements.php`

⚠️ **Удалите файл после проверки!**

## Рекомендуемые настройки php.ini

```ini
; Увеличьте лимиты для загрузки файлов
upload_max_filesize = 20M
post_max_size = 20M

; Увеличьте лимит памяти
memory_limit = 256M

; Увеличьте время выполнения скриптов
max_execution_time = 300

; Включите отображение ошибок (только для разработки!)
display_errors = Off
log_errors = On
error_log = /path/to/php-error.log

; Настройки сессий
session.cookie_httponly = 1
session.cookie_secure = 1  ; Только для HTTPS
session.use_strict_mode = 1

; Часовой пояс
date.timezone = Europe/Moscow
```

## Проверка после установки

1. **Откройте админ-панель:**
   ```
   http://ваш-домен/travel/admin/login.php
   ```

2. **Проверьте консоль браузера (F12):**
   - Не должно быть ошибок JavaScript
   - Все запросы должны возвращать 200 OK

3. **Проверьте логи ошибок:**
   ```bash
   # Apache
   tail -f /var/log/apache2/error.log
   
   # Nginx
   tail -f /var/log/nginx/error.log
   
   # PHP-FPM
   tail -f /var/log/php8.1-fpm.log
   ```

4. **Проверьте производительность:**
   - Dashboard должен загружаться за < 1 секунды
   - Списки данных за < 500ms

## Оптимизация производительности сервера

### Для Apache

Включите модули:
```bash
sudo a2enmod rewrite
sudo a2enmod deflate
sudo a2enmod expires
sudo a2enmod headers
sudo systemctl restart apache2
```

### Для Nginx

Добавьте в конфигурацию:
```nginx
# Кеширование статических файлов
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Сжатие
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

### Для MySQL

Оптимизируйте настройки в `my.cnf`:
```ini
[mysqld]
innodb_buffer_pool_size = 256M
query_cache_size = 32M
query_cache_type = 1
max_connections = 100
```

## Поддержка

Если проблемы остаются:
1. Проверьте логи ошибок PHP и веб-сервера
2. Запустите `check_requirements.php`
3. Проверьте права доступа к файлам
4. Убедитесь, что все миграции выполнены
5. Проверьте настройки подключения к БД

## Контакты хостинг-провайдеров

Если не можете установить расширения самостоятельно, обратитесь в поддержку хостинга:
- Укажите, что нужно установить PHP расширения: mbstring, pdo_mysql
- Попросите проверить права доступа к директориям
- Попросите проверить настройки PHP
