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
    
    $adminId = $_SESSION['admin_id'];
    $viewType = isset($_POST['view_type']) ? $_POST['view_type'] : '';
    
    if (!in_array($viewType, ['photos', 'comments'])) {
        throw new Exception('Неверный тип просмотра');
    }
    
    // Проверяем существование таблицы
    try {
        $pdo->query("SELECT 1 FROM admin_views LIMIT 1");
    } catch (Exception $e) {
        // Таблица не существует, создаем её
        $sql = "CREATE TABLE IF NOT EXISTS admin_views (
            id INT AUTO_INCREMENT PRIMARY KEY,
            admin_id INT NOT NULL,
            view_type ENUM('photos', 'comments') NOT NULL,
            last_viewed_at DATETIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_admin_view (admin_id, view_type),
            INDEX idx_admin_id (admin_id),
            INDEX idx_view_type (view_type)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        $pdo->exec($sql);
    }
    
    // Обновляем или вставляем запись
    $stmt = $pdo->prepare("
        INSERT INTO admin_views (admin_id, view_type, last_viewed_at)
        VALUES (:admin_id, :view_type, NOW())
        ON DUPLICATE KEY UPDATE last_viewed_at = NOW()
    ");
    
    $stmt->execute([
        ':admin_id' => $adminId,
        ':view_type' => $viewType
    ]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Просмотр отмечен'
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при отметке просмотра: ' . $e->getMessage()
    ]);
}
