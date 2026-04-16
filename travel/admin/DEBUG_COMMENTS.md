# Отладка комментариев

## Проблема
У пользователя есть 8 комментариев, но они не отображаются в профиле.

## Что было исправлено

### 1. Неправильное имя колонки
**Было:**
```sql
SELECT c.comment_text ...
```

**Стало:**
```sql
SELECT c.comment as comment_text ...
```

**Причина:** В таблице `comments` колонка называется `comment`, а не `comment_text`.

### 2. SQL запрос для комментариев к постам пользователя
**Было:**
```sql
WHERE p.user_id = :user_id
```

**Стало:**
```sql
WHERE p.user_id = :user_id AND c.user_id != :user_id
```

**Причина:** Нужно исключать комментарии пользователя к своим же постам, чтобы они не дублировались.

### 2. Добавлена отладка в консоль
Добавлены `console.log` для проверки данных:
- В функции `displayUserDetails` перед вызовом функций отображения
- В функциях `displayUserComments` и `displayCommentsOnUserPosts`

## Как проверить

### 1. Откройте консоль браузера (F12)
Перейдите на вкладку Console

### 2. Откройте профиль пользователя
Например: `user_details.php?id=20`

### 3. Проверьте вывод в консоли
Должны появиться сообщения:
```
User comments: Array(X)
displayUserComments called with X comments
Comments on user posts: Array(Y)
displayCommentsOnUserPosts called with Y comments
```

### 4. Используйте тестовый скрипт
Откройте: `test_user_comments.php?user_id=20`

Скрипт покажет:
- Всего комментариев пользователя
- Комментарии пользователя (написанные)
- Всего постов пользователя
- Комментарии к постам пользователя (от всех)
- Комментарии к постам пользователя (от других)
- Комментарии пользователя к своим же постам

## Возможные причины проблемы

### 1. Пользователь комментирует только свои посты
Если все 8 комментариев - это комментарии к своим же постам:
- В "Написанные" они будут отображаться
- В "Полученные" они НЕ будут отображаться (это правильно)

### 2. Нет постов у пользователя
Если у пользователя нет постов, то "Полученные комментарии" будут пустыми.

### 3. Проблема с данными
Проверьте целостность данных:
```sql
-- Проверка комментариев
SELECT c.*, p.user_id as post_owner_id
FROM comments c
JOIN photos p ON c.photo_id = p.id
WHERE c.user_id = 20;

-- Проверка постов
SELECT * FROM photos WHERE user_id = 20;
```

## SQL запросы для проверки

### Комментарии пользователя (написанные)
```sql
SELECT c.id, c.comment as comment_text, c.created_at,
       p.id as post_id, p.title as post_title,
       p.user_id as post_owner_id,
       u.first_name, u.last_name
FROM comments c
JOIN photos p ON c.photo_id = p.id
JOIN users u ON p.user_id = u.id
WHERE c.user_id = 20
ORDER BY c.created_at DESC;
```

### Комментарии к постам пользователя (от других)
```sql
SELECT c.id, c.comment as comment_text, c.created_at,
       p.id as post_id, p.title as post_title,
       u.id as commenter_id, u.first_name, u.last_name
FROM comments c
JOIN photos p ON c.photo_id = p.id
JOIN users u ON c.user_id = u.id
WHERE p.user_id = 20 AND c.user_id != 20
ORDER BY c.created_at DESC;
```

### Комментарии пользователя к своим постам
```sql
SELECT COUNT(*) as count
FROM comments c
JOIN photos p ON c.photo_id = p.id
WHERE p.user_id = 20 AND c.user_id = 20;
```

## Ожидаемое поведение

### Вкладка "Комментарии" → "Написанные"
Показывает ВСЕ комментарии пользователя, включая:
- Комментарии к постам других пользователей
- Комментарии к своим собственным постам

### Вкладка "Комментарии" → "Полученные"
Показывает комментарии К ПОСТАМ пользователя от ДРУГИХ пользователей:
- НЕ включает комментарии пользователя к своим же постам
- Показывает только комментарии от других людей

## Если проблема не решена

1. Проверьте консоль браузера на ошибки JavaScript
2. Проверьте логи PHP сервера
3. Используйте `test_user_comments.php` для детальной проверки
4. Проверьте, что API возвращает данные: откройте в браузере
   `api/users/get_user_details.php?user_id=20`
5. Проверьте структуру базы данных (таблицы comments, photos, users)
