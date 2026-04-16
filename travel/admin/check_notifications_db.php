<?php
session_start();
require_once 'config/admin_config.php';
require_once '../config.php';

// Check if user is authenticated
if (!isset($_SESSION['admin_id'])) {
    die('Not authenticated');
}

header('Content-Type: text/plain; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    echo "=== ПРОВЕРКА БАЗЫ ДАННЫХ ===\n\n";
    
    // Проверка таблицы photos
    echo "1. Фотографии:\n";
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM photos");
    $total = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    echo "   Всего фото: $total\n";
    
    $stmt = $pdo->query("SELECT COUNT(*) as pending FROM photos WHERE moderation_status IS NULL OR moderation_status = 'pending'");
    $pending = $stmt->fetch(PDO::FETCH_ASSOC)['pending'];
    echo "   На модерации: $pending\n";
    
    $stmt = $pdo->query("SELECT COUNT(*) as approved FROM photos WHERE moderation_status = 'approved'");
    $approved = $stmt->fetch(PDO::FETCH_ASSOC)['approved'];
    echo "   Одобрено: $approved\n";
    
    // Последние 5 фото
    echo "\n   Последние 5 фото:\n";
    $stmt = $pdo->query("SELECT id, title, moderation_status, created_at FROM photos ORDER BY created_at DESC LIMIT 5");
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "   - ID: {$row['id']}, Status: {$row['moderation_status']}, Created: {$row['created_at']}\n";
    }
    
    // Проверка таблицы comments
    echo "\n2. Комментарии:\n";
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM comments");
    $total = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
    echo "   Всего комментариев: $total\n";
    
    // Последние 5 комментариев
    echo "\n   Последние 5 комментариев:\n";
    $stmt = $pdo->query("SELECT id, photo_id, created_at FROM comments ORDER BY created_at DESC LIMIT 5");
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "   - ID: {$row['id']}, Photo ID: {$row['photo_id']}, Created: {$row['created_at']}\n";
    }
    
    // Проверка таблицы admin_views
    echo "\n3. Просмотры админа:\n";
    $adminId = $_SESSION['admin_id'];
    
    try {
        $stmt = $pdo->prepare("SELECT * FROM admin_views WHERE admin_id = :admin_id");
        $stmt->execute([':admin_id' => $adminId]);
        $views = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (empty($views)) {
            echo "   Нет записей о просмотрах\n";
        } else {
            foreach ($views as $view) {
                echo "   - Type: {$view['view_type']}, Last viewed: {$view['last_viewed_at']}\n";
            }
        }
    } catch (Exception $e) {
        echo "   Таблица admin_views не существует или ошибка: " . $e->getMessage() . "\n";
    }
    
    echo "\n=== КОНЕЦ ПРОВЕРКИ ===\n";
    
} catch (Exception $e) {
    echo "ОШИБКА: " . $e->getMessage() . "\n";
}
