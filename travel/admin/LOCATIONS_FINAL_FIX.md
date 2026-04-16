# ✅ Финальное исправление отображения локаций

## Что исправлено

### 1. Платные посты (Commercial Posts)
- **API**: `get_commercial_post_relations.php` - убрана перезапись `location_name` в `null`
- **API**: `get_all_commercial_posts.php` - добавлен `COALESCE` для приоритета значений
- **Frontend**: `commercial_post_details.php` - улучшена проверка на пустую строку
- **Frontend**: `user_details.php` (вкладка "Платные посты") - добавлен fallback на координаты

### 2. Обычные посты (Photos)
- **Frontend**: `user_details.php` (вкладка "Посты") - добавлен fallback на координаты
- **API**: `get_all_posts.php` - уже возвращал `location_name`, `latitude`, `longitude` ✅

### 3. Лайкнутые посты (Likes)
- **API**: `get_all_likes.php` - добавлены `latitude` и `longitude` в SQL запрос
- **API**: `get_all_likes.php` - убран дублирующий запрос для получения локации
- **Frontend**: `user_details.php` (вкладка "Лайки") - добавлен fallback на координаты

## Логика отображения (везде одинаковая)

```javascript
if (location_name && location_name.trim() !== '') {
    // Показываем название локации
    display(location_name)
} else if (latitude && longitude) {
    // Показываем координаты
    display(`📍 ${latitude}, ${longitude}`)
} else {
    // Ничего нет
    display('Не указана')
}
```

## Приоритет для платных постов (SQL)

```sql
COALESCE(
    cp.location_name,           -- 1. Из таблицы commercial_posts
    CASE 
        WHEN cp.type = 'photo' THEN l.title  -- 2. Из связанного фото
        ELSE NULL
    END
) as location_name
```

## Результат

✅ Все локации теперь отображаются правильно
✅ Приоритет: название → координаты → "Не указана"
✅ Единая логика во всех местах
✅ Оптимизированы SQL запросы (убраны дублирующие запросы)

## Измененные файлы (5)

1. `travel/admin/api/posts/get_commercial_post_relations.php`
2. `travel/admin/api/posts/get_all_commercial_posts.php`
3. `travel/admin/api/likes/get_all_likes.php`
4. `travel/admin/views/user_details.php`
5. `travel/admin/views/commercial_post_details.php`
