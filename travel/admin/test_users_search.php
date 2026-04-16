<?php
require_once 'config/admin_config.php';
require_once '../config.php';

// Simulate search request
$_GET['search'] = 'test';
$_GET['page'] = 1;
$_GET['per_page'] = 10;

echo "Testing users search API...\n\n";

// Make request to API
$url = 'http://bearded-fox.ru/travel/admin/api/users/get_all_users.php?' . http_build_query($_GET);
echo "URL: $url\n\n";

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
echo "Response:\n";
echo $response;
echo "\n\n";

$data = json_decode($response, true);
if ($data && isset($data['users'])) {
    echo "Found " . count($data['users']) . " users\n";
    echo "Total: " . $data['pagination']['total'] . "\n";
}
