# 🗺️ Исправление отображения названий локаций в платных постах

## Проблема
Везде показывались координаты вместо названий локаций, хотя в базе данных поле `location_name` было заполнено.

## Причина
1. **API перезаписывал данные**: В `get_commercial_post_relations.php` поле `location_name` из базы данных перезаписывалось в `null`, а потом пыталось получиться из связанного фото
2. **SQL запрос игнорировал данные**: В `get_all_commercial_posts.php` SQL запрос использовал `CASE` вместо `COALESCE`, что игнорировало `cp.location_name` из таблицы
3. **Слабая проверка на фронтенде**: JavaScript проверял только `if (p.location_name)`, что не отсекало пустые строки

## Решение

### 1. API: get_commercial_post_relations.php
**Было:**
```php
$commercialPost['location_name'] = null;
if ($commercialPost['type'] == 'photo' && $commercialPost['photo_id']) {
    // получение из фото
}
```

**Стало:**
```php
if (empty($commercialPost['location_name']) && $commercialPost['type'] == 'photo' && $commercialPost['photo_id']) {
    // получение из фото только если location_name пустое
}
```

### 2. API: get_all_commercial_posts.php
**Было:**
```sql
CASE 
    WHEN cp.type = 'photo' AND p.location_id IS NOT NULL THEN l.title
    ELSE NULL
END as location_name
```

**Стало:**
```sql
COALESCE(
    cp.location_name,
    CASE 
        WHEN cp.type = 'photo' AND p.location_id IS NOT NULL THEN l.title
        ELSE NULL
    END
) as location_name
```

### 3. Frontend: user_details.php
**Было:**
```javascript
if (p.location_name) {
    locationText = `📍 ${p.location_name}`;
}
```

**Стало:**
```javascript
if (p.location_name && p.location_name.trim() !== '') {
    locationText = `📍 ${p.location_name}`;
}
```

### 4. Frontend: commercial_post_details.php
**Было:**
```javascript
${cp.location_name || (cp.latitude && cp.longitude ? `📍 ${cp.latitude}, ${cp.longitude}` : '-')}
```

**Стало:**
```javascript
${(cp.location_name && cp.location_name.trim() !== '') ? cp.location_name : (cp.latitude && cp.longitude ? `📍 ${cp.latitude}, ${cp.longitude}` : '-')}
```

## Результат
✅ Теперь приоритет отображения:
1. **Название локации** из `commercial_posts.location_name` (если заполнено)
2. **Название локации** из связанного фото (если тип = 'photo' и есть location_id)
3. **Координаты** (если нет названия, но есть координаты)
4. **Прочерк** (если нет ни названия, ни координат)

## Измененные файлы
- `travel/admin/api/posts/get_commercial_post_relations.php` - исправлена перезапись location_name
- `travel/admin/api/posts/get_all_commercial_posts.php` - добавлен COALESCE для приоритета
- `travel/admin/api/likes/get_all_likes.php` - добавлены координаты в SQL запрос
- `travel/admin/views/user_details.php` - обновлено отображение локаций во всех вкладках
- `travel/admin/views/commercial_post_details.php` - улучшена проверка location_name

### 5. API: get_all_likes.php
**Было:**
```sql
SELECT ... p.location_id ...
FROM likes l
INNER JOIN photos p ON l.photo_id = p.id
```
Затем отдельный запрос для получения локации.

**Стало:**
```sql
SELECT ... loc.title as locationName, loc.latitude, loc.longitude ...
FROM likes l
INNER JOIN photos p ON l.photo_id = p.id
LEFT JOIN locations loc ON p.location_id = loc.id
```

### 6. Frontend: user_details.php - Лайкнутые посты
**Было:**
```javascript
Локация: ${p.locationName || 'Не указана'}
```

**Стало:**
```javascript
Локация: ${(p.locationName && p.locationName.trim() !== '') ? p.locationName : (p.latitude && p.longitude ? `📍 ${parseFloat(p.latitude).toFixed(4)}, ${parseFloat(p.longitude).toFixed(4)}` : 'Не указана')}
```

## Где применено
✅ **Вкладка "Посты"** - обычные посты пользователя
✅ **Вкладка "Платные посты"** - коммерческие посты
✅ **Вкладка "Лайки"** - посты, которые лайкнул пользователь
✅ **Страница деталей платного поста** - commercial_post_details.php

## Тестирование
1. Откройте профиль пользователя с постами
2. Проверьте вкладку "Посты" - должны показываться названия локаций или координаты
3. Проверьте вкладку "Платные посты" - пост #47 (Universal Volcano Bay) должен показывать название
4. Проверьте вкладку "Лайки" - должны показываться локации лайкнутых постов
5. Откройте детали платного поста - должно показываться название локации
