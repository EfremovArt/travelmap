-- Создание системного альбома для standalone коммерческих постов

-- Сначала проверим, существует ли уже альбом с id = 0
SELECT COUNT(*) as album_exists FROM albums WHERE id = 0;

-- Если альбом не существует, создаем его
INSERT IGNORE INTO albums (
    id, 
    title, 
    description, 
    owner_id, 
    is_public, 
    created_at, 
    updated_at
) VALUES (
    0,
    'System Album for Standalone Commercial Posts',
    'This is a system album used for commercial posts that are not associated with any specific user album',
    1, -- Используем ID первого пользователя системы, или можно создать специального системного пользователя
    0, -- Не публичный
    NOW(),
    NOW()
);

-- Проверяем результат
SELECT * FROM albums WHERE id = 0;
