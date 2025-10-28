-- Тестовые данные для коммерческих постов
-- Выполните этот скрипт после создания таблицы commercial_posts

-- Добавляем тестовые коммерческие посты для альбома с ID 10
INSERT INTO commercial_posts (
    user_id, 
    album_id, 
    title, 
    description, 
    image_url,
    price, 
    currency, 
    contact_info, 
    is_active
) VALUES 
(
    5, -- user_id (Same Video)
    10, -- album_id (существующий альбом)
    'Туристические услуги в Париже',
    'Предлагаю экскурсии по Парижу, трансфер из аэропорта, помощь с размещением. Опыт работы 5 лет.',
    '/travel/uploads/location_images/5_34_67ea3ddec2fd8_1743404510.webp', -- изображение из существующих фото
    50.00,
    'EUR',
    'Телефон: +33 123 456 789, Email: paris.tours@example.com',
    1
),
(
    7, -- user_id (Web Studio)
    10, -- album_id (тот же альбом)
    'Фотосессия в Париже',
    'Профессиональная фотосессия в самых красивых местах Парижа. Включает обработку фото.',
    '/travel/uploads/location_images/6_41_67f52351d09f7_1744118609.jpg', -- изображение из существующих фото
    120.00,
    'EUR',
    'Instagram: @paris_photographer, WhatsApp: +33 987 654 321',
    1
),
(
    5, -- user_id (Same Video)
    10, -- album_id (тот же альбом)
    'Аренда квартиры в центре',
    'Уютная квартира в центре Парижа, 2 комнаты, рядом с метро. Доступна с завтрашнего дня.',
    '/travel/uploads/location_images/20_42_67f7ebe8e1ab8_1744301032.png', -- изображение из существующих фото
    80.00,
    'EUR',
    'Airbnb: Paris Center Apartment, Телефон: +33 555 123 456',
    1
),
(
    7, -- user_id (Web Studio)
    10, -- album_id (тот же альбом)
    'Кулинарные мастер-классы',
    'Научитесь готовить традиционные французские блюда с профессиональным шеф-поваром.',
    '/travel/uploads/location_images/20_43_67f81b50f39c7_1744313168.jpg', -- изображение из существующих фото
    75.00,
    'EUR',
    'Email: cooking@paris.com, Телефон: +33 111 222 333',
    1
),
(
    5, -- user_id (Same Video)
    10, -- album_id (тот же альбом)
    'Винные туры',
    'Посетите лучшие винодельни Франции с дегустацией вин и сыров.',
    '/travel/uploads/location_images/20_44_67f82f4743797_1744318279.jpg', -- изображение из существующих фото
    95.00,
    'EUR',
    'WhatsApp: +33 444 555 666, Instagram: @wine_tours_paris',
    1
);

-- Проверяем, что данные добавились
SELECT 
    cp.id,
    cp.title,
    cp.price,
    cp.currency,
    u.first_name,
    u.last_name,
    a.title as album_title
FROM commercial_posts cp
LEFT JOIN users u ON cp.user_id = u.id
LEFT JOIN albums a ON cp.album_id = a.id
WHERE cp.album_id = 10;
