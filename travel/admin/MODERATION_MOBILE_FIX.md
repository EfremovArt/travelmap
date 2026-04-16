# Исправления модерации для мобильных устройств

## Дата: 20 ноября 2025

## Проблемы и решения

### 1. ❌ Проблема: Невозможно поставить галочку на мобильных
**Описание**: При клике на чекбокс на телефоне сразу открывался пост, невозможно было выбрать фото.

**Решение**:
- Добавлен контейнер `.checkbox-container` с увеличенной областью клика (60x60px на мобильных)
- Увеличен размер самого чекбокса до 26px на мобильных устройствах
- Добавлен отдельный обработчик клика для контейнера чекбокса
- Клик на контейнер переключает состояние чекбокса без открытия поста
- Обработчик клика на карточку теперь игнорирует клики на область чекбокса

**Код изменений**:
```javascript
// Контейнер чекбокса с большой областью клика
checkboxContainer.addEventListener('click', function(e) {
    e.stopPropagation();
    const checkbox = this.querySelector('.photo-checkbox');
    if (checkbox && e.target !== checkbox) {
        checkbox.checked = !checkbox.checked;
        checkbox.dispatchEvent(new Event('change'));
    }
});
```

**CSS стили**:
```css
.checkbox-container {
    min-width: 50px;
    min-height: 50px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    z-index: 10;
}

@media (max-width: 767.98px) {
    .checkbox-container {
        min-width: 60px;
        min-height: 60px;
    }
    
    .photo-checkbox-red {
        width: 26px;
        height: 26px;
    }
}
```

### 2. ❌ Проблема: Поиск пользователя только по ID
**Описание**: В фильтре модерации можно было искать пользователя только по ID, что неудобно.

**Решение**:
- Изменен тип поля с `number` на `text`
- Изменен placeholder с "ID" на "Имя или email"
- Обновлен API для поиска по имени, фамилии или email
- Поиск работает с частичным совпадением (LIKE)

**API изменения**:
```php
// Новый параметр user_search
$userSearch = isset($_GET['user_search']) ? trim($_GET['user_search']) : null;

// Поиск по имени, фамилии или email
if ($userSearch) {
    $whereConditions[] = '(u.first_name LIKE :user_search 
                          OR u.last_name LIKE :user_search 
                          OR u.email LIKE :user_search 
                          OR CONCAT(u.first_name, " ", u.last_name) LIKE :user_search)';
    $params[':user_search'] = '%' . $userSearch . '%';
}
```

**JavaScript изменения**:
```javascript
// Отправка user_search вместо user_id
const userSearch = document.getElementById('filterUser').value.trim();
if (userSearch) currentFilters.user_search = userSearch;
```

## Измененные файлы

1. **travel/admin/assets/js/moderation.js**
   - Добавлен контейнер чекбокса с увеличенной областью клика
   - Добавлен обработчик клика для контейнера
   - Изменен параметр фильтра с `user_id` на `user_search`

2. **travel/admin/assets/css/admin.css**
   - Добавлены стили для `.checkbox-container`
   - Увеличен размер чекбокса на мобильных до 26px
   - Увеличена область клика до 60x60px на мобильных

3. **travel/admin/views/moderation.php**
   - Изменен тип поля фильтра с `number` на `text`
   - Изменен placeholder на "Имя или email"
   - Увеличена ширина колонки с `col-md-2` до `col-md-3`

4. **travel/admin/api/moderation/get_all_photos.php**
   - Добавлен параметр `user_search`
   - Добавлен SQL запрос для поиска по имени/email
   - Поиск работает с частичным совпадением

## Результаты

✅ **Мобильные устройства**: Теперь легко ставить и убирать галочки на телефоне
✅ **Удобный поиск**: Можно искать пользователей по имени или email, не зная их ID
✅ **Большая область клика**: 60x60px на мобильных для комфортного использования
✅ **Частичное совпадение**: Поиск работает даже при вводе части имени или email

## Тестирование

Протестировано на:
- ✅ iPhone (iOS Safari)
- ✅ Android (Chrome Mobile)
- ✅ Планшеты
- ✅ Десктоп браузеры

## Примеры использования

**Поиск пользователя**:
- Ввод: "john" → найдет John Smith, john@example.com
- Ввод: "smith" → найдет John Smith, Mary Smith
- Ввод: "@gmail" → найдет всех пользователей с Gmail
- Ввод: "иван" → найдет Иван Петров, Петр Иванов
