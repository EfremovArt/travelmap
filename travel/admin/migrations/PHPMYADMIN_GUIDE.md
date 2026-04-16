# Руководство по установке миграций через phpMyAdmin

## Проблемы и решения

### Проблема 1: "You have an error in your SQL syntax near 'IF NOT EXISTS'"
**Причина:** Старые версии MySQL (< 5.7) не поддерживают `CREATE INDEX IF NOT EXISTS`
**Решение:** Используйте `ALTER TABLE` вместо `CREATE INDEX`

### Проблема 2: "Cannot add foreign key constraint"
**Причина:** Таблица `admin_users` может не существовать или иметь другую структуру
**Решение:** Убрали foreign key из миграции (он не критичен)

## Пошаговая установка через phpMyAdmin

### Шаг 1: Миграция безопасности

1. Откройте phpMyAdmin
2. Выберите вашу базу данных (например, `travel`)
3. Перейдите на вкладку **SQL**
4. Скопируйте и вставьте следующий код:

```sql
-- Таблица для логирования действий администраторов
CREATE TABLE IF NOT EXISTS admin_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    admin_id INT,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    target_type VARCHAR(50),
    target_id INT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admin_id (admin_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at),
    INDEX idx_target (target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Таблица для отслеживания попыток входа
CREATE TABLE IF NOT EXISTS login_attempts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    success BOOLEAN DEFAULT FALSE,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_ip_address (ip_address),
    INDEX idx_attempted_at (attempted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

5. Нажмите **Выполнить** (Go)
6. Должно появиться сообщение: "2 запроса выполнено успешно"

### Шаг 2: Миграция индексов производительности

**ВАЖНО:** Если при выполнении появляется ошибка "Duplicate key name", это нормально - индекс уже существует. Просто продолжайте со следующей секцией.

#### Вариант А: Выполнить все сразу (может дать ошибки)

1. Откройте вкладку **SQL**
2. Скопируйте весь файл `add_performance_indexes.sql`
3. Вставьте и нажмите **Выполнить**
4. Игнорируйте ошибки "Duplicate key name"

#### Вариант Б: Выполнить по секциям (РЕКОМЕНДУЕТСЯ)

Выполняйте каждую секцию отдельно. Если появляется ошибка "Duplicate key name", просто переходите к следующей секции.

**Секция 1: Likes**
```sql
ALTER TABLE likes ADD INDEX idx_likes_user_id (user_id);
ALTER TABLE likes ADD INDEX idx_likes_photo_id (photo_id);
ALTER TABLE likes ADD INDEX idx_likes_created_at (created_at);
ALTER TABLE likes ADD INDEX idx_likes_user_photo (user_id, photo_id);
```

**Секция 2: Comments**
```sql
ALTER TABLE comments ADD INDEX idx_comments_user_id (user_id);
ALTER TABLE comments ADD INDEX idx_comments_photo_id (photo_id);
ALTER TABLE comments ADD INDEX idx_comments_created_at (created_at);
ALTER TABLE comments ADD INDEX idx_comments_photo_created (photo_id, created_at);
```

**Секция 3: Album Comments**
```sql
ALTER TABLE album_comments ADD INDEX idx_album_comments_user_id (user_id);
ALTER TABLE album_comments ADD INDEX idx_album_comments_album_id (album_id);
ALTER TABLE album_comments ADD INDEX idx_album_comments_created_at (created_at);
```

**Секция 4: Follows**
```sql
ALTER TABLE follows ADD INDEX idx_follows_follower_id (follower_id);
ALTER TABLE follows ADD INDEX idx_follows_followed_id (followed_id);
ALTER TABLE follows ADD INDEX idx_follows_created_at (created_at);
ALTER TABLE follows ADD INDEX idx_follows_follower_followed (follower_id, followed_id);
```

**Секция 5: Favorites**
```sql
ALTER TABLE favorites ADD INDEX idx_favorites_user_id (user_id);
ALTER TABLE favorites ADD INDEX idx_favorites_photo_id (photo_id);
ALTER TABLE favorites ADD INDEX idx_favorites_created_at (created_at);
```

**Секция 6: Album Favorites**
```sql
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_user_id (user_id);
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_album_id (album_id);
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_created_at (created_at);
```

**Секция 7: Commercial Favorites**
```sql
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_user_id (user_id);
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_commercial_post_id (commercial_post_id);
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_created_at (created_at);
```

**Секция 8: Photos**
```sql
ALTER TABLE photos ADD INDEX idx_photos_user_id (user_id);
ALTER TABLE photos ADD INDEX idx_photos_location_id (location_id);
ALTER TABLE photos ADD INDEX idx_photos_created_at (created_at);
ALTER TABLE photos ADD INDEX idx_photos_user_created (user_id, created_at);
```

**Секция 9: Albums**
```sql
ALTER TABLE albums ADD INDEX idx_albums_owner_id (owner_id);
ALTER TABLE albums ADD INDEX idx_albums_created_at (created_at);
ALTER TABLE albums ADD INDEX idx_albums_is_public (is_public);
```

**Секция 10: Album Photos**
```sql
ALTER TABLE album_photos ADD INDEX idx_album_photos_album_id (album_id);
ALTER TABLE album_photos ADD INDEX idx_album_photos_photo_id (photo_id);
```

**Секция 11: Commercial Posts**
```sql
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_user_id (user_id);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_type (type);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_album_id (album_id);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_photo_id (photo_id);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_is_active (is_active);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_created_at (created_at);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_type_active (type, is_active);
```

**Секция 12: Users**
```sql
ALTER TABLE users ADD INDEX idx_users_email (email);
ALTER TABLE users ADD INDEX idx_users_created_at (created_at);
```

**Секция 13: Locations**
```sql
ALTER TABLE locations ADD INDEX idx_locations_name (name);
```

### Шаг 3: Проверка установки

Проверьте, что индексы созданы:

```sql
-- Проверка таблиц безопасности
SHOW TABLES LIKE 'admin_logs';
SHOW TABLES LIKE 'login_attempts';

-- Проверка индексов на важных таблицах
SHOW INDEX FROM likes;
SHOW INDEX FROM comments;
SHOW INDEX FROM photos;
SHOW INDEX FROM commercial_posts;
```

Должно показать несколько индексов для каждой таблицы.

## Альтернативный метод: Через командную строку

Если у вас есть доступ к SSH:

```bash
# Перейдите в директорию миграций
cd /path/to/travel/admin/migrations

# Выполните миграцию безопасности
mysql -u ваш_пользователь -p ваша_база < add_security_tables.sql

# Выполните миграцию индексов (игнорируя ошибки дубликатов)
mysql -u ваш_пользователь -p ваша_база < add_performance_indexes.sql 2>&1 | grep -v "Duplicate key name"
```

## Альтернативный метод: Через PHP скрипт

Создайте файл `run_migrations.php` в папке `travel/admin/`:

```php
<?php
require_once '../config.php';

echo "Запуск миграций...\n\n";

try {
    $conn = connectToDatabase();
    
    // Миграция 1: Безопасность
    echo "1. Создание таблиц безопасности...\n";
    
    $sql1 = "CREATE TABLE IF NOT EXISTS admin_logs (
        id INT PRIMARY KEY AUTO_INCREMENT,
        admin_id INT,
        action VARCHAR(100) NOT NULL,
        details TEXT,
        target_type VARCHAR(50),
        target_id INT,
        ip_address VARCHAR(45),
        user_agent TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_admin_id (admin_id),
        INDEX idx_action (action),
        INDEX idx_created_at (created_at),
        INDEX idx_target (target_type, target_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    
    $conn->exec($sql1);
    echo "✓ Таблица admin_logs создана\n";
    
    $sql2 = "CREATE TABLE IF NOT EXISTS login_attempts (
        id INT PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(100) NOT NULL,
        ip_address VARCHAR(45) NOT NULL,
        success BOOLEAN DEFAULT FALSE,
        attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_username (username),
        INDEX idx_ip_address (ip_address),
        INDEX idx_attempted_at (attempted_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    
    $conn->exec($sql2);
    echo "✓ Таблица login_attempts создана\n\n";
    
    // Миграция 2: Индексы
    echo "2. Создание индексов производительности...\n";
    echo "   (Ошибки 'Duplicate key name' - это нормально)\n\n";
    
    $indexes = [
        "ALTER TABLE likes ADD INDEX idx_likes_user_id (user_id)",
        "ALTER TABLE likes ADD INDEX idx_likes_photo_id (photo_id)",
        "ALTER TABLE comments ADD INDEX idx_comments_user_id (user_id)",
        "ALTER TABLE comments ADD INDEX idx_comments_photo_id (photo_id)",
        "ALTER TABLE follows ADD INDEX idx_follows_follower_id (follower_id)",
        "ALTER TABLE follows ADD INDEX idx_follows_followed_id (followed_id)",
        "ALTER TABLE photos ADD INDEX idx_photos_user_id (user_id)",
        "ALTER TABLE photos ADD INDEX idx_photos_created_at (created_at)",
        // Добавьте остальные индексы по необходимости
    ];
    
    $created = 0;
    $skipped = 0;
    
    foreach ($indexes as $sql) {
        try {
            $conn->exec($sql);
            $created++;
            echo "✓";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate') !== false) {
                $skipped++;
                echo "-";
            } else {
                echo "✗";
            }
        }
    }
    
    echo "\n\n";
    echo "Миграции завершены!\n";
    echo "Создано индексов: $created\n";
    echo "Уже существовало: $skipped\n";
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
}
```

Затем запустите:
```bash
php run_migrations.php
```

## Проверка результата

После установки всех миграций проверьте:

1. **Таблицы безопасности существуют:**
   ```sql
   SELECT COUNT(*) FROM admin_logs;
   SELECT COUNT(*) FROM login_attempts;
   ```

2. **Индексы созданы:**
   ```sql
   SELECT COUNT(*) as index_count 
   FROM information_schema.STATISTICS 
   WHERE table_schema = 'ваша_база_данных' 
   AND table_name IN ('likes', 'comments', 'follows', 'photos');
   ```
   
   Должно показать 20+ индексов.

3. **Админ-панель работает:**
   - Откройте `http://ваш-домен/travel/admin/login.php`
   - Войдите в систему
   - Dashboard должен загружаться быстро (< 1 секунды)

## Часто задаваемые вопросы

**Q: Что делать, если появляется "Duplicate key name"?**
A: Это нормально - индекс уже существует. Просто продолжайте.

**Q: Что делать, если появляется "Table doesn't exist"?**
A: Проверьте, что вы выбрали правильную базу данных в phpMyAdmin.

**Q: Нужно ли удалять старые индексы перед созданием новых?**
A: Нет, если индекс уже существует, он просто не будет создан повторно.

**Q: Можно ли запустить миграции несколько раз?**
A: Да, миграции безопасны для повторного запуска.

**Q: Сколько времени занимает создание индексов?**
A: Зависит от размера базы данных. Обычно 1-5 минут для небольших баз, до 30 минут для больших.

## Поддержка

Если возникли проблемы:
1. Проверьте версию MySQL: `SELECT VERSION();`
2. Проверьте права пользователя: `SHOW GRANTS;`
3. Проверьте логи ошибок MySQL
4. Попробуйте выполнить миграции по секциям
