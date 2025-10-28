-- Обновление локаций существующих коммерческих постов
-- Дата: 12 октября 2025
-- Описание: Обновляет location_name для постов на основе связей с фото

-- Обновляем location_name для постов, привязанных к фото
UPDATE commercial_posts cp
INNER JOIN commercial_post_photos cpp ON cp.id = cpp.commercial_post_id
INNER JOIN photos p ON cpp.photo_id = p.id
INNER JOIN locations l ON p.location_id = l.id
SET 
    cp.location_name = l.title,
    cp.latitude = COALESCE(cp.latitude, l.latitude),
    cp.longitude = COALESCE(cp.longitude, l.longitude)
WHERE 
    cp.location_name IS NULL OR cp.location_name = ''
    OR (cp.latitude IS NULL AND l.latitude IS NOT NULL);

-- Проверяем результат
SELECT 
    COUNT(*) as total_posts,
    SUM(CASE WHEN location_name IS NOT NULL AND location_name != '' THEN 1 ELSE 0 END) as posts_with_location,
    SUM(CASE WHEN location_name IS NULL OR location_name = '' THEN 1 ELSE 0 END) as posts_without_location
FROM commercial_posts
WHERE is_active = 1;

