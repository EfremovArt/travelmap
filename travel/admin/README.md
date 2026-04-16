# TravelMap Admin Panel

Административная панель для управления контентом и пользователями приложения TravelMap.

## Быстрый старт

📖 **Для быстрой установки смотрите [QUICK_START.md](QUICK_START.md)**

## Установка

### 1. Создание таблицы администраторов

Выполните SQL скрипт для создания таблицы `admin_users`:

```bash
mysql -u travel -p travel < setup_admin_table.sql
```

Или выполните SQL команды вручную через phpMyAdmin или другой клиент MySQL.

### 2. Тестовый администратор

После выполнения скрипта будет создан тестовый администратор:

- **Имя пользователя:** `admin`
- **Пароль:** `admin123`

⚠️ **ВАЖНО:** Измените пароль после первого входа!

### 3. Настройка прав доступа

```bash
chmod 755 travel/admin/cache
chown www-data:www-data travel/admin/cache  # для Ubuntu/Debian
```

### 4. Доступ к панели

Откройте в браузере:
```
http://your-domain/travel/admin/login.php
```

## Структура директорий

```
admin/
├── config/              # Конфигурационные файлы
│   └── admin_config.php # Функции авторизации
├── api/                 # API endpoints (будут добавлены в следующих задачах)
├── views/               # Страницы интерфейса (будут добавлены в следующих задачах)
├── assets/              # Статические ресурсы
│   ├── css/            # Стили
│   ├── js/             # JavaScript
│   └── images/         # Изображения
├── includes/            # Общие компоненты (будут добавлены в следующих задачах)
├── index.php            # Главная страница
├── login.php            # Страница входа
└── logout.php           # Выход из системы
```

## Создание нового администратора

Для создания нового администратора используйте PHP скрипт:

```php
<?php
$password = 'your_secure_password';
$hash = password_hash($password, PASSWORD_DEFAULT);
echo "Password hash: " . $hash . "\n";

// Затем выполните SQL:
// INSERT INTO admin_users (username, password_hash, email) 
// VALUES ('username', '$hash', 'email@example.com');
?>
```

## Безопасность

Административная панель включает комплексную систему безопасности:

### Установка функций безопасности

1. **Создайте таблицы безопасности:**
   ```bash
   php install_security.php
   ```
   
   Или вручную:
   ```bash
   mysql -u travel -p travel < migrations/add_security_tables.sql
   ```

2. **Проверьте установку:**
   ```bash
   php test_security.php
   ```

### Реализованные функции безопасности

- ✅ **CSRF Protection** - Защита от межсайтовой подделки запросов
- ✅ **Input Validation** - Валидация всех входных данных
- ✅ **Output Escaping** - Экранирование вывода для предотвращения XSS
- ✅ **Admin Action Logging** - Логирование всех действий администраторов
- ✅ **Brute Force Protection** - Защита от перебора паролей (5 попыток за 15 минут)
- ✅ **Session Security** - Безопасное управление сессиями
- ✅ **SQL Injection Prevention** - Использование prepared statements
- ✅ **Password Hashing** - Хеширование паролей с bcrypt

### Документация

Подробная документация по безопасности доступна в файле [SECURITY.md](SECURITY.md)

### Мониторинг

Просмотр логов действий администраторов:
```sql
SELECT * FROM admin_logs 
WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY created_at DESC;
```

Просмотр неудачных попыток входа:
```sql
SELECT username, COUNT(*) as attempts, MAX(attempted_at) as last_attempt
FROM login_attempts 
WHERE success = 0 
AND attempted_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY username
ORDER BY attempts DESC;
```

## Оптимизация и производительность

### Установка индексов базы данных

Для оптимальной производительности установите индексы базы данных:

```bash
cd travel/admin/migrations
php apply_indexes.php
```

Или вручную:
```bash
mysql -u travel -p travel < migrations/add_performance_indexes.sql
```

### Тестирование производительности

Запустите скрипт тестирования производительности:

```bash
cd travel/admin
php test_performance.php
```

Этот скрипт проверит:
- Подключение к базе данных
- Наличие индексов
- Производительность запросов
- Работу системы кеширования
- Размеры таблиц
- Использование индексов

### Кеширование

Панель администратора использует файловое кеширование для оптимизации:

- **Директория кеша:** `travel/admin/cache/`
- **TTL по умолчанию:** 5 минут
- **Кешируемые данные:** Статистика dashboard

**Очистка кеша:**
```php
require_once 'config/cache_config.php';
$adminCache->clear();
```

**Очистка устаревшего кеша:**
```php
$adminCache->cleanExpired();
```

### Целевые показатели производительности

- Dashboard (с кешем): < 200ms
- Dashboard (без кеша): < 1s
- Списки данных: < 500ms
- Детальные страницы: < 1s
- Операции удаления: < 300ms

### Документация

- **[OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md)** - Полное руководство по оптимизации
- **[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** - Чеклист для тестирования

## Тестирование

### Ручное тестирование

Используйте подробный чеклист для тестирования всех функций:

```bash
cat TESTING_CHECKLIST.md
```

Чеклист включает тестирование:
- ✅ Аутентификации и авторизации
- ✅ Dashboard и статистики
- ✅ Управления лайками
- ✅ Управления комментариями
- ✅ Управления пользователями
- ✅ Управления подписками
- ✅ Управления избранным
- ✅ Управления публикациями
- ✅ Модерации контента
- ✅ Безопасности (SQL injection, XSS, CSRF)
- ✅ Производительности
- ✅ Адаптивного дизайна
- ✅ Совместимости с браузерами

### Автоматическое тестирование

Запустите тесты безопасности:
```bash
php test_security.php
```

Запустите тесты производительности:
```bash
php test_performance.php
```

## Мониторинг

### Логи действий администраторов

```sql
SELECT * FROM admin_logs 
WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY created_at DESC;
```

### Медленные запросы

Включите лог медленных запросов в MySQL:
```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
```

### Размеры таблиц

```sql
SELECT 
    table_name,
    table_rows,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
FROM information_schema.TABLES
WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;
```

## Поддержка

Для вопросов по:
- **Безопасности:** см. [SECURITY.md](SECURITY.md)
- **Оптимизации:** см. [OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md)
- **Тестированию:** см. [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)


## Решение проблем

### Проблема: "You have an error in your SQL syntax near 'IF NOT EXISTS'"

**Причина:** Старые версии MySQL (< 5.7) не поддерживают `CREATE INDEX IF NOT EXISTS`

**Решение:** Используйте исправленные файлы миграций:
- Файлы уже обновлены для совместимости с MySQL 5.5+
- Используйте `ALTER TABLE` вместо `CREATE INDEX`
- Смотрите [PHPMYADMIN_GUIDE.md](migrations/PHPMYADMIN_GUIDE.md) для пошаговой инструкции

### Проблема: "Cannot add foreign key constraint"

**Причина:** Таблица `admin_users` может не существовать или иметь другую структуру

**Решение:** 
- Foreign key убран из миграции (он не критичен для работы)
- Используйте обновленный файл `migrations/add_security_tables.sql`

### Проблема: "Duplicate key name"

**Это нормально!** Индекс уже существует. Просто продолжайте со следующей командой.

### Проблема: "Table doesn't exist"

**Решение:** Пропустите создание индексов для этой таблицы - она не используется в вашей базе данных.

### Проблема: "Permission denied" при записи в cache

**Решение:**
```bash
chmod 755 travel/admin/cache
chown www-data:www-data travel/admin/cache
```

### Проблема: Dashboard загружается медленно

**Решение:**
1. Проверьте, что индексы созданы: `SHOW INDEX FROM likes;`
2. Проверьте, что кеш работает (в ответе API должно быть `"cached": true`)
3. Очистите кеш: `rm -rf travel/admin/cache/*.cache`

## Документация

### Основная документация
- **[QUICK_START.md](QUICK_START.md)** - Быстрый старт (начните отсюда!)
- **[README.md](README.md)** - Этот файл, полное руководство
- **[SECURITY.md](SECURITY.md)** - Документация по безопасности

### Миграции и установка
- **[migrations/README.md](migrations/README.md)** - Документация по миграциям
- **[migrations/PHPMYADMIN_GUIDE.md](migrations/PHPMYADMIN_GUIDE.md)** - Подробная инструкция для phpMyAdmin

### Оптимизация и тестирование
- **[OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md)** - Руководство по оптимизации
- **[OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md)** - Краткое описание оптимизаций
- **[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** - Чеклист для тестирования (280+ тестов)
- **[RESPONSIVE_DESIGN_TEST.md](RESPONSIVE_DESIGN_TEST.md)** - Тестирование адаптивного дизайна

### Справочники по безопасности
- **[SECURITY_QUICK_REFERENCE.md](SECURITY_QUICK_REFERENCE.md)** - Быстрый справочник
- **[SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md)** - Чеклист безопасности
- **[SECURITY_IMPLEMENTATION_SUMMARY.md](SECURITY_IMPLEMENTATION_SUMMARY.md)** - Описание реализации

## Версии и совместимость

### Требования
- **PHP:** 7.4 или выше
- **MySQL:** 5.5 или выше (рекомендуется 5.7+)
- **Web Server:** Apache 2.4+ или Nginx 1.18+
- **Расширения PHP:** PDO, PDO_MySQL, JSON, mbstring

### Протестировано на
- PHP 7.4, 8.0, 8.1, 8.2
- MySQL 5.7, 8.0
- MariaDB 10.3, 10.5, 10.6
- Apache 2.4
- Nginx 1.18

### Совместимость с браузерами
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+
