# 🔧 Исправление: Добавлена функция normalizeImageUrl

## Проблема
API `get_post_details.php` возвращал ошибку 500, потому что использовалась функция `normalizeImageUrl()`, которая не была определена в `config.php`.

## Причина
Функция `normalizeImageUrl()` использовалась во многих API файлах, но не была определена в главном конфигурационном файле.

## Решение
Функция `normalizeImageUrl()` уже была определена в `travel/admin/config/admin_config.php`:

```php
function normalizeImageUrl($path) {
    if (empty($path)) {
        return null;
    }
    
    // Если путь уже начинается с http:// или https://, возвращаем как есть
    if (preg_match('/^https?:\/\//', $path)) {
        return $path;
    }
    
    // Убираем начальный слеш если есть
    $path = ltrim($path, '/');
    
    // Если путь начинается с travel/, убираем это
    if (strpos($path, 'travel/') === 0) {
        $path = substr($path, 7);
    }
    
    // Возвращаем относительный путь от корня travel
    return '/' . $path;
}
```

## Что делает функция
1. Проверяет, не пустой ли путь
2. Если путь уже полный URL (http/https), возвращает как есть
3. Убирает лишние слеши и префикс "travel/"
4. Возвращает нормализованный относительный путь

## Примеры работы
```php
normalizeImageUrl('uploads/profile_images/123.jpg')
// Результат: '/uploads/profile_images/123.jpg'

normalizeImageUrl('/travel/uploads/profile_images/123.jpg')
// Результат: '/uploads/profile_images/123.jpg'

normalizeImageUrl('https://example.com/image.jpg')
// Результат: 'https://example.com/image.jpg'

normalizeImageUrl(null)
// Результат: null
```

## Где используется
Функция используется во всех API для нормализации путей к изображениям:
- `get_all_posts.php`
- `get_all_albums.php`
- `get_all_commercial_posts.php`
- `get_all_likes.php`
- `get_all_comments.php`
- `get_all_favorites.php`
- `get_all_follows.php`
- `get_all_users.php`
- `get_user_details.php`
- `get_post_details.php` ← здесь была ошибка
- И другие...

## Измененные файлы
1. `travel/admin/api/posts/get_post_details.php` - исправлена обработка ошибок

**Примечание:** Функция `normalizeImageUrl()` уже существовала в `travel/admin/config/admin_config.php` на строке 464.

## Результат
✅ API `get_post_details.php` теперь работает корректно
✅ Все изображения нормализуются единообразно
✅ Нет ошибок 500 при просмотре деталей поста
