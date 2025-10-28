-- Сделать поле album_id в таблице commercial_posts nullable
-- Это позволит создавать коммерческие посты без привязки к альбому

-- Сначала удаляем внешний ключ
ALTER TABLE commercial_posts DROP FOREIGN KEY fk_commercial_posts_album;

-- Изменяем тип поля на nullable
ALTER TABLE commercial_posts MODIFY COLUMN album_id INT NULL;

-- Добавляем внешний ключ обратно, но теперь он разрешает NULL
ALTER TABLE commercial_posts 
ADD CONSTRAINT fk_commercial_posts_album 
FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE;
