<?php
require_once 'config/admin_config.php';
require_once '../config.php';

$pdo = connectToDatabase();
$stmt = $pdo->query("SHOW COLUMNS FROM locations");
$columns = $stmt->fetchAll(PDO::FETCH_COLUMN);

echo "Поля в таблице locations:\n";
print_r($columns);

// Также проверим данные
$stmt = $pdo->query("SELECT * FROM locations LIMIT 1");
$data = $stmt->fetch(PDO::FETCH_ASSOC);
echo "\nПример данных:\n";
print_r($data);
