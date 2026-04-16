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
$message = '';
$error = '';

// Получаем последнее фото
$stmt = $pdo->query("SELECT id, title, user_id FROM photos ORDER BY created_at DESC LIMIT 1");
$lastPhoto = $stmt->fetch(PDO::FETCH_ASSOC);

// Получаем последний альбом
$stmt = $pdo->query("SELECT id, title, owner_id FROM albums ORDER BY created_at DESC LIMIT 1");
$lastAlbum = $stmt->fetch(PDO::FETCH_ASSOC);

// Получаем первого пользователя (для теста)
$stmt = $pdo->query("SELECT id, first_name, last_name FROM users ORDER BY id ASC LIMIT 1");
$testUser = $stmt->fetch(PDO::FETCH_ASSOC);

// Обработка формы
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $commentText = trim($_POST['comment'] ?? '');
    $commentType = $_POST['type'] ?? 'photo';
    
    if (empty($commentText)) {
        $error = 'Введите текст комментария';
    } else {
        try {
            if ($commentType === 'photo' && $lastPhoto) {
                $stmt = $pdo->prepare("
                    INSERT INTO comments (photo_id, user_id, comment, created_at) 
                    VALUES (:photo_id, :user_id, :comment, NOW())
                ");
                $stmt->execute([
                    ':photo_id' => $lastPhoto['id'],
                    ':user_id' => $testUser['id'],
                    ':comment' => $commentText
                ]);
                $message = "Комментарий добавлен к фото ID: {$lastPhoto['id']}";
            } elseif ($commentType === 'album' && $lastAlbum) {
                $stmt = $pdo->prepare("
                    INSERT INTO album_comments (album_id, user_id, comment, created_at) 
                    VALUES (:album_id, :user_id, :comment, NOW())
                ");
                $stmt->execute([
                    ':album_id' => $lastAlbum['id'],
                    ':user_id' => $testUser['id'],
                    ':comment' => $commentText
                ]);
                $message = "Комментарий добавлен к альбому ID: {$lastAlbum['id']}";
            } else {
                $error = 'Не найдено фото или альбом для комментария';
            }
        } catch (Exception $e) {
            $error = 'Ошибка: ' . $e->getMessage();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Добавить тестовый комментарий</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-5">
        <h1><i class="bi bi-chat-dots"></i> Добавить тестовый комментарий</h1>
        
        <?php if ($message): ?>
            <div class="alert alert-success alert-dismissible fade show">
                <i class="bi bi-check-circle"></i> <?php echo $message; ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        <?php endif; ?>
        
        <?php if ($error): ?>
            <div class="alert alert-danger alert-dismissible fade show">
                <i class="bi bi-exclamation-triangle"></i> <?php echo $error; ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            </div>
        <?php endif; ?>
        
        <div class="row">
            <div class="col-md-6">
                <div class="card mb-4">
                    <div class="card-header bg-primary text-white">
                        <h5><i class="bi bi-image"></i> Последнее фото</h5>
                    </div>
                    <div class="card-body">
                        <?php if ($lastPhoto): ?>
                            <p><strong>ID:</strong> <?php echo $lastPhoto['id']; ?></p>
                            <p><strong>Название:</strong> <?php echo htmlspecialchars($lastPhoto['title'] ?: 'Без названия'); ?></p>
                            <p><strong>User ID:</strong> <?php echo $lastPhoto['user_id']; ?></p>
                        <?php else: ?>
                            <p class="text-muted">Нет фото в базе</p>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
            
            <div class="col-md-6">
                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5><i class="bi bi-collection"></i> Последний альбом</h5>
                    </div>
                    <div class="card-body">
                        <?php if ($lastAlbum): ?>
                            <p><strong>ID:</strong> <?php echo $lastAlbum['id']; ?></p>
                            <p><strong>Название:</strong> <?php echo htmlspecialchars($lastAlbum['title'] ?: 'Без названия'); ?></p>
                            <p><strong>Owner ID:</strong> <?php echo $lastAlbum['owner_id']; ?></p>
                        <?php else: ?>
                            <p class="text-muted">Нет альбомов в базе</p>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <div class="card-header bg-warning">
                <h5><i class="bi bi-pencil"></i> Добавить комментарий</h5>
            </div>
            <div class="card-body">
                <form method="POST">
                    <div class="mb-3">
                        <label class="form-label">Тип комментария</label>
                        <div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="radio" name="type" id="typePhoto" value="photo" checked <?php echo !$lastPhoto ? 'disabled' : ''; ?>>
                                <label class="form-check-label" for="typePhoto">
                                    К фото <?php echo !$lastPhoto ? '(нет фото)' : ''; ?>
                                </label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="radio" name="type" id="typeAlbum" value="album" <?php echo !$lastAlbum ? 'disabled' : ''; ?>>
                                <label class="form-check-label" for="typeAlbum">
                                    К альбому <?php echo !$lastAlbum ? '(нет альбомов)' : ''; ?>
                                </label>
                            </div>
                        </div>
                    </div>
                    
                    <div class="mb-3">
                        <label for="comment" class="form-label">Текст комментария</label>
                        <textarea class="form-control" id="comment" name="comment" rows="3" required placeholder="Введите текст комментария..."></textarea>
                        <small class="text-muted">От пользователя: <?php echo htmlspecialchars($testUser['first_name'] . ' ' . $testUser['last_name']); ?> (ID: <?php echo $testUser['id']; ?>)</small>
                    </div>
                    
                    <button type="submit" class="btn btn-primary">
                        <i class="bi bi-send"></i> Добавить комментарий
                    </button>
                    
                    <button type="button" class="btn btn-secondary" onclick="fillTestComment()">
                        <i class="bi bi-lightning"></i> Заполнить тестовым текстом
                    </button>
                </form>
            </div>
        </div>
        
        <div class="mt-4">
            <a href="test_notifications_api.php" class="btn btn-info">
                <i class="bi bi-bell"></i> Проверить уведомления
            </a>
            <a href="test_comments_count.php" class="btn btn-success">
                <i class="bi bi-chat-dots"></i> Статистика комментариев
            </a>
            <a href="views/moderation.php#comments" class="btn btn-warning">
                <i class="bi bi-eye"></i> Открыть модерацию
            </a>
        </div>
        
        <div class="alert alert-info mt-4">
            <h6><i class="bi bi-info-circle"></i> Как проверить уведомления:</h6>
            <ol>
                <li>Добавьте комментарий через эту форму</li>
                <li>Подождите до 10 секунд</li>
                <li>Посмотрите на колокольчик в верхнем меню - должно появиться уведомление</li>
                <li>Или нажмите "Проверить уведомления" для мгновенной проверки</li>
            </ol>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function fillTestComment() {
            const comments = [
                'Отличное фото! 👍',
                'Красивое место! Где это?',
                'Супер! Хочу туда съездить!',
                'Какая красота! 😍',
                'Тестовый комментарий для проверки уведомлений'
            ];
            const randomComment = comments[Math.floor(Math.random() * comments.length)];
            document.getElementById('comment').value = randomComment;
        }
        
        // Автоматически заполнить при загрузке
        <?php if (!$message && !$error): ?>
        fillTestComment();
        <?php endif; ?>
    </script>
</body>
</html>
