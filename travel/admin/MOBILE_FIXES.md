# Исправления для мобильной версии

## Проблема 1: Колокольчик уведомлений не работает на мобильных

### Причина
Ссылка `<a href="#">` с `data-bs-toggle="dropdown"` плохо работает на мобильных устройствах из-за конфликта событий touch/click.

### Решение
1. **Заменена ссылка на кнопку**: `<a>` → `<button type="button">`
2. Убрана ручная инициализация dropdown - Bootstrap 5 управляет автоматически
3. Изменен порядок загрузки скриптов: jQuery → Bootstrap (вместо Bootstrap → jQuery)
4. Добавлены CSS стили для кнопки, чтобы она выглядела как nav-link
5. Используется только событие `shown.bs.dropdown` для загрузки уведомлений

### Изменения в коде

**header.php:**
```html
<!-- Было -->
<a class="nav-link position-relative" href="#" id="notificationsDropdown" role="button" data-bs-toggle="dropdown">

<!-- Стало -->
<button class="nav-link position-relative btn btn-link text-white border-0" id="notificationsDropdown" type="button" data-bs-toggle="dropdown">
```

**footer.php:**
```html
<!-- Изменен порядок загрузки -->
<!-- jQuery (required for DataTables and loaded first) -->
<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>

<!-- Bootstrap 5 JS Bundle -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
```

### Файлы
- `travel/admin/includes/header.php` - заменена ссылка на кнопку
- `travel/admin/includes/footer.php` - изменен порядок загрузки скриптов
- `travel/admin/assets/js/admin.js` - убрана ручная инициализация
- `travel/admin/assets/css/admin.css` - добавлены стили для кнопки

## Проблема 2: Страница перезагружается в разделе модерации

### Причина
Автообновление каждые 30 секунд вызывает полную перезагрузку галереи (`gallery.innerHTML = ''`), что создает эффект "прыжка" страницы на мобильных устройствах.

### Решение
1. **Отключено автообновление на мобильных устройствах** (ширина экрана <= 768px)
2. Добавлена проверка `window.innerWidth` в функциях `startPhotosAutoRefresh()` и `startCommentsAutoRefresh()`
3. Обновлен индикатор автообновления - на мобильных показывает "Автообновление отключено"
4. На десктопах автообновление работает с сохранением позиции скролла

### Почему отключено на мобильных?
- Мобильные устройства имеют ограниченную производительность
- Перерисовка DOM вызывает заметные "прыжки" страницы
- Пользователи могут вручную обновить страницу при необходимости
- Уменьшается нагрузка на сервер от мобильных пользователей

### Файлы
- `travel/admin/assets/js/moderation.js`

## Дополнительные улучшения

### CSS для колокольчика
- Увеличена область клика до 44x44px (48x48px на мобильных)
- Добавлен `touch-action: manipulation` для лучшей работы с touch-событиями
- Добавлена визуальная обратная связь при нажатии (`:active`)

### Файлы
- `travel/admin/assets/css/admin.css`

## Тестирование

### Колокольчик
1. Открыть админку на мобильном устройстве
2. Кликнуть на колокольчик - должен открыться с первого раза
3. Проверить, что уведомления загружаются

### Модерация
1. Открыть раздел модерации на мобильном
2. Прокрутить страницу вниз
3. Подождать 30+ секунд
4. Убедиться, что страница НЕ прыгает вверх
5. Проверить индикатор "Автообновление отключено"

## Откат изменений

Если нужно вернуть автообновление на мобильных:

```javascript
// В moderation.js, удалить эти строки:
const isMobile = window.innerWidth <= 768;
if (isMobile) {
    console.log('Auto-refresh disabled on mobile');
    return;
}
```
