<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID текущего пользователя
$userId = requireAuth();

// Обработка запроса методами DELETE или POST
if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Получаем данные из запроса
$input = json_decode(file_get_contents('php://input'), true);

// Проверяем наличие необходимых данных
if (!isset($input['photo_id'])) {
    handleError("Отсутствует обязательное поле: photo_id", 400);
}

$photoId = intval($input['photo_id']);

try {
    // Подключаемся к базе данных
    $db = connectToDatabase();
    
    // Проверяем, существует ли фотография и принадлежит ли она текущему пользователю
    $stmt = $db->prepare("
        SELECT id, user_id, file_path, title FROM photos 
        WHERE id = :photo_id AND user_id = :user_id
    ");
    $stmt->bindParam(':photo_id', $photoId);
    $stmt->bindParam(':user_id', $userId);
    $stmt->execute();
    
    $photo = $stmt->fetch();
    
    if (!$photo) {
        handleError("Указанная фотография не найдена или не принадлежит текущему пользователю", 404);
    }
    
    // Начинаем транзакцию для атомарности операции
    $db->beginTransaction();
    
    try {
        // Удаляем связанные данные
        
        // Удаляем лайки
        $stmt = $db->prepare("DELETE FROM likes WHERE photo_id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        $deletedLikes = $stmt->rowCount();
        
        // Удаляем из избранного
        $stmt = $db->prepare("DELETE FROM favorites WHERE photo_id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        $deletedFavorites = $stmt->rowCount();
        
        // Удаляем комментарии
        $stmt = $db->prepare("DELETE FROM comments WHERE photo_id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        $deletedComments = $stmt->rowCount();
        
        // Удаляем из альбомов
        $stmt = $db->prepare("DELETE FROM album_photos WHERE photo_id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        $deletedFromAlbums = $stmt->rowCount();
        
        // Проверяем, используется ли фотография как обложка альбомов
        $stmt = $db->prepare("UPDATE albums SET cover_photo_id = NULL WHERE cover_photo_id = :photo_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->execute();
        $updatedAlbumCovers = $stmt->rowCount();
        
        // Удаляем саму фотографию
        $stmt = $db->prepare("DELETE FROM photos WHERE id = :photo_id AND user_id = :user_id");
        $stmt->bindParam(':photo_id', $photoId);
        $stmt->bindParam(':user_id', $userId);
        $stmt->execute();
        
        if ($stmt->rowCount() === 0) {
            throw new Exception('Не удалось удалить фотографию из базы данных');
        }
        
        // Подтверждаем транзакцию
        $db->commit();
        
        // Удаляем файл с диска
        $filePath = $_SERVER['DOCUMENT_ROOT'] . $photo['file_path'];
        $fileDeleted = false;
        if (file_exists($filePath)) {
            $fileDeleted = unlink($filePath);
            if (!$fileDeleted) {
                error_log("Warning: Could not delete file: $filePath");
            }
        }
        
        // Отправляем успешный ответ
        echo json_encode([
            'success' => true,
            'message' => 'Фотография удалена успешно',
            'deleted_data' => [
                'photo_id' => $photoId,
                'likes_deleted' => $deletedLikes,
                'favorites_deleted' => $deletedFavorites,
                'comments_deleted' => $deletedComments,
                'removed_from_albums' => $deletedFromAlbums,
                'album_covers_updated' => $updatedAlbumCovers,
                'file_deleted' => $fileDeleted,
                'file_path' => $photo['file_path']
            ]
        ]);
        
    } catch (Exception $e) {
        // Откатываем транзакцию при ошибке
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Error in delete_photo.php: " . $e->getMessage());
    handleError("Ошибка при удалении фотографии: " . $e->getMessage(), 500);
}
