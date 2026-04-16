# Проверка отображения комментариев

## Проблема
Комментарии показывали "Нет текста" вместо реального текста.

## Причина
API возвращает поле `commentText`, а JavaScript искал `text`, `comment_text` или `comment`.

## Решение
Исправлена функция `displayPhotoComments()` в `moderation.js`:

```javascript
const commentText = comment.commentText || comment.comment_text || comment.text || comment.comment || '';
```

## Как проверить

### 1. Через тестовый файл
Откройте: `http://your-domain/travel/admin/test_comments_api.php`

Проверьте:
- Список фото с комментариями
- Структуру таблицы `comments`
- Структуру таблицы `album_comments`
- Какое поле содержит текст комментария (должно быть `comment`)

### 2. Через консоль браузера
1. Откройте страницу модерации
2. Откройте консоль (F12)
3. Кликните на фото с комментариями
4. В консоли увидите:
   ```
   Comments API response: {success: true, comments: [...]}
   First comment structure: {id: 1, commentText: "...", ...}
   ```

### 3. Визуально на странице
1. Откройте модерацию
2. Найдите фото с комментариями (иконка 💬 с числом)
3. Кликните на фото
4. В модальном окне должны отображаться комментарии с текстом
5. Кнопка корзины должна быть видна справа от каждого комментария

## Структура данных

### API возвращает (get_all_comments.php):
```json
{
  "success": true,
  "comments": [
    {
      "id": 1,
      "userId": 123,
      "userName": "Иван Иванов",
      "commentText": "Отличное фото!",  ← ЭТО ПОЛЕ
      "commentType": "photo",
      "createdAt": "2025-11-19 12:00:00"
    }
  ]
}
```

### База данных (таблица comments):
```sql
CREATE TABLE comments (
  id INT PRIMARY KEY,
  user_id INT,
  photo_id INT,
  comment TEXT,  ← В БД поле называется 'comment'
  created_at TIMESTAMP
);
```

### Маппинг в API:
```php
'commentText' => $row['comment_text'],  // comment_text из SQL запроса
```

### SQL запрос в API:
```sql
SELECT c.comment as comment_text  -- Переименовываем в comment_text
```

## Итог
Цепочка: БД `comment` → SQL `comment_text` → PHP `commentText` → JS `commentText`
