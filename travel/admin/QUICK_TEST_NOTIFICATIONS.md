# Быстрый тест уведомлений

## Шаг 1: Откройте простой тест
```
http://your-domain/travel/admin/test_bell_simple.html
```

Нажмите на колокольчик. Должен открыться dropdown с уведомлениями.

**Если работает** → переходите к Шагу 2  
**Если НЕ работает** → проблема в браузере или JavaScript отключен

## Шаг 2: Откройте админку
```
http://your-domain/travel/admin/
```

Откройте консоль браузера (F12) и проверьте логи.

**Ожидаемые логи:**
```
DOM Ready - Starting initialization...
Initialized X dropdowns
Notifications dropdown: <a id="notificationsDropdown">
Notifications menu: <div id="notificationsMenu">
Initializing notifications dropdown...
Notifications dropdown initialized successfully
```

## Шаг 3: Нажмите на колокольчик

**Ожидаемые логи:**
```
Notification bell clicked!
Is shown: false
Opening dropdown
```

**Если dropdown открылся** → ✅ Все работает!  
**Если dropdown НЕ открылся** → см. ниже

## Проблемы и решения

### Проблема: "Notifications dropdown or menu not found!"
**Решение:** Элементы не найдены в DOM
- Проверьте, что `header.php` обновлен
- Очистите кэш сервера
- Проверьте права доступа к файлам

### Проблема: "$ is not defined"
**Решение:** jQuery не загружен
- Проверьте `footer.php` - jQuery должен быть первым
- Проверьте сетевые запросы в DevTools

### Проблема: Колокольчик не реагирует, но логов нет
**Решение:** JavaScript не выполняется
- Проверьте, что `admin.js` загружен (вкладка Network в DevTools)
- Проверьте, что нет ошибок JavaScript выше в консоли
- Очистите кэш браузера (Ctrl+Shift+R)

### Проблема: Dropdown открывается, но расширяет navbar
**Решение:** CSS не применился
- Проверьте, что `admin.css` обновлен
- Проверьте в DevTools, что `#notificationsMenu` имеет `position: absolute`
- Очистите кэш браузера

## Быстрое решение

Если ничего не помогает, используйте резервную версию:

1. Откройте `header_bootstrap_dropdown.php.backup`
2. Скопируйте содержимое
3. Замените секцию с уведомлениями в `header.php`
4. Удалите функцию `initNotificationsDropdown()` из `admin.js`

Это вернет стандартный Bootstrap dropdown, который точно работает.

## Контакты для поддержки

Если проблема сохраняется, предоставьте:
1. Скриншот консоли браузера (F12)
2. Скриншот вкладки Network (загрузка admin.js)
3. Версию браузера
4. Устройство (desktop/mobile)
