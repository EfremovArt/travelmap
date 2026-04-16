<?php
require_once 'config/admin_config.php';
adminRequireAuth();

$logFile = __DIR__ . '/../user/request_debug.log';

if (file_exists($logFile)) {
    unlink($logFile);
}

echo json_encode(['success' => true]);
