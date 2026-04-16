# Implementation Plan: Admin Panel

- [x] 1. Настройка базовой структуры и авторизации
  - Создать директорию `travel/admin/` и базовую структуру папок
  - Создать таблицу `admin_users` в базе данных для администраторов
  - Реализовать `admin/config/admin_config.php` с функциями авторизации (`adminRequireAuth()`, `adminLogin()`, `adminLogout()`)
  - Создать страницу авторизации `admin/login.php` с формой входа
  - Создать `admin/logout.php` для выхода из системы
  - _Requirements: Authentication System_

- [x] 2. Создание базового UI и навигации
  - Создать `admin/includes/header.php` с верхней панелью и информацией об администраторе
  - Создать `admin/includes/sidebar.php` с боковым меню навигации
  - Создать `admin/includes/footer.php` с общим футером
  - Создать `admin/assets/css/admin.css` с базовыми стилями
  - Подключить Bootstrap 5, DataTables.js, SweetAlert2, Chart.js
  - Создать главную страницу `admin/index.php` с подключением всех компонентов
  - _Requirements: UI/UX Design_

- [x] 3. Реализация Dashboard (главная панель)
  - Создать `admin/api/dashboard/get_stats.php` для получения общей статистики
  - Реализовать SQL запросы для подсчета пользователей, постов, лайков, комментариев, подписок, избранного
  - Создать `admin/views/dashboard.php` с отображением статистики в карточках
  - Добавить график активности за последние 7 дней с использованием Chart.js
  - _Requirements: Requirement 1-8 (общая статистика)_

- [x] 4. Реализация управления лайками
  - Создать `admin/api/likes/get_all_likes.php` с пагинацией, фильтрацией и поиском
  - Реализовать SQL запрос с JOIN для получения данных пользователей и постов
  - Создать `admin/views/likes.php` с таблицей лайков
  - Создать `admin/assets/js/likes.js` для инициализации DataTables и обработки фильтров
  - Добавить фильтры по пользователю и посту
  - _Requirements: Requirement 1_

- [x] 5. Реализация управления комментариями
  - Создать `admin/api/comments/get_all_comments.php` с пагинацией, фильтрацией и поиском
  - Создать `admin/api/comments/delete_comment.php` для удаления комментария
  - Реализовать SQL запросы для получения комментариев к постам и альбомам
  - Создать `admin/views/comments.php` с таблицей комментариев и кнопками удаления
  - Создать `admin/assets/js/comments.js` для обработки удаления с подтверждением
  - Добавить фильтры по пользователю, посту и альбому
  - _Requirements: Requirement 2_

- [x] 6. Реализация управления пользователями
  - Создать `admin/api/users/get_all_users.php` с пагинацией и поиском
  - Создать `admin/api/users/get_user_details.php` для получения детальной информации о пользователе
  - Реализовать SQL запросы для подсчета статистики пользователя (подписчики, посты, лайки, комментарии)
  - Создать `admin/views/users.php` с таблицей пользователей
  - Создать `admin/views/user_details.php` с детальной информацией о пользователе
  - Создать `admin/assets/js/users.js` для навигации к деталям пользователя
  - Отобразить на странице пользователя: подписчиков, подписки, избранное, комментированные посты
  - _Requirements: Requirement 3_

- [x] 7. Реализация управления подписками
  - Создать `admin/api/follows/get_all_follows.php` с пагинацией и фильтрацией
  - Реализовать SQL запрос с JOIN для получения данных подписчика и пользователя
  - Создать `admin/views/follows.php` с таблицей подписок
  - Создать `admin/assets/js/follows.js` для инициализации DataTables
  - Добавить фильтр по пользователю и поиск по имени
  - _Requirements: Requirement 4_

- [x] 8. Реализация управления избранным
  - Создать `admin/api/favorites/get_all_favorites.php` с поддержкой разных типов (photo/album/commercial)
  - Реализовать SQL запросы для получения избранного из таблиц `favorites`, `album_favorites`, `commercial_favorites`
  - Создать `admin/views/favorites.php` с вкладками для разных типов избранного
  - Создать `admin/assets/js/favorites.js` для переключения вкладок и загрузки данных
  - Добавить фильтр по пользователю и типу контента
  - _Requirements: Requirement 5_

- [x] 9. Реализация управления публикациями
  - Создать `admin/api/posts/get_all_posts.php` для получения всех постов
  - Создать `admin/api/posts/get_all_albums.php` для получения всех альбомов
  - Создать `admin/api/posts/get_all_commercial_posts.php` для получения коммерческих постов
  - Создать `admin/api/posts/get_album_photos.php` для получения фотографий альбома
  - Создать `admin/api/posts/get_commercial_post_relations.php` для получения связей коммерческого поста
  - Создать `admin/views/posts.php` с вкладками для постов, альбомов и коммерческих постов
  - Создать `admin/views/commercial_post_details.php` для отображения связей коммерческого поста
  - Создать `admin/assets/js/posts.js` для переключения вкладок и навигации
  - Добавить фильтры по автору и поиск по заголовку/локации
  - _Requirements: Requirement 6, Requirement 8_

- [x] 10. Реализация модерации контента
  - Создать `admin/api/moderation/get_all_photos.php` для получения всех фотографий
  - Создать `admin/api/moderation/delete_photo.php` для удаления одной фотографии
  - Создать `admin/api/moderation/bulk_delete_photos.php` для массового удаления
  - Реализовать удаление файла из файловой системы при удалении из БД
  - Создать `admin/views/moderation.php` с галереей фотографий и чекбоксами для выбора
  - Создать `admin/assets/js/moderation.js` для обработки удаления с подтверждением
  - Добавить фильтры по автору и дате
  - Реализовать превью фотографии при наведении
  - _Requirements: Requirement 7_

- [x] 11. Добавление безопасности и валидации
  - Добавить CSRF токены для всех форм удаления и изменения данных
  - Реализовать функцию генерации и проверки CSRF токенов
  - Добавить валидацию всех входных параметров в API эндпоинтах
  - Добавить экранирование вывода с `htmlspecialchars()` во всех view файлах
  - Добавить логирование действий администраторов (создать таблицу `admin_logs`)
  - Реализовать ограничение попыток входа (защита от брутфорса)
  - _Requirements: Security Considerations_

- [x] 12. Оптимизация и финальное тестирование
  - Добавить индексы в базу данных для оптимизации запросов
  - Реализовать кеширование статистики на главной странице
  - Оптимизировать SQL запросы с большим количеством JOIN
  - Протестировать все разделы админки вручную
  - Протестировать фильтрацию, поиск и пагинацию
  - Протестировать удаление контента
  - Проверить работу на разных разрешениях экрана
  - _Requirements: Performance Considerations, Testing Strategy_
