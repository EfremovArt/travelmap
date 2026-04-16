# Быстрый старт - Установка админ-панели

## Краткая инструкция

### 1. Загрузите файлы на сервер

Загрузите папку `travel/admin/` на ваш сервер.

### 2. Настройте права доступа

```bash
chmod 755 travel/admin/cache
```

### 3. Выполните миграции

#### Вариант А: Через браузер (САМЫЙ ПРОСТОЙ) ⭐

1. Откройте в браузере:
   ```
   http://ваш-домен/travel/admin/create_security_tables.php
   ```

2. Скрипт автоматически создаст таблицы безопасности

3. **ВАЖНО:** Удалите файл после использования:
   ```bash
   rm travel/admin/create_security_tables.php
   ```

4. Переходите к шагу 4 (проверка установки)

#### Вариант Б: Через phpMyAdmin

Откройте phpMyAdmin → Выберите базу данных → Вкладка SQL → Вставьте:

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

#### Миграция 2: Индексы производительности

**ВАЖНО:** Выполняйте по одной секции. Если появляется ошибка "Duplicate key name" - это нормально, переходите к следующей секции.

**Секция 1:**
```sql
ALTER TABLE likes ADD INDEX idx_likes_user_id (user_id);
ALTER TABLE likes ADD INDEX idx_likes_photo_id (photo_id);
ALTER TABLE likes ADD INDEX idx_likes_created_at (created_at);
```

**Секция 2:**
```sql
ALTER TABLE comments ADD INDEX idx_comments_user_id (user_id);
ALTER TABLE comments ADD INDEX idx_comments_photo_id (photo_id);
ALTER TABLE comments ADD INDEX idx_comments_created_at (created_at);
```

**Секция 3:**
```sql
ALTER TABLE follows ADD INDEX idx_follows_follower_id (follower_id);
ALTER TABLE follows ADD INDEX idx_follows_followed_id (followed_id);
ALTER TABLE follows ADD INDEX idx_follows_created_at (created_at);
```

**Секция 4:**
```sql
ALTER TABLE favorites ADD INDEX idx_favorites_user_id (user_id);
ALTER TABLE favorites ADD INDEX idx_favorites_photo_id (photo_id);
ALTER TABLE favorites ADD INDEX idx_favorites_created_at (created_at);
```

**Секция 5:**
```sql
ALTER TABLE photos ADD INDEX idx_photos_user_id (user_id);
ALTER TABLE photos ADD INDEX idx_photos_location_id (location_id);
ALTER TABLE photos ADD INDEX idx_photos_created_at (created_at);
```

**Секция 6:**
```sql
ALTER TABLE albums ADD INDEX idx_albums_owner_id (owner_id);
ALTER TABLE albums ADD INDEX idx_albums_created_at (created_at);
ALTER TABLE albums ADD INDEX idx_albums_is_public (is_public);
```

**Секция 7:**
```sql
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_user_id (user_id);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_type (type);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_is_active (is_active);
ALTER TABLE commercial_posts ADD INDEX idx_commercial_posts_created_at (created_at);
```

**Секция 8:**
```sql
ALTER TABLE users ADD INDEX idx_users_email (email);
ALTER TABLE users ADD INDEX idx_users_created_at (created_at);
```

**Секция 9 (если есть таблица album_comments):**
```sql
ALTER TABLE album_comments ADD INDEX idx_album_comments_user_id (user_id);
ALTER TABLE album_comments ADD INDEX idx_album_comments_album_id (album_id);
```

**Секция 10 (если есть таблица album_favorites):**
```sql
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_user_id (user_id);
ALTER TABLE album_favorites ADD INDEX idx_album_favorites_album_id (album_id);
```

**Секция 11 (если есть таблица commercial_favorites):**
```sql
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_user_id (user_id);
ALTER TABLE commercial_favorites ADD INDEX idx_commercial_favorites_commercial_post_id (commercial_post_id);
```

### 4. Проверьте установку

Откройте в браузере:
```
http://ваш-домен/travel/admin/login.php
```

Войдите с учетными данными администратора.

### 5. Проверьте, что всё работает

- ✅ Dashboard загружается быстро (< 1 секунды)
- ✅ Все разделы открываются без ошибок
- ✅ Таблицы отображаются корректно
- ✅ Поиск и фильтрация работают

## Что делать, если что-то не работает

### Ошибка: "Call to undefined function mb_strlen()"

**Причина:** Расширение mbstring не установлено на сервере

**Решение:** ✅ **УЖЕ ИСПРАВЛЕНО!** Код обновлен и работает без mbstring.

Если ошибка всё ещё появляется, обновите файл `travel/admin/config/admin_config.php` с GitHub.

### Ошибка: "Duplicate key name"
**Решение:** Это нормально - индекс уже существует. Продолжайте со следующей секции.

### Ошибка: "Table doesn't exist"
**Решение:** Пропустите эту секцию - таблица не используется в вашей базе данных.

### Ошибка: "Permission denied" для cache
**Решение:**
```bash
chmod 755 travel/admin/cache
chown www-data:www-data travel/admin/cache
```

### Ошибка: "could not find driver"
**Причина:** Расширение PDO_MySQL не установлено

**Решение:** Обратитесь в поддержку хостинга или см. [SERVER_REQUIREMENTS.md](SERVER_REQUIREMENTS.md)

### Dashboard загружается медленно
**Решение:**
1. Проверьте, что индексы созданы: `SHOW INDEX FROM likes;`
2. Очистите кеш браузера
3. Проверьте подключение к базе данных

## Полная документация

- **[README.md](README.md)** - Полное руководство
- **[PHPMYADMIN_GUIDE.md](migrations/PHPMYADMIN_GUIDE.md)** - Подробная инструкция для phpMyAdmin
- **[OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md)** - Руководство по оптимизации
- **[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** - Чеклист тестирования

## Поддержка

Если возникли проблемы, проверьте:
1. Версию MySQL: `SELECT VERSION();` (должна быть 5.5+)
2. Права пользователя базы данных
3. Логи ошибок PHP и MySQL
4. Настройки в `travel/config.php`
