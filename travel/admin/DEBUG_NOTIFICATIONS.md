# Отладка уведомлений

## Проблема
Колокольчик уведомлений не работает ни в одной версии.

## Шаги для отладки

### 1. Откройте тестовую страницу
Откройте `test_bell_simple.html` в браузере:
```
http://your-domain/travel/admin/test_bell_simple.html
```

Эта страница содержит минимальный код без зависимостей от админки. Если она работает, значит проблема в основном коде админки.

### 2. Проверьте консоль браузера
Откройте консоль разработчика (F12) и проверьте:

**Ожидаемые сообщения:**
```
DOM Ready - Starting initialization...
Initialized X dropdowns
Notifications dropdown: <a id="notificationsDropdown">
Notifications menu: <div id="notificationsMenu">
Initializing notifications dropdown...
Notifications dropdown initialized successfully
Initialization complete
```

**При клике на колокольчик:**
```
Notification bell clicked!
Is shown: false
Opening dropdown
```

### 3. Проверьте ошибки JavaScript
Если видите ошибки типа:
- `$ is not defined` - jQuery не загружен
- `bootstrap is not defined` - Bootstrap не загружен
- `Cannot read property 'addEventListener' of null` - элемент не найден

### 4. Проверьте порядок загрузки скриптов
В `footer.php` должен быть такой порядок:
1. jQuery
2. Bootstrap
3. admin.js

### 5. Проверьте кэш браузера
Очистите кэш браузера или откройте в режиме инкогнито.

### 6. Проверьте версию файла
В URL admin.js должен быть параметр `?v=timestamp`:
```
/travel/admin/assets/js/admin.js?v=1234567890
```

## Что было изменено

### Разделение функций
- `initDropdowns()` - инициализирует Bootstrap dropdowns
- `initNotificationsDropdown()` - инициализирует кастомный dropdown уведомлений

### Задержки инициализации
- Bootstrap dropdowns: 100ms
- Notifications dropdown: 150ms
- Load notifications: 200ms

Это гарантирует, что все элементы DOM загружены перед инициализацией.

### Логирование
Добавлены console.log для отладки на каждом этапе.

## Если проблема сохраняется

1. Проверьте, что файлы обновлены на сервере
2. Очистите кэш сервера (если есть)
3. Проверьте права доступа к файлам
4. Проверьте, что нет конфликтов с другими скриптами

## Временное решение

Если ничего не помогает, можно вернуться к стандартному Bootstrap dropdown:

В `header.php` замените:
```html
<div class="position-relative me-3">
    <a ... id="notificationsDropdown">
```

На:
```html
<li class="nav-item dropdown me-3">
    <a ... id="notificationsDropdown" data-bs-toggle="dropdown">
```

И удалите кастомную логику из `admin.js`.
