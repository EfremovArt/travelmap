<?php
// Временный файл для отладки - показывает что приходит от приложения
header('Content-Type: application/json; charset=UTF-8');

// Логируем все что приходит
$logFile = __DIR__ . '/request_debug.log';

$debugInfo = [
    'timestamp' => date('Y-m-d H:i:s'),
    'method' => $_SERVER['REQUEST_METHOD'],
    'headers' => getallheaders(),
    'get' => $_GET,
    'post' => $_POST,
    'raw_input' => file_get_contents('php://input'),
    'json_decoded' => json_decode(file_get_contents('php://input'), true),
    'session' => isset($_SESSION) ? $_SESSION : 'No session',
    'cookies' => $_COOKIE
];

// Сохраняем в лог
file_put_contents($logFile, json_encode($debugInfo, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n\n", FILE_APPEND);

// Возвращаем ответ
echo json_encode([
    'success' => true,
    'message' => 'Debug info saved',
    'received' => $debugInfo
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
