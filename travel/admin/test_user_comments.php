<?php
require_once 'config/admin_config.php';
require_once '../config.php';

// Укажите ID пользователя для проверки
$userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : 20;

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "=== Проверка комментариев пользователя ID: $userId ===\n\n";
    
    // 1. Общее количество комментариев пользователя
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM comments WHERE user_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $totalComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "1. Всего комментариев пользователя: $totalComments\n\n";
    
    // 2. Комментарии пользователя (написанные)
    $userCommentsSql = "
        SELECT c.id, c.comment as comment_text, c.created_at,
               p.id as post_id, p.title as post_title, p.file_path as post_image,
               p.user_id as post_owner_id,
               u.id as post_author_id, u.first_name as post_author_first_name, u.last_name as post_author_last_name
        FROM comments c
        JOIN photos p ON c.photo_id = p.id
        JOIN users u ON p.user_id = u.id
        WHERE c.user_id = :user_id
        ORDER BY c.created_at DESC
        LIMIT 50
    ";
    $stmt = $pdo->prepare($userCommentsSql);
    $stmt->execute([':user_id' => $userId]);
    $userComments = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "2. Комментарии пользователя (написанные): " . count($userComments) . "\n";
    foreach ($userComments as $comment) {
        echo "   - ID: {$comment['id']}, Текст: \"{$comment['comment_text']}\", К посту: \"{$comment['post_title']}\" (автор: {$comment['post_author_first_name']} {$comment['post_author_last_name']})\n";
    }
    echo "\n";
    
    // 3. Посты пользователя
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM photos WHERE user_id = :user_id");
    $stmt->execute([':user_id' => $userId]);
    $totalPosts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "3. Всего постов пользователя: $totalPosts\n\n";
    
    // 4. Комментарии к постам пользователя (от всех)
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM comments c
        JOIN photos p ON c.photo_id = p.id
        WHERE p.user_id = :user_id
    ");
    $stmt->execute([':user_id' => $userId]);
    $totalCommentsOnPosts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "4. Всего комментариев к постам пользователя: $totalCommentsOnPosts\n\n";
    
    // 5. Комментарии к постам пользователя (от других)
    $commentsOnUserPostsSql = "
        SELECT c.id, c.comment as comment_text, c.created_at,
               p.id as post_id, p.title as post_title, p.file_path as post_image,
               u.id as commenter_id, u.first_name as commenter_first_name, u.last_name as commenter_last_name,
               u.profile_image_url as commenter_profile_image
        FROM comments c
        JOIN photos p ON c.photo_id = p.id
        JOIN users u ON c.user_id = u.id
        WHERE p.user_id = :user_id AND c.user_id != :user_id
        ORDER BY c.created_at DESC
        LIMIT 50
    ";
    $stmt = $pdo->prepare($commentsOnUserPostsSql);
    $stmt->execute([':user_id' => $userId]);
    $commentsOnUserPosts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "5. Комментарии к постам пользователя (от других): " . count($commentsOnUserPosts) . "\n";
    foreach ($commentsOnUserPosts as $comment) {
        echo "   - ID: {$comment['id']}, От: {$comment['commenter_first_name']} {$comment['commenter_last_name']}, Текст: \"{$comment['comment_text']}\", К посту: \"{$comment['post_title']}\"\n";
    }
    echo "\n";
    
    // 6. Комментарии пользователя к своим же постам
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM comments c
        JOIN photos p ON c.photo_id = p.id
        WHERE p.user_id = :user_id AND c.user_id = :user_id
    ");
    $stmt->execute([':user_id' => $userId]);
    $selfComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "6. Комментарии пользователя к своим же постам: $selfComments\n\n";
    
    // 7. Проверка структуры данных
    echo "7. Структура данных комментариев:\n";
    if (count($userComments) > 0) {
        echo json_encode($userComments[0], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    } else {
        echo "   Нет комментариев для отображения\n";
    }
    
} catch (Exception $e) {
    echo "Ошибка: " . $e->getMessage() . "\n";
    echo "Файл: " . $e->getFile() . "\n";
    echo "Строка: " . $e->getLine() . "\n";
}
