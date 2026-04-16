# Настройка системы модерации

## Что изменилось

Добавлена полноценная система модерации контента с тремя статусами:
- **pending** (на проверке) - новые фото по умолчанию
- **approved** (одобрено) - видны пользователям в приложении
- **rejected** (отклонено) - скрыты от пользователей

## Установка

### 1. Применить миграцию базы данных

Откройте в браузере:
```
http://your-domain/travel/admin/apply_moderation_migration.php
```

Или выполните SQL вручную через phpMyAdmin:
```sql
-- Файл: migrations/add_moderation_status.sql
```

### 2. Что делает миграция

- Добавляет колонку `moderation_status` в таблицу `photos`
- Добавляет колонки `moderated_at` и `moderated_by`
- Создает индекс для быстрой фильтрации
- **Важно**: Все существующие фото автоматически получают статус `approved`

### 3. Новые API endpoints

**Одобрить фото:**
```
POST /api/moderation/approve_photo.php
Body: { "photoId": 123 }
```

**Отклонить фото:**
```
POST /api/moderation/reject_photo.php
Body: { "photoId": 123 }
```

**Массовое одобрение:**
```
POST /api/moderation/bulk_approve_photos.php
Body: { "photoIds": [1, 2, 3] }
```

**Массовое отклонение:**
```
POST /api/moderation/bulk_reject_photos.php
Body: { "photoIds": [1, 2, 3] }
```

## Использование админки

### Фильтры

В панели модерации доступны фильтры:
- **Статус**: pending / approved / rejected / all
- **Пользователь**: ID пользователя
- **Дата**: диапазон дат

По умолчанию показываются только фото со статусом **pending**.

### Действия

**Для отдельных фото:**
- Кнопка ✓ (зеленая) - одобрить
- Кнопка ✗ (красная) - отклонить

**Массовые действия:**
1. Выберите фото чекбоксами
2. Нажмите "Одобрить" или "Отклонить" в шапке страницы

### Бейджи статусов

- 🟢 **Одобрено** - зеленый бейдж
- 🔴 **Отклонено** - красный бейдж
- 🟡 **На проверке** - желтый бейдж

## Интеграция с приложением

### Важно для мобильного приложения

Теперь при загрузке фото в API нужно:

1. **При создании фото** устанавливать `moderation_status = 'pending'`
2. **При получении фото** фильтровать только `moderation_status = 'approved'`

### Пример SQL для приложения

```sql
-- Получить только одобренные фото
SELECT * FROM photos 
WHERE moderation_status = 'approved'
ORDER BY created_at DESC;

-- Создать новое фото (автоматически pending)
INSERT INTO photos (user_id, title, file_path, moderation_status)
VALUES (?, ?, ?, 'pending');
```

## Workflow модерации

1. Пользователь загружает фото → статус `pending`
2. Фото **не видно** другим пользователям
3. Админ заходит в панель модерации
4. Админ видит фото со статусом `pending`
5. Админ одобряет → статус `approved` → фото видно всем
6. Или админ отклоняет → статус `rejected` → фото скрыто

## Проверка работы

После применения миграции:

1. Зайдите в админку: `/travel/admin/views/moderation.php`
2. Выберите фильтр "Все" чтобы увидеть все фото
3. Все существующие фото должны иметь статус "Одобрено"
4. Попробуйте одобрить/отклонить тестовое фото

## Откат (если нужно)

Если нужно вернуться к старой версии:

```sql
ALTER TABLE photos DROP FOREIGN KEY fk_photos_moderated_by;
ALTER TABLE photos DROP COLUMN moderation_status;
ALTER TABLE photos DROP COLUMN moderated_at;
ALTER TABLE photos DROP COLUMN moderated_by;
DROP INDEX idx_moderation_status ON photos;
```
