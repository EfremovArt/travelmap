<?php
// Включаем отображение ошибок для отладки
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();

echo "<h2>Тест удаления пользователя</h2>";

// Получаем список пользователей
echo "<h3>Список пользователей</h3>";
$stmt = $pdo->query("
    SELECT id, first_name, last_name, email, created_at
    FROM users
    ORDER BY id DESC
    LIMIT 10
");
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "<table border='1' cellpadding='5'>";
echo "<tr><th>ID</th><th>Имя</th><th>Email</th><th>Дата регистрации</th><th>Действия</th></tr>";
foreach ($users as $user) {
    echo "<tr>";
    echo "<td>{$user['id']}</td>";
    echo "<td>{$user['first_name']} {$user['last_name']}</td>";
    echo "<td>{$user['email']}</td>";
    echo "<td>{$user['created_at']}</td>";
    echo "<td>";
    echo "<form method='post' style='display:inline;' onsubmit='return confirm(\"Вы уверены?\");'>";
    echo "<input type='hidden' name='user_id' value='{$user['id']}'>";
    echo "<button type='submit' name='test_delete'>Удалить</button>";
    echo "</form>";
    echo " | ";
    echo "<form method='post' style='display:inline;'>";
    echo "<input type='hidden' name='check_user_id' value='{$user['id']}'>";
    echo "<button type='submit' name='check_relations'>Проверить связи</button>";
    echo "</form>";
    echo "</td>";
    echo "</tr>";
}
echo "</table>";

// Проверка связей пользователя
if (isset($_POST['check_relations'])) {
    $userId = intval($_POST['check_user_id']);
    
    echo "<h3>Связи пользователя ID: $userId</h3>";
    
    $tables = [
        'likes' => 'user_id',
        'album_likes' => 'user_id',
        'comments' => 'user_id',
        'album_comments' => 'user_id',
        'favorites' => 'user_id',
        'album_favorites' => 'user_id',
        'follows (follower)' => 'follower_id',
        'follows (following)' => 'following_id',
        'albums' => 'owner_id',
        'commercial_posts' => 'user_id',
        'photos' => 'user_id'
    ];
    
    echo "<table border='1' cellpadding='5'>";
    echo "<tr><th>Таблица</th><th>Количество записей</th></tr>";
    
    foreach ($tables as $table => $column) {
        $tableName = explode(' ', $table)[0];
        try {
            $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM {$tableName} WHERE {$column} = :user_id");
            $stmt->execute([':user_id' => $userId]);
            $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
            echo "<tr><td>{$table}</td><td>{$count}</td></tr>";
        } catch (Exception $e) {
            echo "<tr><td>{$table}</td><td style='color: red;'>Ошибка: {$e->getMessage()}</td></tr>";
        }
    }
    
    echo "</table>";
}

// Тестовое удаление
if (isset($_POST['test_delete'])) {
    $userId = intval($_POST['user_id']);
    
    echo "<h3>Попытка удаления пользователя ID: $userId</h3>";
    
    // Симулируем запрос к API
    $_POST['user_id'] = $userId;
    
    try {
        // Helper function to safely delete from table
        $safeDelete = function($table, $column, $userId) use ($pdo) {
            try {
                $stmt = $pdo->prepare("DELETE FROM {$table} WHERE {$column} = :user_id");
                $stmt->execute([':user_id' => $userId]);
                return $stmt->rowCount();
            } catch (Exception $e) {
                error_log("Warning: Could not delete from {$table}: " . $e->getMessage());
                echo "<p style='color: orange;'>⚠ {$table}: {$e->getMessage()}</p>";
                return 0;
            }
        };
        
        $pdo->beginTransaction();
        
        $deletedCounts = [];
        
        echo "<h4>Удаление связанных данных:</h4>";
        
        $deletedCounts['likes'] = $safeDelete('likes', 'user_id', $userId);
        echo "<p>✓ Likes: {$deletedCounts['likes']}</p>";
        
        $deletedCounts['album_likes'] = $safeDelete('album_likes', 'user_id', $userId);
        echo "<p>✓ Album likes: {$deletedCounts['album_likes']}</p>";
        
        $deletedCounts['comments'] = $safeDelete('comments', 'user_id', $userId);
        echo "<p>✓ Comments: {$deletedCounts['comments']}</p>";
        
        $deletedCounts['album_comments'] = $safeDelete('album_comments', 'user_id', $userId);
        echo "<p>✓ Album comments: {$deletedCounts['album_comments']}</p>";
        
        $deletedCounts['favorites'] = $safeDelete('favorites', 'user_id', $userId);
        echo "<p>✓ Favorites: {$deletedCounts['favorites']}</p>";
        
        $deletedCounts['album_favorites'] = $safeDelete('album_favorites', 'user_id', $userId);
        echo "<p>✓ Album favorites: {$deletedCounts['album_favorites']}</p>";
        
        $deletedCounts['follows_follower'] = $safeDelete('follows', 'follower_id', $userId);
        echo "<p>✓ Follows (follower): {$deletedCounts['follows_follower']}</p>";
        
        $deletedCounts['follows_following'] = $safeDelete('follows', 'following_id', $userId);
        echo "<p>✓ Follows (following): {$deletedCounts['follows_following']}</p>";
        
        try {
            $stmt = $pdo->prepare("
                DELETE ap FROM album_photos ap
                INNER JOIN albums a ON ap.album_id = a.id
                WHERE a.owner_id = :user_id
            ");
            $stmt->execute([':user_id' => $userId]);
            $deletedCounts['album_photos'] = $stmt->rowCount();
            echo "<p>✓ Album photos: {$deletedCounts['album_photos']}</p>";
        } catch (Exception $e) {
            echo "<p style='color: orange;'>⚠ Album photos: {$e->getMessage()}</p>";
            $deletedCounts['album_photos'] = 0;
        }
        
        $deletedCounts['albums'] = $safeDelete('albums', 'owner_id', $userId);
        echo "<p>✓ Albums: {$deletedCounts['albums']}</p>";
        
        try {
            $stmt = $pdo->prepare("
                DELETE pcp FROM photo_commercial_posts pcp
                INNER JOIN photos p ON pcp.photo_id = p.id
                WHERE p.user_id = :user_id
            ");
            $stmt->execute([':user_id' => $userId]);
            $deletedCounts['photo_commercial_posts'] = $stmt->rowCount();
            echo "<p>✓ Photo commercial posts: {$deletedCounts['photo_commercial_posts']}</p>";
        } catch (Exception $e) {
            echo "<p style='color: orange;'>⚠ Photo commercial posts: {$e->getMessage()}</p>";
            $deletedCounts['photo_commercial_posts'] = 0;
        }
        
        $deletedCounts['commercial_posts'] = $safeDelete('commercial_posts', 'user_id', $userId);
        echo "<p>✓ Commercial posts: {$deletedCounts['commercial_posts']}</p>";
        
        $deletedCounts['photos'] = $safeDelete('photos', 'user_id', $userId);
        echo "<p>✓ Photos: {$deletedCounts['photos']}</p>";
        
        $deletedCounts['notifications'] = $safeDelete('notifications', 'user_id', $userId);
        echo "<p>✓ Notifications: {$deletedCounts['notifications']}</p>";
        
        $deletedCounts['sessions'] = $safeDelete('sessions', 'user_id', $userId);
        echo "<p>✓ Sessions: {$deletedCounts['sessions']}</p>";
        
        // Delete user
        $stmt = $pdo->prepare("DELETE FROM users WHERE id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        
        if ($stmt->rowCount() === 0) {
            throw new Exception('Пользователь не найден');
        }
        
        $deletedCounts['user'] = 1;
        echo "<p style='color: green;'><strong>✓ User deleted: 1</strong></p>";
        
        $pdo->commit();
        
        $totalDeleted = array_sum($deletedCounts);
        echo "<p style='color: green; font-size: 18px;'><strong>✓ Успешно удалено! Всего записей: {$totalDeleted}</strong></p>";
        
        echo "<p><a href='test_delete_user.php'>← Обновить список</a></p>";
        
    } catch (Exception $e) {
        $pdo->rollBack();
        echo "<p style='color: red; font-size: 18px;'><strong>✗ Ошибка: {$e->getMessage()}</strong></p>";
        echo "<pre>" . $e->getTraceAsString() . "</pre>";
    }
}

echo "<hr>";
echo "<p><a href='views/users.php'>← Вернуться к списку пользователей</a></p>";
?>
