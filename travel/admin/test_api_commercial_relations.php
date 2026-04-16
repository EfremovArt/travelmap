<?php
// Тестируем API напрямую
$commercialPostId = 54;
$url = "http://" . $_SERVER['HTTP_HOST'] . dirname($_SERVER['PHP_SELF']) . "/api/posts/get_commercial_post_relations.php?commercial_post_id=" . $commercialPostId;

echo "Тестирование API: $url\n\n";

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HEADER, true);

// Копируем cookies для авторизации
if (isset($_SERVER['HTTP_COOKIE'])) {
    curl_setopt($ch, CURLOPT_COOKIE, $_SERVER['HTTP_COOKIE']);
}

$response = curl_exec($ch);
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$header = substr($response, 0, $headerSize);
$body = substr($response, $headerSize);

curl_close($ch);

echo "=== HEADERS ===\n";
echo $header . "\n";

echo "\n=== BODY ===\n";
echo $body . "\n";

echo "\n=== JSON DECODE ===\n";
$json = json_decode($body, true);
if ($json) {
    print_r($json);
} else {
    echo "Ошибка декодирования JSON: " . json_last_error_msg() . "\n";
}
