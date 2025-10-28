<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['id']) || !isset($input['title']) || !isset($input['latitude']) || !isset($input['longitude'])) {
    handleError("Отсутствуют обязательные поля: id, title, latitude, longitude", 400);
}

$locationId = intval($input['id']);
$title = trim($input['title']);
$description = isset($input['description']) ? trim($input['description']) : null;
$latitude = floatval($input['latitude']);
$longitude = floatval($input['longitude']);
$imageUrls = isset($input['imageUrls']) ? $input['imageUrls'] : [];

// Валидация данных
if (empty($title)) {
    handleError("Название локации обязательно для заполнения", 400);
}

if ($latitude < -90 || $latitude > 90) {
    handleError("Широта должна быть в диапазоне от -90 до 90", 400);
}

if ($longitude < -180 || $longitude > 180) {
    handleError("Долгота должна быть в диапазоне от -180 до 180", 400);
}

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Проверяем, существует ли локация и принадлежит ли она текущему пользователю
    $stmt = $db->prepare("
        SELECT id FROM locations 
        WHERE id = :location_id AND user_id = :user_id
    ");
    $stmt->bindParam(':location_id', $locationId);
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    
    if (!$stmt->fetch()) {
        handleError("Указанная локация не найдена или не принадлежит текущему пользователю", 404);
    }
    
    // Обновляем локацию
    $stmt = $db->prepare("
        UPDATE locations 
        SET title = :title, 
            description = :description, 
            latitude = :latitude, 
            longitude = :longitude,
            updated_at = NOW()
        WHERE id = :location_id AND user_id = :user_id
    ");
    $stmt->bindParam(':title', $title);
    $stmt->bindParam(':description', $description);
    $stmt->bindParam(':latitude', $latitude);
    $stmt->bindParam(':longitude', $longitude);
    $stmt->bindParam(':location_id', $locationId);
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    
    // Обработка изображений
    // Проверяем, был ли передан параметр imageUrls (даже если он пустой)
    if (isset($input['imageUrls']) && is_array($imageUrls)) {
        // Начинаем транзакцию для атомарности операции с изображениями
        $db->beginTransaction();
        
        try {
            // 1) Читаем существующие фото для локации, чтобы сохранить их метаданные
            $selectExistingStmt = $db->prepare("
                SELECT file_path, title, description
                FROM photos
                WHERE location_id = :location_id AND user_id = :user_id
            ");
            $selectExistingStmt->bindParam(':location_id', $locationId);
            $selectExistingStmt->bindParam(':user_id', $userId);
            $selectExistingStmt->execute();
            $existingRows = $selectExistingStmt->fetchAll();
            
            // Хелпер для нормализации пути к относительному виду /travel/...
            $normalizeToRelative = function($path) {
                // Если полный URL — берём path часть
                if (filter_var($path, FILTER_VALIDATE_URL)) {
                    $onlyPath = parse_url($path, PHP_URL_PATH);
                    $path = $onlyPath ?: $path;
                }
                // Приводим к началу с /travel/ при необходимости
                if (strpos($path, '/travel/') === 0) {
                    return $path;
                }
                if (strpos($path, 'travel/') === 0) {
                    return '/' . $path;
                }
                // Частый кейс: прислали путь из uploads без префикса /travel
                if (strpos($path, '/uploads/location_images/') === 0) {
                    return '/travel' . $path;
                }
                if (strpos($path, 'uploads/location_images/') === 0) {
                    return '/travel/' . $path;
                }
                // По умолчанию возвращаем как есть
                return $path;
            };
            
            // Карта метаданных по нормализованному пути
            $existingMeta = [];
            foreach ($existingRows as $row) {
                $key = $normalizeToRelative($row['file_path']);
                $existingMeta[$key] = [
                    'title' => $row['title'],
                    'description' => $row['description']
                ];
            }
            
            // 2) Сохраняем информацию об альбомах до удаления фото
            // (foreign key с CASCADE удалит записи из album_photos при удалении фото)
            $selectAlbumLinksStmt = $db->prepare("
                SELECT ap.album_id, ap.position, p.file_path
                FROM album_photos ap
                JOIN photos p ON p.id = ap.photo_id
                WHERE p.location_id = :location_id AND p.user_id = :user_id
            ");
            $selectAlbumLinksStmt->bindParam(':location_id', $locationId);
            $selectAlbumLinksStmt->bindParam(':user_id', $userId);
            $selectAlbumLinksStmt->execute();
            $albumLinks = $selectAlbumLinksStmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Создаем mapping: нормализованный путь -> [album_id, position]
            $pathToAlbumLinks = [];
            foreach ($albumLinks as $link) {
                $normalizedPath = $normalizeToRelative($link['file_path']);
                if (!isset($pathToAlbumLinks[$normalizedPath])) {
                    $pathToAlbumLinks[$normalizedPath] = [];
                }
                $pathToAlbumLinks[$normalizedPath][] = [
                    'album_id' => $link['album_id'],
                    'position' => $link['position']
                ];
            }
            
            // 3) Удаляем все существующие фотографии для данной локации
            // (CASCADE автоматически удалит записи из album_photos)
            $deletePhotosStmt = $db->prepare("
                DELETE FROM photos 
                WHERE location_id = :location_id AND user_id = :user_id
            ");
            $deletePhotosStmt->bindParam(':location_id', $locationId);
            $deletePhotosStmt->bindParam(':user_id', $userId);
            $deletePhotosStmt->execute();
            $deletedCount = $deletePhotosStmt->rowCount();
            
            // 3) Добавляем новые фотографии в правильном порядке, восстанавливая метаданные
            $insertPhotoStmt = $db->prepare("
                INSERT INTO photos (user_id, location_id, file_path, title, description, position) 
                VALUES (:user_id, :location_id, :file_path, :title, :description, :position)
            ");
            
            $addedPhotos = [];
            $pathToNewId = []; // mapping: нормализованный путь -> новый photo ID
            
            foreach ($imageUrls as $index => $imageUrl) {
                // Улучшенная валидация и нормализация пути
                if (!empty($imageUrl)) {
                    $relativePath = $normalizeToRelative($imageUrl);
                    
                    if (!empty($relativePath) && (
                        filter_var($imageUrl, FILTER_VALIDATE_URL) ||
                        (strpos($relativePath, '/travel/') === 0) ||
                        (strpos($relativePath, 'travel/') === 0)
                    )) {
                        $meta = isset($existingMeta[$relativePath]) ? $existingMeta[$relativePath] : ['title' => null, 'description' => null];
                        
                        $insertPhotoStmt->bindParam(':user_id', $userId);
                        $insertPhotoStmt->bindParam(':location_id', $locationId);
                        $insertPhotoStmt->bindParam(':file_path', $relativePath);
                        $insertPhotoStmt->bindParam(':title', $meta['title']);
                        $insertPhotoStmt->bindParam(':description', $meta['description']);
                        $insertPhotoStmt->bindParam(':position', $index);
                        $insertPhotoStmt->execute();
                        
                        $newPhotoId = $db->lastInsertId();
                        
                        $addedPhotos[] = [
                            'id' => $newPhotoId,
                            'file_path' => $relativePath,
                            'position' => $index,
                            'title' => $meta['title'],
                            'description' => $meta['description']
                        ];
                        
                        // Сохраняем mapping для обновления album_photos
                        $pathToNewId[$relativePath] = $newPhotoId;
                    }
                }
            }
            
            // 4) Восстанавливаем связи в album_photos с новыми photo_id
            $insertAlbumPhotoStmt = $db->prepare("
                INSERT INTO album_photos (album_id, photo_id, position) 
                VALUES (:album_id, :photo_id, :position)
                ON DUPLICATE KEY UPDATE position = VALUES(position)
            ");
            
            $albumPhotosRestored = 0;
            foreach ($pathToAlbumLinks as $path => $links) {
                if (isset($pathToNewId[$path])) {
                    $newPhotoId = $pathToNewId[$path];
                    foreach ($links as $link) {
                        $insertAlbumPhotoStmt->bindParam(':album_id', $link['album_id']);
                        $insertAlbumPhotoStmt->bindParam(':photo_id', $newPhotoId);
                        $insertAlbumPhotoStmt->bindParam(':position', $link['position']);
                        $insertAlbumPhotoStmt->execute();
                        $albumPhotosRestored++;
                    }
                }
            }
            
            // 5) Подтверждаем транзакцию
            $db->commit();
            
            // Информация об изображениях
            $imagesInfo = [
                'images_updated' => true,
                'images_deleted' => $deletedCount,
                'images_added' => count($addedPhotos),
                'images_count' => count($addedPhotos),
                'album_photos_restored' => $albumPhotosRestored,
                'images' => $addedPhotos
            ];
            
        } catch (Exception $e) {
            // Откатываем транзакцию при ошибке
            $db->rollback();
            handleError("Ошибка при обновлении изображений: " . $e->getMessage(), 500);
        }
    } else {
        // Если imageUrls не передан, оставляем изображения без изменений
        $imagesInfo = [
            'images_updated' => false,
            'images_count' => 0,
            'message' => 'Изображения не были переданы для обновления'
        ];
    }
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'message' => 'Локация обновлена успешно',
        'location' => [
            'id' => $locationId,
            'userId' => $userId,
            'title' => $title,
            'description' => $description,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'updatedAt' => date('Y-m-d H:i:s')
        ],
        'images' => $imagesInfo,
        'debug_info' => [
            'db_working' => $db ? true : false,
            'userId' => $userId,
            'params_received' => [
                'title' => $title ? 'yes' : 'no',
                'latitude' => $latitude ? 'yes' : 'no',
                'longitude' => $longitude ? 'yes' : 'no',
                'imageUrls_isset' => isset($input['imageUrls']) ? 'yes' : 'no',
                'imageUrls_count' => is_array($imageUrls) ? count($imageUrls) : 'not array',
                'imageUrls_content' => is_array($imageUrls) ? $imageUrls : 'not array'
            ]
        ]
    ]);
    
} catch (Exception $e) {
    handleError("Ошибка при обновлении локации: " . $e->getMessage(), 500);
} 