# SQL Шпаргалка для быстрой установки

## Копируйте и вставляйте в phpMyAdmin

### Шаг 1: Таблицы безопасности (обязательно)

```sql
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

### Шаг 2: Индексы (выполняйте по одной секции)

**Игнорируйте ошибки "Duplicate key name" - это нормально!**

#### Секция 1: Likes
```sql
ALTER TABLE likes ADD INDEX idx_likes_user_id (user_id);
ALTER TABLE likes ADD INDEX idx_likes_photo_id (photo_id);
ALTER TABLE likes ADD INDEX idx_likes_created_at (created_at);
ALTER TABLE likes ADD INDEX idx_likes_user_photo (user_id, photo_id);
```

#### Секция 2: Comments
```sql
ALTER TABLE comments ADD INDEX idx_comments_user_id (user_id);
ALTER TABLE comments ADD INDEX idx_comments_photo_id (photo_id);
ALTER TABLE comments ADD INDEX idx_comments_created_at (created_at);
ALTER TABLE comments ADD INDEX idx_comments_photo_created (photo_id, created_at);
```

#### Секция 3: Follows
```sql
ALTER TABLE follows ADD INDEX idx_follows_follower_id (follower_id);
ALTER TABLE follows ADD INDEX idx_follows_followed_id (followed_id);
ALTER TABLE follows ADD INDEX idx_follows_created_at (created_at);
ALTER TABLE follows ADD INDEX idx_follows_follower_followed (follower_id, followed_id);
```

#### Секция 4: Favorites
```sql
ALTER TABLE favorites ADD INDEX idx_favorites_user_id (user_id);
ALTER TABLE favorites ADD INDEX idx_favorites_photo_id (photo_id);
ALTER TABLE favorites ADD INDEX idx_favorites_created_at (created_at);
```

#### Секция 5: Photos
```sql
ALTER TABLE photos ADD INDEX idx_photos_user_id (user_id);
ALTER TABLE photos ADD INDEX idx_photos_location_id (location_id);
ALTER TABLE photos ADD INDEX idx_photos_created_at (created_at);
ALTER TABLE photos ADD INDEX idx_photos_user_created (user_id, created_at);
```

#### Секция 6: Albums
```sql
ALTER TABLE albums ADD INDEX idx_albums_owner_id (owner_id);
ALTER TABLE albums ADD INDEX idx_albums_created_at (created_at);
ALTER TABLE albums ADD INDEX idx_albums_is_public (is_public);
```

#### Секция 7: Commercial Posts
```sql
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_user_id (user_id);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_type (type);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_is_active (is_active);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_created_at (created_at);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_type_active (type, is_active);
```

#### Секция 8: Users
```sql
ALTER TABLE users ADD INDEX idx_users_email (email);
ALTER TABLE users ADD INDEX idx_users_created_at (created_at);
```

#### Секция 9: Locations (если есть)
```sql
ALTER TABLE locations ADD INDEX idx_locations_name (name);
```

#### Секция 10: Album Comments (если есть)
```sql
ALTER TABLE album_comments ADD INDEX idx_album_comments_user_id (user_id);
ALTER TABLE album_comments ADD INDEX idx_album_comments_album_id (album_id);
ALTER TABLE album_comments ADD INDEX idx_album_comments_created_at (created_at);
```

#### Секция 11: Album Favorites (если есть)
```sql
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_user_id (user_id);
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_album_id (album_id);
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_created_at (created_at);
```

#### Секция 12: Commercial Favorites (если есть)
```sql
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_user_id (user_id);
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_commercial_post_id (commercial_post_id);
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_created_at (created_at);
```

#### Секция 13: Album Photos (если есть)
```sql
ALTER TABLE album_photos ADD INDEX idx_album_photos_album_id (album_id);
ALTER TABLE album_photos ADD INDEX idx_album_photos_photo_id (photo_id);
```

### Шаг 3: Проверка

```sql
-- Проверка таблиц безопасности
SELECT COUNT(*) FROM admin_logs;
SELECT COUNT(*) FROM login_attempts;

-- Проверка индексов
SHOW INDEX FROM likes;
SHOW INDEX FROM comments;
SHOW INDEX FROM photos;

-- Проверка всех индексов
SELECT 
    table_name,
    COUNT(*) as index_count
FROM information_schema.STATISTICS 
WHERE table_schema = DATABASE()
AND table_name IN ('likes', 'comments', 'follows', 'favorites', 'photos', 'albums', 'commercial_posts', 'users')
GROUP BY table_name;
```

## Быстрая проверка после установки

```sql
-- Должно вернуть 0 (таблицы пустые, но существуют)
SELECT COUNT(*) FROM admin_logs;
SELECT COUNT(*) FROM login_attempts;

-- Должно показать несколько индексов для каждой таблицы
SHOW INDEX FROM likes WHERE Key_name LIKE 'idx_%';
SHOW INDEX FROM comments WHERE Key_name LIKE 'idx_%';
SHOW INDEX FROM photos WHERE Key_name LIKE 'idx_%';
```

## Удаление (если нужно откатить)

```sql
-- Удаление таблиц безопасности
DROP TABLE IF EXISTS admin_logs;
DROP TABLE IF EXISTS login_attempts;

-- Удаление индексов (пример для likes)
ALTER TABLE likes DROP INDEX idx_likes_user_id;
ALTER TABLE likes DROP INDEX idx_likes_photo_id;
ALTER TABLE likes DROP INDEX idx_likes_created_at;
ALTER TABLE likes DROP INDEX idx_likes_user_photo;
```

## Полезные команды

```sql
-- Показать все таблицы
SHOW TABLES;

-- Показать структуру таблицы
DESCRIBE admin_logs;

-- Показать все индексы таблицы
SHOW INDEX FROM likes;

-- Показать размер таблиц
SELECT 
    table_name,
    table_rows,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
FROM information_schema.TABLES
WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;

-- Проверить версию MySQL
SELECT VERSION();

-- Показать текущую базу данных
SELECT DATABASE();
```

## Примечания

- ⚠️ Ошибка "Duplicate key name" - это нормально, индекс уже существует
- ⚠️ Ошибка "Table doesn't exist" - пропустите эту секцию
- ✅ Выполняйте по одной секции за раз
- ✅ Проверяйте результат после каждой секции
- ✅ Создание индексов может занять 1-5 минут для больших таблиц

## Готово!

После выполнения всех команд:
1. Откройте `http://ваш-домен/travel/admin/login.php`
2. Войдите в систему
3. Dashboard должен загружаться быстро (< 1 секунды)
