<?php
require_once '../config.php';
initApi();

// Функция для логирования в файл
function debugLog($message) {
    $logFile = '/www/wwwroot/bearded-fox.ru/travel/debug.log';
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] FAVORITE: $message" . PHP_EOL;
    file_put_contents($logFile, $logMessage, FILE_APPEND | LOCK_EX);
}

// Проверяем авторизацию и получаем ID пользователя
$userId = requireAuth();
debugLog("Получен запрос от пользователя ID: $userId");

// Обрабатываем только методы POST и DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

$photoId = $input['photo_id'];

// Debug логирование
debugLog("Получен запрос с photo_id = " . print_r($photoId, true));
debugLog("Метод запроса = " . $_SERVER['REQUEST_METHOD']);

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();

    // Определяем, относится ли идентификатор к обычному фото или к коммерческому посту
    $realPhotoId = null;                 // id в таблице photos
    $isCommercial = false;               // флаг коммерческого поста
    $commercialPostId = null;            // id в таблице commercial_posts

    // Сначала пытаемся интерпретировать как коммерческий пост (чтобы избежать коллизий ID)
    if (is_numeric($photoId)) {
        $stmt = $db->prepare("SELECT id FROM commercial_posts WHERE id = :cp_id");
        $stmt->bindParam(':cp_id', $photoId);
        $stmt->execute();
        if ($row = $stmt->fetch()) {
            $isCommercial = true;
            $commercialPostId = (int)$row['id'];
            debugLog("Найден коммерческий пост с ID = " . $commercialPostId);
        } else {
            debugLog("Коммерческий пост с ID = " . $photoId . " НЕ найден");
        }
    }

    // Если это не коммерческий пост — ищем в таблице photos (по id или uuid)
    if (!$isCommercial) {
        if (is_numeric($photoId)) {
            $stmt = $db->prepare("SELECT id FROM photos WHERE id = :photo_id");
            $stmt->bindParam(':photo_id', $photoId);
            $stmt->execute();
            if ($row = $stmt->fetch()) {
                $realPhotoId = $row['id'];
            }
        } else if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $photoId)) {
            $stmt = $db->prepare("SELECT id FROM photos WHERE uuid = :photo_uuid");
            $stmt->bindParam(':photo_uuid', $photoId);
            $stmt->execute();
            if ($row = $stmt->fetch()) {
                $realPhotoId = $row['id'];
            }
        }

        if (!$realPhotoId) {
            handleError("Фотография/пост не найден", 404);
        }
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Добавление в избранное
        if ($isCommercial) {
            debugLog("Обрабатываем коммерческий пост ID = " . $commercialPostId . " для пользователя ID = " . $userId);
            
            // Создаем таблицу для избранного коммерческих постов при необходимости
            $db->exec("CREATE TABLE IF NOT EXISTS commercial_post_favorites (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                commercial_post_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_commercial_post_favorite (user_id, commercial_post_id),
                INDEX idx_commercial_post_favorites_user_id (user_id),
                INDEX idx_commercial_post_favorites_post_id (commercial_post_id),
                CONSTRAINT fk_commercial_post_favorites_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                CONSTRAINT fk_commercial_post_favorites_post FOREIGN KEY (commercial_post_id) REFERENCES commercial_posts(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

            // Проверяем существование
            $stmt = $db->prepare("SELECT id FROM commercial_post_favorites WHERE user_id = :user_id AND commercial_post_id = :cp_id");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':cp_id', $commercialPostId);
            $stmt->execute();
            if ($stmt->fetch()) {
                debugLog("Пост уже в избранном");
                echo json_encode([
                    'success' => true,
                    'message' => 'Пост уже в избранном',
                    'favoritesCount' => (int)$db->query("SELECT COUNT(*) FROM commercial_post_favorites WHERE commercial_post_id = ".$db->quote($commercialPostId))->fetchColumn(),
                    'debug_info' => [
                        'is_commercial' => true,
                        'commercial_post_id' => $commercialPostId
                    ]
                ]);
                exit;
            }

            // Вставляем
            debugLog("Вставляем новую запись в commercial_post_favorites");
            $stmt = $db->prepare("INSERT INTO commercial_post_favorites (user_id, commercial_post_id) VALUES (:user_id, :cp_id)");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':cp_id', $commercialPostId);
            $result = $stmt->execute();
            
            if ($result) {
                debugLog("Запись успешно добавлена");
            } else {
                debugLog("Ошибка при добавлении записи: " . print_r($stmt->errorInfo(), true));
            }

            // Счётчик
            $stmt = $db->prepare("SELECT COUNT(*) as favorites_count FROM commercial_post_favorites WHERE commercial_post_id = :cp_id");
            $stmt->bindParam(':cp_id', $commercialPostId);
            $stmt->execute();
            $favoritesCount = (int)$stmt->fetch()['favorites_count'];

            debugLog("Общее количество избранного для поста = " . $favoritesCount);

            echo json_encode([
                'success' => true,
                'message' => 'Коммерческий пост добавлен в избранное',
                'favoritesCount' => $favoritesCount,
                'debug_info' => [
                    'is_commercial' => true,
                    'commercial_post_id' => $commercialPostId
                ]
            ]);
        } else {
            // Обычное фото
            // Проверяем, существует ли уже в избранном
            $stmt = $db->prepare("SELECT id FROM favorites WHERE user_id = :user_id AND photo_id = :photo_id");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':photo_id', $realPhotoId);
            $stmt->execute();
            if ($stmt->fetch()) {
                echo json_encode([
                    'success' => true,
                    'message' => 'Фотография уже в избранном'
                ]);
                exit;
            }

            // Добавляем в избранное
            $stmt = $db->prepare("INSERT INTO favorites (user_id, photo_id) VALUES (:user_id, :photo_id)");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':photo_id', $realPhotoId);
            $stmt->execute();

            // Счётчик
            $stmt = $db->prepare("SELECT COUNT(*) as favorites_count FROM favorites WHERE photo_id = :photo_id");
            $stmt->bindParam(':photo_id', $realPhotoId);
            $stmt->execute();
            $favoritesCount = (int)$stmt->fetch()['favorites_count'];

            echo json_encode([
                'success' => true,
                'message' => 'Фотография добавлена в избранное',
                'favorite' => [
                    'userId' => $userId,
                    'photoId' => $photoId
                ],
                'favoritesCount' => $favoritesCount,
                'debug_info' => [
                    'photo_id_type' => gettype($photoId),
                    'photo_id_value' => $photoId,
                    'real_photo_id' => $realPhotoId
                ]
            ]);
        }
    } else if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        // Удаление из избранного
        if ($isCommercial) {
            // Таблица может отсутствовать — создадим на всякий случай
            $db->exec("CREATE TABLE IF NOT EXISTS commercial_post_favorites (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                commercial_post_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uq_commercial_post_favorite (user_id, commercial_post_id),
                INDEX idx_commercial_post_favorites_user_id (user_id),
                INDEX idx_commercial_post_favorites_post_id (commercial_post_id),
                CONSTRAINT fk_commercial_post_favorites_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                CONSTRAINT fk_commercial_post_favorites_post FOREIGN KEY (commercial_post_id) REFERENCES commercial_posts(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

            // Удаляем
            $stmt = $db->prepare("DELETE FROM commercial_post_favorites WHERE user_id = :user_id AND commercial_post_id = :cp_id");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':cp_id', $commercialPostId);
            $stmt->execute();
            $rowCount = $stmt->rowCount();

            // Счётчик
            $stmt = $db->prepare("SELECT COUNT(*) as favorites_count FROM commercial_post_favorites WHERE commercial_post_id = :cp_id");
            $stmt->bindParam(':cp_id', $commercialPostId);
            $stmt->execute();
            $favoritesCount = (int)$stmt->fetch()['favorites_count'];

            echo json_encode([
                'success' => true,
                'message' => $rowCount > 0 ? 'Коммерческий пост удален из избранного' : 'Коммерческий пост не найден в избранном',
                'favoritesCount' => $favoritesCount,
                'debug_info' => [
                    'is_commercial' => true,
                    'commercial_post_id' => $commercialPostId,
                    'rows_affected' => $rowCount
                ]
            ]);
        } else {
            // Обычное фото
            $stmt = $db->prepare("DELETE FROM favorites WHERE user_id = :user_id AND photo_id = :photo_id");
            $stmt->bindParam(':user_id', $userId);
            $stmt->bindParam(':photo_id', $realPhotoId);
            $stmt->execute();
            $rowCount = $stmt->rowCount();

            // Счётчик
            $stmt = $db->prepare("SELECT COUNT(*) as favorites_count FROM favorites WHERE photo_id = :photo_id");
            $stmt->bindParam(':photo_id', $realPhotoId);
            $stmt->execute();
            $favoritesCount = (int)$stmt->fetch()['favorites_count'];

            echo json_encode([
                'success' => true,
                'message' => $rowCount > 0 ? 'Фотография удалена из избранного' : 'Фотография не найдена в избранном',
                'favoritesCount' => $favoritesCount,
                'debug_info' => [
                    'photo_id_type' => gettype($photoId),
                    'photo_id_value' => $photoId,
                    'real_photo_id' => $realPhotoId,
                    'rows_affected' => $rowCount
                ]
            ]);
        }
    }
    
} catch (Exception $e) {
    handleError("Ошибка при работе с избранным: " . $e->getMessage(), 500);
} 