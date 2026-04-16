# Таблица photo_commercial_posts

## Назначение
Таблица `photo_commercial_posts` хранит связи между фотографиями и коммерческими постами. Она определяет, на каких фотографиях должен отображаться конкретный коммерческий пост.

## Структура таблицы

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | INT(11) | Первичный ключ |
| `photo_id` | INT(11) | ID фотографии (FK → photos.id) |
| `commercial_post_id` | INT(11) | ID коммерческого поста (FK → commercial_posts.id) |
| `position` | INT(11) | Позиция отображения (для сортировки) |
| `is_active` | TINYINT(1) | Активен ли показ (1 = да, 0 = нет) |
| `created_at` | TIMESTAMP | Дата создания связи |

## Индексы

- `PRIMARY KEY` на `id`
- `UNIQUE KEY` на `(photo_id, commercial_post_id)` - предотвращает дублирование
- `INDEX` на `photo_id` - для быстрого поиска по фото
- `INDEX` на `commercial_post_id` - для быстрого поиска по коммерческому посту
- `INDEX` на `is_active` - для фильтрации активных
- `INDEX` на `(photo_id, commercial_post_id, is_active)` - составной индекс
- `INDEX` на `created_at` - для сортировки по дате

## Foreign Keys

- `fk_pcp_photo`: `photo_id` → `photos.id` (ON DELETE CASCADE)
- `fk_pcp_commercial_post`: `commercial_post_id` → `commercial_posts.id` (ON DELETE CASCADE)

## Установка

### Вариант 1: Через веб-интерфейс (рекомендуется)
1. Откройте в браузере: `https://bearded-fox.ru/travel/admin/create_photo_commercial_posts_table.php`
2. Следуйте инструкциям на экране
3. Таблица будет создана автоматически

### Вариант 2: Через phpMyAdmin
1. Откройте phpMyAdmin
2. Выберите базу данных `travel`
3. Перейдите на вкладку "SQL"
4. Скопируйте содержимое файла `create_photo_commercial_posts_table.sql`
5. Вставьте в поле SQL и нажмите "Выполнить"

### Вариант 3: Через командную строку
```bash
mysql -u username -p travel < create_photo_commercial_posts_table.sql
```

## Использование

### Добавление связи
```sql
INSERT INTO photo_commercial_posts (photo_id, commercial_post_id, position, is_active)
VALUES (123, 45, 1, 1);
```

### Получение всех фото, где отображается коммерческий пост
```sql
SELECT p.*, pcp.position
FROM photo_commercial_posts pcp
INNER JOIN photos p ON pcp.photo_id = p.id
WHERE pcp.commercial_post_id = 45
AND pcp.is_active = 1
ORDER BY pcp.position ASC;
```

### Получение всех коммерческих постов для фото
```sql
SELECT cp.*, pcp.position
FROM photo_commercial_posts pcp
INNER JOIN commercial_posts cp ON pcp.commercial_post_id = cp.id
WHERE pcp.photo_id = 123
AND pcp.is_active = 1
ORDER BY pcp.position ASC;
```

## Примечания

- При удалении фотографии все связи автоматически удаляются (CASCADE)
- При удалении коммерческого поста все связи автоматически удаляются (CASCADE)
- Уникальный индекс предотвращает создание дублирующихся связей
- Поле `position` позволяет управлять порядком отображения коммерческих постов на фото
- Поле `is_active` позволяет временно отключать показ без удаления связи
