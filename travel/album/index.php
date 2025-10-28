<?php
require_once __DIR__ . '/../config.php';

initApi();
$pdo = connectToDatabase();

function json_ok($data = []) {
  echo json_encode(array_merge(['success' => true], $data));
  exit;
}

function json_error($message, $code = 400, $extra = []) {
  http_response_code($code);
  echo json_encode(array_merge(['success' => false, 'message' => $message], $extra));
  exit;
}

function get_json_body() {
  $raw = file_get_contents('php://input');
  if (!$raw) return [];
  $data = json_decode($raw, true);
  return is_array($data) ? $data : [];
}

function get_param($key, $default = null) {
  if (isset($_GET[$key])) return $_GET[$key];
  if (isset($_POST[$key])) return $_POST[$key];
  $json = get_json_body();
  return isset($json[$key]) ? $json[$key] : $default;
}

function require_int($value, $name) {
  if ($value === null || $value === '' || !is_numeric($value)) {
    json_error("Invalid or missing $name", 422);
  }
  return (int)$value;
}

function paginate_params() {
  $page = max(1, (int)get_param('page', 1));
  $per = min(100, max(1, (int)get_param('per_page', 20)));
  $offset = ($page - 1) * $per;
  return [$page, $per, $offset];
}

$action = get_param('action', '');
$method = $_SERVER['REQUEST_METHOD'];
$override = isset($_POST['_method']) ? strtoupper($_POST['_method']) : (get_json_body()['_method'] ?? null);
if ($override) $method = $override;

// CRUD альбомов
if ($action === 'create' && $method === 'POST') {
  $userId = requireAuth();
  $title = trim((string)get_param('title', ''));
  $description = trim((string)get_param('description', ''));
  $isPublic = (int) get_param('is_public', 1);
  $coverPhotoId = get_param('cover_photo_id');
  $postIds = get_param('post_ids', []);
  if (!is_array($postIds)) $postIds = [];
  if ($title === '') json_error('Title is required', 422);

  // Логирование для отладки
  error_log("=== ALBUM CREATE DEBUG ===");
  error_log("User ID: $userId");
  error_log("Title: $title");
  error_log("Cover Photo ID (raw): " . var_export($coverPhotoId, true));
  error_log("Post IDs: " . json_encode($postIds));

  try {
    $pdo->beginTransaction();

    // Проверка принадлежности фото пользователю
    if (!empty($postIds)) {
      $in = str_repeat('?,', count($postIds) - 1) . '?';
      $stmt = $pdo->prepare("SELECT id FROM photos WHERE id IN ($in) AND user_id = ?");
      $params = array_map('intval', $postIds);
      $params[] = $userId;
      $stmt->execute($params);
      $owned = $stmt->fetchAll(PDO::FETCH_COLUMN);
      if (count($owned) !== count($postIds)) {
        $pdo->rollBack();
        json_error('Some photos do not belong to current user', 403);
      }
    }

    // Создание альбома
    $stmt = $pdo->prepare("INSERT INTO albums (owner_id, title, description, cover_photo_id, is_public) VALUES (?, ?, ?, ?, ?)");
    $coverIdInt = $coverPhotoId !== null && $coverPhotoId !== '' ? (int)$coverPhotoId : null;
    error_log("Cover ID converted to int: " . var_export($coverIdInt, true));
    $stmt->execute([$userId, $title, $description, $coverIdInt, $isPublic]);
    $albumId = (int)$pdo->lastInsertId();
    error_log("Album created with ID: $albumId");

    // Добавление фото
    if (!empty($postIds)) {
      $pos = 0;
      $stmt = $pdo->prepare("INSERT INTO album_photos (album_id, photo_id, position) VALUES (?, ?, ?)");
      foreach ($postIds as $pid) {
        $stmt->execute([$albumId, (int)$pid, $pos++]);
      }
      error_log("Added " . count($postIds) . " photos to album");
      
      // ИСПРАВЛЕННАЯ ЛОГИКА: Устанавливаем первое фото как обложку ТОЛЬКО если пользователь НЕ загрузил свою обложку
      if ($coverIdInt === null && !empty($postIds)) {
        error_log("No custom cover provided, using first post as cover: " . $postIds[0]);
        $pdo->prepare("UPDATE albums SET cover_photo_id = ? WHERE id = ?")->execute([(int)$postIds[0], $albumId]);
      } else if ($coverIdInt !== null) {
        error_log("Using custom uploaded cover: $coverIdInt");
      }
    } else if ($coverIdInt !== null) {
      // Случай когда загружена только обложка без постов
      error_log("Album created with custom cover only, no posts");
    }

    $pdo->commit();
    json_ok(['album_id' => $albumId]);
  } catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    json_error('Failed to create album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'update' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  $title = get_param('title');
  $description = get_param('description');
  $isPublic = get_param('is_public');
  $coverPhotoId = get_param('cover_photo_id');

  try {
    // Проверка владельца
    $stmt = $pdo->prepare("SELECT owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $owner = $stmt->fetchColumn();
    if (!$owner) json_error('Album not found', 404);
    if ((int)$owner !== (int)$userId) json_error('Forbidden', 403);

    $fields = [];
    $params = [];
    if ($title !== null) { $fields[] = 'title = ?'; $params[] = trim((string)$title); }
    if ($description !== null) { $fields[] = 'description = ?'; $params[] = trim((string)$description); }
    if ($isPublic !== null) { $fields[] = 'is_public = ?'; $params[] = (int)$isPublic; }
    if ($coverPhotoId !== null && $coverPhotoId !== '') { $fields[] = 'cover_photo_id = ?'; $params[] = (int)$coverPhotoId; }

    if (!empty($fields)) {
      $sql = 'UPDATE albums SET ' . implode(', ', $fields) . ' WHERE id = ?';
      $params[] = $albumId;
      $stmt = $pdo->prepare($sql);
      $stmt->execute($params);
    }

    json_ok(['album_id' => $albumId]);
  } catch (Throwable $e) {
    json_error('Failed to update album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'delete' && $method === 'DELETE') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("DELETE FROM albums WHERE id = ? AND owner_id = ?");
    $stmt->execute([$albumId, $userId]);
    if ($stmt->rowCount() === 0) json_error('Album not found or not owner', 404);
    json_ok(['deleted' => true]);
  } catch (Throwable $e) {
    json_error('Failed to delete album: ' . $e->getMessage(), 500);
  }
}

// Управление фото в альбоме
if ($action === 'add_photos' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  $postIds = get_param('post_ids', []);
  if (!is_array($postIds) || empty($postIds)) json_error('post_ids is required', 422);

  try {
    // Проверка владельца альбома
    $stmt = $pdo->prepare("SELECT owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $owner = $stmt->fetchColumn();
    if (!$owner) json_error('Album not found', 404);
    if ((int)$owner !== (int)$userId) json_error('Forbidden', 403);

    // Текущая максимальная позиция
    $stmt = $pdo->prepare("SELECT COALESCE(MAX(position), -1) FROM album_photos WHERE album_id = ?");
    $stmt->execute([$albumId]);
    $pos = (int)$stmt->fetchColumn() + 1;

    $insert = $pdo->prepare("INSERT IGNORE INTO album_photos (album_id, photo_id, position) VALUES (?, ?, ?)");
    foreach ($postIds as $pid) {
      $insert->execute([$albumId, (int)$pid, $pos++]);
    }

    json_ok(['album_id' => $albumId]);
  } catch (Throwable $e) {
    json_error('Failed to add photos: ' . $e->getMessage(), 500);
  }
}

if ($action === 'remove_photos' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  $postIds = get_param('post_ids', []);
  if (!is_array($postIds) || empty($postIds)) json_error('post_ids is required', 422);

  try {
    // Проверка существования альбома и получение владельца
    $stmt = $pdo->prepare("SELECT owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $albumOwner = $stmt->fetchColumn();
    if (!$albumOwner) json_error('Album not found', 404);
    
    $isAlbumOwner = ((int)$albumOwner === (int)$userId);
    
    // Если пользователь не владелец альбома, проверяем, что он может удалить только свои фотографии
    if (!$isAlbumOwner) {
      $in = str_repeat('?,', count($postIds) - 1) . '?';
      $params = array_map('intval', $postIds);
      $params[] = $userId;
      
      $stmt = $pdo->prepare("SELECT COUNT(*) FROM photos WHERE id IN ($in) AND user_id = ?");
      $stmt->execute($params);
      $ownedPhotosCount = $stmt->fetchColumn();
      
      if ($ownedPhotosCount !== count($postIds)) {
        json_error('You can only remove your own photos from others\' albums', 403);
      }
    }

    // Удаляем фотографии из альбома
    $in = str_repeat('?,', count($postIds) - 1) . '?';
    $params = array_map('intval', $postIds);
    array_unshift($params, $albumId);

    $stmt = $pdo->prepare("DELETE FROM album_photos WHERE album_id = ? AND photo_id IN ($in)");
    $stmt->execute($params);

    json_ok(['album_id' => $albumId, 'removed_photos' => $stmt->rowCount()]);
  } catch (Throwable $e) {
    json_error('Failed to remove photos: ' . $e->getMessage(), 500);
  }
}

if ($action === 'set_cover' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  $coverPhotoId = require_int(get_param('cover_photo_id'), 'cover_photo_id');

  try {
    // Проверка владельца
    $stmt = $pdo->prepare("SELECT owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $owner = $stmt->fetchColumn();
    if (!$owner) json_error('Album not found', 404);
    if ((int)$owner !== (int)$userId) json_error('Forbidden', 403);

    $pdo->prepare("UPDATE albums SET cover_photo_id = ? WHERE id = ?")->execute([$coverPhotoId, $albumId]);
    json_ok(['album_id' => $albumId]);
  } catch (Throwable $e) {
    json_error('Failed to set cover: ' . $e->getMessage(), 500);
  }
}

// Получение
if ($action === 'get_album' && $method === 'GET') {
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("SELECT a.*, u.first_name, u.last_name, u.profile_image_url, CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name FROM albums a JOIN users u ON u.id=a.owner_id WHERE a.id = ?");
    $stmt->execute([$albumId]);
    $album = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$album) json_error('Album not found', 404);

    // Получаем URL обложки, если она есть
    if ($album['cover_photo_id']) {
      $coverStmt = $pdo->prepare("SELECT file_path FROM photos WHERE id = ?");
      $coverStmt->execute([$album['cover_photo_id']]);
      $coverRow = $coverStmt->fetch(PDO::FETCH_ASSOC);
      if ($coverRow) {
        $album['cover_url'] = $coverRow['file_path'];
      }
    }

    $photosStmt = $pdo->prepare("SELECT p.id, p.user_id, p.location_id, p.file_path, p.original_file_path, p.title, p.description, p.created_at FROM album_photos ap JOIN photos p ON p.id=ap.photo_id WHERE ap.album_id = ? ORDER BY ap.position ASC, ap.id ASC");
    $photosStmt->execute([$albumId]);
    $photos = $photosStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Добавляем fallback для оригинальных изображений (обратная совместимость)
    foreach ($photos as &$photo) {
        if (empty($photo['original_file_path'])) {
            $photo['original_file_path'] = $photo['file_path'];
        }
    }
    unset($photo);

    // Подсчитываем количество уникальных постов (локаций)
    $uniqueLocations = [];
    foreach ($photos as $photo) {
        $locId = $photo['location_id'];
        if ($locId !== null && $locId !== '') {
            $uniqueLocations[$locId] = true;
        }
    }
    $postsCount = count($uniqueLocations);
    // Если нет location_id ни у одной фотографии, но есть фотографии, считаем как 1 пост (старые альбомы)
    if ($postsCount === 0 && count($photos) > 0) {
        $postsCount = 1;
    }

    // Likes count
    $likes = $pdo->prepare("SELECT COUNT(*) FROM album_likes WHERE album_id = ?");
    $likes->execute([$albumId]);
    $likesCount = (int)$likes->fetchColumn();

    json_ok(['album' => $album, 'photos' => $photos, 'likesCount' => $likesCount, 'postsCount' => $postsCount]);
  } catch (Throwable $e) {
    json_error('Failed to get album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'get_user_albums' && $method === 'GET') {
  $userId = require_int(get_param('user_id'), 'user_id');
  list($page, $per, $offset) = paginate_params();
  try {
    $stmt = $pdo->prepare("
      SELECT SQL_CALC_FOUND_ROWS 
        a.*, 
        (SELECT COUNT(*) FROM album_photos ap WHERE ap.album_id=a.id) AS photos_count, 
        CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name,
        u.first_name, u.last_name, u.profile_image_url,
        p.file_path AS cover_url
      FROM albums a 
      JOIN users u ON u.id=a.owner_id 
      LEFT JOIN photos p ON p.id=a.cover_photo_id
      WHERE a.owner_id = ? 
      ORDER BY a.updated_at DESC 
      LIMIT ? OFFSET ?
    ");
    $stmt->bindValue(1, $userId, PDO::PARAM_INT);
    $stmt->bindValue(2, $per, PDO::PARAM_INT);
    $stmt->bindValue(3, $offset, PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $total = (int)$pdo->query("SELECT FOUND_ROWS()")->fetchColumn();
    json_ok(['albums' => $rows, 'pagination' => ['total' => $total, 'perPage' => $per, 'currentPage' => $page, 'lastPage' => (int)ceil($total / $per)]]);
  } catch (Throwable $e) {
    json_error('Failed to get user albums: ' . $e->getMessage(), 500);
  }
}

if ($action === 'get_all_albums' && $method === 'GET') {
  list($page, $per, $offset) = paginate_params();
  try {
    $stmt = $pdo->prepare("
      SELECT SQL_CALC_FOUND_ROWS 
        a.*, 
        (SELECT COUNT(*) FROM album_photos ap WHERE ap.album_id=a.id) AS photos_count, 
        CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name,
        u.first_name, u.last_name, u.profile_image_url,
        p.file_path AS cover_url
      FROM albums a 
      JOIN users u ON u.id=a.owner_id 
      LEFT JOIN photos p ON p.id=a.cover_photo_id
      WHERE a.is_public=1 
      ORDER BY a.updated_at DESC 
      LIMIT ? OFFSET ?
    ");
    $stmt->bindValue(1, $per, PDO::PARAM_INT);
    $stmt->bindValue(2, $offset, PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $total = (int)$pdo->query("SELECT FOUND_ROWS()")->fetchColumn();
    json_ok(['albums' => $rows, 'pagination' => ['total' => $total, 'perPage' => $per, 'currentPage' => $page, 'lastPage' => (int)ceil($total / $per)]]);
  } catch (Throwable $e) {
    json_error('Failed to get albums: ' . $e->getMessage(), 500);
  }
}

// Лайки альбомов
if ($action === 'like' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("INSERT IGNORE INTO album_likes (user_id, album_id) VALUES (?, ?)");
    $stmt->execute([$userId, $albumId]);
    json_ok();
  } catch (Throwable $e) {
    json_error('Failed to like album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'unlike' && $method === 'DELETE') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("DELETE FROM album_likes WHERE user_id = ? AND album_id = ?");
    $stmt->execute([$userId, $albumId]);
    json_ok();
  } catch (Throwable $e) {
    json_error('Failed to unlike album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'check_like' && $method === 'GET') {
  $albumId = require_int(get_param('album_id'), 'album_id');
  $currentUser = checkAuth();
  $userId = $currentUser ? $currentUser['id'] : null;
  try {
    $countStmt = $pdo->prepare("SELECT COUNT(*) FROM album_likes WHERE album_id = ?");
    $countStmt->execute([$albumId]);
    $likesCount = (int)$countStmt->fetchColumn();

    $isLiked = false;
    if ($userId) {
      $stmt = $pdo->prepare("SELECT 1 FROM album_likes WHERE user_id = ? AND album_id = ? LIMIT 1");
      $stmt->execute([$userId, $albumId]);
      $isLiked = (bool)$stmt->fetchColumn();
    }

    json_ok(['likesCount' => $likesCount, 'isLiked' => $isLiked]);
  } catch (Throwable $e) {
    json_error('Failed to check like: ' . $e->getMessage(), 500);
  }
}

if ($action === 'get_likes' && $method === 'GET') {
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("SELECT al.user_id, u.first_name, u.last_name, u.profile_image_url, CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name FROM album_likes al JOIN users u ON u.id=al.user_id WHERE al.album_id = ? ORDER BY al.created_at DESC");
    $stmt->execute([$albumId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    json_ok(['likes' => $rows]);
  } catch (Throwable $e) {
    json_error('Failed to get likes: ' . $e->getMessage(), 500);
  }
}

// Избранное альбомов
if ($action === 'favorite' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("INSERT IGNORE INTO album_favorites (user_id, album_id) VALUES (?, ?)");
    $stmt->execute([$userId, $albumId]);
    json_ok();
  } catch (Throwable $e) {
    json_error('Failed to favorite album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'unfavorite' && $method === 'DELETE') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("DELETE FROM album_favorites WHERE user_id = ? AND album_id = ?");
    $stmt->execute([$userId, $albumId]);
    json_ok();
  } catch (Throwable $e) {
    json_error('Failed to unfavorite album: ' . $e->getMessage(), 500);
  }
}

if ($action === 'check_favorite' && $method === 'GET') {
  $albumId = require_int(get_param('album_id'), 'album_id');
  $currentUser = checkAuth();
  $userId = $currentUser ? $currentUser['id'] : null;
  try {
    $countStmt = $pdo->prepare("SELECT COUNT(*) FROM album_favorites WHERE album_id = ?");
    $countStmt->execute([$albumId]);
    $favoritesCount = (int)$countStmt->fetchColumn();

    $isFavorite = false;
    if ($userId) {
      $stmt = $pdo->prepare("SELECT 1 FROM album_favorites WHERE user_id = ? AND album_id = ? LIMIT 1");
      $stmt->execute([$userId, $albumId]);
      $isFavorite = (bool)$stmt->fetchColumn();
    }

    json_ok(['favoritesCount' => $favoritesCount, 'isFavorite' => $isFavorite]);
  } catch (Throwable $e) {
    json_error('Failed to check favorite: ' . $e->getMessage(), 500);
  }
}

if ($action === 'get_favorites' && $method === 'GET') {
  $albumId = require_int(get_param('album_id'), 'album_id');
  try {
    $stmt = $pdo->prepare("SELECT af.user_id, u.first_name, u.last_name, u.profile_image_url, CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name FROM album_favorites af JOIN users u ON u.id=af.user_id WHERE af.album_id = ? ORDER BY af.created_at DESC");
    $stmt->execute([$albumId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    json_ok(['favorites' => $rows]);
  } catch (Throwable $e) {
    json_error('Failed to get favorites: ' . $e->getMessage(), 500);
  }
}

// Комментарии к альбомам
if ($action === 'comment' && $method === 'POST') {
  $userId = requireAuth();
  $albumId = require_int(get_param('album_id'), 'album_id');
  $comment = trim((string)get_param('comment', ''));
  if ($comment === '') json_error('Comment is required', 422);
  try {
    $stmt = $pdo->prepare("INSERT INTO album_comments (user_id, album_id, comment) VALUES (?, ?, ?)");
    $stmt->execute([$userId, $albumId, $comment]);
    json_ok(['comment_id' => (int)$pdo->lastInsertId()]);
  } catch (Throwable $e) {
    json_error('Failed to add comment: ' . $e->getMessage(), 500);
  }
}

if ($action === 'get_comments' && $method === 'GET') {
  $albumId = require_int(get_param('album_id'), 'album_id');
  list($page, $per, $offset) = paginate_params();
  try {
    $stmt = $pdo->prepare("SELECT SQL_CALC_FOUND_ROWS ac.*, u.first_name, u.last_name, u.profile_image_url, CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS author_name FROM album_comments ac JOIN users u ON u.id=ac.user_id WHERE ac.album_id = ? ORDER BY ac.created_at DESC LIMIT ? OFFSET ?");
    $stmt->bindValue(1, $albumId, PDO::PARAM_INT);
    $stmt->bindValue(2, $per, PDO::PARAM_INT);
    $stmt->bindValue(3, $offset, PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $total = (int)$pdo->query("SELECT FOUND_ROWS()")->fetchColumn();
    json_ok(['comments' => $rows, 'pagination' => ['total' => $total, 'perPage' => $per, 'currentPage' => $page, 'lastPage' => (int)ceil($total / $per)]]);
  } catch (Throwable $e) {
    json_error('Failed to get comments: ' . $e->getMessage(), 500);
  }
}

if ($action === 'delete_comment' && $method === 'DELETE') {
  $userId = requireAuth();
  $commentId = require_int(get_param('comment_id'), 'comment_id');
  try {
    // Разрешаем удалять автору комментария или владельцу альбома
    $stmt = $pdo->prepare("SELECT user_id, album_id FROM album_comments WHERE id = ?");
    $stmt->execute([$commentId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) json_error('Comment not found', 404);

    $authorId = (int)$row['user_id'];
    $albumId = (int)$row['album_id'];

    $stmt = $pdo->prepare("SELECT owner_id FROM albums WHERE id = ?");
    $stmt->execute([$albumId]);
    $ownerId = (int)$stmt->fetchColumn();

    if ($authorId !== (int)$userId && $ownerId !== (int)$userId) json_error('Forbidden', 403);

    $del = $pdo->prepare("DELETE FROM album_comments WHERE id = ?");
    $del->execute([$commentId]);
    json_ok(['deleted' => true]);
  } catch (Throwable $e) {
    json_error('Failed to delete comment: ' . $e->getMessage(), 500);
  }
}

// Если действие не распознано
json_error('Unknown action', 404);
