<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();

// Обработка запроса только методом GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

// Получение параметров для пагинации
$page = isset($_GET['page']) ? intval($_GET['page']) : 1;
$perPage = isset($_GET['per_page']) ? intval($_GET['per_page']) : 50;

// Ограничение максимального количества элементов на странице
if ($perPage > 100) {
    $perPage = 100;
}

// Вычисление смещения для SQL запроса
$offset = ($page - 1) * $perPage;

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Выводим диагностическую информацию
    error_log("Получение всех локаций. Запрос от пользователя: $userId");
    
    // Получаем общее количество локаций
    $stmt = $db->prepare("
        SELECT COUNT(*) as total 
        FROM locations
    ");
    $stmt->execute();
    $total = $stmt->fetch()['total'];
    
    // Получаем все локации с пагинацией
    $stmt = $db->prepare("
        SELECT id, title, description, latitude, longitude, address, city, country, 
               created_at, updated_at, user_id
        FROM locations 
        ORDER BY created_at DESC
        LIMIT :limit OFFSET :offset
    ");
    $stmt->bindParam(':limit', $perPage, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $locations = $stmt->fetchAll();
    
    // Выводим информацию о найденных локациях
    error_log("Найдено локаций: " . count($locations));
    
    // Получаем фотографии для каждой локации
    foreach ($locations as &$location) {
        $stmtPhotos = $db->prepare("
            SELECT id, user_id, file_path, original_file_path, title, description, created_at, position
            FROM photos 
            WHERE location_id = :location_id
            ORDER BY position ASC, id ASC
        ");
        $stmtPhotos->bindParam(':location_id', $location['id']);
        $stmtPhotos->execute();
        $photos = $stmtPhotos->fetchAll();
        
        // Добавляем fallback для оригинальных изображений (обратная совместимость)
        foreach ($photos as &$photo) {
            if (empty($photo['original_file_path'])) {
                $photo['original_file_path'] = $photo['file_path'];
            }
        }
        unset($photo);
        
        $location['photos'] = $photos;
        
        // Добавляем отладочную информацию о фотографиях
        error_log("Локация ID: " . $location['id'] . ", найдено фотографий: " . count($location['photos']));
    }
    
    // Вычисляем общее количество страниц
    $totalPages = ceil($total / $perPage);
    
    // Отправляем успешный ответ
    echo json_encode([
        'success' => true,
        'data' => [
            'locations' => $locations,
            'pagination' => [
                'total' => $total,
                'per_page' => $perPage,
                'current_page' => $page,
                'total_pages' => $totalPages
            ]
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Ошибка при получении локаций: " . $e->getMessage());
    handleError("Ошибка при получении локаций: " . $e->getMessage(), 500);
} 