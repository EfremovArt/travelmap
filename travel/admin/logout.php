<?php
require_once __DIR__ . '/config/admin_config.php';

// Выполняем выход из системы
adminLogout();

// Перенаправляем на страницу входа
header('Location: /travel/admin/login.php');
exit;
