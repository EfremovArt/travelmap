<?php
require_once '../config.php';
initApi();

// Проверяем авторизацию и получаем ID пользователя (для единообразия доступа)
$userId = requireAuth();

// Обрабатываем только GET запросы
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    handleError("Метод не поддерживается", 405);
}

try {
    $db = connectToDatabase();

    // Получаем максимальную дату создания среди всех фото
    $stmt = $db->prepare("SELECT MAX(created_at) as latest_created_at FROM photos");
    $stmt->execute();
    $row = $stmt->fetch();

    $latest = isset($row['latest_created_at']) ? $row['latest_created_at'] : null;

    echo json_encode([
        'success' => true,
        'message' => 'Последний created_at получен успешно',
        'latestCreatedAt' => $latest, // формат DATETIME (например, '2025-08-08 12:34:56')
    ]);
} catch (Exception $e) {
    handleError("Ошибка при получении последней даты: " . $e->getMessage(), 500);
}
