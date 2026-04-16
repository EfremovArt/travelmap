# Исправления модерации

## Проблемы и решения

### 1. ❌ Ошибка aria-hidden в консоли
**Проблема:** `Blocked aria-hidden on an element because its descendant retained focus`

**Решение:**
- Добавлены обработчики событий `shown.bs.modal` и `hidden.bs.modal`
- При открытии модального окна `aria-hidden` удаляется
- При закрытии модального окна `aria-hidden` восстанавливается
- Добавлен `aria-labelledby` для связи с заголовком
- Добавлен `aria-label` для кнопки закрытия

**Файлы:**
- `travel/admin/assets/js/moderation.js` - функция `showPhotoPreview()`
- `travel/admin/views/moderation.php` - HTML модального окна

### 2. ❌ Ошибка 404 для temp_photo.jpg
**Проблема:** `GET https://bearded-fox.ru/travel/temp_photo.jpg 404 (Not Found)`

**Решение:**
- Улучшена фильтрация изображений в функции отображения карточек
- Добавлена проверка на `temp_photo.jpg` в модальном окне
- При обнаружении невалидного пути используется placeholder: `/travel/admin/assets/images/default-avatar.svg`

**Файлы:**
- `travel/admin/assets/js/moderation.js` - функции рендеринга карточек и `showPhotoPreview()`

### 3. ❌ Кнопка удаления комментария - красный прямоугольник
**Проблема:** Вместо иконки корзины отображался красный прямоугольник

**Решение:**
- Добавлена библиотека Bootstrap Icons в header
- Добавлены CSS стили для кнопки `.delete-comment-btn`
- Иконка `<i class="bi bi-trash"></i>` теперь корректно отображается

**Файлы:**
- `travel/admin/includes/header.php` - подключение Bootstrap Icons CDN
- `travel/admin/assets/css/admin.css` - стили для кнопки удаления

## Тестирование

Откройте файл `test_moderation_fixes.html` в браузере для проверки:
1. Иконка корзины отображается корректно
2. Все Bootstrap Icons загружаются
3. Модальное окно работает без ошибок aria-hidden

## Технические детали

### Bootstrap Icons CDN
```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
```

### CSS для кнопки удаления
```css
.delete-comment-btn {
    padding: 0.25rem 0.5rem;
    font-size: 0.875rem;
    background-color: #dc3545;
    color: white;
    transition: all 0.2s ease;
}
```

### JavaScript для aria-hidden
```javascript
modalEl.addEventListener('shown.bs.modal', function() {
    modalEl.removeAttribute('aria-hidden');
});

modalEl.addEventListener('hidden.bs.modal', function() {
    modalEl.setAttribute('aria-hidden', 'true');
});
```

### 4. ❌ Комментарии показывают "Нет текста"
**Проблема:** Все комментарии отображались как "Нет текста"

**Решение:**
- API возвращает поле `commentText` (camelCase)
- JavaScript проверял неправильные имена полей
- Исправлена логика извлечения текста комментария
- Добавлено логирование в консоль для отладки

**Файлы:**
- `travel/admin/assets/js/moderation.js` - функция `displayPhotoComments()`
- `travel/admin/api/comments/get_all_comments.php` - возвращает `commentText`

**Проверка полей:**
```javascript
const commentText = comment.commentText || comment.comment_text || comment.text || comment.comment || '';
```

### 5. ❌ Комментарии не удаляются (400 Bad Request)
**Проблема:** При попытке удалить комментарий возникала ошибка 400

**Причина:**
- API ожидает параметры `commentId` и `commentType` (camelCase)
- JavaScript отправлял `comment_id` и `comment_type` (snake_case)

**Решение:**
- Изменены параметры в функции `deleteComment()` на camelCase
- Добавлен `parseInt()` для commentId
- Улучшена обработка ошибок с выводом сообщения от сервера

**Файлы:**
- `travel/admin/assets/js/moderation.js` - функция `deleteComment()`

**Было:**
```javascript
body: JSON.stringify({ 
    comment_id: commentId,
    comment_type: commentType
})
```

**Стало:**
```javascript
body: JSON.stringify({ 
    commentId: parseInt(commentId),
    commentType: commentType
})
```

### 6. ❌ Повторная ошибка aria-hidden на container-fluid
**Проблема:** Bootstrap автоматически добавляет `aria-hidden="true"` к элементам вне модального окна, включая `container-fluid`

**Причина:**
- Bootstrap 5 добавляет aria-hidden к родительским элементам для accessibility
- Это вызывает ошибку, когда фокус остается на элементах с aria-hidden

**Решение:**
- Убран `aria-hidden="true"` из HTML модального окна
- Добавлен обработчик события `hidden.bs.modal`
- После закрытия модального окна удаляется aria-hidden со всех `.container-fluid`
- Убрано логирование в консоль

**Файлы:**
- `travel/admin/views/moderation.php` - убран aria-hidden из HTML
- `travel/admin/assets/js/moderation.js` - очистка aria-hidden после закрытия модального окна

**Код:**
```javascript
modalEl.addEventListener('hidden.bs.modal', function() {
    const containers = document.querySelectorAll('.container-fluid[aria-hidden="true"]');
    containers.forEach(container => {
        container.removeAttribute('aria-hidden');
    });
});
```

## Проверка

✅ Нет ошибок aria-hidden в консоли
✅ Нет 404 ошибок для temp_photo.jpg
✅ Иконка корзины отображается корректно
✅ Все Bootstrap Icons работают
✅ Модальное окно доступно для assistive technology
✅ Комментарии отображают правильный текст
✅ Комментарии успешно удаляются

## Отладка

### Проверка комментариев:
1. `test_comments_api.php` - структура БД и данные комментариев
2. `test_delete_comment.php` - проверка параметров API удаления
3. Консоль браузера - логирование структуры комментариев

### Проверка aria-hidden:
1. Откройте консоль браузера (F12)
2. Откройте модальное окно с фото
3. Не должно быть ошибок "Blocked aria-hidden"
4. Проверьте, что фокус работает корректно на кнопке закрытия
