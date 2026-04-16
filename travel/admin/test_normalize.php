<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h2>Testing normalizeImageUrl function</h2>";

require_once '../config.php';

echo "<p>Config loaded</p>";

if (function_exists('normalizeImageUrl')) {
    echo "<p style='color: green;'>✅ Function normalizeImageUrl exists!</p>";
    
    $tests = [
        'uploads/profile_images/123.jpg',
        '/travel/uploads/profile_images/123.jpg',
        'https://example.com/image.jpg',
        null,
        ''
    ];
    
    echo "<h3>Test results:</h3>";
    foreach ($tests as $test) {
        $result = normalizeImageUrl($test);
        echo "<p><strong>Input:</strong> " . var_export($test, true) . "<br>";
        echo "<strong>Output:</strong> " . var_export($result, true) . "</p>";
    }
} else {
    echo "<p style='color: red;'>❌ Function normalizeImageUrl NOT found!</p>";
}

echo "<hr>";
echo "<h3>Testing API call:</h3>";
echo "<p>Calling get_post_details.php...</p>";

$apiUrl = "https://bearded-fox.ru/travel/admin/api/posts/get_post_details.php?photo_id=213";
echo "<p><a href='$apiUrl' target='_blank'>Open API URL</a></p>";
