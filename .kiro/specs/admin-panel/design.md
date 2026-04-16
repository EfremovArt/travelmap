# Design Document: Admin Panel

## Overview

Административная панель будет реализована как отдельное веб-приложение с использованием PHP для бэкенда и HTML/CSS/JavaScript для фронтенда. Панель будет иметь модульную структуру с отдельными разделами для каждой функциональности.

## Architecture

### Technology Stack

**Backend:**
- PHP 7.4+ (соответствует текущему стеку проекта)
- MySQL/MariaDB (существующая база данных)
- PDO для работы с базой данных

**Frontend:**
- HTML5
- CSS3 (Bootstrap 5 для быстрой разработки UI)
- Vanilla JavaScript (или jQuery для совместимости)
- DataTables.js для таблиц с пагинацией и поиском

### Directory Structure

```
travel/
├── admin/
│   ├── index.php                    # Главная страница админки
│   ├── login.php                    # Страница авторизации
│   ├── logout.php                   # Выход из системы
│   ├── config/
│   │   └── admin_config.php         # Конфигурация админки
│   ├── api/
│   │   ├── likes/
│   │   │   ├── get_all_likes.php
│   │   │   └── get_likes_stats.php
│   │   ├── comments/
│   │   │   ├── get_all_comments.php
│   │   │   ├── delete_comment.php
│   │   │   └── get_comments_stats.php
│   │   ├── users/
│   │   │   ├── get_all_users.php
│   │   │   ├── get_user_details.php
│   │   │   └── get_user_stats.php
│   │   ├── follows/
│   │   │   ├── get_all_follows.php
│   │   │   └── get_follows_stats.php
│   │   ├── favorites/
│   │   │   ├── get_all_favorites.php
│   │   │   └── get_favorites_stats.php
│   │   ├── posts/
│   │   │   ├── get_all_posts.php
│   │   │   ├── get_all_albums.php
│   │   │   ├── get_all_commercial_posts.php
│   │   │   ├── get_album_photos.php
│   │   │   └── get_commercial_post_relations.php
│   │   └── moderation/
│   │       ├── get_all_photos.php
│   │       ├── delete_photo.php
│   │       └── bulk_delete_photos.php
│   ├── views/
│   │   ├── dashboard.php            # Главная панель с статистикой
│   │   ├── likes.php                # Управление лайками
│   │   ├── comments.php             # Управление комментариями
│   │   ├── users.php                # Управление пользователями
│   │   ├── user_details.php         # Детальная страница пользователя
│   │   ├── follows.php              # Управление подписками
│   │   ├── favorites.php            # Управление избранным
│   │   ├── posts.php                # Управление публикациями
│   │   ├── moderation.php           # Модерация контента
│   │   └── commercial_post_details.php  # Детали коммерческого поста
│   ├── assets/
│   │   ├── css/
│   │   │   └── admin.css            # Стили админки
│   │   ├── js/
│   │   │   ├── admin.js             # Общие скрипты
│   │   │   ├── likes.js
│   │   │   ├── comments.js
│   │   │   ├── users.js
│   │   │   ├── follows.js
│   │   │   ├── favorites.js
│   │   │   ├── posts.js
│   │   │   └── moderation.js
│   │   └── images/
│   └── includes/
│       ├── header.php               # Общий хедер
│       ├── sidebar.php              # Боковое меню
│       └── footer.php               # Общий футер
```

## Components and Interfaces

### 1. Authentication System

**Purpose:** Защита админ-панели от несанкционированного доступа

**Implementation:**
- Отдельная таблица `admin_users` в базе данных для администраторов
- Сессионная авторизация с проверкой прав доступа
- Хеширование паролей с использованием `password_hash()`

**Database Schema:**
```sql
CREATE TABLE admin_users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP NULL
);
```

**Functions:**
- `adminRequireAuth()` - проверка авторизации администратора
- `adminLogin($username, $password)` - авторизация
- `adminLogout()` - выход из системы

### 2. Dashboard (Главная панель)

**Purpose:** Отображение общей статистики системы

**Metrics:**
- Общее количество пользователей
- Общее количество постов
- Общее количество лайков
- Общее количество комментариев
- Общее количество подписок
- Общее количество избранного
- Активность за последние 7 дней (график)

**API Endpoint:** `GET /admin/api/dashboard/get_stats.php`

**Response:**
```json
{
  "success": true,
  "stats": {
    "totalUsers": 100,
    "totalPosts": 500,
    "totalLikes": 1500,
    "totalComments": 300,
    "totalFollows": 200,
    "totalFavorites": 400,
    "recentActivity": {
      "newUsers": 5,
      "newPosts": 20,
      "newComments": 15
    }
  }
}
```

### 3. Likes Management

**Purpose:** Просмотр и анализ лайков

**Features:**
- Таблица со всеми лайками
- Фильтрация по пользователю
- Фильтрация по посту
- Поиск по имени пользователя
- Сортировка по дате

**API Endpoint:** `GET /admin/api/likes/get_all_likes.php`

**Query Parameters:**
- `page` - номер страницы (default: 1)
- `per_page` - количество на странице (default: 50)
- `user_id` - фильтр по пользователю (optional)
- `photo_id` - фильтр по посту (optional)
- `search` - поиск по имени (optional)
- `sort_by` - поле сортировки (default: created_at)
- `sort_order` - порядок сортировки (asc/desc, default: desc)

**Response:**
```json
{
  "success": true,
  "likes": [
    {
      "id": 1,
      "userId": 5,
      "userName": "John Doe",
      "userEmail": "john@example.com",
      "userProfileImage": "/path/to/image.jpg",
      "photoId": 10,
      "photoTitle": "Eiffel Tower",
      "photoPreview": "/path/to/photo.jpg",
      "createdAt": "2025-01-15 10:30:00"
    }
  ],
  "pagination": {
    "total": 1500,
    "perPage": 50,
    "currentPage": 1,
    "lastPage": 30
  }
}
```

### 4. Comments Management

**Purpose:** Просмотр, поиск и удаление комментариев

**Features:**
- Таблица со всеми комментариями
- Фильтрация по пользователю
- Фильтрация по посту/альбому
- Поиск по тексту комментария
- Удаление комментария
- Сортировка по дате

**API Endpoints:**

**GET /admin/api/comments/get_all_comments.php**

**Query Parameters:**
- `page` - номер страницы
- `per_page` - количество на странице
- `user_id` - фильтр по пользователю (optional)
- `photo_id` - фильтр по посту (optional)
- `album_id` - фильтр по альбому (optional)
- `search` - поиск по тексту (optional)
- `sort_by` - поле сортировки
- `sort_order` - порядок сортировки

**Response:**
```json
{
  "success": true,
  "comments": [
    {
      "id": 1,
      "userId": 5,
      "userName": "John Doe",
      "userProfileImage": "/path/to/image.jpg",
      "photoId": 10,
      "albumId": null,
      "photoTitle": "Eiffel Tower",
      "albumTitle": null,
      "commentText": "Beautiful place!",
      "createdAt": "2025-01-15 10:30:00"
    }
  ],
  "pagination": {...}
}
```

**DELETE /admin/api/comments/delete_comment.php**

**Request Body:**
```json
{
  "commentId": 1
}
```

**Response:**
```json
{
  "success": true,
  "message": "Комментарий успешно удален"
}
```

### 5. Users Management

**Purpose:** Просмотр пользователей и их активности

**Features:**
- Таблица со всеми пользователями
- Детальная страница пользователя
- Статистика по пользователю
- Поиск по имени/email

**API Endpoints:**

**GET /admin/api/users/get_all_users.php**

**Query Parameters:**
- `page`, `per_page`, `search`, `sort_by`, `sort_order`

**Response:**
```json
{
  "success": true,
  "users": [
    {
      "id": 5,
      "firstName": "John",
      "lastName": "Doe",
      "email": "john@example.com",
      "profileImage": "/path/to/image.jpg",
      "createdAt": "2025-01-01 00:00:00",
      "followersCount": 10,
      "followingCount": 15,
      "postsCount": 20,
      "likesCount": 50,
      "commentsCount": 30
    }
  ],
  "pagination": {...}
}
```

**GET /admin/api/users/get_user_details.php?user_id=5**

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 5,
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "profileImage": "/path/to/image.jpg",
    "createdAt": "2025-01-01 00:00:00"
  },
  "stats": {
    "followersCount": 10,
    "followingCount": 15,
    "postsCount": 20,
    "albumsCount": 5,
    "commercialPostsCount": 3,
    "likesGiven": 50,
    "likesReceived": 100,
    "commentsGiven": 30,
    "commentsReceived": 40,
    "favoritesCount": 25
  },
  "followers": [...],
  "following": [...],
  "favoritePosts": [...],
  "favoriteAlbums": [...],
  "commentedPosts": [...],
  "postsWithComments": [...]
}
```

### 6. Follows Management

**Purpose:** Просмотр всех подписок

**Features:**
- Таблица со всеми подписками
- Фильтрация по пользователю
- Поиск по имени

**API Endpoint:** `GET /admin/api/follows/get_all_follows.php`

**Response:**
```json
{
  "success": true,
  "follows": [
    {
      "id": 1,
      "followerId": 5,
      "followerName": "John Doe",
      "followerImage": "/path/to/image.jpg",
      "followedId": 7,
      "followedName": "Jane Smith",
      "followedImage": "/path/to/image2.jpg",
      "createdAt": "2025-01-15 10:30:00"
    }
  ],
  "pagination": {...}
}
```

### 7. Favorites Management

**Purpose:** Просмотр всех добавлений в избранное

**Features:**
- Раздельные вкладки для постов, альбомов и коммерческих постов
- Фильтрация по пользователю
- Фильтрация по типу контента

**API Endpoint:** `GET /admin/api/favorites/get_all_favorites.php`

**Query Parameters:**
- `type` - тип избранного (photo/album/commercial, optional)
- `user_id` - фильтр по пользователю (optional)
- `page`, `per_page`, `sort_by`, `sort_order`

**Response:**
```json
{
  "success": true,
  "favorites": [
    {
      "id": 1,
      "userId": 5,
      "userName": "John Doe",
      "userImage": "/path/to/image.jpg",
      "contentType": "photo",
      "contentId": 10,
      "contentTitle": "Eiffel Tower",
      "contentPreview": "/path/to/photo.jpg",
      "createdAt": "2025-01-15 10:30:00"
    }
  ],
  "pagination": {...}
}
```

### 8. Posts Management

**Purpose:** Просмотр всех публикаций (постов, альбомов, коммерческих постов)

**Features:**
- Раздельные вкладки для разных типов публикаций
- Фильтрация по автору
- Поиск по заголовку/локации
- Просмотр деталей альбома с фотографиями

**API Endpoints:**

**GET /admin/api/posts/get_all_posts.php**

**Response:**
```json
{
  "success": true,
  "posts": [
    {
      "id": 10,
      "userId": 5,
      "userName": "John Doe",
      "locationId": 78,
      "locationName": "Colosseum, Rome",
      "title": "Eiffel Tower",
      "description": "Beautiful view",
      "preview": "/path/to/photo.jpg",
      "createdAt": "2025-01-15 10:30:00",
      "likesCount": 50,
      "commentsCount": 10
    }
  ],
  "pagination": {...}
}
```

**GET /admin/api/posts/get_all_albums.php**

**Response:**
```json
{
  "success": true,
  "albums": [
    {
      "id": 23,
      "ownerId": 7,
      "ownerName": "Web Studio",
      "title": "Top 10 Beautiful Places",
      "description": "Collection of beautiful places",
      "coverPhoto": "/path/to/cover.jpg",
      "photosCount": 5,
      "isPublic": true,
      "createdAt": "2025-01-15 10:30:00",
      "likesCount": 30,
      "commentsCount": 5,
      "favoritesCount": 10
    }
  ],
  "pagination": {...}
}
```

**GET /admin/api/posts/get_album_photos.php?album_id=23**

**Response:**
```json
{
  "success": true,
  "album": {
    "id": 23,
    "title": "Top 10 Beautiful Places",
    "description": "Collection of beautiful places"
  },
  "photos": [
    {
      "id": 138,
      "title": "Eiffel Tower",
      "description": "Beautiful view",
      "filePath": "/path/to/photo.jpg",
      "position": 0,
      "createdAt": "2025-01-15 10:30:00"
    }
  ]
}
```

**GET /admin/api/posts/get_all_commercial_posts.php**

**Response:**
```json
{
  "success": true,
  "commercialPosts": [
    {
      "id": 24,
      "userId": 7,
      "userName": "Web Studio",
      "type": "album",
      "albumId": 23,
      "photoId": null,
      "title": "Excursions to Eiffel Tower",
      "description": "Visit without queues",
      "preview": "/path/to/image.jpg",
      "locationName": "Paris, France",
      "latitude": 48.8534,
      "longitude": 2.3488,
      "isActive": true,
      "createdAt": "2025-01-15 10:30:00"
    }
  ],
  "pagination": {...}
}
```

**GET /admin/api/posts/get_commercial_post_relations.php?commercial_post_id=24**

**Response:**
```json
{
  "success": true,
  "commercialPost": {
    "id": 24,
    "title": "Excursions to Eiffel Tower",
    "type": "album"
  },
  "relatedAlbums": [
    {
      "id": 23,
      "title": "Top 10 Beautiful Places",
      "coverPhoto": "/path/to/cover.jpg",
      "photosCount": 5
    }
  ],
  "relatedPhotos": [
    {
      "id": 138,
      "title": "Eiffel Tower",
      "preview": "/path/to/photo.jpg",
      "locationName": "Paris, France"
    }
  ]
}
```

### 9. Moderation System

**Purpose:** Модерация и удаление фотографий

**Features:**
- Галерея всех фотографий
- Фильтрация по автору
- Фильтрация по дате
- Удаление одной фотографии
- Массовое удаление выбранных фотографий
- Превью фотографии при наведении

**API Endpoints:**

**GET /admin/api/moderation/get_all_photos.php**

**Query Parameters:**
- `page`, `per_page`, `user_id`, `date_from`, `date_to`, `sort_by`, `sort_order`

**Response:**
```json
{
  "success": true,
  "photos": [
    {
      "id": 138,
      "userId": 7,
      "userName": "Web Studio",
      "userEmail": "millionreklamy@gmail.com",
      "locationId": 80,
      "locationName": "Paris, France",
      "title": "Eiffel Tower",
      "description": "Beautiful view",
      "filePath": "/path/to/photo.jpg",
      "createdAt": "2025-01-15 10:30:00",
      "inAlbums": ["Top 10 Beautiful Places"],
      "inCommercialPosts": ["Excursions to Eiffel Tower"]
    }
  ],
  "pagination": {...}
}
```

**DELETE /admin/api/moderation/delete_photo.php**

**Request Body:**
```json
{
  "photoId": 138
}
```

**Response:**
```json
{
  "success": true,
  "message": "Фотография успешно удалена"
}
```

**POST /admin/api/moderation/bulk_delete_photos.php**

**Request Body:**
```json
{
  "photoIds": [138, 139, 140]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Удалено фотографий: 3",
  "deletedCount": 3
}
```

## Data Models

### Admin User Model
```php
class AdminUser {
    public $id;
    public $username;
    public $email;
    public $createdAt;
    public $lastLogin;
}
```

### Extended User Model (for admin panel)
```php
class UserWithStats {
    public $id;
    public $firstName;
    public $lastName;
    public $email;
    public $profileImage;
    public $createdAt;
    public $followersCount;
    public $followingCount;
    public $postsCount;
    public $albumsCount;
    public $commercialPostsCount;
    public $likesGiven;
    public $likesReceived;
    public $commentsGiven;
    public $commentsReceived;
}
```

## Error Handling

**Standard Error Response:**
```json
{
  "success": false,
  "message": "Error description",
  "errorCode": "ERROR_CODE"
}
```

**Error Codes:**
- `AUTH_REQUIRED` - требуется авторизация
- `PERMISSION_DENIED` - недостаточно прав
- `INVALID_PARAMETERS` - неверные параметры
- `NOT_FOUND` - ресурс не найден
- `DATABASE_ERROR` - ошибка базы данных
- `FILE_DELETE_ERROR` - ошибка удаления файла

**Error Handling Functions:**
```php
function adminHandleError($message, $statusCode = 500, $errorCode = null) {
    header("HTTP/1.1 {$statusCode}");
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errorCode' => $errorCode
    ]);
    exit;
}
```

## Testing Strategy

### Manual Testing
- Тестирование каждого раздела админки вручную
- Проверка фильтрации и поиска
- Проверка пагинации
- Проверка удаления контента
- Проверка авторизации и прав доступа

### Test Data
- Использование существующих данных из базы
- Создание тестовых администраторов

### Security Testing
- Проверка SQL-инъекций (использование prepared statements)
- Проверка XSS (экранирование вывода)
- Проверка CSRF (использование токенов)
- Проверка прав доступа

## Security Considerations

1. **Authentication:**
   - Сессионная авторизация с проверкой на каждом запросе
   - Хеширование паролей с `password_hash()`
   - Защита от брутфорса (ограничение попыток входа)

2. **SQL Injection Prevention:**
   - Использование PDO prepared statements для всех запросов
   - Валидация и санитизация входных данных

3. **XSS Prevention:**
   - Экранирование всех выводимых данных с `htmlspecialchars()`
   - Content Security Policy headers

4. **CSRF Prevention:**
   - CSRF токены для всех форм
   - Проверка токенов на сервере

5. **File Operations:**
   - Проверка прав доступа перед удалением файлов
   - Валидация путей к файлам
   - Логирование всех операций удаления

6. **Access Control:**
   - Проверка прав администратора на каждом эндпоинте
   - Логирование всех действий администраторов

## Performance Considerations

1. **Database Queries:**
   - Использование индексов для быстрого поиска
   - Пагинация для больших наборов данных
   - Оптимизация JOIN запросов

2. **Caching:**
   - Кеширование статистики на главной странице
   - Кеширование списков пользователей

3. **Image Loading:**
   - Lazy loading для галереи фотографий
   - Использование thumbnail версий изображений

## UI/UX Design

### Layout
- Боковое меню с навигацией по разделам
- Верхняя панель с информацией о текущем администраторе
- Основная область контента с таблицами/карточками

### Color Scheme
- Основной цвет: #2c3e50 (темно-синий)
- Акцентный цвет: #3498db (синий)
- Фон: #ecf0f1 (светло-серый)
- Текст: #2c3e50 (темно-синий)

### Components
- Bootstrap 5 для базовых компонентов
- DataTables для таблиц с сортировкой и поиском
- SweetAlert2 для модальных окон подтверждения
- Chart.js для графиков статистики

### Responsive Design
- Адаптивная верстка для работы на планшетах
- Минимальное разрешение: 1024x768
