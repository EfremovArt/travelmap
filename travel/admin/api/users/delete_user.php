<?php
error_reporting(0);
ini_set('display_errors', 0);

require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    if (!$pdo) {
        throw new Exception('Не удалось подключиться к базе данных');
    }
    
    // Get user ID from request
    $userId = isset($_POST['user_id']) ? intval($_POST['user_id']) : 0;
    
    if ($userId <= 0) {
        throw new Exception('Неверный ID пользователя');
    }
    
    // Helper function to safely delete from table
    $safeDelete = function($table, $column, $userId) use ($pdo) {
        try {
            $stmt = $pdo->prepare("DELETE FROM {$table} WHERE {$column} = :user_id");
            $stmt->execute([':user_id' => $userId]);
            return $stmt->rowCount();
        } catch (Exception $e) {
            // Table might not exist or have different structure, log but continue
            error_log("Warning: Could not delete from {$table}: " . $e->getMessage());
            return 0;
        }
    };
    
    // Start transaction
    $pdo->beginTransaction();
    
    try {
        $deletedCounts = [];
        
        // Delete user's likes
        $deletedCounts['likes'] = $safeDelete('likes', 'user_id', $userId);
        
        // Delete user's album likes
        $deletedCounts['album_likes'] = $safeDelete('album_likes', 'user_id', $userId);
        
        // Delete user's comments
        $deletedCounts['comments'] = $safeDelete('comments', 'user_id', $userId);
        
        // Delete user's album comments
        $deletedCounts['album_comments'] = $safeDelete('album_comments', 'user_id', $userId);
        
        // Delete user's favorites
        $deletedCounts['favorites'] = $safeDelete('favorites', 'user_id', $userId);
        
        // Delete user's album favorites
        $deletedCounts['album_favorites'] = $safeDelete('album_favorites', 'user_id', $userId);
        
        // Delete user's follows (as follower)
        $deletedCounts['follows_follower'] = $safeDelete('follows', 'follower_id', $userId);
        
        // Delete user's follows (as following)
        $deletedCounts['follows_following'] = $safeDelete('follows', 'following_id', $userId);
        
        // Delete album photos for user's albums
        try {
            $stmt = $pdo->prepare("
                DELETE ap FROM album_photos ap
                INNER JOIN albums a ON ap.album_id = a.id
                WHERE a.owner_id = :user_id
            ");
            $stmt->execute([':user_id' => $userId]);
            $deletedCounts['album_photos'] = $stmt->rowCount();
        } catch (Exception $e) {
            error_log("Warning: Could not delete album_photos: " . $e->getMessage());
            $deletedCounts['album_photos'] = 0;
        }
        
        // Delete user's albums
        $deletedCounts['albums'] = $safeDelete('albums', 'owner_id', $userId);
        
        // Delete photo_commercial_posts links
        try {
            $stmt = $pdo->prepare("
                DELETE pcp FROM photo_commercial_posts pcp
                INNER JOIN photos p ON pcp.photo_id = p.id
                WHERE p.user_id = :user_id
            ");
            $stmt->execute([':user_id' => $userId]);
            $deletedCounts['photo_commercial_posts'] = $stmt->rowCount();
        } catch (Exception $e) {
            error_log("Warning: Could not delete photo_commercial_posts: " . $e->getMessage());
            $deletedCounts['photo_commercial_posts'] = 0;
        }
        
        // Delete user's commercial posts
        $deletedCounts['commercial_posts'] = $safeDelete('commercial_posts', 'user_id', $userId);
        
        // Delete user's photos
        $deletedCounts['photos'] = $safeDelete('photos', 'user_id', $userId);
        
        // Delete user's notifications
        $deletedCounts['notifications'] = $safeDelete('notifications', 'user_id', $userId);
        
        // Delete user's sessions
        $deletedCounts['sessions'] = $safeDelete('sessions', 'user_id', $userId);
        
        // Finally, delete the user
        try {
            $stmt = $pdo->prepare("DELETE FROM users WHERE id = :user_id");
            $stmt->execute([':user_id' => $userId]);
            
            if ($stmt->rowCount() === 0) {
                throw new Exception('Пользователь не найден');
            }
            
            $deletedCounts['user'] = 1;
        } catch (Exception $e) {
            throw new Exception('Не удалось удалить пользователя: ' . $e->getMessage());
        }
        
        // Commit transaction
        $pdo->commit();
        
        // Calculate total deleted items
        $totalDeleted = array_sum($deletedCounts);
        
        echo json_encode([
            'success' => true,
            'message' => 'Пользователь успешно удален',
            'deleted_counts' => $deletedCounts,
            'total_deleted' => $totalDeleted
        ]);
        
    } catch (Exception $e) {
        // Rollback transaction on error
        $pdo->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при удалении пользователя: ' . $e->getMessage()
    ]);
}
