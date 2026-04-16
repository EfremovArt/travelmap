<?php
session_start();
require_once 'config/admin_config.php';
require_once '../config.php';

// Check if user is authenticated
if (!isset($_SESSION['admin_id'])) {
    header('Location: /travel/admin/login.php');
    exit;
}

$pdo = connectToDatabase();
$adminId = $_SESSION['admin_id'];

// Получаем последний просмотр комментариев
$lastCommentView = null;
try {
    $stmt = $pdo->prepare("SELECT last_viewed_at FROM admin_views WHERE admin_id = :admin_id AND view_type = 'comments'");
    $stmt->execute([':admin_id' => $adminId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result) {
        $lastCommentView = $result['last_viewed_at'];
    }
} catch (Exception $e) {
    $lastCommentView = 'Таблица не существует';
}

// Считаем комментарии
$photoComments = 0;
$albumComments = 0;
$newPhotoComments = 0;
$newAlbumComments = 0;

// Всего комментариев к фото
$stmt = $pdo->query("SELECT COUNT(*) as count FROM comments");
$photoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

// Всего комментариев к альбомам
$stmt = $pdo->query("SELECT COUNT(*) as count FROM album_comments");
$albumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

// Новые комментарии к фото
if ($lastCommentView && $lastCommentView !== 'Таблица не существует') {
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM comments WHERE created_at > :last_view");
    $stmt->execute([':last_view' => $lastCommentView]);
    $newPhotoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM album_comments WHERE created_at > :last_view");
    $stmt->execute([':last_view' => $lastCommentView]);
    $newAlbumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
} else {
    // За последние 24 часа
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM comments WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)");
    $newPhotoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM album_comments WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)");
    $newAlbumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
}

// Последние 5 комментариев к фото
$stmt = $pdo->query("SELECT id, photo_id, comment, created_at FROM comments ORDER BY created_at DESC LIMIT 5");
$recentPhotoComments = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Последние 5 комментариев к альбомам
$stmt = $pdo->query("SELECT id, album_id, comment, created_at FROM album_comments ORDER BY created_at DESC LIMIT 5");
$recentAlbumComments = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Тест счетчика комментариев</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-5">
        <h1>Тест счетчика комментариев</h1>
        
        <div class="alert alert-info">
            <strong>Последний просмотр комментариев:</strong> 
            <?php echo $lastCommentView ?: 'Никогда'; ?>
        </div>
        
        <div class="row">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <h5>Комментарии к фото</h5>
                    </div>
                    <div class="card-body">
                        <p><strong>Всего:</strong> <?php echo $photoComments; ?></p>
                        <p><strong>Новых:</strong> <span class="badge bg-danger"><?php echo $newPhotoComments; ?></span></p>
                        
                        <h6 class="mt-3">Последние 5:</h6>
                        <ul class="list-group">
                            <?php foreach ($recentPhotoComments as $comment): ?>
                                <li class="list-group-item">
                                    <small class="text-muted"><?php echo $comment['created_at']; ?></small><br>
                                    Photo ID: <?php echo $comment['photo_id']; ?><br>
                                    <?php echo htmlspecialchars(substr($comment['comment'], 0, 50)); ?>...
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                </div>
            </div>
            
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-success text-white">
                        <h5>Комментарии к альбомам</h5>
                    </div>
                    <div class="card-body">
                        <p><strong>Всего:</strong> <?php echo $albumComments; ?></p>
                        <p><strong>Новых:</strong> <span class="badge bg-danger"><?php echo $newAlbumComments; ?></span></p>
                        
                        <h6 class="mt-3">Последние 5:</h6>
                        <ul class="list-group">
                            <?php foreach ($recentAlbumComments as $comment): ?>
                                <li class="list-group-item">
                                    <small class="text-muted"><?php echo $comment['created_at']; ?></small><br>
                                    Album ID: <?php echo $comment['album_id']; ?><br>
                                    <?php echo htmlspecialchars(substr($comment['comment'], 0, 50)); ?>...
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="card mt-4">
            <div class="card-header bg-warning">
                <h5>Итого новых комментариев</h5>
            </div>
            <div class="card-body">
                <h2><?php echo $newPhotoComments + $newAlbumComments; ?></h2>
                <p>Это число должно отображаться на колокольчике уведомлений</p>
            </div>
        </div>
        
        <div class="mt-4">
            <a href="test_notifications_api.php" class="btn btn-primary">Тест API уведомлений</a>
            <a href="views/moderation.php#comments" class="btn btn-success">Открыть модерацию комментариев</a>
            <button class="btn btn-secondary" onclick="location.reload()">Обновить</button>
        </div>
    </div>
</body>
</html>
