# Comments Management API

## Endpoints

### GET /admin/api/comments/get_all_comments.php

Получает список всех комментариев (к постам и альбомам) с пагинацией, фильтрацией и поиском.

**Query Parameters:**
- `page` (int, optional): Номер страницы (default: 1)
- `per_page` (int, optional): Количество записей на странице (default: 50, max: 100)
- `user_id` (int, optional): Фильтр по ID пользователя
- `photo_id` (int, optional): Фильтр по ID поста
- `album_id` (int, optional): Фильтр по ID альбома
- `search` (string, optional): Поиск по тексту комментария или имени пользователя
- `sort_by` (string, optional): Поле сортировки (created_at, user_id, photo_id, album_id)
- `sort_order` (string, optional): Порядок сортировки (asc, desc)

**Response:**
```json
{
  "success": true,
  "comments": [
    {
      "id": 1,
      "userId": 5,
      "userName": "John Doe",
      "userEmail": "john@example.com",
      "userProfileImage": "/path/to/image.jpg",
      "photoId": 10,
      "albumId": null,
      "photoTitle": "Eiffel Tower",
      "albumTitle": null,
      "commentText": "Beautiful place!",
      "commentType": "photo",
      "createdAt": "2025-01-15 10:30:00"
    }
  ],
  "pagination": {
    "total": 300,
    "perPage": 50,
    "currentPage": 1,
    "lastPage": 6
  }
}
```

### DELETE /admin/api/comments/delete_comment.php

Удаляет комментарий по ID.

**Request Body:**
```json
{
  "commentId": 1,
  "commentType": "photo"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Комментарий успешно удален"
}
```

## Features

- Объединяет комментарии к постам (таблица `comments`) и альбомам (таблица `album_comments`)
- Поддерживает фильтрацию по пользователю, посту и альбому
- Поиск по тексту комментария и имени пользователя
- Пагинация для больших наборов данных
- Сортировка по различным полям
- Безопасное удаление с проверкой существования

## Database Tables

### comments
- Комментарии к постам (фотографиям)
- Поля: id, user_id, photo_id, comment, created_at

### album_comments
- Комментарии к альбомам
- Поля: id, user_id, album_id, comment, created_at
