<?php
require_once '../config.php';
initApi();

// Обработка запроса только методом POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    handleError("Метод не поддерживается", 405);
}

// Запускаем сессию
session_start();

// Очищаем все данные сессии
session_unset();
session_destroy();

// Отправляем успешный ответ
echo json_encode([
    'success' => true,
    'message' => 'Выход выполнен успешно'
]); 