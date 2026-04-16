# Исправление проблемы с URL изображений

## Проблема 1: Google URL
DataTables показывал ошибку "Invalid JSON response" при загрузке коммерческих постов. В консоли была ошибка 404 для URL вида:
```
https://bearded-fox.ru/travel/https://lh3.googleusercontent.com/...
```

Проблема заключалась в том, что внешние URL (Google profile images) обрабатывались как относительные пути.

## Проблема 2: Дублирование /travel/
После первого исправления появились ошибки 404 для локальных файлов:
```
https://bearded-fox.ru/travel/travel/uploads/profile_images/...
```

Проблема заключалась в том, что пути в базе данных уже содержали `travel/`, и функция `normalizeImageUrl()` добавляла ещё один `/travel/`.

## Решение

### 1. JavaScript (клиентская сторона)
Добавлена функция `normalizeImageUrl()` во все JavaScript файлы админ-панели, которая:
- Проверяет, является ли URL внешним (начинается с `http://` или `https://`)
- Если да - возвращает URL как есть
- Если нет - возвращает путь без изменений (обработка на сервере)

### 2. PHP (серверная сторона)
Исправлена функция `normalizeImageUrl()` в `travel/admin/config/admin_config.php`:
- Убирает все повторяющиеся вхождения `travel/` в начале пути
- Добавляет `/travel/` в начало один раз
- Правильно обрабатывает внешние URL (Google, etc)

### 3. API
Упрощён `get_all_commercial_posts.php` - теперь использует общую функцию `normalizeImageUrl()` вместо собственной логики.

## Исправленные файлы

### JavaScript:
- `travel/admin/assets/js/posts.js` - обычные посты, альбомы, коммерческие посты + обработка ошибок
- `travel/admin/assets/js/users.js` - профили пользователей
- `travel/admin/assets/js/comments.js` - комментарии
- `travel/admin/assets/js/likes.js` - лайки
- `travel/admin/assets/js/favorites.js` - избранное
- `travel/admin/assets/js/follows.js` - подписки
- `travel/admin/assets/js/moderation.js` - модерация фото

### PHP:
- `travel/admin/config/admin_config.php` - функция `normalizeImageUrl()`
- `travel/admin/api/posts/get_all_posts.php` - отключены ошибки, проверка $pdo
- `travel/admin/api/posts/get_all_albums.php` - исправлено `cover_preview` → `cover_photo`, отключены ошибки
- `travel/admin/api/posts/get_all_commercial_posts.php` - упрощена логика, отключены ошибки

## Тестирование
После применения исправлений:
1. Откройте https://bearded-fox.ru/travel/admin/views/posts.php
2. Перейдите на вкладку "Коммерческие посты"
3. Убедитесь, что:
   - Таблица загружается без ошибок
   - Изображения профилей Google отображаются корректно
   - Локальные изображения отображаются корректно
   - Нет ошибок 404 в консоли браузера
